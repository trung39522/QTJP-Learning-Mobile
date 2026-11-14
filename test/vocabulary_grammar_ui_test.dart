import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtjp_mobile/app/app_controller.dart';
import 'package:qtjp_mobile/core/network/api_client.dart';
import 'package:qtjp_mobile/core/theme/qtjp_theme.dart';
import 'package:qtjp_mobile/main.dart';
import 'package:qtjp_mobile/screens/grammar/grammar_repository.dart';
import 'package:qtjp_mobile/screens/grammar/grammar_screen.dart';

void main() {
  for (final width in [320.0, 430.0]) {
    testWidgets(
      'dedicated vocabulary entry opens searchable API words at $width dp',
      (tester) async {
        tester.view.physicalSize = Size(width, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var grades = 0;
        final app = AppController(
          api: ApiClient(
            transport: (m, u, h, b) async {
              if (u.path.endsWith('/login')) {
                return const ApiResponse(200, {
                  'id': 1,
                  'username': 'learner',
                  'token': 'session',
                });
              }
              if (u.path.endsWith('/unread-count')) {
                return const ApiResponse(200, {'unreadCount': 0});
              }
              if (u.path.endsWith('/decks')) {
                return const ApiResponse(200, [
                  {'id': 11, 'name': 'Bài 1', 'level': 'N5', 'wordCount': 2},
                ]);
              }
              if (u.path.endsWith('/vocabularies')) {
                return const ApiResponse(200, [
                  {
                    'id': 81,
                    'word': 'がっこう',
                    'kanji': '学校',
                    'hiragana': 'がっこう',
                    'meaning': 'trường học',
                  },
                  {
                    'id': 82,
                    'word': 'ねこ',
                    'kanji': '猫',
                    'hiragana': 'ねこ',
                    'meaning': 'mèo',
                  },
                ]);
              }
              if (u.path.endsWith('/progress')) {
                if (m == 'GET') return const ApiResponse(200, []);
                grades++;
              }
              return const ApiResponse(200, {});
            },
          ),
        );
        addTearDown(app.dispose);
        await app.login('learner', 'password');
        await tester.pumpWidget(QTJPMobile(controller: app));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Học tập'));
        await tester.pumpAndSettle();
        final entry = find.byKey(const ValueKey('learning-vocabulary'));
        await tester.ensureVisible(entry);
        await tester.tap(entry);
        await tester.pumpAndSettle();
        expect(find.text('Từ vựng theo cấp độ'), findsOneWidget);
        final deck = find.byKey(const ValueKey('11'));
        await tester.ensureVisible(deck);
        await tester.tap(deck);
        await tester.pumpAndSettle();
        final search = find.byKey(const ValueKey('vocabulary-search'));
        expect(search, findsOneWidget);
        await tester.enterText(search, 'mèo');
        await tester.pumpAndSettle();
        expect(find.text('猫'), findsOneWidget);
        expect(find.text('学校'), findsNothing);
        expect(grades, 0);
        await app.logout();
        await tester.pumpAndSettle();
        expect(search, findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final dark in [false, true]) {
    testWidgets(
      'grammar separates structures, cases and readings on a narrow large-text screen dark=$dark',
      (tester) async {
        tester.view.physicalSize = const Size(320, 740);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 1.5;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final app = AppController(
          api: ApiClient(
            transport: (m, u, h, b) async {
              if (u.path.endsWith('/login')) {
                return const ApiResponse(200, {
                  'id': 1,
                  'username': 'learner',
                  'token': 'session',
                });
              }
              return const ApiResponse(200, {
                'id': 7,
                'level': 'N5',
                'lessonNumber': 1,
                'title': 'Chỉ định sự vật',
                'grammarPoints': [
                  {
                    'pattern': 'その + N',
                    'meaning': 'Danh từ ở gần người nghe',
                    'structure': ['その + Danh từ'],
                    'usageCases': [
                      {
                        'title': 'Chỉ đồ vật',
                        'usage': 'Dùng trước danh từ.',
                        'notes': ['Cần có danh từ theo sau.'],
                        'examples': [
                          {
                            'segments': [
                              {'text': 'その靴', 'reading': 'くつ'},
                              {'text': 'は新しいです。'},
                            ],
                            'translation': 'Đôi giày đó mới.',
                          },
                        ],
                      },
                    ],
                    'relatedPatterns': ['この + N'],
                  },
                ],
              });
            },
          ),
        );
        addTearDown(app.dispose);
        await app.login('learner', 'password');
        await tester.pumpWidget(
          AppScope(
            controller: app,
            child: MaterialApp(
              theme: dark ? QTJPTheme.dark : QTJPTheme.light,
              home: GrammarLessonScreen(
                id: '7',
                repository: GrammarRepository(app.api),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final text in [
          'Cấu trúc',
          'その + Danh từ',
          'Chỉ đồ vật',
          'その',
          '靴',
          'くつ',
          'Đôi giày đó mới.',
          'Lưu ý',
          'Mẫu liên quan',
        ]) {
          final item = find.text(text);
          await tester.ensureVisible(item);
          await tester.pumpAndSettle();
          expect(item, findsOneWidget);
          expect(tester.takeException(), isNull, reason: text);
        }
      },
    );
  }
}
