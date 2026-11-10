import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtjp_mobile/app/app_controller.dart';
import 'package:qtjp_mobile/core/network/api_client.dart';
import 'package:qtjp_mobile/main.dart';
import 'package:qtjp_mobile/screens/ai/learning_ai_repository.dart';
import 'package:qtjp_mobile/screens/ai/learning_ai_screen.dart';

Map<String, dynamic> entry() => {
  'entry': {
    'found': true,
    'word': '学校',
    'reading': 'がっこう',
    'meaning': 'trường học',
    'explanation': 'Dùng để chỉ nơi học tập',
    'examples': [],
    'relatedWords': ['学生'],
  },
  'fromCache': true,
};
const quota = {'vip': false, 'remaining': 2, 'limit': 3};
Future<AppController> appFor(ApiTransport transport) async {
  final app = AppController(
    api: ApiClient(
      transport: (m, u, h, b) async {
        if (u.path.endsWith('/login')) {
          return const ApiResponse(200, {
            'id': 1,
            'username': 'learner',
            'token': 'test',
          });
        }
        if (u.path.endsWith('/logout')) return const ApiResponse(200, {});
        return transport(m, u, h, b);
      },
    ),
  );
  addTearDown(app.dispose);
  await app.login('learner', 'password');
  return app;
}

