import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtjp_mobile/core/theme/qtjp_theme.dart';
import 'package:qtjp_mobile/core/widgets/qtjp_reference_table.dart';
import 'package:qtjp_mobile/screens/exam/widgets/exam_skill_chart.dart';
import 'package:qtjp_mobile/screens/exam/widgets/exam_result_dashboard.dart';
import 'package:qtjp_mobile/screens/flashcard/flashcard_study_screen.dart';
import 'package:qtjp_mobile/screens/flashcard/models/flashcard_deck.dart';
import 'package:qtjp_mobile/screens/flashcard/vocabulary_practice_screen.dart';

final _deck = FlashcardDeck(
  id: 'test',
  name: 'Mẫu kính ngữ và sinh hoạt',
  level: 'N3',
  description: '',
  words: const [
    FlashcardWord(
      id: 1,
      word: '〜でございます',
      hiragana: 'でございます',
      romaji: 'degozaimasu',
      meaning: 'là (cách nói lịch sự, trang trọng)',
      example: 'こちらは受付でございます。',
      exampleVi: 'Đây là quầy tiếp tân.',
      partOfSpeech: 'Mẫu kính ngữ',
    ),
    FlashcardWord(
      id: 2,
      word: '受付',
      hiragana: 'うけつけ',
      romaji: 'uketsuke',
      meaning: 'quầy tiếp tân',
      example: '受付はどこですか。',
      exampleVi: 'Quầy tiếp tân ở đâu?',
    ),
  ],
);
void main() {
  final widths = [320.0, 360.0, 393.0, 430.0];
  for (final width in widths) {
    for (final dark in [false, true]) {
      testWidgets('web-style card and mode selection fit $width dark=$dark', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        var grades = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? QTJPTheme.dark : QTJPTheme.light,
            home: FlashcardStudyScreen(
              deck: _deck,
              onAnswer: (_, _) async {
                grades++;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        final flip = find.byKey(const ValueKey('study-flip'));
        await tester.ensureVisible(flip);
        await tester.tap(flip);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('study-meaning')), findsOneWidget);
        final mode = VocabularyMode.values[widths.indexOf(width)];
        final choice = find.byKey(ValueKey('study-mode-${mode.name}'));
        await tester.ensureVisible(choice);
        await tester.pumpAndSettle();
        await tester.tap(choice);
        await tester.pumpAndSettle();
        final selected = find.byKey(ValueKey('practice-mode-${mode.name}'));
        expect(tester.widget<ChoiceChip>(selected).selected, isTrue);
        final label = find
            .descendant(of: selected, matching: find.byType(Text))
            .first;
        final textStyle = tester
            .widget<DefaultTextStyle>(
              find
                  .ancestor(of: label, matching: find.byType(DefaultTextStyle))
                  .first,
            )
            .style;
        expect(textStyle.color, Colors.white);
        expect(grades, 0);
        expect(tester.takeException(), isNull);
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('study-meaning')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets(
    'conjugation keeps columns aligned and exposes right-hand examples by swiping',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: QTJPTheme.light,
          home: const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: QTJPReferenceTable(
                headers: ['Nhóm', 'Quy tắc', 'Ví dụ'],
                rows: [
                  ['Nhóm I', 'く → いて', '書く → 書いて'],
                  ['Nhóm II', 'Bỏ る + て', '食べる → 食べて'],
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Table), findsOneWidget);
      final before = tester.getTopLeft(find.text('書く → 書いて')).dx;
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(-420, 0),
      );
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('書く → 書いて')).dx, lessThan(before));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'skill chart labels percentages and colors match the category on a narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        MaterialApp(
          theme: QTJPTheme.dark,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(20),
              child: ExamSkillChart(
                categories: [
                  for (final e in {
                    'KANJI': 80,
                    'VOCAB': 60,
                    'GRAMMAR': 70,
                    'READING': 40,
                    'LISTENING': 50,
                  }.entries)
                    {'category': e.key, 'percent': e.value},
                ],
                labels: examSkillLabels,
              ),
            ),
          ),
        ),
      );
      expect(find.text('Hán tự'), findsOneWidget);
      expect(find.text('80%'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('80%')).style!.color,
        examSkillColor('KANJI', dark: true),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
