import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtjp_mobile/core/network/api_client.dart';
import 'package:qtjp_mobile/main.dart';
import 'package:qtjp_mobile/screens/feedback/feedback_repository.dart';

import 'exam_test.dart' as fixture;

void main() {
  test('feedback uses the existing authenticated multipart contract', () async {
    var calls = 0;
    final api = ApiClient(
      transport: (method, uri, headers, body) async {
        calls++;
        expect(method, 'POST');
        expect(uri.path, '/api/feedback/tickets');
        expect(headers['Authorization'], 'Bearer session');
        expect(
          headers['Content-Type'],
          startsWith('multipart/form-data; boundary='),
        );
        final upload = body as ApiBinaryBody;
        final wire = utf8.decode(upload.bytes, allowMalformed: true);
        expect(wire, contains('name="category"\r\n\r\nBUG'));
        expect(wire, contains('name="title"\r\n\r\nLỗi bài nghe'));
        expect(
          wire,
          contains('name="description"\r\n\r\nKhông phát được âm thanh.'),
        );
        expect(wire, contains('name="screenshot"; filename="screenshot.png"'));
        expect(wire, contains('Content-Type: image/png'));
        return const ApiResponse(201, {'id': 7});
      },
    )..token = 'session';
    await FeedbackRepository(api).submit(
      category: 'BUG',
      title: ' Lỗi bài nghe ',
      description: ' Không phát được âm thanh. ',
      screenshot: [137, 80, 78, 71, 13, 10, 26, 10],
    );
    expect(calls, 1);
    await expectLater(
      FeedbackRepository(api).submit(
        category: 'ADMIN',
        title: 'Lỗi bài nghe',
        description: 'Không phát được âm thanh.',
      ),
      throwsA(isA<ApiException>()),
    );
    await expectLater(
      FeedbackRepository(api).submit(
        category: 'BUG',
        title: 'Lỗi bài nghe',
        description: 'Không phát được âm thanh.',
        screenshot: [1, 2, 3],
      ),
      throwsA(isA<ApiException>()),
    );
    expect(calls, 1);
  });

  testWidgets(
    'avatar feedback opens the native form and shows server history',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var posts = 0;
      final app = await fixture.signedIn((method, uri, _, _) async {
        if (uri.path.endsWith('/unread-count')) {
          return const ApiResponse(200, {'unreadCount': 0});
        }
        if (uri.path.endsWith('/profile')) {
          return const ApiResponse(200, {'id': 1, 'username': 'learner'});
        }
        if (uri.path.endsWith('/tickets') && method == 'POST') {
          posts++;
          return const ApiResponse(201, {'id': 7});
        }
        if (uri.path.endsWith('/tickets/mine')) {
          return const ApiResponse(200, {
            'content': [
              {
                'id': 7,
                'category': 'BUG',
                'title': 'Lỗi bài nghe',
                'description': 'Không phát được âm thanh.',
                'status': 'IN_PROGRESS',
                'adminReply': 'QTJP đang kiểm tra vấn đề.',
              },
            ],
            'totalPages': 1,
          });
        }
        return const ApiResponse(200, []);
      });
      await tester.pumpWidget(QTJPMobile(controller: app));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('home-account-avatar')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('account-menu-Nâng cấp VIP')),
        findsOneWidget,
      );
      final feedback = find.byKey(
        const ValueKey('account-menu-Góp ý & Báo lỗi'),
      );
      await tester.ensureVisible(feedback);
      await tester.tap(feedback);
      await tester.pumpAndSettle();
      expect(find.text('Góp ý & Báo lỗi'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('feedback-title')),
        'Lỗi bài nghe',
      );
      await tester.enterText(
        find.byKey(const ValueKey('feedback-description')),
        'Không phát được âm thanh.',
      );
      final send = find.byKey(const ValueKey('feedback-submit'));
      await tester.ensureVisible(send);
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(posts, 1);
      expect(find.text('Cảm ơn bạn! QTJP đã nhận được góp ý.'), findsOneWidget);
      await tester.tap(find.text('Phản hồi của tôi'));
      await tester.pumpAndSettle();
      expect(find.text('Lỗi bài nghe'), findsOneWidget);
      expect(find.text('Đang xử lý'), findsOneWidget);
      expect(find.text('QTJP đang kiểm tra vấn đề.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('late feedback responses cannot enter another session', (
    tester,
  ) async {
    final pending = Completer<ApiResponse>();
    final app = await fixture.signedIn((_, uri, _, _) async {
      if (uri.path.endsWith('/unread-count')) {
        return const ApiResponse(200, {'unreadCount': 0});
      }
      if (uri.path.endsWith('/tickets/mine')) return pending.future;
      return const ApiResponse(200, []);
    });
    await tester.pumpWidget(QTJPMobile(controller: app));
    await tester.pumpAndSettle();
    tester.state<NavigatorState>(find.byType(Navigator)).pushNamed('/feedback');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Phản hồi của tôi'));
    await tester.pump();
    await app.logout();
    pending.complete(
      const ApiResponse(200, {
        'content': [
          {'title': 'Nội dung riêng', 'description': 'Riêng tư'},
        ],
        'totalPages': 1,
      }),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nội dung riêng'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final route in ['/login', '/register']) {
    testWidgets('authentication $route has no Kyuto and restores it on back', (
      tester,
    ) async {
      final app = await fixture.signedIn((_, uri, _, _) async {
        if (uri.path.endsWith('/unread-count')) {
          return const ApiResponse(200, {'unreadCount': 0});
        }
        return const ApiResponse(200, []);
      });
      await tester.pumpWidget(QTJPMobile(controller: app));
      await tester.pumpAndSettle();
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pushNamed(route);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('kyuto-avatar')), findsNothing);
      expect(find.byKey(const ValueKey('kyuto-chatbox')), findsNothing);
      if (route == '/login') {
        expect(find.text('hoặc'), findsNothing);
        final submit = tester.getRect(
          find.byKey(const ValueKey('login-submit')),
        );
        final google = tester.getRect(
          find.byKey(const ValueKey('login-google')),
        );
        expect(google.top - submit.bottom, lessThan(20));
      }
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('kyuto-avatar')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
