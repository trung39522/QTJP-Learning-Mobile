import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtjp_mobile/app/app_controller.dart';
import 'package:qtjp_mobile/core/network/api_client.dart';
import 'package:qtjp_mobile/core/theme/qtjp_theme.dart';
import 'package:qtjp_mobile/screens/exam/exam_screen.dart';

import 'exam_test.dart' as fixture;

void main() {
  for (final width in [320.0, 393.0, 430.0]) {
    testWidgets(
      'listening stays mounted and scrolling survives ticks; navigate at $width dp',
      (tester) async {
        tester.view.physicalSize = Size(width, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var now = DateTime.now();
        final expires = now.add(const Duration(minutes: 20));
        var audioCreations = 0;
        final audio = fixture.FakeAudio();
        final app = await fixture.signedIn((m, u, h, b) async {
          if (u.path.endsWith('/exams')) {
            return const ApiResponse(200, [fixture.summary]);
          }
          if (u.path.endsWith('/history')) return const ApiResponse(200, []);
          if (u.path.endsWith('/exams/10')) {
            return const ApiResponse(200, {'exam': fixture.summary});
          }
          return ApiResponse(200, {
            ...fixture.attempt(0),
            'currentSection': {
              'sectionId': 1,
              'code': 'LISTENING',
              'name': 'Nghe hiểu',
              'startedAt': now
                  .subtract(const Duration(seconds: 20))
                  .toUtc()
                  .toIso8601String(),
              'expiresAt': expires.toUtc().toIso8601String(),
              'audioUrl': '/uploads/exam.mp3',
              'questions': List.generate(
                4,
                (i) => {
                  ...fixture.question(i),
                  'category': 'LISTENING',
                  'text':
                      'Câu hỏi nghe ${i + 1}: ${List.filled(30, 'Nội dung câu hỏi.').join(' ')}',
                  'selectedOption': i == 1 ? 1 : null,
                  'markedForReview': i == 2,
                },
              ),
            },
          });
        });
        await tester.pumpWidget(
          AppScope(
            controller: app,
            child: MaterialApp(
              theme: QTJPTheme.light,
              home: ExamScreen(
                initialLevel: 'N5',
                embedded: width == 393,
                now: () => now,
                audioFactory: () {
                  audioCreations++;
                  return audio;
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await fixture.enterRoom(tester);
        expect(audioCreations, 1);
        final scroll = find.byType(SingleChildScrollView).first;
        await tester.drag(scroll, const Offset(0, -340));
        await tester.pumpAndSettle();
        final scrollable = find
            .descendant(of: scroll, matching: find.byType(Scrollable))
            .first;
        final offset = tester
            .state<ScrollableState>(scrollable)
            .position
            .pixels;
        expect(offset, greaterThan(100));
        now = now.add(const Duration(seconds: 5));
        await tester.pump(const Duration(seconds: 5));
        expect(
          tester.state<ScrollableState>(scrollable).position.pixels,
          closeTo(offset, .5),
        );
        expect(audioCreations, 1);
        expect(audio.positions.length, 1);

        final menu = find.byKey(const ValueKey('exam-question-menu'));
        await tester.ensureVisible(menu);
        await tester.tap(menu);
        await tester.pumpAndSettle();
        expect(find.byTooltip('Ẩn danh sách câu hỏi'), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byTooltip('Ẩn danh sách câu hỏi'), findsNothing);
        expect(find.text('Rời phòng thi?'), findsNothing);
        await tester.tap(menu);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('exam-question-2')));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Ẩn danh sách câu hỏi'), findsNothing);
        expect(find.text('Câu 3/4'), findsOneWidget);
        final card = find.byKey(const ValueKey('exam-question-card'));
        var rect = tester.getRect(card);
        await tester.dragFrom(
          Offset(rect.center.dx, (rect.top + 28).clamp(90, 660)),
          const Offset(-150, 0),
        );
        await tester.pumpAndSettle();
        expect(find.text('Câu 4/4'), findsOneWidget);
        rect = tester.getRect(card);
        await tester.dragFrom(
          Offset(rect.center.dx, (rect.top + 28).clamp(90, 660)),
          const Offset(150, 0),
        );
        await tester.pumpAndSettle();
        expect(find.text('Câu 3/4'), findsOneWidget);
        expect(audioCreations, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
