import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/network/api_exceptions.dart';
import '../../models/assignment_submission.dart';
import '../../repositories/student_assignments_repository.dart';
import 'assignments_state.dart';

class AssignmentsCubit extends Cubit<AssignmentsState> {
  final StudentAssignmentsRepository _repository;

  AssignmentsCubit({
    required StudentAssignmentsRepository repository,
  })  : _repository = repository,
        super(const AssignmentsInitial());

  Future<void> loadAssignments({bool reset = true}) async {
    if (reset) {
      emit(const AssignmentsLoading());
    }

    try {
      final data = await _repository.getAssignments();
      emit(AssignmentsLoaded(data: data));
    } on ApiException catch (e) {
      emit(AssignmentsError(e.message));
    } catch (e) {
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
    if (currentState is AssignmentsLoaded) {
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

      // Refresh list to update status
      await loadAssignments(reset: false);
      return submission;
    } catch (e) {
      if (state is AssignmentsLoaded) {
        emit((state as AssignmentsLoaded).copyWith(isSubmitting: false));
      }
      if (e is ApiException) rethrow;
      throw ApiException('فشل إرسال التكليف السريري: $e');
    }
  }
}