Future<void> show(
  WidgetTester tester,
  AppController app,
  LearningAiTool tool,
) async {
  await tester.pumpWidget(
    AppScope(
      controller: app,
      child: MaterialApp(
        home: LearningAiScreen(tool: tool, initialText: '学校'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tap(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'dictionary and grammar expose their AI actions through native routes',
    (tester) async {
      var calls = 0;
      final app = await appFor((m, u, h, b) async {
        if (u.path.endsWith('/quota')) return const ApiResponse(200, quota);
        if (m == 'GET') return const ApiResponse(200, []);
        calls++;
        return u.path == '/api/dictionary/ai'
            ? ApiResponse(200, entry())
            : const ApiResponse(200, {'grammarPoints': []});
      });
      await tester.pumpWidget(QTJPMobile(controller: app));
      tester
          .state<NavigatorState>(find.byType(Navigator))
          .pushNamed('/learn/dictionary');
      await tester.pumpAndSettle();
      await tap(tester, 'dictionary-ai');
      expect(calls, 0);
      await tap(tester, 'learning-ai-submit');
      expect(calls, 1);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      tester
          .state<NavigatorState>(find.byType(Navigator))
          .pushNamed('/learn/grammar');
      await tester.pumpAndSettle();
      await tap(tester, 'grammar-ai');
      await tester.enterText(
        find.byKey(const ValueKey('learning-ai-input')),
        '私は学生です',
      );
      await tap(tester, 'learning-ai-submit');
      expect(calls, 2);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'dictionary timeout cannot be resent until quota has been checked',
    (tester) async {
      var posts = 0, quotaCalls = 0;
      final app = await appFor((m, u, h, b) async {
        if (m == 'GET') {
          quotaCalls++;
          return const ApiResponse(200, quota);
        }
        posts++;
        throw const ApiException('Timeout', code: 'REQUEST_TIMEOUT');
      });
      await show(tester, app, LearningAiTool.dictionary);
      await tap(tester, 'learning-ai-submit');
      expect(posts, 1);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('learning-ai-submit')),
            )
            .onPressed,
        isNull,
      );
      await tester.ensureVisible(
        find.text('Kiểm tra lượt AI trước khi thử lại'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kiểm tra lượt AI trước khi thử lại'));
      await tester.pumpAndSettle();
      expect(quotaCalls, 2);
      expect(posts, 1);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('learning-ai-submit')),
            )
            .onPressed,
        isNotNull,
      );
    },
  );
  test('dictionary and grammar call their exact AI APIs with authenticated bounded input', () async {
    final calls = <String>[];
    final expectedModes = ['LOOKUP', 'EXPLAIN'];
    final api = ApiClient(
      transport: (m, u, h, b) async {
        expect(h['Authorization'], 'Bearer test');
        calls.add('$m ${u.path}');
        if (u.path.endsWith('/quota')) return const ApiResponse(200, quota);
        if (u.path == '/api/dictionary/ai') {
          expect(b, {'keyword': '学校', 'mode': expectedModes.removeAt(0)});
          return ApiResponse(200, entry());
        }
        expect(b, {'sentence': '学校', 'translationHint': '', 'context': ''});
        return const ApiResponse(200, {'grammarPoints': []});
      },
    )..token = 'test';
    final repo = LearningAiRepository(api);
    await repo.quota();
    await repo.request(LearningAiTool.dictionary, ' 学校 ');
    await repo.request(LearningAiTool.dictionary, '学校', explain: true);
    await repo.request(LearningAiTool.grammar, '学校');
    await expectLater(
      repo.request(LearningAiTool.dictionary, List.filled(101, 'a').join()),
      throwsA(isA<ApiException>()),
    );
    expect(calls.length, 4);
    expect(expectedModes, isEmpty);
    expect(calls.last, 'POST /api/grammar/analyze');
  });
  testWidgets(
    'dictionary loads quota without AI, then supports lookup and explain explicitly',
    (tester) async {
      final modes = <String>[];
      final app = await appFor((m, u, h, b) async {
        if (u.path.endsWith('/quota')) return const ApiResponse(200, quota);
        modes.add((b as Map)['mode'] as String);
        return ApiResponse(200, entry());
      });
      await show(tester, app, LearningAiTool.dictionary);
      expect(modes, isEmpty);
      await tap(tester, 'learning-ai-submit');
      expect(find.text('Dùng để chỉ nơi học tập'), findsOneWidget);
      await tap(tester, 'learning-ai-explain');
      expect(modes, ['LOOKUP', 'EXPLAIN']);
      await app.logout();
      await tester.pumpAndSettle();
      expect(find.text('Dùng để chỉ nơi học tập'), findsNothing);
    },
  );
  testWidgets(
    'dictionary quota error keeps input and takes remaining quota from server',
    (tester) async {
      final app = await appFor((m, u, h, b) async {
        if (u.path.endsWith('/quota')) return const ApiResponse(200, quota);
        return const ApiResponse(429, {
          'message': 'Đã hết lượt hôm nay',
          'quota': {'vip': false, 'remaining': 0},
        });
      });
      await show(tester, app, LearningAiTool.dictionary);
      await tap(tester, 'learning-ai-submit');
      expect(find.text('Đã hết lượt hôm nay'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('learning-ai-input')))
            .controller!
            .text,
        '学校',
      );
      expect(find.textContaining('Lượt AI còn lại: 0'), findsOneWidget);
    },
  );
  testWidgets(
    'grammar renders structured AI analysis and ignores replies after logout',
    (tester) async {
      var calls = 0;
      final pending = Completer<ApiResponse>();
      final app = await appFor((m, u, h, b) async {
        calls++;
        if (calls > 1) return pending.future;
        return const ApiResponse(200, {
          'sentence': '学校に行きます',
          'translation': 'Đi đến trường',
          'grammarPoints': [
            {
              'grammar': {
                'pattern': 'に',
                'meaning': 'Nơi đến',
                'structure': ['Địa điểm + に'],
                'examples': [],
              },
              'contextNote': 'Chỉ đích đến',
            },
          ],
        });
      });
      await show(tester, app, LearningAiTool.grammar);
      expect(calls, 0);
      await tap(tester, 'learning-ai-submit');
      expect(find.text('Nơi đến'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('learning-ai-submit')),
      );
      await tester.tap(find.byKey(const ValueKey('learning-ai-submit')));
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('learning-ai-submit')),
            )
            .onPressed,
        isNull,
      );
      await app.logout();
      pending.complete(
        const ApiResponse(200, {
          'translation': 'private result',
          'grammarPoints': [],
        }),
      );
      await tester.pumpAndSettle();
      expect(find.text('private result'), findsNothing);
      expect(find.text('Nơi đến'), findsNothing);
      expect(calls, 2);
    },
  );
}
