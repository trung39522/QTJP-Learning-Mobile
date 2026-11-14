import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/theme/qtjp_colors.dart';

class DictionaryVoice {
  static const channel = MethodChannel('qtjp/dictionary_input');
  Future<List<String>> recognize(String language) async {
    try {
      final results = await channel.invokeListMethod<String>(
        'recognizeSpeech',
        {'language': language},
      );
      return (results ?? [])
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toSet()
          .take(5)
          .toList();
    } on MissingPluginException {
      throw const FormatException(
        'Tra giọng nói chưa khả dụng trên thiết bị này. Bạn có thể dùng micro của bàn phím.',
      );
    } on PlatformException catch (error) {
      throw FormatException(
        error.message ?? 'Không thể nhận dạng giọng nói. Hãy thử lại.',
      );
    }
  }
}

class DictionaryHandwritingSheet extends StatefulWidget {
  const DictionaryHandwritingSheet({super.key});
  @override
  State<DictionaryHandwritingSheet> createState() =>
      _DictionaryHandwritingSheetState();
}

class _DictionaryHandwritingSheetState
    extends State<DictionaryHandwritingSheet> {
  final _text = TextEditingController();
  WebViewController? _web;
  Timer? _timeout;
  bool _ready = false;
  String? _error;
  List<String> _candidates = [];
  int _loadRevision = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_web == null) unawaited(_load());
  }

  Future<void> _load() async {
    final revision = ++_loadRevision;
    _timeout?.cancel();
    setState(() {
      _ready = false;
      _error = null;
      _candidates = [];
    });
    try {
      final background = context.qtjp.surface;
      final ink = context.qtjp.heading;
      final web = WebViewController();
      _web = web;
      await web.setJavaScriptMode(JavaScriptMode.unrestricted);
      await web.setBackgroundColor(background);
      await web.addJavaScriptChannel(
        'QTJPInput',
        onMessageReceived: (message) {
          if (!mounted || revision != _loadRevision) return;
          try {
            final data = jsonDecode(message.message) as Map<String, dynamic>;
            if (data['ready'] == true) {
              _timeout?.cancel();
              setState(() {
                _ready = true;
                _error = null;
              });
            } else if (data['error'] is String) {
              setState(() => _error = data['error'] as String);
            } else if (data['candidates'] is List) {
              setState(() {
                _candidates = (data['candidates'] as List)
                    .whereType<String>()
                    .where(
                      (s) =>
                          s.runes.length == 1 &&
                          RegExp(r'[\u3040-\u30ff\u3400-\u9fff]').hasMatch(s),
                    )
                    .toSet()
                    .take(12)
                    .toList();
                _error = _candidates.isEmpty
                    ? 'Chưa nhận rõ chữ. Hãy viết to hơn rồi thử lại.'
                    : null;
              });
            }
          } catch (_) {
            setState(
              () => _error = 'Chưa đọc được kết quả nhận dạng. Hãy thử lại.',
            );
          }
        },
      );
      await web.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) =>
              request.url == 'about:blank' ||
                  request.url.startsWith('data:text/html')
              ? NavigationDecision.navigate
              : NavigationDecision.prevent,
        ),
      );
      if (!mounted || revision != _loadRevision) return;
      await web.loadHtmlString(
        _canvasHtml(
          '#${background.toARGB32().toRadixString(16).substring(2)}',
          '#${ink.toARGB32().toRadixString(16).substring(2)}',
        ),
      );
      if (!mounted || revision != _loadRevision) return;
      setState(() {});
      _timeout = Timer(const Duration(seconds: 25), () {
        if (mounted && revision == _loadRevision && !_ready) {
          setState(
            () => _error =
                'Không tải được bộ nhận dạng. Kiểm tra Internet rồi thử lại.',
          );
        }
      });
    } catch (_) {
      if (mounted && revision == _loadRevision) {
        setState(() => _error = 'Không mở được bảng viết trên thiết bị này.');
      }
    }
  }

  Future<void> _command(String command) async {
    try {
      await _web?.runJavaScript('qtjp.$command()');
      if (mounted && command != 'recognize') {
        setState(() {
          _candidates = [];
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Chưa xử lý được nét vẽ. Hãy thử lại.');
      }
    }
  }

  @override
  void dispose() {
    _loadRevision++;
    _timeout?.cancel();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Tra chữ viết tay',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                tooltip: 'Đóng',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Text(
            'Viết từng chữ, chọn kết quả để ghép thành từ.',
            style: TextStyle(color: context.qtjp.muted),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _text,
            maxLength: 40,
            decoration: const InputDecoration(labelText: 'Từ cần tra'),
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) Navigator.pop(context, value.trim());
            },
          ),
          if (!_ready && _error == null) const LinearProgressIndicator(),
          SizedBox.square(
            dimension: 256,
            child: _web == null
                ? const SizedBox.shrink()
                : WebViewWidget(
                    controller: _web!,
                    gestureRecognizers: {
                      Factory<OneSequenceGestureRecognizer>(
                        () => EagerGestureRecognizer(),
                      ),
                    },
                  ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (!_ready && _error != null)
            TextButton(
              onPressed: _load,
              child: const Text('Tải lại bộ nhận dạng'),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final candidate in _candidates)
                ActionChip(
                  label: Text(candidate, style: const TextStyle(fontSize: 24)),
                  onPressed: () {
                    if (_text.text.runes.length >= 40) return;
                    _text.text += candidate;
                    _text.selection = TextSelection.collapsed(
                      offset: _text.text.length,
                    );
                    unawaited(_command('erase'));
                  },
                ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              TextButton.icon(
                onPressed: _ready ? () => _command('undo') : null,
                icon: const Icon(Icons.undo),
                label: const Text('Hoàn tác'),
              ),
              TextButton.icon(
                onPressed: _ready ? () => _command('erase') : null,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Xóa nét'),
              ),
              FilledButton.tonal(
                onPressed: _ready ? () => _command('recognize') : null,
                child: const Text('Nhận dạng'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                if (_text.text.trim().isNotEmpty) {
                  Navigator.pop(context, _text.text.trim());
                }
              },
              child: const Text('Tra từ này'),
            ),
          ),
        ],
      ),
    ),
  );
}

