import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtjp_mobile/app/app_controller.dart';
import 'package:qtjp_mobile/core/network/api_client.dart';
import 'package:qtjp_mobile/core/storage/session_store.dart';
import 'package:qtjp_mobile/main.dart';
import 'package:qtjp_mobile/screens/profile/models/account_presentation.dart';
import 'package:qtjp_mobile/screens/profile/widgets/account_menu_content.dart';

Map<String, dynamic> user({bool vip = false, String role = 'USER'}) => {
  'id': 1,
  'username': 'admin',
  'role': role,
  'membership': vip ? 'VIP' : 'FREE',
  'isVip': vip,
  'vipExpiresAt': vip ? '2099-12-01T12:00:00' : null,
  'email': 'learner@example.com',
  'authProvider': 'LOCAL',
};

class MemoryStore implements SessionStore {
  String? token;
  @override
  Future<void> clear() async => token = null;
  @override
  Future<String?> read(String server) async => token;
  @override
  Future<void> write(String server, String value) async => token = value;
}

Future<AppController> account({
  Map<String, dynamic>? profile,
  ApiTransport? handler,
  SessionStore? store,
}) async {
  final data = profile ?? user();
  final app = AppController(
    sessionStore: store,
    api: ApiClient(
      transport: (method, uri, headers, body) async {
        if (uri.path.endsWith('/login')) {
          return ApiResponse(200, {...data, 'token': 'test-token'});
        }
        if (uri.path.endsWith('/logout')) return const ApiResponse(200, {});
        if (handler != null) return handler(method, uri, headers, body);
        if (uri.path.endsWith('/profile')) return ApiResponse(200, data);
        if (uri.path.endsWith('/unread-count')) {
          return const ApiResponse(200, {'unreadCount': 3});
        }
        if (uri.path.endsWith('/sessions')) return const ApiResponse(200, []);
        return const ApiResponse(200, {});
      },
    ),
  );
  addTearDown(app.dispose);
  await app.login('admin', 'password', remember: store != null);
  return app;
}

Future<void> openMenu(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('home-account-avatar')));
  await tester.pumpAndSettle();
}

