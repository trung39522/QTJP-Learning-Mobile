import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtjp_mobile/app/app_controller.dart';
import 'package:qtjp_mobile/core/network/api_client.dart';
import 'package:qtjp_mobile/screens/vip/vip_repository.dart';
import 'package:qtjp_mobile/screens/vip/vip_screen.dart';

Map<String, dynamic> order({String status = 'PENDING'}) => {
  'orderCode': 'VIP-test-1',
  'months': 1,
  'amount': 49000,
  'status': status,
  'createdAt': '2026-11-10T20:00:00',
};
Map<String, dynamic> checkout() => {
  ...order(),
  'paymentUrl': Uri.https('sandbox.vnpayment.vn', '/paymentv2/vpcpay.html', {
    'vnp_TxnRef': 'VIP-test-1',
    'vnp_Amount': '4900000',
    'vnp_CurrCode': 'VND',
    'vnp_SecureHash': List.filled(128, 'a').join(),
    'vnp_ExpireDate': '20990101000000',
  }).toString(),
};
Future<AppController> login(ApiTransport handler) async {
  final app = AppController(
    api: ApiClient(
      transport: (m, u, h, b) async {
        if (u.path.endsWith('/login')) {
          return const ApiResponse(200, {
            'id': 1,
            'username': 'learner',
            'membership': 'FREE',
            'token': 'test-token',
          });
        }
        if (u.path.endsWith('/logout')) return const ApiResponse(200, {});
        return handler(m, u, h, b);
      },
    ),
  );
  addTearDown(app.dispose);
  await app.login('learner', 'test password');
  return app;
}

