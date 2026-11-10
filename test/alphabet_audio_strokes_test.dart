import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_drawing/path_drawing.dart';
import 'package:qtjp_mobile/core/theme/qtjp_theme.dart';
import 'package:qtjp_mobile/screens/alphabet/data/kana_stroke_repository.dart';
import 'package:qtjp_mobile/screens/alphabet/models/kana.dart';
import 'package:qtjp_mobile/screens/alphabet/services/kana_speech.dart';
import 'package:qtjp_mobile/screens/alphabet/widgets/kana_detail_sheet.dart';
import 'package:qtjp_mobile/screens/alphabet/widgets/kana_stroke_viewer.dart';

import 'helpers/settle_kana_detail.dart';

class ControlledSpeech implements KanaSpeech {
  final List<String> spoken = [];
  Completer<void>? pending;
  int stops = 0;
  bool unavailable = false;

  @override
  Future<void> speak(String text) {
    if (unavailable) {
      throw const KanaSpeechFailure('Thiết bị chưa có giọng đọc tiếng Nhật.');
    }
    spoken.add(text);
    pending = Completer<void>();
    return pending!.future;
  }

  @override
  Future<void> stop() async {
    stops++;
    pending?.complete();
    pending = null;
  }
}

class RetryStrokeRepository implements KanaStrokeRepository {
  final _bundled = BundledKanaStrokeRepository();
  int calls = 0;

  @override
  Future<List<KanaGlyph>> load(String text) async {
    if (++calls == 1) throw StateError('Asset load failure');
    return _bundled.load(text);
  }
}

Widget sheetHost({
  required ControlledSpeech speech,
  KanaStrokeRepository? repository,
  Kana? kana,
  TextScaler textScaler = TextScaler.noScaling,
}) => MaterialApp(
  theme: QTJPTheme.light,
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: textScaler),
      child: Scaffold(
        body: KanaDetailSheet(
          initialKana: kana ?? allKana.first,
          script: KanaScript.hiragana,
          speech: speech,
          strokeRepository: repository,
        ),
      ),
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'offline strokes cover every character and compound in both kana scripts',
    () async {
      final repository = BundledKanaStrokeRepository();
      final characters = <String>{};
      for (final script in KanaScript.values) {
        for (final kana in allKana) {
          final text = kana.text(script);
          final glyphs = await repository.load(text);
          expect(glyphs.map((glyph) => glyph.character).join(), text);
          for (final glyph in glyphs) {
            if (!characters.add(glyph.character)) continue;
            expect(glyph.paths, isNotEmpty);
            expect(glyph.numbers.length, glyph.paths.length);
            for (final source in glyph.paths) {
              final path = parseSvgPathData(source);
              expect(
                path.computeMetrics().fold(
                  0.0,
                  (sum, metric) => sum + metric.length,
                ),
                greaterThan(0),
                reason: 'Non-empty stroke for ${glyph.character}',
              );
            }
          }
        }
      }
      expect(characters.length, 148);
      expect((await repository.load('あ')).single.paths.length, 3);
    },
  );

  group('device Japanese speech', () {
    const channel = MethodChannel('flutter_tts');
    final calls = <MethodCall>[];
    bool available = true;
    Completer<bool>? availability;

    setUp(() {
      calls.clear();
      available = true;
      availability = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'isLanguageAvailable') {
              return availability == null
                  ? available
                  : await availability!.future;
            }
            return 1;
          });
    });

    tearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    test(
      'configures ja-JP and sends kana rather than romaji to the native engine',
      () async {
        final speech = DeviceKanaSpeech();
        await speech.speak('きゃ');
        expect(
          calls.firstWhere((call) => call.method == 'setLanguage').arguments,
          'ja-JP',
        );
        expect(
          calls
              .firstWhere((call) => call.method == 'awaitSpeakCompletion')
              .arguments,
          isTrue,
        );
        final args = calls
            .singleWhere((call) => call.method == 'speak')
            .arguments;
        expect(args is Map ? args['text'] : args, 'きゃ');
        await speech.stop();
      },
    );

    test('missing Japanese voice is recoverable after a retry', () async {
      final speech = DeviceKanaSpeech();
      available = false;
      await expectLater(speech.speak('あ'), throwsA(isA<KanaSpeechFailure>()));
      expect(calls.where((call) => call.method == 'speak'), isEmpty);
      available = true;
      await speech.speak('あ');
      expect(calls.where((call) => call.method == 'speak'), hasLength(1));
    });

    test(
      'stop prevents late playback while voice configuration is still pending',
      () async {
        availability = Completer<bool>();
        final speech = DeviceKanaSpeech();
        final pending = speech.speak('あ');
        await Future<void>.delayed(Duration.zero);
        await speech.stop();
        availability!.complete(true);
        await pending;
        expect(calls.where((call) => call.method == 'speak'), isEmpty);
      },
    );
  });

  testWidgets('speech stops on character change, backgrounding and disposal', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final speech = ControlledSpeech();
    await prepareKanaAssets(tester);
    await tester.pumpWidget(sheetHost(speech: speech));
    await settleKanaDetail(tester);
    await tester.tap(find.byKey(const ValueKey('kana-speak')));
    await tester.pumpAndSettle();
    expect(speech.spoken, ['あ']);
    expect(find.text('Dừng đọc'), findsOneWidget);

    await tester.tap(find.byTooltip('Chữ tiếp'));
    await tester.pumpAndSettle();
    expect(speech.stops, 1);
    expect(find.text('Nghe cách đọc'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('kana-speak')));
    await tester.pumpAndSettle();
    expect(speech.spoken, ['あ', 'い']);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(speech.stops, 2);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(speech.stops, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'speech and stroke errors show retryable feedback without disabling the sheet',
    (tester) async {
      final speech = ControlledSpeech()..unavailable = true;
      await prepareKanaAssets(tester);
      await tester.pumpWidget(
        sheetHost(speech: speech, repository: RetryStrokeRepository()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Không thể mở hướng dẫn nét viết.'), findsOneWidget);
      final retry = find.text('Tải lại nét viết');
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await settleKanaDetail(tester);
      expect(find.byType(KanaStrokeViewer), findsOneWidget);

      final speak = find.byKey(const ValueKey('kana-speak'));
      await tester.ensureVisible(speak);
      await tester.tap(speak);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('kana-speech-error')), findsOneWidget);
      expect(find.text('Nghe cách đọc'), findsOneWidget);
      speech.unavailable = false;
      await tester.tap(speak);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('kana-speech-error')), findsNothing);
      expect(speech.spoken, ['あ']);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'compound stroke controls fit a landscape screen with larger text',
    (tester) async {
      tester.view.physicalSize = const Size(640, 320);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await prepareKanaAssets(tester);
      await tester.pumpWidget(
        sheetHost(
          speech: ControlledSpeech(),
          kana: allKana.last,
          textScaler: const TextScaler.linear(1.5),
        ),
      );
      await settleKanaDetail(tester);
      final viewer = tester.widget<KanaStrokeViewer>(
        find.byType(KanaStrokeViewer),
      );
      expect(viewer.glyphs, hasLength(2));
      final replay = find.byKey(const ValueKey('kana-stroke-replay'));
      await tester.ensureVisible(replay);
      await tester.tap(replay);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Tạm dừng'), findsOneWidget);
      final pause = find.text('Tạm dừng');
      await tester.ensureVisible(pause);
      await tester.tap(pause);
      await tester.pump();
      expect(find.text('Tiếp tục'), findsOneWidget);
      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
