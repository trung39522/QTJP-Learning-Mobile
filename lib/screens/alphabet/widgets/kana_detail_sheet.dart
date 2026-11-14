import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/qtjp_colors.dart';
import '../data/kana_stroke_repository.dart';
import '../models/kana.dart';
import '../services/kana_speech.dart';
import 'kana_stroke_viewer.dart';

class KanaDetailSheet extends StatefulWidget {
  const KanaDetailSheet({
    required this.initialKana,
    required this.script,
    this.speech,
    this.strokeRepository,
    super.key,
  });

  final Kana initialKana;
  final KanaScript script;
  final KanaSpeech? speech;
  final KanaStrokeRepository? strokeRepository;

  @override
  State<KanaDetailSheet> createState() => _KanaDetailSheetState();
}

class _KanaDetailSheetState extends State<KanaDetailSheet>
    with WidgetsBindingObserver {
  late int _index;
  late final KanaSpeech _speech;
  late final KanaStrokeRepository _repository;
  late Future<List<KanaGlyph>> _strokeData;
  int _speechOperation = 0;
  bool _reading = false;
  String? _speechError;

  Kana get _current => allKana[_index];
  String get _text => _current.text(widget.script);

  @override
  void initState() {
    super.initState();
    _index = allKana.indexWhere(
      (kana) => kana.hiragana == widget.initialKana.hiragana,
    );
    if (_index < 0) _index = 0;
    _speech = widget.speech ?? DeviceKanaSpeech();
    _repository = widget.strokeRepository ?? BundledKanaStrokeRepository();
    _strokeData = _repository.load(_text);
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> _stopEngine() async {
    try {
      await _speech.stop();
    } catch (_) {
      // Sheet navigation/teardown must not fail if an engine disappears.
    }
  }

  void _stopReading() {
    _speechOperation++;
    if (mounted) setState(() => _reading = false);
    unawaited(_stopEngine());
  }

  void _move(int delta) {
    _stopReading();
    setState(() {
      _index = (_index + delta + allKana.length) % allKana.length;
      _speechError = null;
      _strokeData = _repository.load(_text);
    });
  }

  Future<void> _read() async {
    if (_reading) {
      _stopReading();
      return;
    }
    final operation = ++_speechOperation;
    setState(() {
      _reading = true;
      _speechError = null;
    });
    try {
      await _speech.speak(_text);
    } catch (error) {
      if (mounted && operation == _speechOperation) {
        setState(
          () => _speechError = error is KanaSpeechFailure
              ? error.message
              : 'Không thể phát âm lúc này. Vui lòng thử lại.',
        );
      }
    } finally {
      if (mounted && operation == _speechOperation) {
        setState(() => _reading = false);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _stopReading();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _speechOperation++;
    unawaited(_stopEngine());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final counterpart = widget.script == KanaScript.hiragana
        ? _current.katakana
        : _current.hiragana;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.88,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              0,
              20,
              20 + MediaQuery.viewPaddingOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton.filledTonal(
                      tooltip: 'Chữ trước',
                      onPressed: () => _move(-1),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    Expanded(
                      child: Text(
                        '${_index + 1} / ${allKana.length}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.qtjp.muted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Đóng'),
                    ),
                    IconButton.filledTonal(
                      tooltip: 'Chữ tiếp',
                      onPressed: () => _move(1),
                      icon: const Icon(Icons.arrow_forward_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _text,
                  key: const ValueKey('kana-detail-character'),
                  style: TextStyle(
                    fontSize: 48,
                    color: context.qtjp.heading,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  _current.romaji,
                  key: const ValueKey('kana-detail-romaji'),
                  style: TextStyle(
                    fontSize: 24,
                    color: context.qtjp.blue,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${widget.script == KanaScript.hiragana ? 'Katakana' : 'Hiragana'}: $counterpart',
                  style: TextStyle(color: context.qtjp.muted),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  key: const ValueKey('kana-speak'),
                  onPressed: _read,
                  style: FilledButton.styleFrom(
                    backgroundColor: QTJPColors.navy,
                  ),
                  icon: Icon(
                    _reading ? Icons.stop_rounded : Icons.volume_up_rounded,
                  ),
                  label: Text(_reading ? 'Dừng đọc' : 'Nghe cách đọc'),
                ),
                if (_speechError != null) ...[
                  const SizedBox(height: 12),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _speechError!,
                      key: const ValueKey('kana-speech-error'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: QTJPColors.red,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                FutureBuilder<List<KanaGlyph>>(
                  key: ValueKey(_text),
                  future: _strokeData,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(
                          semanticsLabel: 'Đang tải nét viết',
                        ),
                      );
                    }
                    if (snapshot.hasError || !snapshot.hasData) {
                      return Column(
                        children: [
                          const Text(
                            'Không thể mở hướng dẫn nét viết.',
                            textAlign: TextAlign.center,
                          ),
                          TextButton(
                            onPressed: () => setState(() {
                              _strokeData = _repository.load(_text);
                            }),
                            child: const Text('Tải lại nét viết'),
                          ),
                        ],
                      );
                    }
                    return KanaStrokeViewer(
                      key: ValueKey('strokes-$_text'),
                      glyphs: snapshot.data!,
                    );
                  },
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => showLicensePage(
                    context: context,
                    applicationName: 'QTJP Learning',
                  ),
                  child: Text(
                    'Nét viết: KanjiVG · CC BY-SA 3.0',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.qtjp.muted, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
