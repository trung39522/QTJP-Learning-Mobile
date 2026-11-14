import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtjp_mobile/app/app_controller.dart';
import 'package:qtjp_mobile/core/network/api_client.dart';
import 'package:qtjp_mobile/screens/exam/digital_exam.dart';
import 'package:qtjp_mobile/screens/exam/exam_listening_player.dart';
import 'package:qtjp_mobile/screens/exam/exam_repository.dart';
import 'package:qtjp_mobile/screens/exam/exam_screen.dart';

const summary = {
  'id': 10,
  'title': 'Đề N5 từ máy chủ',
  'level': 'N5',
  'totalQuestions': 2,
  'totalDurationSeconds': 120,
  'structuredReady': true,
  'sections': [],
};
Map<String, dynamic> question(
  int section, {
  int? selected,
  bool marked = false,
}) => {
  'answerKeyId': 100 + section,
  'category': 'VOCAB',
  'problemNo': 1,
  'questionNo': 1,
  'text': '学校の読み方は？',
  'selectedOption': selected,
  'markedForReview': marked,
  'choices': [
    {'optionNo': 1, 'text': 'がっこう'},
    {'optionNo': 2, 'text': 'せんせい'},
  ],
};
Map<String, dynamic> attempt(
  int stage, {
  int? selected,
  bool marked = false,
  DateTime? deadline,
}) => {
  'attemptId': 5,
  'examId': 10,
  'title': 'Đề N5 từ máy chủ',
  'level': 'N5',
  'totalQuestions': 2,
  'status': stage == 3 ? 'SUBMITTED' : 'IN_PROGRESS',
  if (stage != 1 && stage != 3)
    'currentSection': {
      'sectionId': stage + 1,
      'code': 'VOCAB',
      'name': 'Từ vựng',
      'order': stage + 1,
      'startedAt': DateTime.now().toUtc().toIso8601String(),
      'expiresAt': (deadline ?? DateTime.now().add(const Duration(minutes: 20)))
          .toUtc()
          .toIso8601String(),
      'questions': [question(stage, selected: selected, marked: marked)],
    },
  if (stage == 1)
    'breakState': {
      'sectionId': 3,
      'sectionName': 'Ngữ pháp',
      'expiresAt': DateTime.now()
          .add(const Duration(minutes: 10))
          .toUtc()
          .toIso8601String(),
    },
};
Map<String, dynamic> result() => {
  'attemptId': 5,
  'examId': 10,
  'title': 'Đề N5 từ máy chủ',
  'level': 'N5',
  'totalQuestions': 2,
  'correctCount': 1,
  'scorePercent': 50,
  'practiceScore': 90,
  'teacherComment': 'Ưu tiên luyện thêm từ vựng.',
  'categories': [],
  'answers': [
    {
      ...question(0, selected: 1),
      'questionText': '学校の読み方は？',
      'correct': true,
      'correctOption': 1,
      'explanation': '学校 đọc là がっこう.',
    },
  ],
};
Future<AppController> signedIn(ApiTransport transport) async {
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
        if (u.path.endsWith('/logout')) return const ApiResponse(200, {});
        expect(h['Authorization'], 'Bearer test');
        return transport(m, u, h, b);
      },
    ),
  );
  addTearDown(app.dispose);
  await app.login('learner', 'password');
  return app;
}

