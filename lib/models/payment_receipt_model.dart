import '../features/payments/domain/entities/payment_method.dart';
import '../features/payments/domain/entities/payment_receipt.dart';
import '../features/payments/domain/entities/receipt_status.dart';

/// نموذج البيانات (DTO) الممثل لإيصال السداد المالي وفق عقد OpenAPI:
/// - POST /student/courses/{slug}/receipt
/// - GET /student/receipts
class PaymentReceiptModel extends PaymentReceipt {
  const PaymentReceiptModel({
    required super.id,
    super.userId,
    required super.courseId,
    required super.paymentMethod,
    required super.paymentMethodLabel,
    required super.senderIdentifier,
    super.transactionReference,
    required super.amountPaid,
    super.receiptImageUrl,
    super.status = ReceiptStatus.pending,
    super.adminNotes,
    super.reviewedAt,
    required super.createdAt,
    super.updatedAt,
    super.courseTitle,
    super.courseSlug,
  });

  PaymentReceiptModel copyWith({
    int? id,
    int? userId,
    int? courseId,
    PaymentMethod? paymentMethod,
    String? paymentMethodLabel,
    String? senderIdentifier,
    String? transactionReference,
    double? amountPaid,
    String? receiptImageUrl,
    ReceiptStatus? status,
    String? adminNotes,
    DateTime? reviewedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? courseTitle,
    String? courseSlug,
  }) {
    return PaymentReceiptModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      courseId: courseId ?? this.courseId,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentMethodLabel: paymentMethodLabel ?? this.paymentMethodLabel,
      senderIdentifier: senderIdentifier ?? this.senderIdentifier,
      transactionReference: transactionReference ?? this.transactionReference,
      amountPaid: amountPaid ?? this.amountPaid,
      receiptImageUrl: receiptImageUrl ?? this.receiptImageUrl,
      status: status ?? this.status,
      adminNotes: adminNotes ?? this.adminNotes,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      courseTitle: courseTitle ?? this.courseTitle,
      courseSlug: courseSlug ?? this.courseSlug,
    );
  }

  factory PaymentReceiptModel.fromJson(Map<String, dynamic> json) {
    final dynamic idRaw = json['id'];
    final int id = (idRaw is num)
        ? idRaw.toInt()
        : (int.tryParse(idRaw?.toString() ?? '') ?? 0);

    final dynamic userIdRaw = json['user_id'];
    final int? userId = (userIdRaw is num)
        ? userIdRaw.toInt()
        : int.tryParse(userIdRaw?.toString() ?? '');

    final dynamic courseIdRaw = json['course_id'];
    final int courseId = (courseIdRaw is num)
        ? courseIdRaw.toInt()
        : (int.tryParse(courseIdRaw?.toString() ?? '') ?? 0);

    final rawMethod = json['payment_method']?.toString();
    final PaymentMethod method =
        PaymentMethod.tryParse(rawMethod) ?? PaymentMethod.vodafoneCash;
    final String methodLabel =
        json['payment_method_label']?.toString().trim().isNotEmpty == true
            ? json['payment_method_label'].toString()
            : method.displayLabelAr;

    final String sender = json['sender_identifier']?.toString() ?? '';

    final String? ref = json['transaction_reference']?.toString();

    final dynamic amountRaw = json['amount_paid'];
    final double amount = (amountRaw is num)
        ? amountRaw.toDouble()
        : (double.tryParse(amountRaw?.toString() ?? '') ?? 0.0);

    final String? receiptUrl = json['receipt_image_url']?.toString();

    final ReceiptStatus status =
        ReceiptStatus.fromApiValue(json['status']?.toString());

    final String? adminNotes = json['admin_notes']?.toString();

    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    final DateTime createdAt =
        parseDate(json['created_at']) ?? DateTime.now();
    final DateTime? reviewedAt = parseDate(json['reviewed_at']);
    final DateTime? updatedAt = parseDate(json['updated_at']);

    String? courseTitle;
    String? courseSlug;
    if (json['course'] is Map) {
      final cMap = json['course'] as Map;
      courseTitle = cMap['title']?.toString();
      courseSlug = cMap['slug']?.toString();
    } else {
      courseTitle = json['course_title']?.toString();
      courseSlug = json['course_slug']?.toString();
    }

    return PaymentReceiptModel(
      id: id,
      userId: userId,
      courseId: courseId,
      paymentMethod: method,
      paymentMethodLabel: methodLabel,
      senderIdentifier: sender,
      transactionReference: ref,
      amountPaid: amount,
      receiptImageUrl: receiptUrl,
      status: status,
      adminNotes: adminNotes,
      reviewedAt: reviewedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
      courseTitle: courseTitle,
      courseSlug: courseSlug,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        if (userId != null) 'user_id': userId,
        'course_id': courseId,
        'payment_method': paymentMethod.apiValue,
        'payment_method_label': paymentMethodLabel,
        'sender_identifier': senderIdentifier,
        if (transactionReference != null)
          'transaction_reference': transactionReference,
        'amount_paid': amountPaid,
        if (receiptImageUrl != null) 'receipt_image_url': receiptImageUrl,
        'status': status.name,
        if (adminNotes != null) 'admin_notes': adminNotes,
        if (reviewedAt != null) 'reviewed_at': reviewedAt!.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
        if (courseTitle != null) 'course_title': courseTitle,
        if (courseSlug != null) 'course_slug': courseSlug,
      };
}
