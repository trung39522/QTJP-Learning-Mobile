import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import 'video_repository.dart';

class VideoControls {
  Future<void> Function(String method, num? value)? invoke;
  Future<void> play() async {
    await invoke?.call('play', null);
  }

  Future<void> pause() async {
    await invoke?.call('pause', null);
  }

  Future<void> seek(int milliseconds) async {
    if (milliseconds >= 0) await invoke?.call('seek', milliseconds / 1000);
  }
}

String videoPlayerOrigin(String packageName) {
  final id = packageName.toLowerCase();
  if (!RegExp(r'^[a-z0-9_]+(?:\.[a-z0-9_]+)+$').hasMatch(id)) {
    throw const FormatException('Invalid application identifier');
  }
  return 'https://$id';
}

/// This HTML contains only the provider's documented media player. No QTJP
/// website, token, AI answer, or user-entered URL is loaded into the WebView.
String videoPlayerHtml(LearningVideo video, String origin) {
  final id = jsonEncode(video.sourceId);
  final yt = video.platform == 'YOUTUBE';
  return '''<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="referrer" content="strict-origin-when-cross-origin"><style>html,body{padding:0;margin:0;height:100%;background:#000}iframe,#player{height:100%;width:100%;border:0}</style></head><body><div id="player"></div><script>
function emit(type,value){FlutterVideo.postMessage(JSON.stringify({type:type,value:value}));}
var player,ready=false;
window.qtjpCommand=function(method,value){
 if(!ready)return;
 ${yt ? "if(method==='play')player.playVideo();if(method==='pause')player.pauseVideo();if(method==='seek')player.seekTo(value,true);" : "var type=method==='seek'?'seekTo':method;player.contentWindow.postMessage({'x-tiktok-player':true,type:type,value:value},'https://www.tiktok.com');"}
};
${yt ? '''function onYouTubeIframeAPIReady(){player=new YT.Player('player',{videoId:$id,width:'100%',height:'100%',playerVars:{playsinline:1,rel:0,origin:${jsonEncode(origin)}},events:{onReady:function(){ready=true;emit('ready',true);},onError:function(event){emit('error',String(event.data));}}});}
var script=document.createElement('script');script.src='https://www.youtube.com/iframe_api';script.onerror=function(){emit('error','network');};document.head.appendChild(script);
setInterval(function(){if(ready)emit('time',player.getCurrentTime());},250);''' : '''player=document.createElement('iframe');player.src='https://www.tiktok.com/player/v1/'+$id+'?controls=1&progress_bar=1&play_button=1&timestamp=1&autoplay=0';player.allow='autoplay; encrypted-media; fullscreen';player.setAttribute('allowfullscreen','');document.getElementById('player').replaceWith(player);
window.addEventListener('message',function(event){if(event.origin!=='https://www.tiktok.com'||event.source!==player.contentWindow)return;var data=event.data;if(!data||data['x-tiktok-player']!==true)return;if(data.type==='onPlayerReady'){ready=true;emit('ready',true);}if(data.type==='onCurrentTime'){var time=typeof data.value==='number'?data.value:data.value.currentTime;emit('time',time);}if(data.type==='onError'||data.type==='onPlayerError')emit('error','provider');});'''}
</script></body></html>''';
}

class LearningVideoPlayer extends StatefulWidget {
  const LearningVideoPlayer({
    required this.video,
    required this.controls,
    required this.onPosition,
    super.key,
  });
  final LearningVideo video;
  final VideoControls controls;
  final ValueChanged<int> onPosition;
  @override
  State<LearningVideoPlayer> createState() => _LearningVideoPlayerState();
}

