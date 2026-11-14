import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtjp_mobile/app/app_controller.dart';
import 'package:qtjp_mobile/core/network/api_client.dart';
import 'package:qtjp_mobile/main.dart';

Future<AppController> account(ApiTransport transport) async {
  final app = AppController(
    api: ApiClient(
      transport: (m, u, h, b) async {
        if (u.path.endsWith('/login')) {
          return ApiResponse(200, {
            'id': (b as Map)['username'] == 'one' ? 1 : 2,
            'username': b['username'],
            'token': 'same-test-token',
          });
        }
        if (u.path.endsWith('/logout')) return const ApiResponse(200, {});
        if (u.path == '/api/notifications/unread-count') {
          return const ApiResponse(200, {'unreadCount': 0});
        }
        return transport(m, u, h, b);
      },
    ),
  );
  addTearDown(app.dispose);
  await app.login('one', 'password');
  return app;
}

const deck = {'id': 1, 'name': 'Bộ thẻ riêng', 'level': 'N5', 'wordCount': 1};
const word = {'id': 99, 'word': '仕事', 'meaning': 'công việc'};

Future<void> open(WidgetTester tester, AppController app, String route) async {
  await tester.pumpWidget(QTJPMobile(controller: app));
  tester.state<NavigatorState>(find.byType(Navigator)).pushNamed(route);
  await tester.pumpAndSettle();
}

void main() {
  for (final status in [200, 401]) {
    test(
      'late HTTP $status cannot affect a new session with the same token',
      () async {
        final pending = Completer<ApiResponse>();
        final app = await account((m, u, h, b) => pending.future);
        final result = app.api.get('/protected', authenticated: true);
        final assertion = expectLater(
          result,
          throwsA(
            isA<ApiException>().having(
              (e) => e.code,
              'session change',
              'SESSION_CHANGED',
            ),
          ),
        );
        await app.login('two', 'password');
        pending.complete(ApiResponse(status, {'private': 'old data'}));
        await assertion;
        expect(app.isAuthenticated, isTrue);
        expect(app.user?['id'], 2);
      },
    );
  }

  testWidgets(
    'late deck response cannot open a study screen after switching accounts',
    (tester) async {
      final pending = Completer<ApiResponse>();
      final app = await account((m, u, h, b) async {
        if (u.path.endsWith('/decks')) return const ApiResponse(200, [deck]);
        return pending.future;
      });
      await open(tester, app, '/learn/flashcard?level=N5');
      await tester.tap(find.byKey(const ValueKey('1')));
      await tester.pump();
      await app.login('two', 'password');
      await tester.pumpAndSettle();
      pending.complete(const ApiResponse(200, [word]));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('study-flip')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('study hides old cards and cannot save into another account', (
    tester,
  ) async {
    var saves = 0;
    final app = await account((m, u, h, b) async {
      if (u.path.endsWith('/decks')) return const ApiResponse(200, [deck]);
      if (u.path.endsWith('/vocabularies')) {
        return const ApiResponse(200, [word]);
      }
      if (m == 'GET' && u.path.endsWith('/progress')) {
        return const ApiResponse(200, []);
      }
      saves++;
      return const ApiResponse(200, {});
    });
    await open(tester, app, '/learn/flashcard?level=N5');
    await tester.tap(find.byKey(const ValueKey('1')));
    await tester.pumpAndSettle();
    expect(find.text('仕事'), findsOneWidget);
    await app.login('two', 'password');
    await tester.pumpAndSettle();
    expect(find.text('仕事'), findsNothing);
    expect(find.byKey(const ValueKey('study-remembered')), findsNothing);
    expect(saves, 0);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('grammar detail clears protected content at logout', (
    tester,
  ) async {
    final app = await account(
      (m, u, h, b) async => const ApiResponse(200, {
        'id': 7,
        'title': 'Nội dung dành cho tài khoản',
        'level': 'N5',
        'lessonNumber': 1,
        'grammarPoints': [],
      }),
    );
    await open(tester, app, '/learn/grammar?level=N5&lesson=7');
    expect(find.text('Nội dung dành cho tài khoản'), findsOneWidget);
    await app.logout();
    await tester.pumpAndSettle();
    expect(find.text('Nội dung dành cho tài khoản'), findsNothing);
    expect(find.text('Đăng nhập để học'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
