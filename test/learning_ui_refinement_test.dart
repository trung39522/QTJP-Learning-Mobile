import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtjp_mobile/app/app_controller.dart';
import 'package:qtjp_mobile/core/network/api_client.dart';
import 'package:qtjp_mobile/core/theme/qtjp_theme.dart';
import 'package:qtjp_mobile/screens/alphabet/services/kana_speech.dart';
import 'package:qtjp_mobile/screens/dictionary/dictionary_input_tools.dart';
import 'package:qtjp_mobile/screens/dictionary/dictionary_screen.dart';
import 'package:qtjp_mobile/screens/flashcard/data/flashcard_repository.dart';
import 'package:qtjp_mobile/screens/flashcard/flashcard_study_screen.dart';
import 'package:qtjp_mobile/screens/home/widgets/qtjp_home_hero.dart';
import 'package:qtjp_mobile/screens/home/widgets/home_feature_carousel.dart';
import 'package:qtjp_mobile/screens/home/models/home_feature_item.dart';
import 'package:qtjp_mobile/screens/home/widgets/home_feature_card.dart';

class TestSpeech implements KanaSpeech {
  final spoken = <String>[];
  @override
  Future<void> speak(String text) async => spoken.add(text);
  @override
  Future<void> stop() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'arc cards follow an unfinished swipe and return on cancellation',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeFeatureCarousel(
              features: homeFeatureItems,
              selectedLevel: 'N5',
              onFeatureTap: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final stage = find.byKey(const ValueKey('home-feature-carousel'));
      final active = find.byWidgetPredicate(
        (w) => w is HomeFeatureCard && w.isActive,
      );
      final before = tester.getCenter(active);
      final gesture = await tester.startGesture(tester.getCenter(stage));
      await gesture.moveBy(const Offset(-25, 0));
      await gesture.moveBy(const Offset(-80, 0));
      await tester.pump();
      expect(tester.getCenter(active).dx, lessThan(before.dx));
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(tester.getCenter(active).dx, closeTo(before.dx, .1));
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [320.0, 360.0, 393.0, 430.0]) {
    for (final dark in [false, true]) {
      testWidgets(
        'dictionary voice selection and real examples at $width dark=$dark',
        (tester) async {
          tester.view.physicalSize = Size(width, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final requests = <Uri>[];
          final speech = TestSpeech();
          final app = AppController(
            api: ApiClient(
              transport: (m, u, h, b) async {
                requests.add(u);
                return const ApiResponse(200, [
                  {
                    'word': 'じょうけん',
                    'kanji': '条件',
                    'hiragana': 'じょうけん',
                    'romaji': 'jouken',
                    'hanViet': 'ĐIỀU KIỆN',
                    'partOfSpeech': 'Danh từ',
                    'meaning': 'điều kiện; điều khoản',
                    'level': 'N3',
                    'examples': [
                      {
                        'japanese': '契約の条件',
                        'vietnamese': 'Điều khoản hợp đồng.',
                      },
                    ],
                  },
                ]);
              },
            ),
          );
          addTearDown(app.dispose);
          String? language;
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            DictionaryVoice.channel,
            (call) async {
              expect(call.method, 'recognizeSpeech');
              language = (call.arguments as Map)['language'] as String;
              return ['条件', '上限'];
            },
          );
          addTearDown(
            () => tester.binding.defaultBinaryMessenger
                .setMockMethodCallHandler(DictionaryVoice.channel, null),
          );
          await tester.pumpWidget(
            AppScope(
              controller: app,
              child: MaterialApp(
                theme: dark ? QTJPTheme.dark : QTJPTheme.light,
                home: DictionaryScreen(speech: speech),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('「ĐIỀU KIỆN」'), findsOneWidget);
          await tester.tap(find.text('VI'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Giọng nói'));
          await tester.pumpAndSettle();
          expect(language, 'vi-VN');
          await tester.tap(find.widgetWithText(SimpleDialogOption, '条件'));
          await tester.pumpAndSettle();
          expect(requests.last.queryParameters['keyword'], '条件');
          final sound = find.byTooltip('Phát âm tiếng Nhật');
          await tester.ensureVisible(sound);
          await tester.tap(sound);
          await tester.pumpAndSettle();
          expect(speech.spoken.single, 'じょうけん');
          final example = find.text('契約の条件');
          await tester.ensureVisible(example);
          await tester.pumpAndSettle();
          expect(find.text('Điều khoản hợp đồng.'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'cancelled voice makes no search and recognizer errors stay recoverable',
    (tester) async {
      var calls = 0;
      final app = AppController(
        api: ApiClient(
          transport: (m, u, h, b) async {
            calls++;
            return const ApiResponse(200, []);
          },
        ),
      );
      addTearDown(app.dispose);
      var fail = false;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        DictionaryVoice.channel,
        (_) async {
          if (fail) {
            throw PlatformException(
              code: 'unavailable',
              message: 'Không có bộ nhận dạng giọng nói.',
            );
          }
          return <String>[];
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          DictionaryVoice.channel,
          null,
        ),
      );
      await tester.pumpWidget(
        AppScope(
          controller: app,
          child: MaterialApp(
            theme: QTJPTheme.light,
            home: const DictionaryScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Giọng nói'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.byType(SimpleDialog), findsNothing);
      fail = true;
      await tester.tap(find.text('Giọng nói'));
      await tester.pumpAndSettle();
      expect(find.text('Không có bộ nhận dạng giọng nói.'), findsOneWidget);
      expect(calls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'flashcard reverses, flips and opens vocabulary without recording a grade',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final deck = (await const DemoFlashcardRepository().getDecks('N5')).first;
      var saves = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: QTJPTheme.light,
          home: FlashcardStudyScreen(
            deck: deck,
            onAnswer: (_, _) async {
              saves++;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Việt → Nhật'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('study-word'))).data,
        deck.words.first.meaning,
      );
      final flip = find.byKey(const ValueKey('study-flip'));
      await tester.ensureVisible(flip);
      await tester.tap(flip);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const ValueKey('study-meaning')), findsNothing);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('study-meaning')), findsOneWidget);
      await tester.tap(find.byTooltip('Danh sách từ vựng'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('study-vocabulary-list')),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Về lật thẻ'));
      await tester.pumpAndSettle();
      expect(find.text('Thẻ 1 / 5'), findsOneWidget);
      expect(saves, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'home orbit moves with a finger, rotates by button and retains feature actions',
    (tester) async {
      String? opened;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: QTJPHomeHero(
                onPrimaryPressed: () {},
                onAlphabetPressed: () {},
                onFeaturePressed: (id) => opened = id,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final orbit = find.byKey(const ValueKey('home-feature-orbit'));
      await tester.ensureVisible(orbit);
      await tester.pumpAndSettle();
      final label = find.descendant(of: orbit, matching: find.text('Từ điển'));
      final before = tester.getCenter(label);
      final bounds = tester.getRect(orbit);
      final drag = await tester.startGesture(bounds.center);
      await drag.moveBy(const Offset(70, 0));
      await drag.moveBy(const Offset(25, 0));
      await tester.pump();
      expect(tester.getCenter(label), isNot(before));
      await drag.up();
      await tester.pumpAndSettle();
      final afterDrag = tester.getCenter(label);
      await tester.tap(find.byTooltip('Xoay vòng chức năng'));
      await tester.pumpAndSettle();
      expect(tester.getCenter(label), isNot(afterDrag));
      await tester.tap(label);
      await tester.pumpAndSettle();
      expect(opened, 'dictionary');
      expect(tester.takeException(), isNull);
    },
  );
}
