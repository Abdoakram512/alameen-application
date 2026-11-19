import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secure_screen_app/core/storage/course_local_cache.dart';
import 'package:secure_screen_app/core/storage/secure_token_storage.dart';
import 'package:secure_screen_app/datasources/courses_remote_data_source.dart';
import 'package:secure_screen_app/repositories/impl/student_courses_repository_impl.dart';
import 'package:secure_screen_app/repositories/student_courses_repository.dart';
import 'package:secure_screen_app/logic/courses/courses_cubit.dart';
import 'package:secure_screen_app/models/course.dart';
import 'package:secure_screen_app/models/course_level.dart';
import 'package:secure_screen_app/models/lesson.dart';
import 'package:secure_screen_app/models/student_courses_data.dart';
import 'package:secure_screen_app/screens/student/home/widgets/student_course_card.dart';
import 'package:secure_screen_app/screens/student/course_details/widgets/course_curriculum_section.dart';

class Remote extends Mock implements CoursesRemoteDataSource {}

class Cache extends Mock implements CourseLocalCache {}

class Tokens extends Mock implements SecureTokenStorage {}

class Repository extends Mock implements StudentCoursesRepository {}

const course = Course(
  id: '1',
  title: 'Course',
  description: '',
  instructor: '',
  category: '',
  thumbnailUrl: '',
  levels: [],
);

void main() {
  test(
    'Concurrent catalog requests share one HTTP request and persistence',
    () async {
      final remote = Remote();
      final cache = Cache();
      final response = Completer<List<Course>>();
      when(
        () => remote.getPublicCourses(search: null),
      ).thenAnswer((_) => response.future);
      when(() => cache.savePublicCourses(any())).thenAnswer((_) async {});
      final repo = StudentCoursesRepositoryImpl(
        remoteDataSource: remote,
        localCache: cache,
      );
      final first = repo.getPublicCourses();
      final second = repo.getPublicCourses();
      response.complete([course]);
      await Future.wait([first, second]);
      verify(() => remote.getPublicCourses(search: null)).called(1);
      verify(() => cache.savePublicCourses(any())).called(1);
    },
  );
  test(
    'Enrollment coalescing is scoped to token and never caches authorization',
    () async {
      final remote = Remote();
      final tokens = Tokens();
      final response = Completer<StudentCoursesData>();
      when(() => tokens.getToken()).thenAnswer((_) async => 'session-a');
      when(() => remote.getStudentCourses()).thenAnswer((_) => response.future);
      final repo = StudentCoursesRepositoryImpl(
        remoteDataSource: remote,
        tokenStorage: tokens,
      );
      final first = repo.getStudentCourses();
      final second = repo.getStudentCourses();
      await Future<void>.delayed(Duration.zero);
      when(() => tokens.getToken()).thenAnswer((_) async => 'session-b');
      final switched = repo.getStudentCourses();
      await Future<void>.delayed(Duration.zero);
      verify(() => remote.getStudentCourses()).called(2);
      response.complete(const StudentCoursesData());
      await Future.wait([first, second, switched]);
      await repo.getStudentCourses();
      verify(() => remote.getStudentCourses()).called(1);
    },
  );
  test(
    'Duplicate detail requests coalesce and logout discards in-flight results',
    () async {
      final repo = Repository();
      final response = Completer<Course>();
      when(() => repo.streamCourses()).thenAnswer((_) => const Stream.empty());
      when(
        () => repo.getPublicCourses(forceRefresh: false),
      ).thenAnswer((_) async => [course]);
      when(() => repo.getCourseDetails('1')).thenAnswer((_) => response.future);
      final cubit = CoursesCubit(coursesRepository: repo);
      await Future<void>.delayed(Duration.zero);
      final first = cubit.loadCourseDetails('1');
      final second = cubit.loadCourseDetails('1');
      verify(() => repo.getCourseDetails('1')).called(1);
      cubit.clearStudentSession();
      response.complete(
        course.copyWith(hasEnrolled: true, isDetailedFromAuthServer: true),
      );
      expect(await first, isNull);
      expect(await second, isNull);
      await cubit.close();
    },
  );
  testWidgets(
    'Long card text stays bounded at large text scale on narrow phones',
    (tester) async {
      final longText = List.filled(60, 'Long course text').join(' ');
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: SizedBox(
                  width: 300,
                  child: StudentCourseCard(
                    course: course.copyWith(
                      title: longText,
                      description: longText,
                      instructor: longText,
                    ),
                    isEnrolled: true,
                    progress: 0.5,
                    onTap: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final title = tester.widgetList<Text>(find.text(longText)).first;
      expect(title.maxLines, 2);
      expect(title.overflow, TextOverflow.ellipsis);
    },
  );
  testWidgets('Collapsed levels do not build lesson tiles', (tester) async {
    final lessons = List.generate(
      200,
      (i) => Lesson(
        id: '$i',
        title: 'Lesson $i',
        description: '',
        duration: '1:00',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CourseLevelCard(
              level: CourseLevel(
                id: '1',
                title: 'Level',
                description: '',
                order: 1,
                lessons: lessons,
              ),
              levelIndex: 1,
              initiallyExpanded: false,
              isEnrolled: true,
              completedLessonIds: {},
              onPlayLesson: (_) {},
              onLockedLessonTap: () {},
            ),
          ),
        ),
      ),
    );
    expect(find.byType(CourseLessonTile), findsNothing);
    await tester.tap(find.text('Level'));
    await tester.pumpAndSettle();
    expect(find.byType(CourseLessonTile), findsNWidgets(200));
    expect(tester.takeException(), isNull);
  });
}
