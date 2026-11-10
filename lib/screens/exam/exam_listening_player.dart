import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

abstract interface class ExamAudio {
  Stream<void> get completed;
  Future<bool> play(Uri uri, Duration position);
  Future<void> stop();
  Future<void> dispose();
}

class NativeExamAudio implements ExamAudio {
  final _player = AudioPlayer();
  int _operation = 0;
  @override
  Stream<void> get completed => _player.onPlayerComplete;
  @override
  Future<bool> play(Uri uri, Duration position) async {
    final operation = ++_operation;
    await _player.setSourceUrl(uri.toString());
    if (operation != _operation) return false;
    final duration = await _player.getDuration();
    if (operation != _operation) return false;
    if (duration != null && position >= duration) return false;
    await _player.seek(position);
    if (operation != _operation) return false;
    await _player.resume();
    return operation == _operation;
  }

  @override
  Future<void> stop() async {
    _operation++;
    await _player.stop();
  }

  @override
  Future<void> dispose() async {
    _operation++;
    await _player.dispose();
  }
}

class ExamListeningPlayer extends StatefulWidget {
  const ExamListeningPlayer({
    required this.uri,
    required this.startedAt,
    this.audioFactory,
    super.key,
  });
  final Uri uri;
  final DateTime startedAt;
  final ExamAudio Function()? audioFactory;
  @override
  State<ExamListeningPlayer> createState() => _ExamListeningPlayerState();
}

class _ExamListeningPlayerState extends State<ExamListeningPlayer>
    with WidgetsBindingObserver {
  late final _audio = widget.audioFactory?.call() ?? NativeExamAudio();
  StreamSubscription<void>? _complete;
  String _status = 'Đang chuẩn bị bài nghe…';
  bool _busy = false, _failed = false;
  int _operation = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _complete = _audio.completed.listen((_) {
      if (mounted) setState(() => _status = 'Đã phát hết bài nghe.');
    });
    unawaited(_play());
  }

  Future<void> _play() async {
    if (_busy) return;
    final operation = ++_operation;
    _busy = true;
    try {
      final elapsed = DateTime.now().difference(widget.startedAt);
      final played = await _audio
          .play(widget.uri, elapsed.isNegative ? Duration.zero : elapsed)
          .timeout(const Duration(seconds: 20));
      if (mounted && operation == _operation) {
        setState(() {
          _failed = false;
          _status = played
              ? 'Bài nghe đang phát theo thời gian thi.'
              : 'Đã hết thời lượng bài nghe.';
        });
      }
    } catch (_) {
      if (mounted && operation == _operation) await _stop();
      if (mounted && operation == _operation) {
        setState(() {
          _failed = true;
          _status = 'Không phát được bài nghe. Kiểm tra kết nối rồi bật lại. Đồng hồ thi vẫn chạy.';
        });
      }
    } finally {
      if (operation == _operation) _busy = false;
    }
  }

  Future<void> _stop() async {
    try {
      await _audio.stop();
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _operation++;
    _busy = false;
    if (state == AppLifecycleState.resumed) {
      unawaited(_play());
    } else {
      unawaited(_stop());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _operation++;
    unawaited(_complete?.cancel());
    unawaited(_audio.dispose().catchError((Object _) {}));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(_status),
          if (_failed)
            TextButton(
              onPressed: _busy ? null : _play,
              child: const Text('Bật lại âm thanh'),
            ),
        ],
      ),
    ),
  );
}
