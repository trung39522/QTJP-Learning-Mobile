import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtjp_mobile/app/app_controller.dart';
import 'package:qtjp_mobile/core/network/api_client.dart';
import 'package:qtjp_mobile/screens/video/learning_video_player.dart';
import 'package:qtjp_mobile/screens/video/video_repository.dart';
import 'package:qtjp_mobile/screens/video/video_screen.dart';
import 'package:qtjp_mobile/screens/notifications/notifications_screen.dart';
import 'package:qtjp_mobile/main.dart';

const preset = {
  'id': 1,
  'title': 'Video mẫu từ máy chủ',
  'platform': 'YOUTUBE',
  'videoId': 'abcdefghijk',
  'level': 'N5',
};
Map<String, dynamic> video() => {
  'id': 1,
  'title': 'Nội dung học riêng',
  'platform': 'YOUTUBE',
  'videoId': 'abcdefghijk',
  'usage': {'membership': 'FREE', 'remaining': 1},
  'subtitles': [
    {
      'id': 10,
      'startMs': 0,
      'endMs': 1000,
      'japanese': '私は学生です。',
      'vietnamese': 'Tôi là học sinh.',
      'words': [
        {'text': '学生', 'reading': 'がくせい', 'meaning': 'học sinh'},
      ],
    },
    {
      'id': 11,
      'startMs': 1000,
      'endMs': 2000,
      'japanese': '日本語を勉強します。',
      'vietnamese': 'Tôi học tiếng Nhật.',
      'words': [],
    },
  ],
};
Future<AppController> signedIn(ApiTransport handler) async {
  final app = AppController(
    api: ApiClient(
      transport: (m, u, h, b) async {
        if (u.path.endsWith('/login')) {
          return const ApiResponse(200, {
            'id': 1,
            'username': 'learner',
            'token': 'test',
          });
        }
        if (u.path.endsWith('/logout')) {
          return const ApiResponse(200, {});
        }
        return handler(m, u, h, b);
      },
    ),
  );
  addTearDown(app.dispose);
  await app.login('learner', 'password');
  return app;
}