class _LearningVideoPlayerState extends State<LearningVideoPlayer>
    with WidgetsBindingObserver {
  WebViewController? _web;
  Timer? _deadline;
  String? _error;
  bool _ready = false;
  int _generation = 0;
  bool _loading = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  Future<void> _load() async {
    if (_loading) return;
    final generation = ++_generation;
    if (kIsWeb ||
        ![
          TargetPlatform.android,
          TargetPlatform.iOS,
        ].contains(defaultTargetPlatform)) {
      setState(() => _error = 'Trình phát này dành cho Android/iOS.');
      return;
    }
    try {
      _loading = true;
      // YouTube requires HTTPS identity for the installed app in Referer.
      // Using the HTTP/loopback backend origin can cause player error 153.
      final info = await PackageInfo.fromPlatform();
      if (!mounted || generation != _generation) return;
      final origin = videoPlayerOrigin(info.packageName);
      if (_web != null) {
        try {
          await _web!.runJavaScript('window.qtjpCommand("pause",null);');
        } catch (_) {
          /* A failed old page must not block a fresh player. */
        }
      }
      final web = WebViewController.fromPlatformCreationParams(
        WebViewPlatform.instance is WebKitWebViewPlatform
            ? WebKitWebViewControllerCreationParams(
                allowsInlineMediaPlayback: true,
                mediaTypesRequiringUserAction: const {},
              )
            : const PlatformWebViewControllerCreationParams(),
      );
      if (web.platform is AndroidWebViewController) {
        await (web.platform as AndroidWebViewController)
            .setMediaPlaybackRequiresUserGesture(false);
      }
      await web.setJavaScriptMode(JavaScriptMode.unrestricted);
      await web.addJavaScriptChannel(
        'FlutterVideo',
        onMessageReceived: (message) {
          if (!mounted ||
              generation != _generation ||
              message.message.length > 2048) {
            return;
          }
          try {
            final data = jsonDecode(message.message);
            if (data is! Map) return;
            if (data['type'] == 'ready') {
              _deadline?.cancel();
              setState(() {
                _ready = true;
                _error = null;
              });
            }
            if (data['type'] == 'error') {
              _deadline?.cancel();
              setState(
                () => _error = data['value']?.toString() == '153'
                    ? 'YouTube chưa xác nhận được trình phát của ứng dụng (mã 153). Hãy cập nhật ứng dụng và tải lại.'
                    : 'Nhà cung cấp chưa phát được video này (hạn chế nhúng, riêng tư, khu vực hoặc lỗi mạng). Mã: ${data['value'] ?? 'không rõ'}.',
              );
            }
            final time = data['value'];
            if (data['type'] == 'time' &&
                time is num &&
                time.isFinite &&
                time >= 0 &&
                time <= 86400) {
              widget.onPosition((time * 1000).round());
            }
          } on FormatException {
            /* Ignore malformed media events. */
          }
        },
      );
      await web.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            if (request.isMainFrame) {
              return request.url == '$origin/' || request.url == 'about:blank'
                  ? NavigationDecision.navigate
                  : NavigationDecision.prevent;
            }
            final uri = Uri.tryParse(request.url);
            return uri?.scheme == 'https'
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
          onWebResourceError: (error) {
            if (mounted &&
                generation == _generation &&
                error.isForMainFrame == true) {
              setState(
                () => _error = 'Không tải được trình phát video. Hãy thử lại.',
              );
            }
          },
        ),
      );
      if (!mounted || generation != _generation) return;
      widget.controls.invoke = (method, value) async {
        if (!mounted ||
            !_ready ||
            !['play', 'pause', 'seek'].contains(method)) {
          return;
        }
        try {
          await web.runJavaScript(
            'window.qtjpCommand(${jsonEncode(method)},${jsonEncode(value)});',
          );
        } catch (_) {
          /* Page may already be closing. */
        }
      };
      if (!mounted) return;
      setState(() => _web = web);
      await web.loadHtmlString(
        videoPlayerHtml(widget.video, origin),
        baseUrl: '$origin/',
      );
      if (!mounted || generation != _generation) return;
      _deadline = Timer(const Duration(seconds: 25), () {
        if (mounted && !_ready) {
          setState(
            () => _error =
                'Trình phát phản hồi quá lâu. Kiểm tra mạng và thử lại.',
          );
        }
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Chưa khởi tạo được trình phát trên thiết bị này.',
        );
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(widget.controls.pause());
  }

  @override
  void dispose() {
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    _deadline?.cancel();
    widget.controls.invoke = null;
    final web = _web;
    if (web != null) {
      unawaited(
        web
            .runJavaScript('window.qtjpCommand("pause",null);')
            .catchError((Object _) {}),
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox(
        height: widget.video.platform == 'TIKTOK' ? 360 : 240,
        child: _web == null
            ? _error == null
                  ? const Center(child: CircularProgressIndicator())
                  : const SizedBox.shrink()
            : WebViewWidget(controller: _web!),
      ),
      if (_error != null) ...[
        Text(_error!),
        TextButton(
          onPressed: _loading
              ? null
              : () {
                  _deadline?.cancel();
                  setState(() {
                    _error = null;
                    _ready = false;
                  });
                  unawaited(_load());
                },
          child: const Text('Tải lại trình phát'),
        ),
      ],
    ],
  );
}
