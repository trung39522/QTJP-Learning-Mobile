import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtjp_mobile/main.dart';
import 'package:qtjp_mobile/app/app_controller.dart';
import 'package:qtjp_mobile/core/network/api_client.dart';

void main() {
  late AppController controller;
  setUp(() {
    controller = AppController(
      api: ApiClient(
        transport: (method, uri, headers, body) async {
          if (uri.path == '/api/users/login') {
            return const ApiResponse(401, {
              'message': 'Sai tài khoản hoặc mật khẩu',
            });
          }
          return const ApiResponse(200, []);
        },
      ),
    );
  });
  tearDown(() => controller.dispose());
  testWidgets('renders the QTJP branded home screen', (tester) async {
    await tester.pumpWidget(QTJPMobile(controller: controller));

    expect(find.textContaining('Học tiếng Nhật'), findsOneWidget);
    expect(find.text('Bắt đầu học'), findsOneWidget);
    expect(find.text('Bảng chữ cái Nhật'), findsOneWidget);
    expect(find.text('Flashcard từ vựng'), findsOneWidget);
    expect(find.text('Ngữ pháp tiếng Nhật'), findsOneWidget);
    expect(find.text('Từ điển Nhật – Việt'), findsOneWidget);
    expect(find.text('Luyện viết với AI'), findsWidgets);
    expect(find.text('Thi thử JLPT'), findsWidgets);
    expect(find.text('Học qua video'), findsOneWidget);
    expect(find.text('Chọn cấp độ JLPT'), findsOneWidget);
    expect(find.text('Con đường mùa hoa'), findsOneWidget);
    expect(find.text('Phú Sĩ mùa thu'), findsOneWidget);
    expect(find.text('Làm quen'), findsOneWidget);
    expect(find.text('Xây nền kiến thức'), findsOneWidget);
    expect(find.text('Thực hành mỗi ngày'), findsOneWidget);
    expect(find.text('Kiểm tra tiến bộ'), findsOneWidget);
  });

  testWidgets('uses a carousel on compact screens and opens Kyuto', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(QTJPMobile(controller: controller));

    expect(find.byKey(const ValueKey('home-feature-carousel')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('japan-inspiration-carousel')),
      findsOneWidget,
    );
    expect(find.text('Kyuto AI'), findsOneWidget);

    await tester.tap(find.text('Kyuto AI'));
    await tester.pumpAndSettle();

    expect(find.text('Kyuto · Trợ lý AI QTJP'), findsOneWidget);
    expect(find.text('Tra từ vựng'), findsOneWidget);
    expect(find.text('Giải thích ngữ pháp'), findsOneWidget);
  });

  testWidgets('fits a narrow 320 logical pixel screen', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(QTJPMobile(controller: controller));
    await tester.pump();

    expect(find.byKey(const ValueKey('home-feature-carousel')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('japan-inspiration-carousel')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('shares the JLPT level across tabs and preserves it after back', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(QTJPMobile(controller: controller));
    final n3 = find.widgetWithText(ChoiceChip, 'N3');
    await tester.ensureVisible(n3);
    await tester.tap(n3);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Học tập'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'N3')).selected,
      isTrue,
    );

    final flashcard = find.byKey(const ValueKey('learning-flashcard'));
    await tester.ensureVisible(flashcard);
    await tester.tap(flashcard);
    await tester.pumpAndSettle();
    expect(find.text('Cấp độ đang chọn: N3'), findsOneWidget);
    expect(find.text('Đăng nhập để học'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Học tập cùng QTJP'), findsOneWidget);
    await tester.tap(find.text('Luyện đề'));
    await tester.pumpAndSettle();
    expect(find.text('Cấp độ đang chọn: N3'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );
    expect(
      tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'N3')).selected,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'login validates input and remains a guest on a narrow keyboard viewport',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);

      await tester.pumpWidget(QTJPMobile(controller: controller));
      await tester.tap(find.text('Cá nhân'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('profile-login')));
      await tester.pumpAndSettle();

      final submit = find.byKey(const ValueKey('login-submit'));
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.text('Vui lòng nhập tên đăng nhập.'), findsOneWidget);
      expect(find.text('Vui lòng nhập mật khẩu.'), findsOneWidget);

      final username = find.byKey(const ValueKey('login-username'));
      final password = find.byKey(const ValueKey('login-password'));
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      await tester.pumpAndSettle();
      await tester.ensureVisible(username);
      await tester.enterText(username, 'qtjp_learner');
      await tester.ensureVisible(password);
      await tester.enterText(password, 'sample-password');
      await tester.ensureVisible(find.byTooltip('Hiện mật khẩu'));
      await tester.tap(find.byTooltip('Hiện mật khẩu'));
      await tester.pump();
      expect(
        tester
            .widget<TextField>(
              find.descendant(of: password, matching: find.byType(TextField)),
            )
            .obscureText,
        isFalse,
      );

      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('login-error')), findsOneWidget);
      expect(find.text('Sai tài khoản hoặc mật khẩu'), findsOneWidget);
      expect(find.text('Vui lòng nhập mật khẩu.'), findsNothing);
      expect(tester.takeException(), isNull);

      tester.view.resetViewInsets();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
        find.text('Bạn đang khám phá ứng dụng với tư cách khách.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('Kyuto dictionary shortcut navigates out of its sheet', (
    tester,
  ) async {
    await tester.pumpWidget(QTJPMobile(controller: controller));
    await tester.tap(find.text('Kyuto AI'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tra từ vựng'));
    await tester.pumpAndSettle();
    expect(find.text('Từ điển Nhật – Việt'), findsOneWidget);
    expect(find.text('Kyuto · Trợ lý AI QTJP'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Kyuto AI'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
