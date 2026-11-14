import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtjp_mobile/app/app_controller.dart';
import 'package:qtjp_mobile/core/network/api_client.dart';
import 'package:qtjp_mobile/main.dart';
import 'package:qtjp_mobile/screens/home/models/home_feature_item.dart';
import 'package:qtjp_mobile/screens/home/widgets/home_feature_card.dart';
import 'package:qtjp_mobile/screens/home/widgets/home_feature_carousel.dart';

void main() {
  testWidgets(
    'corner avatar follows account changes and opens the account menu',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = AppController(
        api: ApiClient(
          transport: (_, uri, _, _) async {
            return ApiResponse(
              200,
              uri.path.endsWith('/login')
                  ? {
                      'id': 1,
                      'username': 'trung',
                      'fullName': 'Trung',
                      'token': 'test',
                    }
                  : {},
            );
          },
        ),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(QTJPMobile(controller: controller));
      final avatar = find.byKey(const ValueKey('home-account-avatar'));
      expect(
        tester.getCenter(avatar).dx,
        greaterThan(tester.getCenter(find.byTooltip('Thông báo')).dx),
      );
      expect(tester.getRect(avatar).bottom, lessThanOrEqualTo(64));
      await controller.login('trung', 'password');
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: avatar, matching: find.text('T')),
        findsOneWidget,
      );
      controller.updateProfile({
        'id': 1,
        'username': 'trung',
        'fullName': 'Quang',
      });
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: avatar, matching: find.text('Q')),
        findsOneWidget,
      );
      await tester.tap(avatar);
      await tester.pumpAndSettle();
      expect(find.text('Quang'), findsOneWidget);
      expect(find.text('Quản trị'), findsNothing);
      expect(find.text('Cá nhân'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('account-menu-Hồ sơ')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<NavigationBar>(
              find.byType(NavigationBar, skipOffstage: false),
            )
            .selectedIndex,
        0,
      );
      expect(
        tester
            .widget<NavigationBar>(
              find.byType(NavigationBar, skipOffstage: false),
            )
            .destinations
            .length,
        4,
      );
      expect(find.text('Xin chào, Quang'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await controller.logout();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byTooltip('Tài khoản'), findsOneWidget);
      expect(
        find.descendant(of: avatar, matching: find.text('Q')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'four main tabs share a header and learning groups real study modules',
    (tester) async {
      final controller = AppController(
        api: ApiClient(
          transport: (_, _, _, _) async => const ApiResponse(200, []),
        ),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(QTJPMobile(controller: controller));
      expect(
        tester
            .widget<NavigationBar>(find.byType(NavigationBar))
            .destinations
            .length,
        4,
      );
      expect(find.text('Cá nhân'), findsNothing);
      await tester.tap(find.text('Học tập'));
      await tester.pumpAndSettle();
      for (final id in [
        'flashcard',
        'grammar',
        'alphabet',
        'writing',
        'video',
      ]) {
        expect(find.byKey(ValueKey('learning-$id')), findsOneWidget);
      }
      expect(find.byKey(const ValueKey('learning-exam')), findsNothing);
      expect(find.byKey(const ValueKey('learning-vocabulary')), findsOneWidget);
      expect(find.text('Flashcard'), findsOneWidget);
      expect(find.byKey(const ValueKey('learning-dictionary')), findsNothing);
      expect(find.byKey(const ValueKey('home-account-avatar')), findsOneWidget);
      await tester.tap(find.text('Luyện đề'));
      await tester.pumpAndSettle();
      expect(find.text('Luyện đề JLPT'), findsOneWidget);
      expect(find.byKey(const ValueKey('home-account-avatar')), findsOneWidget);
      expect(find.byTooltip('Tải lại'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [320.0, 360.0, 393.0, 430.0, 800.0]) {
    testWidgets(
      'arc carousel swipes, wraps, selects and opens at width $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        String? opened;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: HomeFeatureCarousel(
                    features: homeFeatureItems,
                    selectedLevel: 'N3',
                    onFeatureTap: (feature) => opened = feature.id,
                  ),
                ),
              ),
            ),
          ),
        );
        HomeFeatureCard active() => tester
            .widgetList<HomeFeatureCard>(find.byType(HomeFeatureCard))
            .singleWhere((card) => card.isActive);
        expect(active().feature.id, 'alphabet');
        final cardSize = tester.getSize(find.byWidget(active()));
        expect(cardSize.height, closeTo(cardSize.width, .1));
        await tester.tap(find.byTooltip('Chức năng trước'));
        await tester.pumpAndSettle();
        expect(active().feature.id, 'video');
        await tester.tap(find.byTooltip('Chức năng tiếp theo'));
        await tester.pumpAndSettle();
        expect(active().feature.id, 'alphabet');
        final stage = find.byKey(const ValueKey('home-feature-carousel'));
        await tester.drag(stage, const Offset(-160, 0));
        await tester.pumpAndSettle();
        expect(active().feature.id, 'flashcard');
        expect(opened, isNull);
        final stageRect = tester.getRect(stage);
        await tester.tapAt(Offset(stageRect.left + 8, stageRect.center.dy));
        await tester.pumpAndSettle();
        expect(active().feature.id, 'alphabet');
        expect(opened, isNull);
        await tester.tap(find.byTooltip('Ngữ pháp tiếng Nhật'));
        await tester.pumpAndSettle();
        expect(active().feature.id, 'grammar');
        await tester.tapAt(tester.getCenter(stage));
        await tester.pumpAndSettle();
        expect(opened, 'grammar');
        expect(active().selectedLevel, 'N3');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('arc carousel fits larger system text on a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: HomeFeatureCarousel(
                features: homeFeatureItems,
                selectedLevel: 'N5',
                onFeatureTap: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
