import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

abstract interface class KanaSpeech {
  Future<void> speak(String text);
  Future<void> stop();
}

class KanaSpeechFailure implements Exception {
  const KanaSpeechFailure(this.message);

  final String message;
}

class DeviceKanaSpeech implements KanaSpeech {
  DeviceKanaSpeech({FlutterTts? engine}) : _engine = engine ?? FlutterTts();

  final FlutterTts _engine;
  Future<void>? _configuration;
  int _request = 0;
  bool _hasRequestedSpeech = false;

  Future<void> _configure() async {
    if (await _engine.isLanguageAvailable('ja-JP') != true) {
      throw const KanaSpeechFailure(
        'Thiết bị chưa có giọng đọc tiếng Nhật. '
        'Hãy tải giọng tiếng Nhật trong cài đặt giọng nói của thiết bị rồi thử lại.',
      );
    }
    await _engine.setLanguage('ja-JP');
    await _engine.setSpeechRate(0.4);
    await _engine.setPitch(1);
    await _engine.setVolume(1);
    await _engine.awaitSpeakCompletion(true);
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      await _engine.setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [
        IosTextToSpeechAudioCategoryOptions.mixWithOthers,
      ], IosTextToSpeechAudioMode.voicePrompt);
    }
  }

  @override
  Future<void> speak(String text) async {
    _hasRequestedSpeech = true;
    final request = ++_request;
    try {
      await (_configuration ??= _configure()).timeout(
        const Duration(seconds: 10),
      );
      if (request != _request) return;
      await _engine.stop();
      if (request != _request) return;
      final result = await _engine
          .speak(text)
          .timeout(const Duration(seconds: 15));
      if (request == _request && result != 1) {
        throw const KanaSpeechFailure(
          'Không thể phát âm lúc này. Vui lòng thử lại.',
        );
      }
    } catch (error) {
      if (request != _request) return;
      _configuration = null;
      await stop();
      if (error is KanaSpeechFailure) rethrow;
      throw const KanaSpeechFailure(
        'Không thể phát âm trên thiết bị này. '
        'Hãy kiểm tra giọng đọc tiếng Nhật và thử lại.',
      );
    }
  }

  @override
  Future<void> stop() async {
    _request++; // Invalidates configuration/speech still waiting asynchronously.
    if (!_hasRequestedSpeech) return;
    try {
      await _engine.stop().timeout(const Duration(seconds: 2));
    } catch (_) {
      // Teardown must remain safe if the engine/plugin is unavailable.
    }
  }
}
