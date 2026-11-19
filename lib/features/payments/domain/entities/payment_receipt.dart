import 'package:equatable/equatable.dart';
import 'payment_method.dart';
import 'receipt_status.dart';

/// كيان المجال الممثل لإيصال سداد مالي مسجل للطالب.
/// يوثق السجل المالي فقط ولا يمثل ترخيصاً للوصول للمحتوى المحمي.
class PaymentReceipt extends Equatable {
  final int id;
  final int? userId;
  final int courseId;
  final PaymentMethod paymentMethod;
  final String paymentMethodLabel;
  final String senderIdentifier;
  final String? transactionReference;
  final double amountPaid;
  final String? receiptImageUrl;
  final ReceiptStatus status;
  final String? adminNotes;
  final DateTime? reviewedAt;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? courseTitle;
  final String? courseSlug;

  const PaymentReceipt({
    required this.id,
    this.userId,
    required this.courseId,
    required this.paymentMethod,
    required this.paymentMethodLabel,
    required this.senderIdentifier,
    this.transactionReference,
    required this.amountPaid,
    this.receiptImageUrl,
    this.status = ReceiptStatus.pending,
    this.adminNotes,
    this.reviewedAt,
    required this.createdAt,
    this.updatedAt,
    this.courseTitle,
    this.courseSlug,
  });

  String get courseIdString => courseId.toString();

  String get displayCourseTitle =>
      (courseTitle != null && courseTitle!.trim().isNotEmpty)
          ? courseTitle!.trim()
          : 'دورة تدريبية #$courseId';

  String get displayMethodLabel =>
      paymentMethodLabel.trim().isNotEmpty
          ? paymentMethodLabel.trim()
          : paymentMethod.displayLabelAr;

  String get displaySenderReference =>
      (transactionReference != null && transactionReference!.trim().isNotEmpty)
          ? '$senderIdentifier ($transactionReference)'
          : senderIdentifier;

  @override
  List<Object?> get props => [
        id,
        userId,
        courseId,
        paymentMethod,
        paymentMethodLabel,
        senderIdentifier,
        transactionReference,
        amountPaid,
        receiptImageUrl,
        status,
        adminNotes,
        reviewedAt,
        createdAt,
        updatedAt,
        courseTitle,
        courseSlug,
      ];
}
