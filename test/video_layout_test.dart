import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtjp_mobile/app/app_controller.dart';
import 'package:qtjp_mobile/core/network/api_client.dart';
import 'package:qtjp_mobile/core/theme/qtjp_theme.dart';
import 'package:qtjp_mobile/screens/video/models/video_presentation.dart';
import 'package:qtjp_mobile/screens/video/video_screen.dart';
import 'package:qtjp_mobile/screens/video/widgets/video_card.dart';
import 'package:qtjp_mobile/screens/video/widgets/video_catalog_widgets.dart';

Map<String, dynamic> preset(int id) => {
  'id': id,
  'title':
      'Video nghe tiếng Nhật $id với tiêu đề dài để kiểm tra bố cục điện thoại',
  'platform': 'YOUTUBE',
  'videoId': 'abcdefghijk',
  'level': 'N3',
  'description': 'Nội dung luyện nghe do hệ thống cung cấp.',
};

Future<AppController> signedIn(ApiTransport transport) async {
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
        return transport(method, uri, headers, body);
      },
    ),
  );
  addTearDown(app.dispose);
  await app.login('learner', 'password');
  return app;
}

Future<void> show(WidgetTester tester, AppController app) async {
  await tester.pumpWidget(
    AppScope(
      controller: app,
      child: MaterialApp(
        theme: QTJPTheme.light,
        home: VideoScreen(
          playerBuilder: (context, video, controls, position) =>
              const SizedBox(height: 120, child: Text('Native player surface')),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> reveal(WidgetTester tester, Finder target) async {
  final scroll = find
      .descendant(
        of: find.byKey(const ValueKey('video-scroll')),
        matching: find.byType(Scrollable),
      )
      .first;
  if (target.evaluate().isEmpty) {
    tester.state<ScrollableState>(scroll).position.jumpTo(0);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      target,
      200,
      scrollable: scroll,
      maxScrolls: 60,
    );
  }
  await Scrollable.ensureVisible(tester.element(target), alignment: 0.5);
  await tester.pumpAndSettle();
}

void main() {
  test('thumbnails use supplied URLs or validated YouTube IDs, with no fabricated metadata', () {
    expect(
      VideoPresentation({
        ...preset(1),
        'thumbnailUrl': 'https://cdn.example/a.jpg',
      }).thumbnail,
      'https://cdn.example/a.jpg',
    );
    expect(
      VideoPresentation(preset(1)).thumbnail,
      'https://i.ytimg.com/vi/abcdefghijk/hqdefault.jpg',
    );
    expect(
      VideoPresentation({
        ...preset(1),
        'thumbnailUrl': '/uploads/a.jpg',
      }, baseUrl: 'https://qtjp.example').thumbnail,
      'https://qtjp.example/uploads/a.jpg',
    );
    expect(
      VideoPresentation({
        ...preset(1),
        'platform': 'TIKTOK',
        'videoId': '1234567890123456789',
      }).thumbnail,
      isNull,
    );
    expect(
      VideoPresentation({
        ...preset(1),
        'videoId': '<invalid>',
        'thumbnailUrl': 'javascript:alert(1)',
      }).thumbnail,
      isNull,
    );
  });

  for (final width in [320.0, 360.0, 393.0, 430.0]) {
    testWidgets(
      'video catalog at $width dp keeps cards lazy, chips horizontal and preview separate from AI',
      (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var opens = 0;
        final app = await signedIn((method, uri, headers, body) async {
          if (uri.path.endsWith('/presets')) {
            return ApiResponse(200, List.generate(60, (i) => preset(i + 1)));
          }
          if (uri.path.endsWith('/usage')) {
            return const ApiResponse(200, {
              'membership': 'VIP',
              'dailyLimit': 15,
              'remaining': 7,
            });
          }
          if (uri.path.endsWith('/history')) return const ApiResponse(200, []);
          opens++;
          return ApiResponse(200, {...preset(1), 'subtitles': []});
        });
        await show(tester, app);
        expect(find.text('NGHE · HIỂU · GHI NHỚ'), findsNothing);
        expect(find.text('7 lượt còn lại'), findsOneWidget);
        expect(find.text('Gói VIP'), findsOneWidget);
        expect(
          tester.widgetList<VideoCard>(find.byType(VideoCard)).length,
          lessThan(8),
        );
        final chips = find.descendant(
          of: find.byKey(const ValueKey('video-level-filters')),
          matching: find.byType(ChoiceChip),
        );
        expect(chips, findsNWidgets(6));
        final chipRects = chips
            .evaluate()
            .map((e) => tester.getRect(find.byWidget(e.widget)))
            .toList();
        for (final rect in chipRects) {
          expect(rect.center.dy, closeTo(chipRects.first.center.dy, 0.1));
          expect(rect.width, closeTo(chipRects.first.width, 0.1));
        }
        final watch = find.byKey(const ValueKey('video-preview-1'));
        await reveal(tester, watch);
        final thumbnail = tester.getRect(find.byType(VideoThumbnail).first);
        expect(thumbnail.width / thumbnail.height, closeTo(16 / 9, 0.01));
        final networkImages = tester
            .widgetList<Image>(find.byType(Image))
            .where((image) => image.image is ResizeImage);
        expect(networkImages, isNotEmpty);
        final rail = find.byKey(const PageStorageKey('video-presets-ALL'));
        final firstCard = find.byKey(const ValueKey('video-card-preset-1'));
        final beforeSwipe = tester.getRect(firstCard);
        await tester.drag(rail, Offset(-width * .75, 0));
        await tester.pumpAndSettle();
        final secondCard = find.byKey(const ValueKey('video-card-preset-2'));
        expect(secondCard, findsOneWidget);
        expect(tester.getRect(secondCard).top, closeTo(beforeSwipe.top, .1));
        expect(tester.getRect(secondCard).left, lessThan(beforeSwipe.right));
        expect(opens, 0);
        final railScroll = find.descendant(
          of: rail,
          matching: find.byType(Scrollable),
        );
        tester.state<ScrollableState>(railScroll).position.jumpTo(0);
        await tester.pumpAndSettle();
        expect(opens, 0);
        await tester.tap(watch);
        await tester.pumpAndSettle();
        expect(find.text('Native player surface'), findsOneWidget);
        expect(opens, 0);
        final ai = find.byKey(const ValueKey('video-load-ai'));
        await reveal(tester, ai);
        await tester.tap(ai);
        await tester.pumpAndSettle();
        expect(opens, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'catalog and learning history have independent horizontal scroll positions',
    (tester) async {
      tester.view.physicalSize = const Size(360, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final app = await signedIn((method, uri, headers, body) async {
        if (uri.path.endsWith('/presets')) {
          return ApiResponse(
            200,
            List.generate(12, (index) => preset(index + 1)),
          );
        }
        if (uri.path.endsWith('/history')) {
          return ApiResponse(200, [preset(201), preset(202)]);
        }
        return const ApiResponse(200, {
          'membership': 'VIP',
          'remaining': 7,
          'dailyLimit': 15,
        });
      });
      await show(tester, app);
      await reveal(tester, find.byKey(const ValueKey('video-preview-1')));
      final presets = find.byKey(const PageStorageKey('video-presets-ALL'));
      await tester.drag(presets, const Offset(-240, 0));
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const ValueKey('video-history-201')));
      final history = find.byKey(
        PageStorageKey('video-history-${app.api.sessionVersion}'),
      );
      final scroll = find.descendant(
        of: history,
        matching: find.byType(Scrollable),
      );
      expect(tester.state<ScrollableState>(scroll).position.pixels, 0);
      await tester.drag(history, const Offset(-240, 0));
      await tester.pumpAndSettle();
      expect(
        tester.state<ScrollableState>(scroll).position.pixels,
        greaterThan(0),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'loading, partial usage failure, empty history and thumbnail fallback stay truthful',
    (tester) async {
      final pending = Completer<ApiResponse>();
      final app = await signedIn((method, uri, headers, body) async {
        if (uri.path.endsWith('/presets')) return pending.future;
        if (uri.path.endsWith('/usage')) {
          return const ApiResponse(503, {'message': 'Lượt AI tạm lỗi'});
        }
        return const ApiResponse(200, []);
      });
      await tester.pumpWidget(
        AppScope(
          controller: app,
          child: MaterialApp(theme: QTJPTheme.light, home: const VideoScreen()),
        ),
      );
      await tester.pump();
      expect(find.byType(VideoCardSkeleton), findsWidgets);
      expect(find.text('Đang tải lượt AI…'), findsOneWidget);
      pending.complete(
        ApiResponse(200, [
          {
            ...preset(1),
            'platform': 'TIKTOK',
            'videoId': '1234567890123456789',
          },
        ]),
      );
      await tester.pumpAndSettle();
      expect(find.text('Lượt AI tạm lỗi'), findsOneWidget);
      expect(find.text('0 lượt còn lại'), findsNothing);
      final card = find.byKey(const ValueKey('video-card-preset-1'));
      await reveal(tester, card);
      expect(
        find.byKey(const ValueKey('thumbnail-fallback-1')),
        findsOneWidget,
      );
      await reveal(tester, find.text('Bạn chưa có video trong lịch sử.'));
      expect(find.text('Dành cho bạn'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '320 dp with larger text fits analysis form and filters still use server queries',
    (tester) async {
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final queries = <Map<String, String>>[];
      final app = await signedIn((method, uri, headers, body) async {
        if (uri.path.endsWith('/presets')) {
          queries.add(uri.queryParameters);
          return ApiResponse(
            200,
            uri.queryParameters.isEmpty ? [preset(1), preset(2)] : [],
          );
        }
        if (uri.path.endsWith('/usage')) {
          return const ApiResponse(200, {
            'membership': 'FREE',
            'remaining': 0,
            'dailyLimit': 2,
          });
        }
        return const ApiResponse(200, []);
      });
      await show(tester, app);
      await reveal(tester, find.byKey(const ValueKey('video-preview-1')));
      expect(tester.takeException(), isNull);
      final chip = find.widgetWithText(ChoiceChip, 'N3');
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(queries.last, {'level': 'N3'});
      expect(
        find.text('Máy chủ chưa có video mẫu ở cấp độ này.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