Future<void> mount(
  WidgetTester tester,
  AppController app, {
  DateTime Function()? now,
}) async {
  await tester.pumpWidget(
    AppScope(
      controller: app,
      child: MaterialApp(
        home: ExamScreen(initialLevel: 'N5', now: now),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> enterRoom(WidgetTester tester) async {
  await tap(tester, find.byKey(const ValueKey('exam-10')));
  await tap(tester, find.byKey(const ValueKey('exam-start')));
}

class FakeAudio implements ExamAudio {
  final events = StreamController<void>.broadcast();
  final positions = <Duration>[];
  int stops = 0;
  bool disposed = false;
  @override
  Stream<void> get completed => events.stream;
  @override
  Future<bool> play(Uri uri, Duration position) async {
    positions.add(position);
    return true;
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await events.close();
  }
}

void main() {
  testWidgets(
    'start timeout discovers and resumes saved progress without a duplicate POST',
    (tester) async {
      var started = false, posts = 0, resumes = 0;
      Map<String, dynamic> exam() => {
        ...summary,
        if (started) 'progress': {'attemptId': 5, 'status': 'IN_PROGRESS'},
      };
      final app = await signedIn((m, u, h, b) async {
        if (u.path.endsWith('/exams')) {
          return ApiResponse(200, [exam()]);
        }
        if (u.path.endsWith('/history')) {
          return const ApiResponse(200, []);
        }
        if (u.path.endsWith('/exams/10')) {
          return ApiResponse(200, {'exam': exam()});
        }
        if (u.path.endsWith('/start')) {
          posts++;
          started = true;
          throw const ApiException(
            'Máy chủ có thể đã bắt đầu lượt thi.',
            code: 'REQUEST_TIMEOUT',
          );
        }
        resumes++;
        return ApiResponse(200, attempt(0));
      });
      await mount(tester, app);
      await enterRoom(tester);
      expect(posts, 1);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('exam-start')))
            .onPressed,
        isNull,
      );
      await tap(tester, find.text('Kiểm tra lượt đang làm'));
      await tap(tester, find.byKey(const ValueKey('exam-10')));
      expect(find.text('Tiếp tục bài đang làm'), findsOneWidget);
      await tap(tester, find.byKey(const ValueKey('exam-start')));
      expect(posts, 1);
      expect(resumes, 1);
      expect(find.byKey(const ValueKey('exam-complete')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'JLPT contract uses authenticated routes and server-owned identity',
    () async {
      final calls = <String>[];
      final api = ApiClient(
        transport: (m, u, h, b) async {
          expect(h['Authorization'], 'Bearer test');
          calls.add('$m ${u.path}');
          if (b is Map) expect(b.containsKey('userId'), isFalse);
          if (u.path.endsWith('/exams')) {
            expect(u.queryParameters, {'level': 'N3'});
            return const ApiResponse(200, []);
          }
          if (u.path.endsWith('/history')) return const ApiResponse(200, []);
          if (u.path.endsWith('/start')) expect(b, {'examId': 10});
          if (u.path.endsWith('/answer')) {
            expect(b, {'answerKeyId': 100, 'selectedOption': null});
            return const ApiResponse(200, {
              'answerKeyId': 100,
              'selectedOption': null,
            });
          }
          if (u.path.endsWith('/mark')) {
            expect(b, {'answerKeyId': 100, 'markedForReview': true});
            return const ApiResponse(200, {
              'answerKeyId': 100,
              'markedForReview': true,
            });
          }
          return ApiResponse(200, attempt(0));
        },
      )..token = 'test';
      final repo = ExamRepository(api);
      await repo.exams('N3');
      await repo.history();
      await repo.start(10);
      await repo.attempt(5);
      await repo.answer(5, 100, null);
      await repo.mark(5, 100, true);
      await repo.complete(5);
      await repo.next(5);
      expect(
        calls,
        containsAll([
          'PUT /api/jlpt/attempts/5/answer',
          'POST /api/jlpt/attempts/5/complete-section',
          'POST /api/jlpt/attempts/5/start-next-section',
        ]),
      );
      expect(
        () => repo.asset('https://outside.example/exam.json'),
        throwsA(isA<ApiException>()),
      );
      expect(
        repo.asset('images/a.png', relativeTo: '/uploads/test/exam.json').path,
        '/uploads/test/images/a.png',
      );
      expect(examTime('2026-11-10T18:00:00'), DateTime.utc(2026, 11, 10, 11));
    },
  );

  test('digital mapping separates categories and subquestions with repeated numbers', () {
    final doc = {
      'sections': [
        {
          'title': '文法',
          'mondai': [
            {
              'number': 1,
              'questions': [
                {'number': 1, 'text': 'Wrong category'},
              ],
            },
          ],
        },
        {
          'title': '聴解',
          'mondai': [
            {
              'number': 1,
              'questions': [
                {
                  'number': 1,
                  'sub_question_no': 2,
                  'text': 'Correct subquestion',
                },
              ],
            },
          ],
        },
        {
          'title': '読解',
          'mondai': [
            {
              'number': 1,
              'reading_layout': {
                'mode': 'per_question',
                'groups': [
                  {
                    'question_numbers': [2],
                    'lines': [
                      {'text': 'Unrelated passage'},
                    ],
                  },
                ],
              },
              'questions': [
                {'number': 1, 'text': 'Reading'},
              ],
            },
          ],
        },
      ],
    };
    expect(
      matchDigitalQuestion(doc, {
        'category': 'LISTENING',
        'problemNo': 1,
        'questionNo': 1,
        'subQuestionNo': 2,
      })?.question['text'],
      'Correct subquestion',
    );
    expect(
      matchDigitalQuestion(doc, {
        'category': 'LISTENING',
        'problemNo': 1,
        'questionNo': 1,
      }),
      isNull,
    );
    expect(
      matchDigitalQuestion(doc, {
        'category': 'READING',
        'problemNo': 1,
        'questionNo': 1,
      })?.readingGroups,
      isEmpty,
    );
  });

  testWidgets(
    'JLPT completes saved answers, mark, break, next section and result review',
    (tester) async {
      var stage = 0, starts = 0;
      int? selected;
      var marked = false;
      final app = await signedIn((m, u, h, b) async {
        if (u.path.endsWith('/exams')) return const ApiResponse(200, [summary]);
        if (u.path.endsWith('/history')) {
          return ApiResponse(
            200,
            stage == 3
                ? [
                    {
                      'attemptId': 5,
                      'title': 'Đề N5 từ máy chủ',
                      'level': 'N5',
                      'status': 'SUBMITTED',
                      'correctCount': 1,
                      'totalQuestions': 2,
                      'practiceScore': 90,
                    },
                  ]
                : [],
          );
        }
        if (u.path.endsWith('/exams/10')) {
          return const ApiResponse(200, {
            'exam': summary,
            'description': 'Quy trình thi theo phần.',
            'rules': ['Không tua bài nghe.'],
          });
        }
        if (u.path.endsWith('/start')) {
          starts++;
          return ApiResponse(200, attempt(stage));
        }
        if (u.path.endsWith('/answer')) {
          selected = (b as Map)['selectedOption'] as int?;
        }
        if (u.path.endsWith('/mark')) {
          marked = (b as Map)['markedForReview'] as bool;
        }
        if (u.path.endsWith('/answer') || u.path.endsWith('/mark')) {
          return ApiResponse(200, {
            'answerKeyId': 100 + stage,
            'selectedOption': selected,
            'markedForReview': marked,
          });
        }
        if (u.path.endsWith('/complete-section')) stage = stage == 0 ? 1 : 3;
        if (u.path.endsWith('/start-next-section')) stage = 2;
        if (u.path.endsWith('/result')) return ApiResponse(200, result());
        return ApiResponse(
          200,
          attempt(stage, selected: selected, marked: marked),
        );
      });
      await mount(tester, app);
      expect(starts, 0);
      await enterRoom(tester);
      expect(starts, 1);
      await tap(tester, find.byKey(const ValueKey('exam-option-1')));
      expect(find.text('Đã lưu 1/1 câu của phần này.'), findsOneWidget);
      await tap(tester, find.byKey(const ValueKey('exam-mark')));
      expect(find.byTooltip('Bỏ đánh dấu'), findsOneWidget);
      expect(find.text('Đồng bộ lượt thi'), findsNothing);
      await tap(tester, find.byKey(const ValueKey('exam-complete')));
      await tap(tester, find.text('Xác nhận'));
      expect(find.text('Giờ nghỉ giữa các phần'), findsOneWidget);
      await tap(tester, find.text('Bắt đầu phần tiếp theo'));
      await tap(tester, find.byKey(const ValueKey('exam-complete')));
      await tap(tester, find.text('Xác nhận'));
      expect(find.text('1/2 đúng'), findsOneWidget);
      expect(find.text('50.0% chính xác'), findsOneWidget);
      await tap(tester, find.byKey(const ValueKey('exam-review-100')));
      expect(find.text('学校 đọc là がっこう.'), findsOneWidget);
      await tap(tester, find.text('Về danh sách đề'));
      expect(find.byKey(const ValueKey('exam-history-5')), findsOneWidget);
      await tap(tester, find.byKey(const ValueKey('exam-history-5')));
      expect(find.text('1/2 đúng'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed answer retains selection and requires GET sync before retry',
    (tester) async {
      var writes = 0, syncs = 0;
      final app = await signedIn((m, u, h, b) async {
        if (u.path.endsWith('/exams')) return const ApiResponse(200, [summary]);
        if (u.path.endsWith('/history')) return const ApiResponse(200, []);
        if (u.path.endsWith('/exams/10')) {
          return const ApiResponse(200, {'exam': summary});
        }
        if (u.path.endsWith('/answer')) {
          writes++;
          return const ApiResponse(503, {'message': 'Lưu đáp án bị gián đoạn'});
        }
        if (m == 'GET') syncs++;
        return ApiResponse(200, attempt(0));
      });
      await mount(tester, app);
      await enterRoom(tester);
      await tap(tester, find.byKey(const ValueKey('exam-option-2')));
      expect(writes, 1);
      expect(find.text('Đã lưu 0/1 câu của phần này.'), findsOneWidget);
      expect(
        tester
            .widget<ListTile>(find.byKey(const ValueKey('exam-option-1')))
            .onTap,
        isNull,
      );
      await tap(tester, find.byTooltip('Tải lại'));
      expect(syncs, 1);
      expect(
        tester
            .widget<ListTile>(find.byKey(const ValueKey('exam-option-1')))
            .onTap,
        isNotNull,
      );
      expect(writes, 1);
    },
  );

  testWidgets(
    'timer expiry synchronizes with one GET and never posts completion',
    (tester) async {
      var now = DateTime.utc(2026, 11, 10, 10);
      var reads = 0, completions = 0;
      final deadline = now.add(const Duration(seconds: 5));
      final app = await signedIn((m, u, h, b) async {
        if (u.path.endsWith('/exams')) return const ApiResponse(200, [summary]);
        if (u.path.endsWith('/history')) return const ApiResponse(200, []);
        if (u.path.endsWith('/exams/10')) {
          return const ApiResponse(200, {'exam': summary});
        }
        if (u.path.endsWith('/complete-section')) completions++;
        if (u.path.endsWith('/attempts/5')) {
          reads++;
          return ApiResponse(200, attempt(1));
        }
        return ApiResponse(200, attempt(0, deadline: deadline));
      });
      await mount(tester, app, now: () => now);
      await enterRoom(tester);
      now = now.add(const Duration(seconds: 10));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('Giờ nghỉ giữa các phần'), findsOneWidget);
      expect(reads, 1);
      expect(completions, 0);
    },
  );

  testWidgets(
    'uncertain start prevents duplicate POST and late response cannot cross logout',
    (tester) async {
      var starts = 0;
      final pending = Completer<ApiResponse>();
      final app = await signedIn((m, u, h, b) async {
        if (u.path.endsWith('/exams')) return const ApiResponse(200, [summary]);
        if (u.path.endsWith('/history')) return const ApiResponse(200, []);
        if (u.path.endsWith('/exams/10')) {
          return const ApiResponse(200, {'exam': summary});
        }
        starts++;
        return pending.future;
      });
      await mount(tester, app);
      await tap(tester, find.byKey(const ValueKey('exam-10')));
      final start = find.byKey(const ValueKey('exam-start'));
      await tester.ensureVisible(start);
      await tester.tap(start);
      await tester.pump();
      expect(tester.widget<FilledButton>(start).onPressed, isNull);
      await app.logout();
      await tester.pumpAndSettle();
      pending.complete(ApiResponse(200, attempt(0)));
      await tester.pumpAndSettle();
      expect(starts, 1);
      expect(find.byKey(const ValueKey('exam-complete')), findsNothing);
      expect(find.text('Đăng nhập để học'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'listening resumes at elapsed time and releases audio when leaving',
    (tester) async {
      final audio = FakeAudio();
      await tester.pumpWidget(
        MaterialApp(
          home: ExamListeningPlayer(
            uri: Uri.parse('https://qtjp.example/audio.mp3'),
            startedAt: DateTime.now().subtract(const Duration(seconds: 40)),
            audioFactory: () => audio,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(audio.positions.single.inSeconds, greaterThanOrEqualTo(40));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(audio.stops, greaterThan(0));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(audio.positions.length, 2);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(audio.disposed, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
