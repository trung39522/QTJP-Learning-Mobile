import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtjp_mobile/app/app_controller.dart';
import 'package:qtjp_mobile/core/network/api_client.dart';
import 'package:qtjp_mobile/main.dart';
import 'package:qtjp_mobile/screens/assistant/assistant_repository.dart';
import 'package:qtjp_mobile/screens/writing/writing_repository.dart';

const topic = {
  'id': 10,
  'title': 'Giới thiệu bản thân',
  'level': 'N5',
  'category': 'Đời sống',
  'minSentences': 3,
  'maxSentences': 5,
  'vocabularyHints': ['学生'],
  'grammarHints': ['～です'],
};

Map<String, dynamic> review(int attempt) => {
  'writingId': 500 + attempt,
  'attemptNumber': attempt,
  'previousScore': attempt == 1 ? null : 80,
  'improvement': attempt == 1 ? null : 10,
  'aiModel': 'server-selected-model',
  'evaluation': {
    'totalScore': attempt == 1 ? 80 : 90,
    'scores': {'grammar': 25},
    'summary': 'Bài viết rõ ràng.',
    'correctedText': '私は学生です。',
    'corrections': [
      {
        'original': '私学生',
        'corrected': '私は学生です',
        'errorType': 'Trợ từ',
        'explanation': 'Thêm は và です.',
      },
    ],
    'strengths': ['Dùng từ phù hợp.'],
    'nextSteps': ['Luyện trợ từ.'],
    'vocabularySuggestions': [
      {'word': '学生', 'reading': 'がくせい', 'meaning': 'học sinh'},
    ],
  },
};

Future<AppController> signedIn(ApiTransport transport) async {
  final app = AppController(
    api: ApiClient(
      transport: (method, uri, headers, body) async {
        if (uri.path == '/api/users/login') {
          return const ApiResponse(200, {
            'id': 1,
            'username': 'learner',
            'token': 'test-token',
          });
        }
        if (uri.path == '/api/notifications/unread-count') {
          return const ApiResponse(200, {'unreadCount': 0});
        }
        return transport(method, uri, headers, body);
      },
    ),
  );
  addTearDown(app.dispose);
  await app.login('learner', 'password');
  return app;
}

