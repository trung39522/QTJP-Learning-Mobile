import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtjp_mobile/app/app_controller.dart';
import 'package:qtjp_mobile/core/network/api_client.dart';
import 'package:qtjp_mobile/core/theme/qtjp_theme.dart';
import 'package:qtjp_mobile/screens/exam/widgets/exam_question_navigator.dart';
import 'package:qtjp_mobile/screens/exam/widgets/exam_result_dashboard.dart';
import 'package:qtjp_mobile/screens/flashcard/data/flashcard_repository.dart';
import 'package:qtjp_mobile/screens/flashcard/flashcard_editor_screen.dart';
import 'package:qtjp_mobile/screens/flashcard/models/flashcard_deck.dart';
import 'package:qtjp_mobile/screens/flashcard/vocabulary_practice_screen.dart';
import 'package:qtjp_mobile/screens/grammar/conjugation_screen.dart';
import 'package:qtjp_mobile/screens/grammar/verb_conjugation.dart';
import 'package:qtjp_mobile/screens/grammar/verb_form_tables.dart';

import 'learning_ui_refinement_test.dart' show TestSpeech;

final _deck = FlashcardDeck(
  id: '4',
  name: 'Sinh hoạt',
  level: 'N5',
  description: '',
  words: const [
    FlashcardWord(
      id: 1,
      word: '学校',
      hiragana: 'がっこう',
      romaji: 'gakkou',
      meaning: 'trường học',
      example: '学校へ行きます。',
      exampleVi: 'Tôi đến trường.',
    ),
    FlashcardWord(
      id: 2,
      word: '猫',
      hiragana: 'ねこ',
      romaji: 'neko',
      meaning: 'mèo',
      example: '猫がいます。',
      exampleVi: 'Có mèo.',
    ),
  ],
);
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _mode(WidgetTester tester, String name) async {
  final finder = find.byKey(ValueKey('practice-mode-$name'));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await _tap(tester, finder);
}

