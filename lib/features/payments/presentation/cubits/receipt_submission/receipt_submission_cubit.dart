import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/errors/app_failure.dart';
import '../../../../../repositories/student_payment_repository.dart';
import '../../../domain/entities/receipt_submission_input.dart';
import 'receipt_submission_state.dart';

/// Cubit مسؤول حصراً عن سير عمل إرسال إيصال السداد المالي للدورة.
/// لا يدير سجل الإيصالات ولا يقرر أهلية الدخول للدورة.
class ReceiptSubmissionCubit extends Cubit<ReceiptSubmissionState> {
  final StudentPaymentRepository _repository;
  int _submissionGeneration = 0;

  ReceiptSubmissionCubit({required StudentPaymentRepository repository})
    : _repository = repository,
      super(const ReceiptSubmissionInitial());

  Future<void> submit(
    ReceiptSubmissionInput input, {
    bool checkFileOnDisk = true,
  }) async {
    if (state is ReceiptSubmissionInProgress) return;

    final generation = ++_submissionGeneration;
    if (isClosed) return;
    emit(const ReceiptSubmissionInProgress());
    try {
      final localValidationError = input.validate(
        checkFileOnDisk: checkFileOnDisk,
      );
      if (localValidationError != null) {
        _emitFailure(localValidationError);
        return;
      }
      final receipt = await _repository.submitCourseReceipt(input);
      if (isClosed || generation != _submissionGeneration) return;

      emit(
        ReceiptSubmissionSuccess(
          receipt: receipt,
          message:
              'تم إرسال إيصال سداد "${input.courseTitle}" للمراجعة الإدارية بنجاح.',
        ),
      );
    } on AppFailure catch (failure) {
      if (isClosed || generation != _submissionGeneration) return;
      _emitFailure(failure);
    } catch (_) {
      if (isClosed || generation != _submissionGeneration) return;
      _emitFailure(
        const UnknownFailure(
          'تعذر إرسال إيصال السداد حالياً، يرجى المحاولة لاحقاً.',
        ),
      );
    }
  }

  void _emitFailure(AppFailure failure) {
    switch (failure) {
      case ValidationFailure():
        emit(
          ReceiptSubmissionValidationFailure(
            message: failure.firstErrorMessage,
            fieldErrors: failure.fieldErrors,
          ),
        );
      case NetworkFailure():
        emit(ReceiptSubmissionNetworkFailure(message: failure.message));
      default:
        emit(ReceiptSubmissionFailure(failure: failure));
    }
  }

  void reset() {
    _submissionGeneration++;
    if (!isClosed) {
      emit(const ReceiptSubmissionInitial());
    }
  }

  @override
  Future<void> close() {
    _submissionGeneration++;
    return super.close();
  }
}
