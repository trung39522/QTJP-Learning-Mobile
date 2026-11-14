import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtjp_mobile/core/network/api_client.dart';
import 'package:qtjp_mobile/main.dart';
import 'package:qtjp_mobile/screens/notifications/device_notifications.dart';

import 'exam_test.dart' as exam;

void main() {
  testWidgets(
    'permission reflects the OS result and opens settings after denial',
    (tester) async {
      var status = 'notDetermined';
      final methods = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        DeviceNotifications.channel,
        (call) async {
          methods.add(call.method);
          if (call.method == 'status') return status;
          if (call.method == 'request') return status = 'denied';
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          DeviceNotifications.channel,
          null,
        ),
      );
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: NotificationPermissionCard())),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cho phép thông báo'));
      await tester.pumpAndSettle();
      expect(methods.where((m) => m == 'request'), hasLength(1));
      expect(
        find.text('Thông báo đang tắt trong cài đặt điện thoại.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cài đặt thông báo'));
      await tester.pumpAndSettle();
      expect(methods.last, 'settings');
      expect(methods.where((m) => m == 'request'), hasLength(1));
    },
  );

  testWidgets(
    'device delivery suppresses old and duplicate inbox data and ignores late data at logout',
    (tester) async {
      final delivered = <Map>[];
      var clears = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        DeviceNotifications.channel,
        (call) async {
          if (call.method == 'status') return 'enabled';
          if (call.method == 'show') delivered.add(call.arguments as Map);
          if (call.method == 'clear') clears++;
          if (call.method == 'consumeTap') return false;
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          DeviceNotifications.channel,
          null,
        ),
      );
      var newest = 1;
      Completer<ApiResponse>? gate;
      final app = await exam.signedIn((method, uri, _, _) async {
        if (uri.path == '/api/notifications') {
          if (gate != null) return gate.future;
          return ApiResponse(200, {
            'items': [
              for (var id = newest; id >= 1; id--)
                {
                  'id': id,
                  'title': 'Thông báo $id',
                  'content': 'Nội dung thật $id',
                  'read': false,
                },
            ],
            'unreadCount': newest,
          });
        }
        if (uri.path.endsWith('/unread-count')) {
          return ApiResponse(200, {'unreadCount': newest});
        }
        return const ApiResponse(200, []);
      });
      await tester.pumpWidget(QTJPMobile(controller: app));
      await tester.pumpAndSettle();
      expect(delivered, isEmpty);
      newest = 2;
      await tester.pump(const Duration(seconds: 60));
      await tester.pumpAndSettle();
      expect(delivered.single['id'], 2);
      expect(delivered.single['body'], 'Nội dung thật 2');
      await tester.pump(const Duration(seconds: 60));
      await tester.pumpAndSettle();
      expect(delivered, hasLength(1));
      gate = Completer<ApiResponse>();
      await tester.pump(const Duration(seconds: 60));
      await tester.pump();
      await app.logout();
      await tester.pumpAndSettle();
      gate.complete(
        const ApiResponse(200, {
          'items': [
            {'id': 3, 'title': 'Late private notification', 'read': false},
          ],
        }),
      );
      await tester.pumpAndSettle();
      expect(delivered, hasLength(1));
      expect(clears, greaterThanOrEqualTo(2));
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final width in [320.0, 360.0, 393.0, 430.0]) {
    testWidgets(
      'four tabs preserve lookup and the AI paper opens at $width dp',
      (tester) async {
        tester.view.physicalSize = Size(width, 740);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final app = await exam.signedIn((_, uri, _, _) async {
          if (uri.path.endsWith('/unread-count')) {
            return const ApiResponse(200, {'unreadCount': 0});
          }
          return const ApiResponse(200, []);
        });
        await tester.pumpWidget(QTJPMobile(controller: app));
        await tester.pumpAndSettle();
        final bar = find.byType(NavigationBar);
        expect(tester.widget<NavigationBar>(bar).destinations, hasLength(4));
        await tester.tap(find.text('Tra cứu'));
        await tester.pumpAndSettle();
        final query = find.byKey(const ValueKey('dictionary-query'));
        await tester.enterText(query, '条件');
        await tester.tap(find.text('Học tập'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Tra cứu'));
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(query).controller!.text, '条件');
        await tester.tap(find.text('Trang chủ'));
        await tester.pumpAndSettle();
        final toggle = find.byKey(const ValueKey('home-ai-scroll-toggle'));
        await tester.ensureVisible(toggle);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('home-ai-scroll-content')),
          findsOneWidget,
        );
        expect(find.textContaining('Góp ý bài viết'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