Future<void> show(WidgetTester tester, AppController app, Widget screen) async {
  await tester.pumpWidget(
    AppScope(
      controller: app,
      child: MaterialApp(home: screen),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> reveal(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty &&
      find.byKey(const ValueKey('video-scroll')).evaluate().isNotEmpty) {
    final scroll = find
        .descendant(
          of: find.byKey(const ValueKey('video-scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    tester.state<ScrollableState>(scroll).position.jumpTo(0);
    await tester.pumpAndSettle();
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        220,
        maxScrolls: 40,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('video-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
    }
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> tap(WidgetTester tester, Finder finder) async {
  await reveal(tester, finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

ApiResponse? catalog(Uri uri) {
  if (uri.path.endsWith('/presets')) {
    return const ApiResponse(200, [preset]);
  }
  if (uri.path.endsWith('/history')) {
    return const ApiResponse(200, []);
  }
  if (uri.path.endsWith('/usage')) {
    return const ApiResponse(200, {'membership': 'FREE', 'remaining': 2});
  }
  return null;
}

void main() {
  testWidgets(
    'learning menu opens the complete video catalog, not an implicit N5 filter',
    (tester) async {
      Map<String, String>? query;
      final app = await signedIn((m, u, h, b) async {
        if (u.path.endsWith('/presets')) query = u.queryParameters;
        return catalog(u) ?? const ApiResponse(200, []);
      });
      await tester.pumpWidget(QTJPMobile(controller: app));
      await tap(tester, find.text('Học tập'));
      await tap(tester, find.byKey(const ValueKey('learning-video')));
      expect(query, isEmpty);
      expect(find.widgetWithText(ChoiceChip, 'Tất cả'), findsOneWidget);
    },
  );
  test('video endpoints validate providers, timestamps and keep identity server-owned', () async {
    final paths = <String>[];
    final api = ApiClient(
      transport: (m, u, h, b) async {
        paths.add('$m ${u.path}');
        if (u.path.endsWith('/presets')) {
          expect(h['Authorization'], 'Bearer test');
          expect(u.queryParameters, {'level': 'N3'});
          return const ApiResponse(200, []);
        }
        expect(h['Authorization'], 'Bearer test');
        if (b is Map) {
          expect(b.keys, ['url']);
        }
        if (u.path.endsWith('/history')) {
          return const ApiResponse(200, []);
        }
        if (u.path.endsWith('/usage') || u.path.endsWith('/grammar')) {
          return const ApiResponse(200, {'points': []});
        }
        return ApiResponse(200, video());
      },
    )..token = 'test';
    final repo = VideoRepository(api);
    await repo.presets('N3');
    await repo.history();
    await repo.usage();
    await repo.open(1, preset: true);
    await repo.open(1);
    await repo.analyze('https://youtu.be/abcdefghijk');
    await repo.reanalyze(1);
    await repo.grammar(10);
    expect(
      paths,
      containsAll([
        'GET /api/videos/presets/1',
        'POST /api/videos/analyze',
        'POST /api/videos/subtitles/10/grammar',
      ]),
    );
    final count = paths.length;
    await expectLater(
      repo.analyze('https://youtube.com.attacker.example/watch?v=abc'),
      throwsA(isA<ApiException>()),
    );
    expect(paths.length, count);
    expect(
      () => LearningVideo.fromJson({...video(), 'videoId': '</script>'}),
      throwsA(isA<ApiException>()),
    );
    expect(LearningVideo.fromJson(video()).subtitleAt(1500), 1);
    expect(LearningVideo.fromJson(video()).subtitleAt(3000), -1);
    final html = videoPlayerHtml(
      LearningVideo.fromJson(video()),
      'https://qtjp.example',
    );
    expect(html, contains('youtube.com/iframe_api'));
    expect(html, isNot(contains('Bearer')));
    final tt = videoPlayerHtml(
      LearningVideo.fromJson({
        ...video(),
        'platform': 'TIKTOK',
        'videoId': '1234567890123456789',
      }),
      'https://qtjp.example',
    );
    expect(tt, contains("event.origin!=='https://www.tiktok.com'"));
  });
  testWidgets(
    'video opens only explicitly, syncs subtitles, repeats sentences and explains grammar',
    (tester) async {
      var opens = 0, grammarCalls = 0;
      final commands = <String>[];
      ValueChanged<int>? position;
      final app = await signedIn((m, u, h, b) async {
        final response = catalog(u);
        if (response != null) {
          return response;
        }
        if (u.path.endsWith('/grammar')) {
          grammarCalls++;
          return const ApiResponse(200, {
            'points': [
              {
                'pattern': 'N は N です',
                'structure': ['N は N です'],
                'usage': 'Giới thiệu bản thân',
                'examples': [],
              },
            ],
          });
        }
        opens++;
        return ApiResponse(200, video());
      });
      await show(
        tester,
        app,
        VideoScreen(
          playerBuilder: (context, video, controls, onPosition) {
            position = onPosition;
            controls.invoke = (method, value) async {
              commands.add('$method:$value');
            };
            return const SizedBox(
              height: 50,
              child: Text('Test media surface'),
            );
          },
        ),
      );
      expect(opens, 0);
      expect(grammarCalls, 0);
      await tap(tester, find.byKey(const ValueKey('video-preset-1')));
      expect(opens, 1);
      expect(find.text('私は学生です。'), findsOneWidget);
      expect(find.text('学生 · がくせい'), findsOneWidget);
      await tap(tester, find.byKey(const ValueKey('video-grammar')));
      expect(grammarCalls, 1);
      expect(find.text('Giới thiệu bản thân'), findsOneWidget);
      await tap(tester, find.widgetWithText(ChoiceChip, '2'));
      expect(commands, contains('seek:1.0'));
      position!(0); // A stale player tick must not undo the selected sentence.
      await tester.pump();
      expect(find.text('日本語を勉強します。'), findsOneWidget);
      await tap(tester, find.byKey(const ValueKey('video-repeat')));
      position!(1100); // The player has acknowledged the requested seek.
      position!(2100);
      await tester.pump();
      expect(commands, contains('pause:null'));
      await app.logout();
      await tester.pumpAndSettle();
      expect(find.text('Nội dung học riêng'), findsNothing);
      expect(find.text('Giới thiệu bản thân'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'presets use JWT, default to all levels and survive a failed usage request',
    (tester) async {
      final queries = <Map<String, String>>[];
      final app = await signedIn((m, u, h, b) async {
        if (u.path.endsWith('/presets')) {
          expect(h['Authorization'], 'Bearer test');
          queries.add(u.queryParameters);
          return ApiResponse(200, [
            preset,
            {...preset, 'id': 2, 'title': 'Video có sẵn N4', 'level': 'N4'},
          ]);
        }
        if (u.path.endsWith('/usage')) {
          return const ApiResponse(503, {'message': 'Lượt AI tạm lỗi'});
        }
        return const ApiResponse(200, []);
      });
      await show(tester, app, const VideoScreen());
      expect(queries.single, isEmpty);
      await tap(tester, find.widgetWithText(ChoiceChip, 'N4'));
      expect(find.textContaining('Lượt AI tạm lỗi'), findsOneWidget);
      await tap(tester, find.widgetWithText(ChoiceChip, 'N4'));
      expect(queries.last, {'level': 'N4'});
    },
  );
  testWidgets(
    'preset preview plays metadata without AI until explicitly requested',
    (tester) async {
      var opens = 0;
      final app = await signedIn((m, u, h, b) async {
        final response = catalog(u);
        if (response != null) return response;
        opens++;
        return ApiResponse(200, video());
      });
      await show(
        tester,
        app,
        VideoScreen(
          playerBuilder: (c, v, controls, position) =>
              const Text('Native player test surface'),
        ),
      );
      await tap(tester, find.byKey(const ValueKey('video-preview-1')));
      expect(opens, 0);
      expect(find.text('Native player test surface'), findsOneWidget);
      await tap(tester, find.byKey(const ValueKey('video-load-ai')));
      expect(opens, 1);
      expect(find.text('私は学生です。'), findsOneWidget);
    },
  );
  test(
    'player identifies the installed package over HTTPS, not the USB backend',
    () {
      expect(
        videoPlayerOrigin('com.example.qtjp_mobile'),
        'https://com.example.qtjp_mobile',
      );
      expect(
        videoPlayerOrigin('com.example.qtjpMobile'),
        'https://com.example.qtjpmobile',
      );
      expect(() => videoPlayerOrigin('bad/</script>'), throwsFormatException);
    },
  );
  testWidgets(
    'analysis timeout retains URL and requires history inspection without automatic resend',
    (tester) async {
      var posts = 0;
      final app = await signedIn((m, u, h, b) async {
        final response = catalog(u);
        if (response != null) {
          return response;
        }
        posts++;
        throw const ApiException(
          'Máy chủ có thể vẫn đang phân tích.',
          code: 'REQUEST_TIMEOUT',
        );
      });
      await show(tester, app, const VideoScreen());
      await tester.enterText(
        find.byKey(const ValueKey('video-url')),
        'https://youtu.be/abcdefghijk',
      );
      await tap(tester, find.byKey(const ValueKey('video-analyze')));
      expect(posts, 1);
      await reveal(tester, find.byKey(const ValueKey('video-preset-1')));
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('video-preset-1')))
            .onPressed,
        isNull,
      );
      await reveal(tester, find.byKey(const ValueKey('video-analyze')));
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('video-analyze')))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('video-url')))
            .controller!
            .text,
        'https://youtu.be/abcdefghijk',
      );
      await tap(tester, find.text('Kiểm tra lịch sử trước khi phân tích lại'));
      expect(posts, 1);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('video-analyze')))
            .onPressed,
        isNotNull,
      );
    },
  );
  testWidgets(
    'preset timeout also requires reading history before another open',
    (tester) async {
      var opens = 0;
      final app = await signedIn((m, u, h, b) async {
        final response = catalog(u);
        if (response != null) return response;
        opens++;
        throw const ApiException('Đang xử lý', code: 'REQUEST_TIMEOUT');
      });
      await show(tester, app, const VideoScreen());
      final presetTile = find.byKey(const ValueKey('video-preset-1'));
      await tap(tester, presetTile);
      expect(opens, 1);
      await reveal(tester, presetTile);
      expect(tester.widget<FilledButton>(presetTile).onPressed, isNull);
      await tap(tester, find.text('Kiểm tra lịch sử trước khi phân tích lại'));
      expect(opens, 1);
      await reveal(tester, presetTile);
      expect(tester.widget<FilledButton>(presetTile).onPressed, isNotNull);
    },
  );
  testWidgets(
    'pending analysis blocks duplicate requests and cannot show a late reply after logout',
    (tester) async {
      final pending = Completer<ApiResponse>();
      var posts = 0;
      final app = await signedIn((m, u, h, b) async {
        final response = catalog(u);
        if (response != null) {
          return response;
        }
        posts++;
        return pending.future;
      });
      await show(tester, app, const VideoScreen());
      await tester.enterText(
        find.byKey(const ValueKey('video-url')),
        'https://youtu.be/abcdefghijk',
      );
      final submit = find.byKey(const ValueKey('video-analyze'));
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      await tester.tap(submit);
      await tester.pump();
      expect(tester.widget<FilledButton>(submit).onPressed, isNull);
      await app.logout();
      await tester.pumpAndSettle();
      pending.complete(ApiResponse(200, video()));
      await tester.pumpAndSettle();
      expect(posts, 1);
      expect(find.text('Nội dung học riêng'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'notification read only changes after acknowledgement and external targets never navigate',
    (tester) async {
      var read = false, patches = 0, fail = true;
      final app = await signedIn((m, u, h, b) async {
        if (m == 'PATCH') {
          patches++;
          if (fail) {
            return const ApiResponse(503, {
              'message': 'Chưa lưu được trạng thái đọc',
            });
          }
          read = true;
          return const ApiResponse(204, null);
        }
        return ApiResponse(200, {
          'unreadCount': read ? 0 : 1,
          'items': [
            {
              'id': 3,
              'title': 'Thông báo riêng',
              'content': 'Nội dung tài khoản',
              'read': read,
              'targetUrl': 'https://outside.example',
            },
          ],
        });
      });
      await show(tester, app, const NotificationsScreen());
      expect(patches, 0);
      await tap(tester, find.byKey(const ValueKey('notification-3')));
      expect(find.text('1 thông báo chưa đọc'), findsOneWidget);
      expect(find.text('Chưa lưu được trạng thái đọc'), findsOneWidget);
      fail = false;
      await tap(tester, find.byKey(const ValueKey('notification-3')));
      expect(find.text('0 thông báo chưa đọc'), findsOneWidget);
      expect(find.byType(NotificationsScreen), findsOneWidget);
      await app.logout();
      await tester.pumpAndSettle();
      expect(find.text('Thông báo riêng'), findsNothing);
      expect(find.text('Đăng nhập để học'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