Future<void> show(
  WidgetTester tester,
  AppController app, {
  CheckoutLauncher? launcher,
}) async {
  await tester.pumpWidget(
    AppScope(
      controller: app,
      child: MaterialApp(home: VipScreen(checkoutLauncher: launcher)),
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

Future<void> create(WidgetTester tester) async {
  await tap(tester, find.byKey(const ValueKey('vip-plan-1')));
  await tap(tester, find.byKey(const ValueKey('vip-confirm-create')));
}

ApiResponse profile({bool vip = false}) => ApiResponse(200, {
  'id': 1,
  'username': 'learner',
  'membership': vip ? 'VIP' : 'FREE',
  'isVip': vip,
});

void main() {
  testWidgets(
    'failed status refresh prevents reopening an order until history is verified',
    (tester) async {
      var failHistory = false;
      final app = await login((m, u, h, b) async {
        if (u.path.endsWith('/profile')) return profile();
        if (u.path.endsWith('/create')) return ApiResponse(200, checkout());
        return failHistory
            ? const ApiResponse(503, {
                'message': 'Chưa kiểm tra được giao dịch',
              })
            : const ApiResponse(200, []);
      });
      await show(tester, app, launcher: (_) async => true);
      await create(tester);
      failHistory = true;
      await tap(tester, find.byKey(const ValueKey('vip-refresh')));
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('vip-open-checkout')),
            )
            .onPressed,
        isNull,
      );
      expect(app.user?['membership'], 'FREE');
    },
  );
  test('checkout URL validates provider, order and amount without trusting success parameters', () {
    final valid = VnpayCheckout.fromJson(checkout());
    expect(valid.sandbox, isTrue);
    expect(valid.expired, isFalse);
    for (final replacement in [
      valid.url.replace(host: 'sandbox.vnpayment.vn.attacker.example'),
      valid.url.replace(scheme: 'http'),
      valid.url.replace(
        queryParameters: {...valid.url.queryParameters, 'vnp_Amount': '100'},
      ),
      valid.url.replace(
        queryParameters: {...valid.url.queryParameters, 'vnp_TxnRef': 'other'},
      ),
    ]) {
      expect(
        () => VnpayCheckout.fromJson({
          ...checkout(),
          'paymentUrl': replacement.toString(),
        }),
        throwsA(isA<ApiException>()),
      );
    }
    expect(
      () => VnpayCheckout.fromJson({...checkout(), 'status': 'SUCCESS'}),
      throwsA(isA<ApiException>()),
    );
  });
  test(
    'payment API sends months only and uses authenticated server history',
    () async {
      final paths = <String>[];
      final api = ApiClient(
        transport: (m, u, h, b) async {
          expect(h['Authorization'], 'Bearer test-token');
          paths.add('$m ${u.path}');
          if (m == 'POST') {
            expect(b, {'months': 1});
            return ApiResponse(200, checkout());
          }
          return ApiResponse(200, [order()]);
        },
      )..token = 'test-token';
      final repo = VipRepository(api);
      await repo.create(1);
      expect((await repo.history()).single.orderCode, 'VIP-test-1');
      await expectLater(repo.create(2), throwsA(isA<ApiException>()));
      expect(paths, [
        'POST /api/payments/vnpay/create',
        'GET /api/payments/vnpay/history',
      ]);
    },
  );
  testWidgets(
    'checkout opens only after amount review; resume verifies history and profile',
    (tester) async {
      var creates = 0, launches = 0, paid = false;
      final app = await login((m, u, h, b) async {
        if (u.path.endsWith('/profile')) return profile(vip: paid);
        if (u.path.endsWith('/create')) {
          creates++;
          return ApiResponse(200, checkout());
        }
        return ApiResponse(
          200,
          creates == 0 ? [] : [order(status: paid ? 'SUCCESS' : 'PENDING')],
        );
      });
      await show(
        tester,
        app,
        launcher: (url) async {
          launches++;
          expect(url.host, 'sandbox.vnpayment.vn');
          return true;
        },
      );
      expect(creates, 0);
      await create(tester);
      expect(creates, 1);
      expect(launches, 0);
      expect(app.user?['membership'], 'FREE');
      await tap(tester, find.byKey(const ValueKey('vip-open-checkout')));
      expect(launches, 1);
      expect(app.user?['membership'], 'FREE');
      paid = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(app.user?['membership'], 'VIP');
      expect(find.byKey(const ValueKey('vip-open-checkout')), findsNothing);
      expect(
        find.textContaining('Máy chủ xác nhận đơn VIP-test-1: Thành công'),
        findsOneWidget,
      );
      expect(creates, 1);
    },
  );
  testWidgets(
    'browser failure retries the same order and never fabricates VIP',
    (tester) async {
      var creates = 0, launches = 0;
      final app = await login((m, u, h, b) async {
        if (u.path.endsWith('/profile')) return profile();
        if (u.path.endsWith('/create')) {
          creates++;
          return ApiResponse(200, checkout());
        }
        return const ApiResponse(200, []);
      });
      await show(
        tester,
        app,
        launcher: (_) async {
          launches++;
          return false;
        },
      );
      await create(tester);
      await tap(tester, find.byKey(const ValueKey('vip-open-checkout')));
      await tap(tester, find.byKey(const ValueKey('vip-open-checkout')));
      expect(launches, 2);
      expect(creates, 1);
      expect(app.user?['membership'], 'FREE');
      expect(find.textContaining('Chưa mở được trình duyệt'), findsOneWidget);
    },
  );
  testWidgets(
    'creation timeout requires reading history before another create',
    (tester) async {
      var creates = 0;
      final app = await login((m, u, h, b) async {
        if (u.path.endsWith('/profile')) return profile();
        if (u.path.endsWith('/create')) {
          creates++;
          throw const ApiException(
            'Chưa nhận kết quả',
            code: 'REQUEST_TIMEOUT',
          );
        }
        return ApiResponse(200, creates == 0 ? [] : [order()]);
      });
      await show(tester, app);
      await create(tester);
      expect(creates, 1);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('vip-plan-1')))
            .onPressed,
        isNull,
      );
      await tap(tester, find.byKey(const ValueKey('vip-refresh')));
      expect(
        find.byKey(const ValueKey('vip-order-VIP-test-1')),
        findsOneWidget,
      );
      expect(creates, 1);
      expect(app.user?['membership'], 'FREE');
    },
  );
  testWidgets(
    'failed history blocks order creation and logout ignores late checkout response',
    (tester) async {
      var failHistory = true, creates = 0;
      final pending = Completer<ApiResponse>();
      final app = await login((m, u, h, b) async {
        if (u.path.endsWith('/profile')) return profile();
        if (u.path.endsWith('/create')) {
          creates++;
          return pending.future;
        }
        return failHistory
            ? const ApiResponse(503, {'message': 'Lịch sử tạm lỗi'})
            : const ApiResponse(200, []);
      });
      await show(tester, app);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('vip-plan-1')))
            .onPressed,
        isNull,
      );
      failHistory = false;
      await tap(tester, find.byKey(const ValueKey('vip-refresh')));
      await tap(tester, find.byKey(const ValueKey('vip-plan-1')));
      await tester.tap(find.byKey(const ValueKey('vip-confirm-create')));
      await tester.pump();
      expect(creates, 1);
      await app.logout();
      pending.complete(ApiResponse(200, checkout()));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('vip-open-checkout')), findsNothing);
      expect(find.textContaining('VIP-test-1'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
