import '../../core/utils/network_error_mapper.dart';
import '../../models/registered_student.dart';
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../repositories/students_repository.dart';
import '../../repositories/impl/students_repository_impl.dart';
import 'admin_students_state.dart';

class AdminStudentsCubit extends Cubit<AdminStudentsState> {
  final StudentsRepository _studentsRepository;
  StreamSubscription? _studentsSubscription;
  List<RegisteredStudent> _cached = [];

  AdminStudentsCubit({StudentsRepository? studentsRepository})
    : _studentsRepository = studentsRepository ?? StudentsRepositoryImpl(),
      super(AdminStudentsLoading());

  void loadStudents() {
    emit(AdminStudentsLoading());
    _studentsSubscription?.cancel();
    _studentsSubscription = _studentsRepository.streamStudents().listen(
      (students) {
        _cached = List.unmodifiable(students);
        emit(AdminStudentsLoaded(_cached));
      },
      onError: (e) {
        emit(
          AdminStudentsError(
            NetworkErrorMapper.toArabicMessage(
              e,
              defaultMessage: 'تعذر تحميل بيانات الطلاب.',
            ),
            students: _cached,
          ),
        );
      },
    );
  }

  final Set<String> _inFlightCourseKeys = <String>{};

  bool isCourseBusy(String studentId, String courseId) =>
      _inFlightCourseKeys.contains('${studentId}_$courseId');

  Future<void> toggleStudentCourse(
    String studentId,
    String courseId,
    bool currentEnrolled,
  ) async {
    final key = '${studentId}_$courseId';
    if (_inFlightCourseKeys.contains(key)) return;
    _inFlightCourseKeys.add(key);

    final previousCached = List<RegisteredStudent>.from(_cached);
    final targetGrant = !currentEnrolled;

    // 0ms Optimistic UI Update
    final updatedList = _cached.map((student) {
      if (student.id != studentId) return student;
      final updatedCourses = List<String>.from(student.enrolledCourseIds);
      if (targetGrant) {
        if (!updatedCourses.contains(courseId)) updatedCourses.add(courseId);
      } else {
        updatedCourses.remove(courseId);
      }
      return student.copyWith(enrolledCourseIds: updatedCourses);
    }).toList();

    _cached = List.unmodifiable(updatedList);
    emit(AdminStudentsLoaded(_cached));

    try {
      await _studentsRepository.toggleStudentCourse(
        studentId,
        courseId,
        targetGrant,
      );
    } catch (e) {
      _cached = List.unmodifiable(previousCached);
      emit(
        AdminStudentsError(
          'تعذر تعديل الاشتراك. حدّث البيانات ثم حاول مرة أخرى.',
          students: _cached,
        ),
      );
    } finally {
      _inFlightCourseKeys.remove(key);
    }
  }

  /// تعليق أو إلغاء تعليق حساب الطالب
  Future<bool> toggleStudentSuspension(
    String studentId, {
    required bool suspend,
    String? reason,
  }) async {
    try {
      await _studentsRepository.toggleStudentSuspension(
        studentId,
        suspend: suspend,
        reason: reason,
      );
      return true;
    } catch (e) {
      emit(
        AdminStudentsError(
          'فشل تغيير حالة تعليق الحساب: $e',
          students: _cached,
        ),
      );
      return false;
    }
  }

  /// حذف حساب الطالب نهائياً
  Future<bool> deleteStudent(String studentId) async {
    try {
      await _studentsRepository.deleteStudentAccount(studentId);
      return true;
    } catch (e) {
      emit(
        AdminStudentsError(
          'فشل حذف حساب الطالب: $e',
          students: _cached,
        ),
      );
      return false;
    }
  }

  @override
  Future<void> close() {
    _studentsSubscription?.cancel();
    return super.close();
  }
}