void main() {
  test('verb rules cover all groups, exceptions and invalid inputs', () {
    expect(verbFormTables, hasLength(12));
    expect(conjugateVerb('行く', 'godan')[2], '行って');
    expect(conjugateVerb('いく', 'godan')[3], 'いった');
    expect(conjugateVerb('話す', 'godan').last, '話させられる');
    expect(conjugateVerb('食べる', 'ichidan')[5], '食べられる');
    expect(conjugateVerb('勉強する', 'suru')[5], '勉強できる');
    expect(conjugateVerb('来る', 'kuru')[7], '来い（こい）');
    for (final pair in [
      ('書く', 'godan'),
      ('食べる', 'ichidan'),
      ('する', 'suru'),
      ('くる', 'kuru'),
    ]) {
      expect(conjugateVerb(pair.$1, pair.$2), hasLength(12));
    }
    expect(() => conjugateVerb('読む', 'ichidan'), throwsFormatException);
    expect(() => conjugateVerb('猫', 'kuru'), throwsFormatException);
  });

  for (final width in [320.0, 430.0]) {
    testWidgets(
      'practice modes grade real words, retry writes, and fit $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final grades = <(int?, bool)>[];
        var reject = true;
        final speech = TestSpeech();
        await tester.pumpWidget(
          MaterialApp(
            theme: width == 320 ? QTJPTheme.dark : QTJPTheme.light,
            home: VocabularyPracticeScreen(
              deck: _deck,
              speech: speech,
              onAnswer: (word, known) async {
                if (reject) throw Exception('offline');
                grades.add((word.id, known));
              },
            ),
          ),
        );
        expect(grades, isEmpty);
        await _tap(tester, find.byKey(const ValueKey('practice-option-1')));
        expect(find.byKey(const ValueKey('practice-feedback')), findsNothing);
        expect(find.textContaining('Chưa lưu được kết quả'), findsOneWidget);
        reject = false;
        await _tap(tester, find.byKey(const ValueKey('practice-option-1')));
        expect(grades, [(1, true)]);
        await _mode(tester, 'listening');
        await _tap(tester, find.byKey(const ValueKey('practice-listen')));
        expect(speech.spoken.last, 'がっこう');
        expect(grades, hasLength(1));
        await _mode(tester, 'typing');
        await tester.enterText(
          find.byKey(const ValueKey('practice-typing')),
          ' GAKKOU ',
        );
        await _tap(tester, find.byKey(const ValueKey('practice-check')));
        expect(grades.last, (1, true));
        await _mode(tester, 'fill');
        expect(find.text('＿＿＿＿へ行きます。'), findsOneWidget);
        await _tap(tester, find.byKey(const ValueKey('practice-option-2')));
        expect(grades.last, (1, false));
        await _mode(tester, 'auto');
        expect(find.textContaining('không tự đánh giá'), findsOneWidget);
        final before = grades.length;
        await _tap(tester, find.text('Bắt đầu tự động phát'));
        await tester.pump(const Duration(seconds: 7));
        await _tap(tester, find.text('Dừng tự động phát'));
        expect(grades, hasLength(before));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets('result charts and filters show actual answers at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: width == 320 ? QTJPTheme.dark : QTJPTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ExamResultDashboard(
                result: {
                  'attemptId': 7,
                  'title': 'JLPT N5',
                  'scorePercent': 33.3,
                  'practiceScore': 60,
                  'correctCount': 1,
                  'totalQuestions': 3,
                  'categories': [
                    {
                      'category': 'KANJI',
                      'percent': 100,
                      'correctCount': 1,
                      'totalQuestions': 1,
                    },
                    {
                      'category': 'VOCAB',
                      'percent': 0,
                      'correctCount': 0,
                      'totalQuestions': 1,
                    },
                    {
                      'category': 'LISTENING',
                      'percent': 0,
                      'correctCount': 0,
                      'totalQuestions': 1,
                    },
                  ],
                  'answers': [
                    {
                      'answerKeyId': 1,
                      'category': 'KANJI',
                      'selectedOption': 1,
                      'correct': true,
                    },
                    {
                      'answerKeyId': 2,
                      'category': 'VOCAB',
                      'selectedOption': 2,
                      'correct': false,
                    },
                    {
                      'answerKeyId': 3,
                      'category': 'LISTENING',
                      'selectedOption': null,
                      'correct': false,
                    },
                  ],
                },
                answerBuilder: (a) => Text('Answer ${a['answerKeyId']}'),
              ),
            ),
          ),
        ),
      );
      expect(find.text('33.3% chính xác'), findsOneWidget);
      await _tap(tester, find.text('Sai (1)'));
      expect(find.text('Answer 1'), findsNothing);
      expect(find.text('Answer 2'), findsOneWidget);
      expect(find.text('Answer 3'), findsNothing);
      await _tap(tester, find.text('Bỏ trống (1)'));
      expect(find.text('Answer 3'), findsOneWidget);
      expect(find.text('Answer 2'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'question colors prioritize marked state and preserve current outline',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ExamQuestionNavigator(
            questions: const [
              {'selectedOption': 1},
              {'selectedOption': 2, 'markedForReview': true},
              {},
            ],
            current: 0,
            onSelected: (_) {},
            onClose: () {},
          ),
        ),
      );
      Material tile(int i) => tester.widget<Material>(
        find
            .ancestor(
              of: find.byKey(ValueKey('exam-question-$i')),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(tile(0).color, const Color(0xFF21845B));
      expect(tile(1).color, const Color(0xFFFFE082));
      expect((tile(0).shape! as RoundedRectangleBorder).side.width, 3);
    },
  );

  testWidgets(
    'conjugation reference and practice work at 320 with large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.4;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        MaterialApp(theme: QTJPTheme.light, home: const ConjugationScreen()),
      );
      await _tap(tester, find.text('Thử chia động từ ↓'));
      await tester.enterText(
        find.byKey(const ValueKey('conjugation-input')),
        '泳ぐ',
      );
      await _tap(tester, find.byKey(const ValueKey('conjugation-run')));
      expect(find.text('泳いで'), findsOneWidget);
      expect(find.text('泳いだ'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'personal deck uses existing API, confirmation and session guard',
    (tester) async {
      final calls = <(String, String, Object?)>[];
      final api = ApiClient(
        transport: (m, u, h, b) async {
          calls.add((m, u.path, b));
          if (u.path.endsWith('/login')) {
            return const ApiResponse(200, {
              'id': 1,
              'username': 'learner',
              'token': 'jwt',
            });
          }
          if (m == 'POST' && u.path.endsWith('/decks')) {
            return const ApiResponse(200, {
              'id': 9,
              'name': 'Bộ riêng',
              'level': 'N5',
              'ownerUserId': 1,
              'systemDeck': false,
              'wordCount': 0,
            });
          }
          if (m == 'GET' && u.path.endsWith('/vocabularies')) {
            return const ApiResponse(200, []);
          }
          return const ApiResponse(200, {});
        },
      );
      final app = AppController(api: api);
      addTearDown(app.dispose);
      await app.login('learner', 'password');
      await tester.pumpWidget(
        AppScope(
          controller: app,
          child: MaterialApp(
            home: FlashcardEditorScreen(
              repository: ApiFlashcardRepository(api),
              level: 'N5',
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField).first, 'Bộ riêng');
      await _tap(tester, find.byKey(const ValueKey('deck-save')));
      expect(
        calls.where((c) => c.$1 == 'POST' && c.$2.endsWith('/decks')).single.$3,
        {'level': 'N5', 'name': 'Bộ riêng', 'category': '', 'description': ''},
      );
      await tester.enterText(
        find.byKey(const ValueKey('custom-word-word')),
        '猫',
      );
      await tester.enterText(
        find.byKey(const ValueKey('custom-word-meaning')),
        'mèo',
      );
      await _tap(tester, find.byKey(const ValueKey('custom-word-add')));
      expect(
        calls.any(
          (c) => c.$1 == 'POST' && c.$2.endsWith('/9/custom-vocabularies'),
        ),
        isTrue,
      );
      await _tap(tester, find.text('Xóa bộ từ'));
      await _tap(tester, find.text('Hủy'));
      expect(calls.where((c) => c.$1 == 'DELETE'), isEmpty);
      await app.logout();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('deck-save')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('late practice result cannot survive logout', (tester) async {
    final pending = Completer<void>();
    final app = AppController(
      api: ApiClient(
        transport: (m, u, h, b) async => const ApiResponse(200, {
          'id': 1,
          'username': 'learner',
          'token': 'jwt',
        }),
      ),
    );
    addTearDown(app.dispose);
    await app.login('learner', 'password');
    await tester.pumpWidget(
      AppScope(
        controller: app,
        child: MaterialApp(
          home: VocabularyPracticeScreen(
            deck: _deck,
            sessionVersion: app.api.sessionVersion,
            speech: TestSpeech(),
            onAnswer: (_, _) => pending.future,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('practice-option-1')));
    await tester.pump();
    await app.logout();
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('practice-feedback')), findsNothing);
    expect(find.textContaining('Phiên học đã thay đổi'), findsOneWidget);
  });
}
