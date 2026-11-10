import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtjp_mobile/app/app_controller.dart';
import 'package:qtjp_mobile/core/network/api_client.dart';
import 'package:qtjp_mobile/core/storage/session_store.dart';
import 'package:qtjp_mobile/screens/auth/account_form_screen.dart';
import 'package:qtjp_mobile/screens/auth/account_repository.dart';
import 'package:qtjp_mobile/screens/profile/profile_editor_screen.dart';

class MemoryStore implements SessionStore {
  String? token;
  Completer<void>? writeGate, readGate;
  bool fail = false;
  @override
  Future<String?> read(String server) async {
    final value = token;
    await readGate?.future;
    return value;
  }

  @override
  Future<void> write(String server, String value) async {
    await writeGate?.future;
    if (fail) {
      throw StateError('Locked store');
    }
    token = value;
  }

  @override
  Future<void> clear() async {
    token = null;
  }
}

ApiResponse identity(String name) => ApiResponse(200, {
  'id': name == 'one' ? 1 : 2,
  'username': name,
  'token': 'token-$name',
});
ApiClient accountApi({ApiTransport? other}) => ApiClient(
  transport: (m, u, h, b) async {
    if (u.path.endsWith('/login')) {
      return identity((b as Map)['username'] as String);
    }
    if (u.path.endsWith('/logout')) {
      return const ApiResponse(200, {});
    }
    return other == null
        ? const ApiResponse(200, {'id': 1, 'username': 'one'})
        : other(m, u, h, b);
  },
);
Future<void> show(WidgetTester tester, AppController app, Widget screen) async {
  await tester.pumpWidget(
    AppScope(
      controller: app,
      child: MaterialApp(home: screen),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  test('API never forwards credentials to a foreign target or accepts userinfo in the base URL', () async {
    var calls = 0;
    Future<ApiResponse> transport(
      String m,
      Uri u,
      Map<String, String> h,
      Object? b,
    ) async {
      calls++;
      return const ApiResponse(200, {});
    }

    final credentials = ApiClient(
      baseUrl: 'https://user:pass@api.example',
      transport: transport,
    );
    await expectLater(credentials.get('/public'), throwsA(isA<ApiException>()));
    final api = ApiClient(baseUrl: 'https://api.example', transport: transport)
      ..token = 'secret';
    await expectLater(
      api.request(
        'POST',
        'https://outside.example/login',
        body: {'password': 'secret'},
        authenticated: true,
      ),
      throwsA(isA<ApiException>()),
    );
    expect(calls, 0);
  });
  test(
    'remembered token restores only after backend verifies identity',
    () async {
      final store = MemoryStore();
      final first = AppController(api: accountApi(), sessionStore: store);
      await first.login('one', 'password', remember: true);
      expect(store.token, 'token-one');
      first.dispose();
      final next = AppController(api: accountApi(), sessionStore: store);
      addTearDown(next.dispose);
      await next.restoreSession();
      expect(next.user?['username'], 'one');
      expect(next.rememberSession, isTrue);
      await next.logout();
      expect(store.token, isNull);
      expect(next.isAuthenticated, isFalse);
    },
  );
  test('slow token write cannot resurrect a signed-out session', () async {
    final store = MemoryStore()..writeGate = Completer<void>();
    final app = AppController(api: accountApi(), sessionStore: store);
    addTearDown(app.dispose);
    final login = app.login('one', 'password', remember: true);
    await Future<void>.delayed(Duration.zero);
    expect(app.isAuthenticated, isTrue);
    final logout = app.logout();
    expect(app.isAuthenticated, isFalse);
    store.writeGate!.complete();
    await login;
    await logout;
    expect(store.token, isNull);
  });
  test('pending restore cannot overwrite a newer login', () async {
    final store = MemoryStore()
      ..token = 'old'
      ..readGate = Completer<void>();
    final app = AppController(api: accountApi(), sessionStore: store);
    addTearDown(app.dispose);
    final restore = app.restoreSession();
    await Future<void>.delayed(Duration.zero);
    await app.login('two', 'password', remember: true);
    store.readGate!.complete();
    await restore;
    expect(app.user?['id'], 2);
    expect(app.api.token, 'token-two');
    expect(store.token, 'token-two');
  });
  test(
    'failed login cancels pending restore without leaving a stuck session',
    () async {
      final gate = Completer<ApiResponse>();
      final store = MemoryStore()..token = 'unverified';
      final app = AppController(
        api: ApiClient(
          transport: (m, u, h, b) async {
            if (u.path.endsWith('/login')) return const ApiResponse(401, {});
            return gate.future;
          },
        ),
        sessionStore: store,
      );
      addTearDown(app.dispose);
      final restore = app.restoreSession();
      await Future<void>.delayed(Duration.zero);
      expect(app.api.token, 'unverified');
      await expectLater(
        app.login('one', 'wrong'),
        throwsA(isA<ApiException>()),
      );
      expect(app.restoring, isFalse);
      expect(app.api.token, isNull);
      gate.complete(const ApiResponse(200, {'id': 1, 'username': 'one'}));
      await restore;
      expect(app.isAuthenticated, isFalse);
      expect(store.token, 'unverified');
    },
  );
  test('expired restore deletes stored token; network failure keeps it for explicit retry', () async {
    final expiredStore = MemoryStore()..token = 'expired';
    final expired = AppController(
      api: accountApi(other: (m, u, h, b) async => const ApiResponse(401, {})),
      sessionStore: expiredStore,
    );
    addTearDown(expired.dispose);
    await expired.restoreSession();
    await Future<void>.delayed(Duration.zero);
    expect(expired.isAuthenticated, isFalse);
    expect(expiredStore.token, isNull);
    final offlineStore = MemoryStore()..token = 'unverified';
    final offline = AppController(
      api: accountApi(
        other: (m, u, h, b) async {
          throw const ApiException('Offline');
        },
      ),
      sessionStore: offlineStore,
    );
    addTearDown(offline.dispose);
    await offline.restoreSession();
    expect(offline.isAuthenticated, isFalse);
    expect(offline.api.token, isNull);
    expect(offlineStore.token, 'unverified');
    expect(offline.sessionNotice, isNotNull);
  });
  test(
    'secure storage failure reports a warning without a plain-text fallback',
    () async {
      final store = MemoryStore()..fail = true;
      final app = AppController(api: accountApi(), sessionStore: store);
      addTearDown(app.dispose);
      await app.login('one', 'password', remember: true);
      expect(app.isAuthenticated, isTrue);
      expect(app.sessionNotice, isNotNull);
      expect(app.rememberSession, isFalse);
      expect(store.token, isNull);
    },
  );
  test('account API sends exact reset, profile and security contracts without userId', () async {
    final bodies = <String, Object?>{};
    final api = ApiClient(
      transport: (m, u, h, b) async {
        bodies[u.path] = b;
        if (b is Map) {
          expect(b.containsKey('userId'), isFalse);
        }
        if (u.path.endsWith('/sessions')) {
          return const ApiResponse(200, []);
        }
        return const ApiResponse(200, {'id': 1, 'username': 'one'});
      },
    )..token = 'test';
    final repo = AccountRepository(api);
    await repo.register(
      ' one ',
      'one@example.com',
      '0123456789',
      'abc12345',
      'abc12345',
    );
    await repo.forgot(' one@example.com ');
    await repo.reset(
      'https://website.example/reset-password?token=abc_123',
      'abc12345',
      'abc12345',
    );
    await repo.password('old', 'abc12345', 'abc12345');
    await repo.saveProfile('one@example.com', '0123456789');
    await repo.sessions();
    await repo.revokeOthers();
    expect((bodies['/api/users/reset-password'] as Map)['token'], 'abc_123');
    expect(bodies['/api/users/me/profile'], {
      'email': 'one@example.com',
      'phone': '0123456789',
    });
    expect(bodies['/api/users/me/password'], {
      'currentPassword': 'old',
      'newPassword': 'abc12345',
      'confirmPassword': 'abc12345',
    });
    expect(validatePassword('12345678'), isNotNull);
    expect(validatePhone('+84912345678'), isNull);
  });
  testWidgets(
    'registration validates, preserves server conflict and does not silently log in',
    (tester) async {
      var calls = 0;
      final app = AppController(
        api: ApiClient(
          transport: (m, u, h, b) async {
            calls++;
            return calls == 1
                ? const ApiResponse(409, {
                    'message': 'Tên đăng nhập đã tồn tại',
                  })
                : const ApiResponse(201, {'id': 1});
          },
        ),
      );
      addTearDown(app.dispose);
      await show(
        tester,
        app,
        const AccountFormScreen(form: AccountForm.register),
      );
      await tap(tester, find.byKey(const ValueKey('account-submit')));
      expect(calls, 0);
      for (final entry in {
        'account-username': 'learner',
        'account-email': 'one@example.com',
        'account-phone': '0123456789',
        'account-password': 'abc12345',
        'account-confirm': 'abc12345',
      }.entries) {
        await tester.ensureVisible(find.byKey(ValueKey(entry.key)));
        await tester.enterText(find.byKey(ValueKey(entry.key)), entry.value);
      }
      await tap(tester, find.byKey(const ValueKey('account-submit')));
      expect(find.text('Tên đăng nhập đã tồn tại'), findsOneWidget);
      await tap(tester, find.byKey(const ValueKey('account-submit')));
      expect(find.textContaining('Tạo tài khoản thành công'), findsOneWidget);
      expect(app.isAuthenticated, isFalse);
    },
  );
  testWidgets(
    'forgot-password leads to reset, extracts email link token and clears secrets',
    (tester) async {
      final paths = <String>[];
      final app = AppController(
        api: ApiClient(
          transport: (m, u, h, b) async {
            paths.add(u.path);
            expect(h.containsKey('Authorization'), isFalse);
            if (u.path.endsWith('/reset-password')) {
              expect((b as Map)['token'], 'test-reset-token');
              expect(b['password'], 'abc12345');
            }
            return const ApiResponse(200, {});
          },
        ),
      );
      addTearDown(app.dispose);
      await show(
        tester,
        app,
        const AccountFormScreen(form: AccountForm.forgot),
      );
      await tester.enterText(
        find.byKey(const ValueKey('account-email')),
        'one@example.com',
      );
      await tap(tester, find.byKey(const ValueKey('account-submit')));
      expect(find.textContaining('Nếu email tồn tại'), findsOneWidget);
      await tap(tester, find.text('Tôi đã có liên kết đặt lại mật khẩu'));
      await tester.enterText(
        find.byKey(const ValueKey('account-token')),
        'https://qtjp.example/reset-password?token=test-reset-token',
      );
      await tester.enterText(
        find.byKey(const ValueKey('account-password')),
        'abc12345',
      );
      await tester.enterText(
        find.byKey(const ValueKey('account-confirm')),
        'abc12345',
      );
      await tap(tester, find.byKey(const ValueKey('account-submit')));
      expect(paths, [
        '/api/users/forgot-password',
        '/api/users/reset-password',
      ]);
      expect(find.textContaining('Đổi mật khẩu thành công'), findsOneWidget);
      expect(find.byKey(const ValueKey('account-token')), findsNothing);
      expect(app.isAuthenticated, isFalse);
    },
  );
  testWidgets(
    'password change keeps session on rejection and signs out only after success',
    (tester) async {
      var fail = true;
      final app = AppController(
        api: accountApi(
          other: (m, u, h, b) async => fail
              ? const ApiResponse(400, {
                  'message': 'Mật khẩu hiện tại chưa đúng',
                })
              : const ApiResponse(200, {}),
        ),
      );
      addTearDown(app.dispose);
      await app.login('one', 'password');
      await show(
        tester,
        app,
        const AccountFormScreen(form: AccountForm.password),
      );
      await tester.enterText(
        find.byKey(const ValueKey('account-current')),
        'old password',
      );
      await tester.enterText(
        find.byKey(const ValueKey('account-password')),
        'abc12345',
      );
      await tester.enterText(
        find.byKey(const ValueKey('account-confirm')),
        'abc12345',
      );
      await tap(tester, find.byKey(const ValueKey('account-submit')));
      expect(app.isAuthenticated, isTrue);
      expect(find.text('Mật khẩu hiện tại chưa đúng'), findsOneWidget);
      fail = false;
      await tap(tester, find.byKey(const ValueKey('account-submit')));
      expect(app.api.token, isNull);
      expect(find.textContaining('Đổi mật khẩu thành công'), findsOneWidget);
    },
  );
  testWidgets('profile updates account only after server acknowledgement', (
    tester,
  ) async {
    var fail = true;
    final app = AppController(
      api: accountApi(
        other: (m, u, h, b) async {
          if (m == 'PUT' && fail) {
            return const ApiResponse(409, {'message': 'Email đã được sử dụng'});
          }
          return ApiResponse(200, {
            'id': 1,
            'username': 'one',
            'email': m == 'PUT' ? 'new@example.com' : 'one@example.com',
            'phone': '0123456789',
          });
        },
      ),
    );
    addTearDown(app.dispose);
    await app.login('one', 'password');
    await show(tester, app, const ProfileEditorScreen());
    await tester.enterText(
      find.byKey(const ValueKey('profile-email')),
      'new@example.com',
    );
    await tap(tester, find.byKey(const ValueKey('profile-save')));
    expect(app.user?['email'], 'one@example.com');
    expect(find.text('Email đã được sử dụng'), findsOneWidget);
    fail = false;
    await tap(tester, find.byKey(const ValueKey('profile-save')));
    expect(app.user?['email'], 'new@example.com');
    expect(find.text('Đã cập nhật hồ sơ.'), findsOneWidget);
  });
  testWidgets(
    'password and profile forms cannot act on a replacement session',
    (tester) async {
      var writes = 0;
      final app = AppController(
        api: accountApi(
          other: (m, u, h, b) async {
            if (m != 'GET') {
              writes++;
            }
            return const ApiResponse(200, {
              'id': 1,
              'username': 'one',
              'email': 'one@example.com',
              'phone': '0123456789',
            });
          },
        ),
      );
      addTearDown(app.dispose);
      await app.login('one', 'password');
      await show(tester, app, const ProfileEditorScreen());
      await tester.enterText(
        find.byKey(const ValueKey('profile-email')),
        'edited@example.com',
      );
      await app.login('two', 'password');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('profile-save')), findsNothing);
      expect(find.text('edited@example.com'), findsNothing);
      await show(
        tester,
        app,
        const AccountFormScreen(form: AccountForm.password),
      );
      await tester.enterText(
        find.byKey(const ValueKey('account-current')),
        'old password',
      );
      await app.login('one', 'password');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('account-submit')), findsNothing);
      expect(writes, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
