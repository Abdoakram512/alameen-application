import '../../core/errors/failure_mapper.dart';
import '../../datasources/payment_remote_data_source.dart';
import '../../features/payments/domain/entities/payment_receipt.dart';
import '../../features/payments/domain/entities/receipt_submission_input.dart';
import '../student_payment_repository.dart';

class StudentPaymentRepositoryImpl implements StudentPaymentRepository {
  final PaymentRemoteDataSource _remoteDataSource;

  StudentPaymentRepositoryImpl({
    required PaymentRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  @override
  Future<PaymentReceipt> submitCourseReceipt(
    ReceiptSubmissionInput input,
  ) async {
    final validationError = input.validate();
    if (validationError != null) {
      throw validationError;
    }

    try {
      return await _remoteDataSource.submitCourseReceipt(
        courseSlug: input.effectiveCourseSlug,
        courseId: input.courseId,
        paymentMethod: input.paymentMethod!,
        senderName: input.senderName,
        senderAccount: input.senderAccount,
        amount: input.amount!,
        receiptFilePath: input.receiptFilePath,
        transactionReference: input.transactionReference,
      );
    } catch (e) {
      throw FailureMapper.fromException(
        e,
        fallbackMessage: 'تعذر إرسال إيصال السداد حالياً، يرجى المحاولة لاحقاً.',
      );
    }
  }

  @override
  Future<List<PaymentReceipt>> getStudentReceipts({int? courseId}) async {
    try {
      return await _remoteDataSource.getStudentReceipts(courseId: courseId);
    } catch (e) {
      throw FailureMapper.fromException(
        e,
        fallbackMessage: 'تعذر تحميل سجل الإيصالات المالية حالياً.',
      );
    }
  }
}
