import '../models/payment_receipt_model.dart';

/// Contract for student payments, receipt submissions, and enrollment status.
abstract class StudentPaymentRepository {
  /// Submit a manual payment receipt to enroll in a course.
  Future<PaymentReceiptModel> submitCourseReceipt({
    required String courseSlug,
    required String paymentMethod,
    required String senderName,
    required String senderAccount,
    required double amount,
    required String receiptFilePath,
    String? transactionReference,
  });

  /// Retrieve all receipts submitted by the current authenticated student.
  Future<List<PaymentReceiptModel>> getStudentReceipts({int? courseId});
}
