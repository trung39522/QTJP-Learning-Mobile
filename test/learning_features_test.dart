import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtjp_mobile/core/theme/qtjp_theme.dart';
import 'package:qtjp_mobile/main.dart';
import 'package:qtjp_mobile/screens/flashcard/data/flashcard_repository.dart';
import 'package:qtjp_mobile/screens/flashcard/flashcard_screen.dart';
import 'package:qtjp_mobile/screens/flashcard/models/flashcard_deck.dart';

import 'helpers/settle_kana_detail.dart';

Future<void> tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void narrowScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

class RetryRepository implements FlashcardRepository {
  int calls = 0;

  @override
  Future<List<FlashcardWord>> getWords(FlashcardDeck deck) async => deck.words;

  @override
  Future<void> saveProgress(FlashcardWord word, bool remembered) async {}

  @override
  Future<List<FlashcardDeck>> getDecks(String level) async {
    if (++calls == 1) throw StateError('Sample load failure');
    return const DemoFlashcardRepository().getDecks(level);
  }
}

void main() {
  testWidgets(
    'alphabet route switches scripts, hides romaji and browses details at 320px',
    (tester) async {
      narrowScreen(tester);
      await prepareKanaAssets(tester);
      await tester.pumpWidget(const QTJPMobile());
      final alphabetButton = find.widgetWithText(
        OutlinedButton,
        'Học bảng chữ cái',
      );
      await tester.ensureVisible(alphabetButton);
      await tester.tap(alphabetButton);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('kana-あ')), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Katakana'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('kana-あ')), findsNothing);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(find.text('a'), findsNothing);

      final kana = find.byKey(const ValueKey('kana-ア'));
      await tester.ensureVisible(kana);
      await tester.tap(kana);
      await settleKanaDetail(tester);
      expect(find.text('Hiragana: あ'), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('kana-detail-romaji')))
            .data,
        'a',
      );
      await tester.tap(find.byTooltip('Chữ tiếp'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('kana-detail-character')))
            .data,
        'イ',
      );
      await tester.tap(find.byTooltip('Chữ trước'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Chữ trước'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('kana-detail-character')))
            .data,
        'ピョ',
      );
      await tester.tap(find.text('Đóng'));
      await tester.pumpAndSettle();
      expect(find.text('a'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'sample study flips, grades, reviews missed words and restarts at 320px',
    (tester) async {
      narrowScreen(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: QTJPTheme.light,
          home: const FlashcardScreen(
            initialLevel: 'N3',
            repository: DemoFlashcardRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Chưa có bộ thẻ mẫu cho N3'), findsOneWidget);
      final sampleButton = find.text('Khám phá bộ mẫu N5');
      await tester.ensureVisible(sampleButton);
      await tester.tap(sampleButton);
      await tester.pumpAndSettle();
      await tapKey(tester, 'demo-n5-learning');

      expect(find.byKey(const ValueKey('study-meaning')), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('study-remembered')),
            )
            .onPressed,
        isNull,
      );
      for (var index = 0; index < 5; index++) {
        await tapKey(tester, 'study-flip');
        expect(find.byKey(const ValueKey('study-meaning')), findsOneWidget);
        await tapKey(tester, index == 0 ? 'study-forgot' : 'study-remembered');
      }
      expect(find.text('Đã nhớ: 4 / 5'), findsOneWidget);
      expect(find.text('Chưa nhớ: 1'), findsOneWidget);
      await tapKey(tester, 'study-review');
      expect(find.text('Thẻ 1 / 1'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('study-word'))).data,
        '私',
      );
      await tapKey(tester, 'study-flip');
      await tapKey(tester, 'study-remembered');
      expect(find.text('Đã nhớ: 1 / 1'), findsOneWidget);
      expect(find.byKey(const ValueKey('study-review')), findsNothing);
      await tapKey(tester, 'study-restart');
      expect(find.text('Thẻ 1 / 5'), findsOneWidget);
      expect(find.byKey(const ValueKey('study-meaning')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('deck loading recovers after a failed request', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: QTJPTheme.light,
        home: FlashcardScreen(
          initialLevel: 'N5',
          repository: RetryRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Không thể tải dữ liệu. Vui lòng thử lại.'),
      findsOneWidget,
    );
    final retry = find.text('Thử lại');
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('demo-n5-learning')), findsOneWidget);
    expect(find.text('Không thể tải dữ liệu. Vui lòng thử lại.'), findsNothing);
  });
}
