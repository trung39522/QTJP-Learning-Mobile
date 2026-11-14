import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtjp_mobile/core/network/api_client.dart';
import 'package:qtjp_mobile/main.dart';

import 'exam_test.dart' as exam;

void main() {
  for (final width in [320.0, 360.0, 393.0, 430.0]) {
    testWidgets('chat stays compact above the keyboard at $width dp', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 740);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.4;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final app = await exam.signedIn((_, uri, _, _) async {
        if (uri.path.endsWith('/unread-count')) {
          return const ApiResponse(200, {'unreadCount': 0});
        }
        return const ApiResponse(200, []);
      });
      await tester.pumpWidget(QTJPMobile(controller: app));
      await tester.pumpAndSettle();
      final avatar = find.byKey(const ValueKey('kyuto-avatar'));
      expect(find.text('Kyuto AI'), findsNothing);
      expect(
        tester.getRect(avatar).bottom,
        lessThan(tester.getRect(find.byType(NavigationBar)).top),
      );
      await tester.tap(avatar);
      await tester.pumpAndSettle();
      final box = find.byKey(const ValueKey('kyuto-chatbox'));
      final initial = tester.getRect(box);
      expect(initial.left, greaterThanOrEqualTo(12));
      expect(initial.right, lessThanOrEqualTo(width - 12));
      expect(initial.center.dx, closeTo(width / 2, 1));
      expect(initial.center.dy, closeTo(740 / 2, 1));
      expect(initial.width, lessThanOrEqualTo(320));
      expect(initial.height, lessThan(740 * .85));
      final input = find.byKey(const ValueKey('assistant-input'));
      await tester.enterText(input, 'Giải thích một câu tiếng Nhật');
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(tester.getRect(box).bottom, lessThanOrEqualTo(440));
      expect(tester.getRect(input).bottom, lessThanOrEqualTo(440));
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(box, findsNothing);
      expect(avatar, findsOneWidget);
      expect(tester.testTextInput.isVisible, isFalse);
    });
  }

  testWidgets(
    'chat retains real replies between pages and clears private history at logout',
    (tester) async {
      final requests = <Map>[];
      final app = await exam.signedIn((_, uri, _, body) async {
        if (uri.path == '/api/assistant/chat') {
          requests.add(body as Map);
          return const ApiResponse(200, {
            'answer': 'Nội dung từ API.',
            'remaining': 2,
            'links': [
              {'title': 'Mở từ điển', 'path': '/dictionary'},
            ],
          });
        }
        if (uri.path.endsWith('/unread-count')) {
          return const ApiResponse(200, {'unreadCount': 0});
        }
        return const ApiResponse(200, []);
      });
      await tester.pumpWidget(QTJPMobile(controller: app));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('kyuto-avatar')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('assistant-input')),
        'Câu hỏi đầu',
      );
      await tester.tap(find.byKey(const ValueKey('assistant-send')));
      await tester.pumpAndSettle();
      expect(requests, hasLength(1));
      expect(find.text('Nội dung từ API.'), findsOneWidget);
      await tester.ensureVisible(find.text('Mở từ điển'));
      await tester.tap(find.text('Mở từ điển'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('dictionary-query')), findsOneWidget);
      expect(find.byKey(const ValueKey('kyuto-chatbox')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('kyuto-avatar')));
      await tester.pumpAndSettle();
      expect(find.text('Nội dung từ API.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('assistant-input')),
        'Câu hỏi tiếp',
      );
      await tester.tap(find.byKey(const ValueKey('assistant-send')));
      await tester.pumpAndSettle();
      expect(requests.last['history'], hasLength(2));
      await app.logout();
      await tester.pumpAndSettle();
      expect(find.text('Nội dung từ API.'), findsNothing);
      expect(find.text('Đăng nhập để trò chuyện với Kyuto.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Kyuto hides during an actual exam and returns after leaving the attempt',
    (tester) async {
      final app = await exam.signedIn((_, uri, _, _) async {
        if (uri.path.endsWith('/unread-count')) {
          return const ApiResponse(200, {'unreadCount': 0});
        }
        if (uri.path.endsWith('/exams')) {
          return const ApiResponse(200, [exam.summary]);
        }
        if (uri.path.endsWith('/exams/10')) {
          return const ApiResponse(200, {'exam': exam.summary});
        }
        if (uri.path.endsWith('/start')) {
          return ApiResponse(200, exam.attempt(0));
        }
        return const ApiResponse(200, []);
      });
      await tester.pumpWidget(QTJPMobile(controller: app));
      await tester.pumpAndSettle();
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pushNamed('/learn/exam');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('kyuto-avatar')), findsOneWidget);
      await exam.enterRoom(tester);
      expect(find.byKey(const ValueKey('kyuto-avatar')), findsNothing);
      expect(find.byKey(const ValueKey('kyuto-chatbox')), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xác nhận'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('kyuto-avatar')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
