import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtjp_mobile/app/app_controller.dart';
import 'package:qtjp_mobile/core/network/api_client.dart';
import 'package:qtjp_mobile/core/theme/qtjp_theme.dart';
import 'package:qtjp_mobile/screens/auth/google_identity.dart';
import 'package:qtjp_mobile/screens/auth/login_screen.dart';

import 'account_flows_test.dart' show MemoryStore;

class TestGoogleIdentity implements GoogleIdentity {
  TestGoogleIdentity(this.result);
  final Future<String?> Function() result;
  int calls = 0;
  @override
  Future<String?> credential() {
    calls++;
    return result();
  }
}

Future<void> mount(
  WidgetTester tester,
  AppController app,
  GoogleIdentity identity,
) async {
  await tester.pumpWidget(
    AppScope(
      controller: app,
      child: MaterialApp(
        theme: QTJPTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => LoginScreen(googleIdentity: identity),
                ),
              ),
              child: const Text('Mở đăng nhập'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Mở đăng nhập'));
  await tester.pumpAndSettle();
}

Future<void> submit(WidgetTester tester) async {
  final button = find.byKey(const ValueKey('login-google'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  test('remembered Google login persists only the application JWT', () async {
    final store = MemoryStore();
    final app = AppController(
      sessionStore: store,
      api: ApiClient(
        transport: (_, _, _, _) async => const ApiResponse(200, {
          'id': 3,
          'username': 'google',
          'token': 'qtjp-jwt',
        }),
      ),
    );
    addTearDown(app.dispose);
    await app.loginWithGoogle('google-credential', remember: true);
    expect(store.token, 'qtjp-jwt');
    expect(app.rememberSession, isTrue);
    await app.logout();
    expect(store.token, isNull);
  });
  testWidgets(
    'Google credential uses existing API and only explicitly replaces a VIP session',
    (tester) async {
      final bodies = <Map>[];
      final app = AppController(
        api: ApiClient(
          transport: (m, uri, h, b) async {
            expect(m, 'POST');
            expect(uri.path, '/api/users/google-login');
            expect(h.containsKey('Authorization'), isFalse);
            bodies.add(b as Map);
            if (bodies.length == 1) {
              return const ApiResponse(409, {
                'code': 'VIP_SESSION_ACTIVE',
                'message': 'Phiên VIP đang hoạt động.',
              });
            }
            return const ApiResponse(200, {
              'id': 4,
              'username': 'google-user',
              'token': 'app-session',
              'authProvider': 'GOOGLE',
            });
          },
        ),
      );
      addTearDown(app.dispose);
      final identity = TestGoogleIdentity(() async => 'google-id-token');
      await mount(tester, app, identity);
      await submit(tester);
      expect(app.isAuthenticated, isFalse);
      expect(bodies.single, {
        'credential': 'google-id-token',
        'replaceOtherSession': false,
      });
      await tester.tap(find.text('Tiếp tục đăng nhập'));
      await tester.pumpAndSettle();
      expect(bodies.last, {
        'credential': 'google-id-token',
        'replaceOtherSession': true,
      });
      expect(identity.calls, 1);
      expect(app.api.token, 'app-session');
      expect(app.user!.containsKey('token'), isFalse);
      expect(app.user!['authProvider'], 'GOOGLE');
      expect(find.byKey(const ValueKey('login-google')), findsNothing);
    },
  );

  testWidgets('canceling the Google picker sends no login request', (
    tester,
  ) async {
    var requests = 0;
    final app = AppController(
      api: ApiClient(
        transport: (_, _, _, _) async {
          requests++;
          return const ApiResponse(200, {});
        },
      ),
    );
    addTearDown(app.dispose);
    await mount(tester, app, TestGoogleIdentity(() async => null));
    await submit(tester);
    expect(requests, 0);
    expect(app.isAuthenticated, isFalse);
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const ValueKey('login-google')))
          .onPressed,
      isNotNull,
    );
  });

  test('late Google response cannot restore a logged-out session', () async {
    final pending = Completer<ApiResponse>();
    final app = AppController(
      api: ApiClient(transport: (_, _, _, _) => pending.future),
    );
    addTearDown(app.dispose);
    final login = app.loginWithGoogle('credential');
    await app.logout();
    pending.complete(
      const ApiResponse(200, {
        'id': 1,
        'username': 'old',
        'token': 'old-token',
      }),
    );
    await login;
    expect(app.isAuthenticated, isFalse);
    expect(app.api.token, isNull);
  });
}