// Same MIT recognizer as React; recognition runs locally inside the WebView.
String _canvasHtml(String background, String ink) =>
    '''
<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
<style>html,body{margin:0;background:$background;overflow:hidden}canvas{touch-action:none;display:block;background:linear-gradient(transparent 49.6%,#8393a333 50%,transparent 50.4%),linear-gradient(90deg,transparent 49.6%,#8393a333 50%,transparent 50.4%);border:1px solid #8393a355;box-sizing:border-box;border-radius:16px}</style></head>
<body><canvas id="writing" width="256" height="256"></canvas><script>
const send = data => QTJPInput.postMessage(JSON.stringify(data));
let count=0;
const canvas=document.getElementById('writing');
window.qtjp={
 erase(){KanjiCanvas.erase('writing');count=0},
 undo(){KanjiCanvas.deleteLast('writing');count=Math.max(0,count-1)},
 recognize(){if(!count){send({error:'Hãy viết một ký tự trong khung.'});return}try{const r=KanjiCanvas.recognize('writing');send({candidates:Array.isArray(r)?r:Array.from(r||'')})}catch(e){send({error:'Không nhận dạng được. Hãy viết lại chữ.'})}}
};
canvas.addEventListener('mousedown',()=>count++);canvas.addEventListener('touchstart',()=>count++,{passive:true});
function load(url){return new Promise((resolve,reject)=>{const s=document.createElement('script');s.src=url;s.onload=resolve;s.onerror=reject;document.head.appendChild(s)})}
load('https://cdn.jsdelivr.net/gh/asdfjkl/kanjicanvas@master/docs/resources/javascript/kanji-canvas.min.js')
.then(()=>load('https://cdn.jsdelivr.net/gh/asdfjkl/kanjicanvas@master/docs/resources/javascript/ref-patterns.js'))
.then(()=>{KanjiCanvas.strokeColors=Array(80).fill('$ink');canvas.dataset.strokeNumbers='false';KanjiCanvas.init('writing');send({ready:true})})
.catch(()=>send({error:'Không tải được bộ nhận dạng. Kiểm tra Internet rồi thử lại.'}));
</script></body></html>''';
