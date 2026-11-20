import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_screen_app/models/learning_history.dart';
import 'package:secure_screen_app/models/course.dart';
import 'package:secure_screen_app/models/lesson.dart';
import 'package:secure_screen_app/navigation/student_route_policy.dart';
import 'package:secure_screen_app/screens/student/lesson_playlist.dart';
import 'package:secure_screen_app/screens/onboarding/onboarding_screen.dart';

Lesson lesson(String id, {bool free = false}) => Lesson(
  id: id,
  title: id,
  description: '',
  duration: '10:00',
  muxPlaybackId: 'test',
  isFreePreview: free,
);
void main() {
  test('Course order determines playlist without mutating source', () {
    final course = Course.fromMap({
      'levels': [
        {
          'id': 'second',
          'order': 2,
          'lessons': [
            {'id': 'c', 'order': 1},
          ],
        },
        {
          'id': 'first',
          'order': 1,
          'lessons': [
            {'id': 'b', 'order': 2},
            {'id': 'a', 'order': 1},
          ],
        },
      ],
    });
    expect(orderedLessons(course).map((l) => l.id), ['a', 'b', 'c']);
  });
  test('History rejects malformed records and clamps invalid time', () {
    expect(RecentLesson.decode('broken'), isNull);
    expect(RecentLesson.decode('{"courseId":7}'), isNull);
    final record = RecentLesson.decode(
      const RecentLesson(courseId: 'c', lessonId: 'l', positionMs: -1).encode(),
    );
    expect(record!.positionMs, 0);
    expect(record.lessonId, 'l');
  });
  test(
    'Protected course returns after session resolves and login succeeds',
    () {
      final policy = StudentRoutePolicy();
      expect(
        policy.redirect(
          Uri.parse('/course/c1'),
          signedIn: false,
          resolving: true,
        ),
        '/splash',
      );
      final login = policy.redirect(
        Uri.parse('/splash'),
        signedIn: false,
        resolving: false,
      )!;
      expect(Uri.parse(login).queryParameters['from'], '/course/c1');
      expect(
        policy.redirect(Uri.parse(login), signedIn: true, resolving: false),
        '/course/c1',
      );
    },
  );
  test('Return path cannot point outside known application destinations', () {
    for (final value in [
      'https://example.com',
      '//example.com',
      '/admin',
      '/course/..',
      '/course/a%2Fb',
    ]) {
      expect(safeStudentDestination(value), '/', reason: value);
    }
    expect(safeStudentDestination('/course/c1?unexpected=1'), '/course/c1');
  });
  testWidgets('Locked lesson cannot be selected; preview can', (tester) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LessonPlaylist(
            lessons: [
              lesson('current', free: true),
              lesson('locked'),
              lesson('preview', free: true),
            ],
            selectedId: 'current',
            enrolled: false,
            completedIds: {},
            onSelected: (l) => selected = l.id,
          ),
        ),
      ),
    );
    await tester.tap(find.text('locked'));
    expect(selected, isNull);
    await tester.tap(find.text('preview'));
    expect(selected, 'preview');
  });
  testWidgets(
    'Onboarding resumes on the stored page and reports further progress',
    (tester) async {
      int? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingScreen(
            initialPage: 2,
            onPageChanged: (page) => saved = page,
            onComplete: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('من المعرفة إلى التطبيق'), findsOneWidget);
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(saved, 3);
      expect(find.byType(FilledButton), findsOneWidget);
    },
  );
}
