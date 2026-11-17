import '../../datasources/payment_remote_data_source.dart';
import '../../models/payment_receipt_model.dart';
import '../student_payment_repository.dart';

class StudentPaymentRepositoryImpl implements StudentPaymentRepository {
  final PaymentRemoteDataSource _remoteDataSource;

  StudentPaymentRepositoryImpl({
    required PaymentRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  @override
  Future<PaymentReceiptModel> submitCourseReceipt({
    required String courseSlug,
    required String paymentMethod,
    required String senderName,
    required String senderAccount,
    required double amount,
    required String receiptFilePath,
    String? transactionReference,
  }) {
    return _remoteDataSource.submitCourseReceipt(
      courseSlug: courseSlug,
      paymentMethod: paymentMethod,
      senderName: senderName,
      senderAccount: senderAccount,
      amount: amount,
      receiptFilePath: receiptFilePath,
      transactionReference: transactionReference,
    );
  }

  @override
  Future<List<PaymentReceiptModel>> getStudentReceipts({int? courseId}) {
    return _remoteDataSource.getStudentReceipts(courseId: courseId);
  }
}
