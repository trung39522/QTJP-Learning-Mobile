import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtjp_mobile/app/app_controller.dart';
import 'package:qtjp_mobile/core/network/api_client.dart';
import 'package:qtjp_mobile/core/theme/app_theme_controller.dart';
import 'package:qtjp_mobile/core/theme/qtjp_colors.dart';
import 'package:qtjp_mobile/main.dart';

class MemoryThemeStore implements ThemePreferenceStore {
  String? value;
  Completer<String?>? readGate;
  final writes = <String>[];
  @override
  Future<String?> read() => readGate?.future ?? Future.value(value);
  @override
  Future<void> write(String mode) async {
    writes.add(mode);
    value = mode;
  }
}

const profile = {
  'id': 1,
  'username': 'learner',
  'email': 'learner@example.com',
  'membership': 'VIP',
  'isVip': true,
  'vipExpiresAt': '2099-01-01T00:00:00',
};
AppController account() {
  final app = AppController(
    api: ApiClient(
      transport: (method, uri, headers, body) async {
        if (uri.path.endsWith('/login')) {
          return const ApiResponse(200, {...profile, 'token': 'test-token'});
        }
        if (uri.path.endsWith('/profile')) {
          return const ApiResponse(200, profile);
        }
        if (uri.path.endsWith('/unread-count')) {
          return const ApiResponse(200, {'unreadCount': 14});
        }
        if (uri.path.endsWith('/usage')) {
          return const ApiResponse(200, {
            'membership': 'VIP',
            'dailyLimit': 15,
            'remaining': 7,
          });
        }
        return const ApiResponse(200, []);
      },
    ),
  );
  addTearDown(app.dispose);
  return app;
}

void noTechnicalCopy() {
  for (final text in [
    'website',
    'backend',
    'API_BASE_URL',
    'Máy chủ dữ liệu',
    'Phiên chỉ lưu',
    'kho bảo mật',
  ]) {
    expect(find.textContaining(text), findsNothing);
  }
}

void main() {
  test('appearance is restored independently from the login session', () async {
    final store = MemoryThemeStore();
    final first = AppThemeController(store: store);
    addTearDown(first.dispose);
    first.toggle();
    await first.pendingWrite;
    final second = AppThemeController(store: store);
    addTearDown(second.dispose);
    await second.restore();
    expect(second.mode, ThemeMode.dark);
    expect(store.value, 'dark');
  });

  test(
    'a late restore cannot override a choice and rapid toggles save in order',
    () async {
      final store = MemoryThemeStore()..readGate = Completer<String?>();
      final theme = AppThemeController(store: store);
      addTearDown(theme.dispose);
      final restore = theme.restore();
      theme.toggle();
      store.readGate!.complete('light');
      await restore;
      expect(theme.mode, ThemeMode.dark);
      theme.toggle();
      theme.toggle();
      theme.toggle();
      await theme.pendingWrite;
      expect(store.writes, ['dark', 'light', 'dark', 'light']);
      expect(store.value, 'light');
    },
  );

  for (final width in [320.0, 360.0, 393.0, 430.0]) {
    testWidgets(
      'compact menu and profile switch appearance without changing session at $width dp',
      (tester) async {
        tester.view.physicalSize = Size(width, 750);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final app = account();
        await app.login('learner', 'password');
        final session = app.api.sessionVersion;
        final store = MemoryThemeStore();
        final theme = AppThemeController(store: store);
        addTearDown(theme.dispose);
        await tester.pumpWidget(
          QTJPMobile(controller: app, themeController: theme),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('home-account-avatar')));
        await tester.pumpAndSettle();
        final menu = find.byKey(const ValueKey('account-popover'));
        expect(tester.getSize(menu).width, 220);
        expect(tester.getSize(menu).height, lessThan(430));
        expect(tester.getRect(menu).bottom, lessThanOrEqualTo(740));
        await tester.tap(find.byKey(const ValueKey('appearance-toggle')));
        await tester.pumpAndSettle();
        expect(menu, findsOneWidget);
        expect(find.text('Chế độ tối'), findsOneWidget);
        expect(Theme.of(tester.element(menu)).brightness, Brightness.dark);
        expect(
          tester.widget<Material>(menu).color,
          QTJPColorPalette.dark.surface,
        );
        expect(app.api.token, 'test-token');
        expect(app.api.sessionVersion, session);
        await tester.tap(find.byKey(const ValueKey('account-menu-Hồ sơ')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('profile-summary')), findsOneWidget);
        expect(find.text('Thành viên VIP'), findsOneWidget);
        noTechnicalCopy();
        final toggle = find.byKey(const ValueKey('appearance-toggle'));
        await tester.ensureVisible(toggle);
        await tester.pumpAndSettle();
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(theme.mode, ThemeMode.light);
        expect(app.api.sessionVersion, session);
        await theme.pendingWrite;
        expect(store.value, 'light');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'theme changes preserve typed login fields and hide implementation copy',
    (tester) async {
      final theme = AppThemeController();
      addTearDown(theme.dispose);
      await tester.pumpWidget(
        QTJPMobile(controller: account(), themeController: theme),
      );
      tester.state<NavigatorState>(find.byType(Navigator)).pushNamed('/login');
      await tester.pumpAndSettle();
      final username = find.byKey(const ValueKey('login-username'));
      final password = find.byKey(const ValueKey('login-password'));
      await tester.enterText(username, 'my-account');
      await tester.enterText(password, 'unchanged-password');
      theme.toggle();
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(username).controller!.text,
        'my-account',
      );
      expect(
        tester.widget<TextFormField>(password).controller!.text,
        'unchanged-password',
      );
      expect(Theme.of(tester.element(username)).brightness, Brightness.dark);
      noTechnicalCopy();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'dark learning pages and compact menu remain usable with larger text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 650);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final theme = AppThemeController(initialMode: ThemeMode.dark);
      addTearDown(theme.dispose);
      final app = account();
      await app.login('learner', 'password');
      await tester.pumpWidget(
        QTJPMobile(controller: app, themeController: theme),
      );
      await tester.pumpAndSettle();
      for (final route in [
        '/profile',
        '/security',
        '/learn/dictionary',
        '/learn/grammar',
        '/learn/flashcard',
        '/learn/alphabet',
        '/learn/writing',
        '/learn/video',
        '/learn/exam',
      ]) {
        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        navigator.pushNamed(route);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: route);
        navigator.pop();
        await tester.pumpAndSettle();
      }
      tester.view.physicalSize = const Size(320, 420);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('home-account-avatar')));
      await tester.pumpAndSettle();
      final scroll = find.descendant(
        of: find.byKey(const ValueKey('account-menu-scroll')),
        matching: find.byType(Scrollable),
      );
      expect(
        tester.state<ScrollableState>(scroll).position.maxScrollExtent,
        greaterThan(0),
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('account-menu-Đăng xuất')),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
