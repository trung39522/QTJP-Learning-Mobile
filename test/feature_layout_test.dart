import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtjp_mobile/app/app_controller.dart';
import 'package:qtjp_mobile/core/network/api_client.dart';
import 'package:qtjp_mobile/main.dart';

Future<AppController> account() async {
  final app = AppController(
    api: ApiClient(
      transport: (method, uri, headers, body) async {
        if (uri.path.endsWith('/login')) {
          return const ApiResponse(200, {
            'id': 1,
            'username': 'learner',
            'token': 'test',
          });
        }
        if (uri.path.endsWith('/unread-count')) {
          return const ApiResponse(200, {'unreadCount': 0});
        }
        return const ApiResponse(200, []);
      },
    ),
  );
  addTearDown(app.dispose);
  await app.login('learner', 'password');
  return app;
}

void main() {
  for (final width in [320.0, 360.0, 393.0, 430.0]) {
    testWidgets(
      'web-derived feature pages fit $width dp with original artwork',
      (tester) async {
        tester.view.physicalSize = Size(width, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(QTJPMobile(controller: await account()));
        await tester.pumpAndSettle();
        for (final feature in [
          'dictionary',
          'grammar',
          'flashcard',
          'alphabet',
          'writing',
          'exam',
        ]) {
          final navigator = tester.state<NavigatorState>(
            find.byType(Navigator),
          );
          navigator.pushNamed('/learn/$feature?level=N5');
          await tester.pumpAndSettle();
          final intro = find.byKey(
            ValueKey(
              feature == 'dictionary'
                  ? 'dictionary-query'
                  : 'feature-intro-$feature',
            ),
          );
          expect(intro, findsOneWidget);
          final rect = tester.getRect(intro);
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(width));
          if (feature == 'writing' || feature == 'exam') {
            final asset = feature == 'writing'
                ? 'writing2.jpg'
                : 'jlpt-classroom.jpg';
            expect(
              find.byWidgetPredicate(
                (widget) =>
                    widget is Image &&
                    widget.image is ResizeImage &&
                    (widget.image as ResizeImage).imageProvider ==
                        AssetImage('assets/learning/$asset'),
              ),
              findsOneWidget,
            );
          }
          expect(tester.takeException(), isNull, reason: feature);
          navigator.pop();
          await tester.pumpAndSettle();
        }
      },
    );
  }

  testWidgets(
    'dictionary header collapses and search remains usable above a narrow keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(QTJPMobile(controller: await account()));
      tester
          .state<NavigatorState>(find.byType(Navigator))
          .pushNamed('/learn/dictionary');
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 270);
      await tester.pumpAndSettle();
      final input = find.byKey(const ValueKey('dictionary-query'));
      await Scrollable.ensureVisible(tester.element(input), alignment: .4);
      await tester.pumpAndSettle();
      await tester.enterText(input, '猫');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(input).controller!.text, '猫');
      expect(tester.takeException(), isNull);
    },
  );
}
