import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_admin_app/logic/courses/admin_courses_cubit.dart';
import 'package:secure_admin_app/models/course.dart';
import 'package:secure_admin_app/models/course_level.dart';
import 'package:secure_admin_app/repositories/courses_repository.dart';
import 'package:secure_admin_app/screens/courses/widgets/add_level_dialog.dart';

class SavingRepository implements CoursesRepository {
  Completer<void> pending = Completer<void>();
  int calls = 0;
  @override
  Stream<List<Course>> streamCourses() => const Stream.empty();
  @override
  Future<void> addLevelToCourse(String id, CourseLevel level) {
    calls++;
    return pending.future;
  }
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('AddLevelDialog closes immediately on save and dispatches optimistic addition to cubit', (tester) async {
    final repository = SavingRepository();
    final cubit = AdminCoursesCubit(coursesRepository: repository);
    addTearDown(cubit.close);
    await tester.pumpWidget(MaterialApp(home: BlocProvider.value(
      value: cubit,
      child: Scaffold(body: Builder(builder: (context) => TextButton(
        onPressed: () => AddLevelDialog.show(context, courseId: 'c', currentLevelsCount: 0),
        child: const Text('open'),
      ))),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'المستوى الجديد');
    await tester.tap(find.text('إضافة المستوى'));
    await tester.pumpAndSettle();
    // الدايلوج يغلق فوراً لتجربة سلسة دون تعليق
    expect(find.byType(AddLevelDialog), findsNothing);
    expect(repository.calls, 1);
    repository.pending.complete();
    await tester.pumpAndSettle();
  });
}
