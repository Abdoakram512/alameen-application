import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/network/api_exceptions.dart';
import '../../models/assignment_submission.dart';
import '../../models/clinical_task_data.dart';
import '../../repositories/student_assignments_repository.dart';
import 'assignments_state.dart';

class AssignmentsCubit extends Cubit<AssignmentsState> {
  final StudentAssignmentsRepository _repository;
  int _requestGeneration = 0;
  String? _activeStudentId;

  AssignmentsCubit({
    required StudentAssignmentsRepository repository,
  })  : _repository = repository,
        super(const AssignmentsInitial());

  String? get activeStudentId => _activeStudentId;

  /// مسح حالة التكليفات وعزل الجلسة عند تسجيل الخروج أو تبديل الحساب
  void clear() {
    _requestGeneration++;
    _activeStudentId = null;
    if (!isClosed) {
      emit(const AssignmentsInitial());
    }
  }

  void reset() => clear();

  @override
  Future<void> close() {
    _requestGeneration++;
    _activeStudentId = null;
    return super.close();
  }

  Future<void> loadAssignments({String? studentId, bool reset = true}) async {
    final generation = ++_requestGeneration;
    if (studentId != null) {
      _activeStudentId = studentId;
    }

    if (reset && !isClosed) {
      emit(const AssignmentsLoading());
    }

    try {
      final data = await _repository.getAssignments();
      if (generation != _requestGeneration || isClosed) return;
      emit(AssignmentsLoaded(data: data));
    } on ForbiddenException {
      // ميزة التكليفات معطلة حالياً في إعدادات المنصة على الخادم (tasks: false)
      if (generation != _requestGeneration || isClosed) return;
      emit(const AssignmentsLoaded(data: StudentAssignmentsData()));
    } on ApiException catch (e) {
      if (generation != _requestGeneration || isClosed) return;
      emit(AssignmentsError(e.message));
    } catch (e) {
      if (generation != _requestGeneration || isClosed) return;
      emit(AssignmentsError('تعذر تحميل التكليفات السريرية: $e'));
    }
  }

  Future<AssignmentSubmission> submitClinicalTask({
    required int taskId,
    File? audioFile,
    String? audioBase64,
    int? durationSeconds,
    String? studentNotes,
  }) async {
    final currentState = state;
    if (currentState is AssignmentsLoaded && !isClosed) {
      emit(currentState.copyWith(isSubmitting: true));
    }

    try {
      final submission = await _repository.submitClinicalTask(
        taskId: taskId,
        audioFile: audioFile,
        audioBase64: audioBase64,
        durationSeconds: durationSeconds,
        studentNotes: studentNotes,
      );

      // تحديث قائمة التكليفات بعد التسليم
      await loadAssignments(studentId: _activeStudentId, reset: false);
      return submission;
    } catch (e) {
      if (state is AssignmentsLoaded && !isClosed) {
        emit((state as AssignmentsLoaded).copyWith(isSubmitting: false));
      }
      if (e is ApiException) rethrow;
      throw ApiException('فشل إرسال التكليف السريري: $e');
    }
  }
}