Future<void> menuTap(WidgetTester tester, String label) async {
  final finder = find.byKey(ValueKey('account-menu-$label'));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  test('VIP presentation follows existing payload and expiry without inferring it from ADMIN', () {
    final now = DateTime(2026, 11, 13);
    expect(AccountPresentation(user(role: 'ADMIN')).vipAt(now), isFalse);
    expect(AccountPresentation(user(vip: true)).vipAt(now), isTrue);
    expect(
      AccountPresentation({
        ...user(),
        'membership': 'VIP',
        'vipExpiresAt': '2020-01-01T00:00:00',
      }).vipAt(now),
      isFalse,
    );
    expect(
      AccountPresentation({
        ...user(),
        'membership': 'VIP',
        'vipExpiresAt': '2099-01-01T00:00:00',
      }).vipAt(now),
      isTrue,
    );
    expect(AccountPresentation({...user(), 'isVip': true}).vipAt(now), isTrue);
    expect(
      AccountPresentation({...user(), 'avatarUrl': '/uploads/avatar.png'})
          .avatarUri('https://qtjp.example')
          .toString(),
      'https://qtjp.example/uploads/avatar.png',
    );
    expect(
      AccountPresentation({
        ...user(),
        'avatarUrl': 'https://outside.example/avatar.png',
      }).avatarUri('https://qtjp.example'),
      isNull,
    );
    expect(
      AccountPresentation({...user(), 'avatarUrl': 'http://%'})
          .avatarUri('https://qtjp.example'),
      isNull,
    );
  });

  testWidgets(
    'guest menu opens real sign-in and registration and dismisses outside',
    (tester) async {
      final app = AppController(
        api: ApiClient(
          transport: (_, _, _, _) async => const ApiResponse(200, {}),
        ),
      );
      addTearDown(app.dispose);
      await tester.pumpWidget(QTJPMobile(controller: app));
      await openMenu(tester);
      expect(find.text('Hồ sơ'), findsNothing);
      expect(find.text('Đăng xuất'), findsNothing);
      expect(find.text('Đăng nhập'), findsOneWidget);
      expect(find.text('Đăng ký'), findsOneWidget);
      await tester.tapAt(const Offset(10, 80));
      await tester.pumpAndSettle();
      expect(find.byType(AccountMenuContent), findsNothing);
      await openMenu(tester);
      await menuTap(tester, 'Đăng ký');
      expect(find.byKey(const ValueKey('account-username')), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await openMenu(tester);
      await menuTap(tester, 'Đăng nhập');
      expect(find.byKey(const ValueKey('login-username')), findsOneWidget);
    },
  );

  for (final vip in [false, true]) {
    for (final role in ['USER', 'ADMIN']) {
      testWidgets(
        '$role VIP=$vip gets correct menu, no administration, and a real profile',
        (tester) async {
          final app = await account(
            profile: user(vip: vip, role: role),
          );
          await tester.pumpWidget(QTJPMobile(controller: app));
          await tester.pumpAndSettle();
          final badge = tester.widget<Badge>(
            find.byKey(const ValueKey('notification-badge')),
          );
          expect(badge.isLabelVisible, isTrue);
          expect((badge.label! as Text).data, '3');
          await openMenu(tester);
          expect(
            find.text(vip ? 'Thành viên VIP' : 'Tài khoản miễn phí'),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('vip-crown')),
            vip ? findsNWidgets(2) : findsNothing,
          );
          expect(find.text('Quản trị'), findsNothing);
          expect(find.textContaining('chưa hỗ trợ'), findsNothing);
          expect(find.text('Chế độ sáng'), findsOneWidget);
          expect(find.byType(Switch), findsNothing);
          final labels = ['Hồ sơ', 'Bảo mật', 'Giao diện', 'Đăng xuất'];
          for (var i = 0; i < labels.length - 1; i++) {
            expect(
              tester.getCenter(find.text(labels[i])).dy,
              lessThan(tester.getCenter(find.text(labels[i + 1])).dy),
            );
          }
          await menuTap(tester, 'Hồ sơ');
          expect(find.text('Xin chào, admin'), findsOneWidget);
          expect(find.text('Chỉnh sửa hồ sơ'), findsOneWidget);
          expect(find.text('Nâng cấp / gia hạn VIP'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('security opens existing password and device controls', (
    tester,
  ) async {
    final app = await account();
    await tester.pumpWidget(QTJPMobile(controller: app));
    await openMenu(tester);
    await menuTap(tester, 'Bảo mật');
    expect(find.text('Bảo mật tài khoản'), findsOneWidget);
    await tester.tap(find.text('Đổi mật khẩu'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('account-current')), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thiết bị đăng nhập'));
    await tester.pumpAndSettle();
    expect(find.text('Đăng xuất thiết bị khác'), findsOneWidget);
  });

  testWidgets('menu logout clears the existing secure session and badge', (
    tester,
  ) async {
    final store = MemoryStore();
    final app = await account(store: store);
    expect(store.token, 'test-token');
    await tester.pumpWidget(QTJPMobile(controller: app));
    await openMenu(tester);
    await menuTap(tester, 'Đăng xuất');
    expect(app.isAuthenticated, isFalse);
    expect(app.api.token, isNull);
    expect(store.token, isNull);
    expect(find.byType(AccountMenuContent), findsNothing);
    expect(
      tester
          .widget<Badge>(find.byKey(const ValueKey('notification-badge')))
          .isLabelVisible,
      isFalse,
    );
    await openMenu(tester);
    expect(find.text('Đăng nhập'), findsOneWidget);
    expect(find.text('Hồ sơ'), findsNothing);
  });

  testWidgets('notification badge refreshes after server-confirmed read-all', (
    tester,
  ) async {
    var unread = 4;
    final app = await account(
      handler: (method, uri, headers, body) async {
        if (uri.path.endsWith('/read-all')) {
          unread = 0;
          return const ApiResponse(204, null);
        }
        if (uri.path.endsWith('/unread-count')) {
          return ApiResponse(200, {'unreadCount': unread});
        }
        if (uri.path == '/api/notifications') {
          return ApiResponse(200, {'items': [], 'unreadCount': unread});
        }
        return ApiResponse(200, user());
      },
    );
    await tester.pumpWidget(QTJPMobile(controller: app));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Badge>(find.byKey(const ValueKey('notification-badge')))
          .isLabelVisible,
      isTrue,
    );
    await tester.tap(find.byKey(const ValueKey('header-notifications')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đánh dấu tất cả đã đọc'));
    await tester.pumpAndSettle();
    expect(unread, 0);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Badge>(find.byKey(const ValueKey('notification-badge')))
          .isLabelVisible,
      isFalse,
    );
  });

  testWidgets(
    'late profile and badge responses cannot overwrite a new account',
    (tester) async {
      final oldProfile = Completer<ApiResponse>(),
          oldBadge = Completer<ApiResponse>();
      var current = 1;
      final app = AppController(
        api: ApiClient(
          transport: (method, uri, headers, body) async {
            if (uri.path.endsWith('/login')) {
              current = (body as Map)['username'] == 'one' ? 1 : 2;
              return ApiResponse(200, {
                'id': current,
                'username': current == 1 ? 'one' : 'two',
                'token': 'same-test-token',
              });
            }
            if (uri.path.endsWith('/unread-count')) {
              return current == 1
                  ? oldBadge.future
                  : const ApiResponse(200, {'unreadCount': 2});
            }
            if (uri.path.endsWith('/profile')) {
              return current == 1
                  ? oldProfile.future
                  : const ApiResponse(200, {'id': 2, 'username': 'two'});
            }
            return const ApiResponse(200, {});
          },
        ),
      );
      addTearDown(app.dispose);
      await app.login('one', 'password');
      await tester.pumpWidget(QTJPMobile(controller: app));
      await openMenu(tester);
      await app.login('two', 'password');
      await tester.pumpAndSettle();
      oldProfile.complete(
        const ApiResponse(200, {
          'id': 1,
          'username': 'old-private-name',
          'isVip': true,
        }),
      );
      oldBadge.complete(const ApiResponse(200, {'unreadCount': 99}));
      await tester.pumpAndSettle();
      expect(app.user?['id'], 2);
      expect(
        find.descendant(
          of: find.byType(AccountMenuContent),
          matching: find.text('two'),
        ),
        findsOneWidget,
      );
      expect(find.text('old-private-name'), findsNothing);
      expect(
        (tester
                    .widget<Badge>(
                      find.byKey(const ValueKey('notification-badge')),
                    )
                    .label!
                as Text)
            .data,
        '2',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'compact header and scrolling popover fit large text and bottom insets',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final app = await account(
        profile: {
          ...user(vip: true),
          'fullName': 'Một tên tài khoản rất dài trên điện thoại',
        },
      );
      await tester.pumpWidget(QTJPMobile(controller: app));
      await tester.pumpAndSettle();
      final nav = tester.getRect(find.byType(NavigationBar));
      final kyuto = tester.getRect(find.byKey(const ValueKey('kyuto-avatar')));
      expect(kyuto.bottom, lessThan(nav.top));
      await openMenu(tester);
      await tester.ensureVisible(
        find.byKey(const ValueKey('account-menu-Đăng xuất')),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .getRect(find.byKey(const ValueKey('account-menu-Đăng xuất')))
            .bottom,
        lessThanOrEqualTo(616),
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [320.0, 360.0, 393.0, 430.0]) {
    testWidgets(
      'header and anchored popover fit $width dp and track viewport changes',
      (tester) async {
        tester.view.physicalSize = Size(width, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final app = await account(
          profile: {
            ...user(vip: true),
            'fullName': 'Tên tài khoản rất dài của người học QTJP',
          },
        );
        await tester.pumpWidget(QTJPMobile(controller: app));
        await tester.pumpAndSettle();
        final anchor = find.byKey(const ValueKey('home-account-avatar'));
        final rect = tester.getRect(anchor);
        expect(rect.right, lessThanOrEqualTo(width - 12));
        expect(
          tester
              .getRect(find.byKey(const ValueKey('header-notifications')))
              .right,
          lessThan(rect.left),
        );
        expect(
          find.byKey(const ValueKey('header-account-name')),
          width >= 393 ? findsOneWidget : findsNothing,
        );
        await openMenu(tester);
        final popup = find.byKey(const ValueKey('account-popover'));
        final menu = tester.getRect(popup);
        expect(menu.top, greaterThanOrEqualTo(rect.bottom));
        expect(menu.left, greaterThanOrEqualTo(12));
        expect(menu.right, lessThanOrEqualTo(width - 12));
        expect(menu.width, inInclusiveRange(210, 220));
        expect(find.byType(BottomSheet), findsNothing);
        final rotations = tester.widgetList<Transform>(
          find.byKey(const ValueKey('vip-crown-rotation')),
        );
        expect(rotations.length, 2);
        for (final transform in rotations) {
          expect(transform.transform.storage[1], closeTo(0.422618, 0.001));
        }
        tester.view.physicalSize = const Size(320, 560);
        await tester.pumpAndSettle();
        expect(tester.getRect(popup).right, lessThanOrEqualTo(308));
        expect(tester.getRect(popup).bottom, lessThanOrEqualTo(548));
        await tester.tapAt(tester.getCenter(anchor));
        await tester.pumpAndSettle();
        expect(popup, findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('back closes the popover without switching the learning tab', (
    tester,
  ) async {
    final app = await account();
    await tester.pumpWidget(QTJPMobile(controller: app));
    await tester.tap(find.text('Học tập'));
    await tester.pumpAndSettle();
    await openMenu(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('account-popover')), findsNothing);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );
  });
}