Future<void> openRoute(
  WidgetTester tester,
  AppController app,
  String route,
) async {
  await tester.pumpWidget(QTJPMobile(controller: app));
  tester.state<NavigatorState>(find.byType(Navigator)).pushNamed(route);
  await tester.pumpAndSettle();
}

Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  test(
    'writing endpoints keep identity server-owned and link revision IDs',
    () async {
      final calls = <String>[];
      final api = ApiClient(
        transport: (method, uri, headers, body) async {
          calls.add(uri.path);
          expect(headers['Authorization'], 'Bearer test-token');
          if (uri.path.endsWith('/topics')) {
            expect(uri.queryParameters['level'], 'N5');
            return const ApiResponse(200, [topic]);
          }
          if (uri.path.endsWith('/generate')) {
            expect(body, {'level': 'N3', 'category': 'Công việc'});
            return const ApiResponse(200, topic);
          }
          if (uri.path.endsWith('/submit')) {
            expect(body, {
              'topicId': 10,
              'text': '私は学生です。',
              'parentWritingId': 501,
            });
            return ApiResponse(200, review(2));
          }
          if (uri.path.endsWith('/history')) return const ApiResponse(200, []);
          return const ApiResponse(200, {'totalSubmissions': 2});
        },
      )..token = 'test-token';
      final repo = WritingRepository(api);
      expect((await repo.topics('N5')).single.vocabularyHints, ['学生']);
      await repo.generate('N3', 'Công việc');
      final result = await repo.submit(10, ' 私は学生です。 ', parentWritingId: 501);
      expect(result.id, 502);
      expect(result.score, 90);
      expect(result.improvement, 10);
      expect((await repo.history()).stats['totalSubmissions'], 2);
      expect(calls.where((path) => path.endsWith('/submit')), hasLength(1));
    },
  );

  test(
    'AI validation does not send invalid questions or empty writing',
    () async {
      var calls = 0;
      final api = ApiClient(
        transport: (m, u, h, b) async {
          calls++;
          return const ApiResponse(200, {});
        },
      )..token = 'test-token';
      await expectLater(
        WritingRepository(api).submit(10, ' '),
        throwsA(isA<ApiException>()),
      );
      await expectLater(
        AssistantRepository(api).send('a' * 1001, []),
        throwsA(isA<ApiException>()),
      );
      expect(calls, 0);
    },
  );

  test(
    'Kyuto sends only supported recent turns and preserves server quota errors',
    () async {
      var fail = false;
      final api = ApiClient(
        transport: (m, u, h, b) async {
          if (fail) {
            return const ApiResponse(429, {
              'code': 'QUOTA_EXCEEDED',
              'message': 'Hết lượt hôm nay',
              'links': [
                {'title': 'Ngữ pháp', 'path': '/grammar?level=N3'},
              ],
            });
          }
          final body = b as Map;
          expect(body['message'], 'Giải thích ～ている');
          final history = body['history'] as List;
          expect(history, hasLength(10));
          expect((history.first as Map)['content'], '2');
          expect(
            history.every((row) => (row as Map)['role'] != 'system'),
            isTrue,
          );
          return const ApiResponse(200, {
            'answer': 'Diễn tả hành động đang diễn ra.',
            'remaining': 2,
            'mode': 'RAG',
            'sources': [],
            'links': [],
          });
        },
      )..token = 'test-token';
      final repo = AssistantRepository(api);
      final reply = await repo.send(' Giải thích ～ている ', [
        const AssistantTurn('system', 'untrusted'),
        for (var i = 0; i < 12; i++)
          AssistantTurn(i.isEven ? 'user' : 'assistant', '$i'),
        const AssistantTurn('user', '   '),
        const AssistantTurn('assistant', ''),
      ]);
      expect(reply.remaining, 2);
      fail = true;
      await expectLater(
        repo.send('Ngữ pháp N3', []),
        throwsA(
          isA<ApiException>()
              .having((e) => e.status, 'quota status', 429)
              .having(
                (e) => e.details?['links'],
                'fallback learning links',
                isNotEmpty,
              ),
        ),
      );
    },
  );

  test('assistant navigation rejects external and malformed paths', () {
    for (final path in [
      'https://evil.example',
      '//evil.example',
      '/grammar/../admin',
      '/%2e%2e/admin',
      '/grammar?level=N0',
      '/grammar?level=N3&next=https://evil.example',
      '/grammar?lesson=abc',
      '/dictionary#secret',
      '/dictionary\\evil',
      '/%zz',
      '/vip?payment=success',
      '/exam?level=N3&next=external',
      '/video-learning?next=external',
    ]) {
      expect(assistantMobileRoute(path), isNull, reason: path);
    }
    expect(assistantMobileRoute('/flashcard/N3'), '/learn/flashcard?level=N3');
    expect(
      assistantMobileRoute(
        '/grammar?tab=curriculum&level=N4&lesson=7&pattern=test',
      ),
      '/learn/grammar?level=N4&lesson=7&pattern=test',
    );
    expect(assistantMobileRoute('/profile'), '/profile');
    expect(assistantMobileRoute('/exam?level=N3'), '/learn/exam?level=N3');
    expect(assistantMobileRoute('/video-learning'), '/learn/video');
    expect(
      assistantMobileRoute('/video-learning?level=N3'),
      '/learn/video?level=N3',
    );
    expect(assistantMobileRoute('/vip'), '/vip');
  });

  test('per-request AI deadline is honored without a second request', () async {
    var calls = 0;
    final api = ApiClient(
      transport: (m, u, h, b) {
        calls++;
        return Completer<ApiResponse>().future;
      },
    );
    await expectLater(
      api.request('POST', '/example', timeout: const Duration(milliseconds: 5)),
      throwsA(
        isA<ApiException>().having(
          (e) => e.code,
          'uncertain timeout',
          'REQUEST_TIMEOUT',
        ),
      ),
    );
    expect(calls, 1);
  });

  testWidgets(
    'writing submits, shows feedback, revises and loads grouped history',
    (tester) async {
      final submissions = <Map>[];
      final app = await signedIn((m, uri, h, b) async {
        if (uri.path.endsWith('/topics')) {
          return const ApiResponse(200, [topic]);
        }
        if (uri.path.endsWith('/submit')) {
          submissions.add(b as Map);
          return ApiResponse(200, review(submissions.length));
        }
        if (uri.path.endsWith('/history')) {
          return ApiResponse(200, [
            {
              'topicId': 10,
              'topicTitle': 'Giới thiệu bản thân',
              'level': 'N5',
              'latestScore': 90,
              'improvement': 10,
              'attempts': [
                {
                  'id': 501,
                  'text': '私学生。',
                  'score': 80,
                  'attemptNumber': 1,
                  'submittedAt': '2026-11-10T15:00:00',
                },
                {
                  'id': 502,
                  'text': '私は学生です。',
                  'score': 90,
                  'attemptNumber': 2,
                  'submittedAt': '2026-11-10T15:05:00',
                },
              ],
            },
          ]);
        }
        return const ApiResponse(200, {
          'totalWritings': 1,
          'totalSubmissions': 2,
          'averageScore': 85,
          'highestScore': 90,
          'totalErrors': 1,
        });
      });
      await openRoute(tester, app, '/learn/writing?level=N5');
      await tap(tester, find.byKey(const ValueKey('writing-topic-10')));
      await tester.enterText(
        find.byKey(const ValueKey('writing-input')),
        '私学生。',
      );
      await tap(tester, find.byKey(const ValueKey('writing-submit')));
      expect(find.text('Kết quả: 80/100 · Lần 1'), findsOneWidget);
      expect(
        find.text('Thêm は và です.', findRichText: true),
        findsNothing,
      ); // Explanation is combined with its error type.
      expect(find.text('Trợ từ: Thêm は và です.'), findsOneWidget);
      await tap(tester, find.byKey(const ValueKey('writing-revise')));
      await tester.ensureVisible(find.byKey(const ValueKey('writing-input')));
      await tester.enterText(
        find.byKey(const ValueKey('writing-input')),
        '私は学生です。',
      );
      await tap(tester, find.byKey(const ValueKey('writing-submit')));
      expect(submissions.last['parentWritingId'], 501);
      expect(find.text('Kết quả: 90/100 · Lần 2'), findsOneWidget);
      await tap(tester, find.text('Xem lịch sử & thống kê'));
      expect(find.text('Bài viết: 1 · Lượt nộp: 2'), findsOneWidget);
      await tap(tester, find.text('N5 · Giới thiệu bản thân'));
      expect(find.text('Lần 2 · 90/100'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'draft is preserved on failure and accidental back needs a choice',
    (tester) async {
      var submits = 0;
      final app = await signedIn((m, uri, h, b) async {
        if (uri.path.endsWith('/topics')) {
          return const ApiResponse(200, [topic]);
        }
        submits++;
        return const ApiResponse(503, {'message': 'AI tạm ngừng'});
      });
      await openRoute(tester, app, '/learn/writing?level=N5');
      await tap(tester, find.byKey(const ValueKey('writing-topic-10')));
      await tap(tester, find.byKey(const ValueKey('writing-submit')));
      expect(submits, 0);
      await tester.enterText(
        find.byKey(const ValueKey('writing-input')),
        '私は学生です。',
      );
      await tap(tester, find.byKey(const ValueKey('writing-submit')));
      expect(find.text('AI tạm ngừng'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('writing-input')))
            .controller!
            .text,
        '私は学生です。',
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Rời bài viết?'), findsOneWidget);
      await tester.tap(find.text('Ở lại'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('writing-input')), findsOneWidget);
      expect(submits, 1);
    },
  );

  testWidgets('AI topic generation happens only on explicit action', (
    tester,
  ) async {
    var generates = 0;
    final app = await signedIn((m, uri, h, b) async {
      if (uri.path.endsWith('/topics')) return const ApiResponse(200, []);
      generates++;
      expect(b, {'level': 'N3', 'category': 'Đời sống'});
      return const ApiResponse(200, topic);
    });
    await openRoute(tester, app, '/learn/writing?level=N3');
    expect(generates, 0);
    await tap(tester, find.byKey(const ValueKey('writing-generate')));
    expect(generates, 1);
    expect(find.byKey(const ValueKey('writing-input')), findsOneWidget);
  });

  testWidgets(
    'writing blocks duplicate submits and hides late feedback after logout',
    (tester) async {
      final pending = Completer<ApiResponse>();
      var submissions = 0;
      final app = await signedIn((m, uri, h, b) async {
        if (uri.path.endsWith('/topics')) {
          return const ApiResponse(200, [topic]);
        }
        if (uri.path.endsWith('/logout')) return const ApiResponse(200, {});
        submissions++;
        return pending.future;
      });
      await openRoute(tester, app, '/learn/writing?level=N5');
      await tap(tester, find.byKey(const ValueKey('writing-topic-10')));
      await tester.enterText(
        find.byKey(const ValueKey('writing-input')),
        '私は学生です。',
      );
      final submit = find.byKey(const ValueKey('writing-submit'));
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pump();
      expect(tester.widget<FilledButton>(submit).onPressed, isNull);
      await tester.tap(submit);
      await tester.pump();
      expect(submissions, 1);
      await app.logout();
      await tester.pumpAndSettle();
      pending.complete(ApiResponse(200, review(1)));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('writing-score')), findsNothing);
      expect(find.byKey(const ValueKey('writing-input')), findsNothing);
      expect(find.text('Đăng nhập để học'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'writing timeout retains draft and requires history before another submit',
    (tester) async {
      var submissions = 0;
      final app = await signedIn((m, uri, h, b) async {
        if (uri.path.endsWith('/topics')) {
          return const ApiResponse(200, [topic]);
        }
        submissions++;
        throw const ApiException(
          'Kiểm tra lịch sử trước khi gửi lại.',
          code: 'REQUEST_TIMEOUT',
        );
      });
      await openRoute(tester, app, '/learn/writing?level=N5');
      await tap(tester, find.byKey(const ValueKey('writing-topic-10')));
      await tester.enterText(
        find.byKey(const ValueKey('writing-input')),
        '私は学生です。',
      );
      final submit = find.byKey(const ValueKey('writing-submit'));
      await tap(tester, submit);
      expect(submissions, 1);
      expect(tester.widget<FilledButton>(submit).onPressed, isNull);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('writing-input')))
            .controller!
            .text,
        '私は学生です。',
      );
      expect(find.text('Kiểm tra lịch sử trước khi gửi lại'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Kyuto quota error keeps sources, safe navigation and the unsent question',
    (tester) async {
      var calls = 0;
      final app = await signedIn((m, uri, h, b) async {
        if (uri.path.endsWith('/logout')) return const ApiResponse(200, {});
        calls++;
        return const ApiResponse(429, {
          'code': 'QUOTA_EXCEEDED',
          'message': 'Hết lượt hôm nay',
          'sources': [
            {
              'title': 'Bài 7',
              'type': 'Ngữ pháp',
              'excerpt': 'Mẫu ～ている',
              'path': '/grammar?level=N5&lesson=7',
            },
          ],
          'links': [
            {'title': 'Mở ngữ pháp N5', 'path': '/grammar?level=N5'},
            {'title': 'Mở video', 'path': '/video-learning'},
            {'title': 'Mở JLPT N5', 'path': '/exam?level=N5'},
            {'title': 'Bad link', 'path': 'https://evil.example'},
          ],
        });
      });
      await openRoute(tester, app, '/assistant');
      final input = find.byKey(const ValueKey('assistant-input'));
      await tester.enterText(input, 'Giải thích ～ている');
      await tap(tester, find.byKey(const ValueKey('assistant-send')));
      expect(calls, 1);
      expect(find.text('Hết lượt hôm nay'), findsOneWidget);
      expect(
        find.text('Lượt tổng hợp AI còn lại theo máy chủ: 0'),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(input).controller!.text,
        'Giải thích ～ている',
      );
      expect(find.text('Mở ngữ pháp N5'), findsOneWidget);
      expect(find.text('Bad link'), findsNothing);
      expect(find.text('Mở video'), findsOneWidget);
      expect(find.text('Mở JLPT N5'), findsOneWidget);
      await tap(tester, find.text('Nguồn dữ liệu QTJP (1)'));
      expect(find.text('Bài 7'), findsOneWidget);
      expect(find.text('Ngữ pháp · Mẫu ～ている'), findsOneWidget);
      expect(
        tester.widget<ListTile>(find.widgetWithText(ListTile, 'Bài 7')).onTap,
        isNotNull,
      );
      await app.logout();
      await tester.pumpAndSettle();
      expect(find.text('Bài 7'), findsNothing);
      expect(find.text('Hết lượt hôm nay'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Kyuto sends conversation context and clears private chat at logout',
    (tester) async {
      final requests = <Map>[];
      final app = await signedIn((m, uri, h, b) async {
        if (uri.path.endsWith('/logout')) return const ApiResponse(200, {});
        requests.add(b as Map);
        return const ApiResponse(200, {
          'answer': 'Câu trả lời dựa trên học liệu QTJP.',
          'mode': 'RAG',
          'remaining': 2,
          'sources': [
            {
              'title': 'Bài 7',
              'type': 'Ngữ pháp',
              'excerpt': 'Mẫu ～ている',
              'path': '/grammar?level=N5&lesson=7',
            },
          ],
          'links': [
            {'title': 'Mở ngữ pháp N5', 'path': '/grammar?level=N5'},
            {'title': 'Bad link', 'path': 'https://evil.example'},
          ],
        });
      });
      await openRoute(tester, app, '/assistant');
      expect(requests, isEmpty);
      await tester.enterText(
        find.byKey(const ValueKey('assistant-input')),
        'Giải thích ～ている',
      );
      await tap(tester, find.byKey(const ValueKey('assistant-send')));
      expect(find.text('Câu trả lời dựa trên học liệu QTJP.'), findsOneWidget);
      expect(find.text('Bad link'), findsNothing);
      expect(find.text('Mở ngữ pháp N5'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('assistant-input')),
        'Cho tôi ví dụ',
      );
      await tap(tester, find.byKey(const ValueKey('assistant-send')));
      expect((requests.last['history'] as List), hasLength(2));
      await app.logout();
      await tester.pumpAndSettle();
      expect(find.text('Câu trả lời dựa trên học liệu QTJP.'), findsNothing);
      expect(find.text('Đăng nhập để học'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Kyuto blocks duplicate sends and ignores replies from expired session',
    (tester) async {
      final pending = Completer<ApiResponse>();
      var calls = 0;
      final app = await signedIn((m, uri, h, b) async {
        if (uri.path.endsWith('/logout')) return const ApiResponse(200, {});
        calls++;
        return pending.future;
      });
      await openRoute(tester, app, '/assistant');
      await tester.enterText(
        find.byKey(const ValueKey('assistant-input')),
        'Tiến độ của tôi',
      );
      await tester.tap(find.byKey(const ValueKey('assistant-send')));
      await tester.pump();
      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('assistant-send')))
            .onPressed,
        isNull,
      );
      await app.logout();
      await tester.pumpAndSettle();
      pending.complete(
        const ApiResponse(200, {'answer': 'Thông tin riêng của phiên cũ'}),
      );
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.text('Thông tin riêng của phiên cũ'), findsNothing);
    },
  );
}
