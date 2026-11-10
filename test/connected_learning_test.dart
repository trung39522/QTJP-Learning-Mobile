import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtjp_mobile/app/app_controller.dart';
import 'package:qtjp_mobile/core/network/api_client.dart';
import 'package:qtjp_mobile/main.dart';

void main() {
  testWidgets('real login flow returns to profile with website account', (
    tester,
  ) async {
    final app = AppController(
      api: ApiClient(
        transport: (m, u, h, b) async => const ApiResponse(200, {
          'id': 8,
          'username': 'learner',
          'membership': 'FREE',
          'token': 'test-token',
        }),
      ),
    );
    addTearDown(app.dispose);
    await tester.pumpWidget(QTJPMobile(controller: app));
    await tester.tap(find.text('Cá nhân'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('profile-login')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('login-username')),
      'learner',
    );
    await tester.enterText(
      find.byKey(const ValueKey('login-password')),
      'password',
    );
    final submit = find.byKey(const ValueKey('login-submit'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('Xin chào, learner'), findsOneWidget);
    expect(find.text('Gói tài khoản: FREE'), findsOneWidget);
    expect(find.byKey(const ValueKey('login-password')), findsNothing);
    await tester.ensureVisible(find.text('Đăng xuất'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đăng xuất'));
    await tester.pumpAndSettle();
    expect(app.api.token, isNull);
    expect(find.byKey(const ValueKey('profile-login')), findsOneWidget);
  });

  testWidgets('dictionary displays API results and examples at 320px', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final app = AppController(
      api: ApiClient(
        transport: (m, uri, h, b) async => const ApiResponse(200, [
          {
            'word': '学校',
            'hiragana': 'がっこう',
            'meaning': 'trường học',
            'level': 'N5',
            'examples': [
              {'japanese': '学校に行きます。', 'vietnamese': 'Tôi đi học.'},
            ],
          },
        ]),
      ),
    );
    addTearDown(app.dispose);
    await tester.pumpWidget(QTJPMobile(controller: app));
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed('/learn/dictionary');
    await tester.pumpAndSettle();
    expect(find.text('trường học'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('dictionary-result-0')));
    await tester.pumpAndSettle();
    expect(find.text('学校に行きます。'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'connected flashcard waits for server save and retains card on error',
    (tester) async {
      final save = Completer<ApiResponse>();
      var saveCount = 0;
      final app = AppController(
        api: ApiClient(
          transport: (method, uri, headers, body) async {
            if (uri.path == '/api/users/login') {
              return const ApiResponse(200, {
                'id': 8,
                'username': 'learner',
                'token': 'test-token',
              });
            }
            if (uri.path.endsWith('/decks')) {
              return const ApiResponse(200, [
                {
                  'id': 1,
                  'name': 'Bộ thẻ từ máy chủ',
                  'level': 'N3',
                  'wordCount': 1,
                },
              ]);
            }
            if (uri.path.endsWith('/vocabularies')) {
              return const ApiResponse(200, [
                {'id': 99, 'word': '仕事', 'meaning': 'công việc'},
              ]);
            }
            saveCount++;
            if (saveCount == 1) return save.future;
            return const ApiResponse(200, {});
          },
        ),
      );
      addTearDown(app.dispose);
      await app.login('learner', 'password');
      await tester.pumpWidget(QTJPMobile(controller: app));
      tester
          .state<NavigatorState>(find.byType(Navigator))
          .pushNamed('/learn/flashcard?level=N3');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('1')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('study-flip')));
      await tester.tap(find.byKey(const ValueKey('study-flip')));
      await tester.pumpAndSettle();
      final remembered = find.byKey(const ValueKey('study-remembered'));
      await tester.ensureVisible(remembered);
      await tester.tap(remembered);
      await tester.pump();
      expect(tester.widget<FilledButton>(remembered).onPressed, isNull);
      expect(find.text('Hoàn thành phiên học!'), findsNothing);
      save.complete(const ApiResponse(503, {'message': 'Máy chủ tạm ngừng'}));
      await tester.pumpAndSettle();
      expect(find.textContaining('Chưa lưu được tiến độ'), findsOneWidget);
      expect(find.text('Thẻ 1 / 1'), findsOneWidget);
      await tester.ensureVisible(remembered);
      await tester.tap(remembered);
      await tester.pumpAndSettle();
      expect(find.text('Hoàn thành phiên học!'), findsOneWidget);
      expect(saveCount, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('grammar opens actual lesson structure and Japanese examples', (
    tester,
  ) async {
    final app = AppController(
      api: ApiClient(
        transport: (m, uri, h, b) async {
          if (uri.path == '/api/users/login') {
            return const ApiResponse(200, {
              'id': 8,
              'username': 'learner',
              'token': 'test-token',
            });
          }
          if (uri.path.endsWith('/lessons')) {
            return const ApiResponse(200, [
              {
                'id': 7,
                'level': 'N5',
                'lessonNumber': 1,
                'title': 'Giới thiệu bản thân',
              },
            ]);
          }
          return const ApiResponse(200, {
            'id': 7,
            'level': 'N5',
            'lessonNumber': 1,
            'title': 'Giới thiệu bản thân',
            'grammarPoints': [
              {
                'pattern': 'N は N です',
                'meaning': 'là',
                'structure': ['N1 は N2 です'],
                'usage': 'Giới thiệu bản thân.',
                'examples': [
                  {
                    'segments': [
                      {'text': '私', 'reading': 'わたし'},
                      {'text': 'は学生です。'},
                    ],
                    'translation': 'Tôi là học sinh.',
                  },
                ],
              },
            ],
          });
        },
      ),
    );
    addTearDown(app.dispose);
    await app.login('learner', 'password');
    await tester.pumpWidget(QTJPMobile(controller: app));
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed('/learn/grammar?level=N5');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Giới thiệu bản thân'));
    await tester.pumpAndSettle();
    expect(find.text('N は N です'), findsOneWidget);
    expect(find.text('N1 は N2 です'), findsOneWidget);
    expect(find.text('私は学生です。'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
