import '../features/payments/domain/entities/payment_receipt.dart';
import '../features/payments/domain/entities/receipt_submission_input.dart';

/// عقد مستودع الإيصالات المالية وسجل الدفعات.
abstract class StudentPaymentRepository {
  /// إرسال إيصال سداد مالي عبر نموذج مدخلات محقق النوع.
  Future<PaymentReceipt> submitCourseReceipt(ReceiptSubmissionInput input);

  /// استرجاع جميع إيصالات السداد المقدمة من الطالب الموثق.
  Future<List<PaymentReceipt>> getStudentReceipts({int? courseId});
}
