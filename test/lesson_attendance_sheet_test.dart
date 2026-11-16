import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secure_admin_app/logic/students/admin_students_cubit.dart';
import 'package:secure_admin_app/logic/students/admin_students_state.dart';
import 'package:secure_admin_app/models/lesson.dart';
import 'package:secure_admin_app/models/registered_student.dart';
import 'package:secure_admin_app/screens/courses/widgets/lesson_attendance_sheet.dart';

class MockAdminStudentsCubit extends Mock implements AdminStudentsCubit {}

void main() {
  late MockAdminStudentsCubit mockStudentsCubit;

  final sampleStudent = RegisteredStudent(
    id: 'std_01',
    name: 'أحمد محمود',
    email: 'ahmed@example.com',
    phone: '01012345678',
    joinedAt: DateTime(2026, 1, 1),
    enrolledCourseIds: const ['course_101'],
    completedLessonIds: const {},
  );

  setUp(() {
    mockStudentsCubit = MockAdminStudentsCubit();
    when(() => mockStudentsCubit.state).thenReturn(
      AdminStudentsLoaded([sampleStudent]),
    );
    when(() => mockStudentsCubit.stream).thenAnswer(
      (_) => Stream.value(
        AdminStudentsLoaded([sampleStudent]),
      ),
    );
  });

  const testLesson = Lesson(
    id: 'les_01',
    title: 'مقدمة في تشخيص اللدغات',
    description: 'شرح أولي لأسس الفحص الإكلينيكي',
    duration: '15:00',
    muxPlaybackId: 'test_mux_playback_id',
  );

  testWidgets('LessonAttendanceSheet renders title, tabs and switches smoothly', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider<AdminStudentsCubit>.value(
            value: mockStudentsCubit,
            child: const LessonAttendanceSheet(
              courseId: 'course_101',
              lesson: testLesson,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('سجل حضور ومشاهدات المحاضرة'), findsOneWidget);
    expect(find.text('مقدمة في تشخيص اللدغات'), findsOneWidget);
    expect(find.text('حضروا الدرس'), findsOneWidget);
    expect(find.text('لم يحضروا بعد'), findsOneWidget);

    // Switch tab to unwatched
    await tester.tap(find.text('لم يحضروا بعد'));
    await tester.pumpAndSettle();

    // Verify student Ahmed is in unwatched since no watch logs exist in test
    expect(find.text('أحمد محمود'), findsOneWidget);
    expect(find.text('تذكير'), findsOneWidget);
  });
}
