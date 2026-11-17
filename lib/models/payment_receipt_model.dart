import 'package:equatable/equatable.dart';
import 'access_request.dart';

/// DTO representing a payment receipt submitted by a student,
/// strictly matching the Laravel REST API OpenAPI schema for:
/// - POST /student/courses/{slug}/receipt
/// - GET /student/receipts
class PaymentReceiptModel extends Equatable {
  final int id;
  final int? userId;
  final int courseId;
  final String paymentMethod;
  final String paymentMethodLabel;
  final String senderIdentifier;
  final String? transactionReference;
  final double amountPaid;
  final String? receiptImageUrl;
  final AccessStatus status;
  final String? adminNotes;
  final DateTime? reviewedAt;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? courseTitle;
  final String? courseSlug;

  const PaymentReceiptModel({
    required this.id,
    this.userId,
    required this.courseId,
    required this.paymentMethod,
    required this.paymentMethodLabel,
    required this.senderIdentifier,
    this.transactionReference,
    required this.amountPaid,
    this.receiptImageUrl,
    this.status = AccessStatus.pending,
    this.adminNotes,
    this.reviewedAt,
    required this.createdAt,
    this.updatedAt,
    this.courseTitle,
    this.courseSlug,
  });

  PaymentReceiptModel copyWith({
    int? id,
    int? userId,
    int? courseId,
    String? paymentMethod,
    String? paymentMethodLabel,
    String? senderIdentifier,
    String? transactionReference,
    double? amountPaid,
    String? receiptImageUrl,
    AccessStatus? status,
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

    final dynamic userIdRaw = json['user_id'] ?? json['userId'];
    final int? userId = (userIdRaw is num)
        ? userIdRaw.toInt()
        : int.tryParse(userIdRaw?.toString() ?? '');

    final dynamic courseIdRaw = json['course_id'] ?? json['courseId'];
    final int courseId = (courseIdRaw is num)
        ? courseIdRaw.toInt()
        : (int.tryParse(courseIdRaw?.toString() ?? '') ?? 0);

    final String method = (json['payment_method'] ?? json['paymentMethod'])?.toString() ?? 'vodafone_cash';
    final String methodLabel = json['payment_method_label']?.toString() ??
        (method == 'instapay' ? 'إنستاباي (InstaPay)' : 'فودافون كاش (Vodafone Cash)');

    final String sender = (json['sender_identifier'] ??
            json['sender_account'] ??
            json['sender_name'] ??
            json['senderNumberOrRef'])
        ?.toString() ??
        '';

    final String? ref = json['transaction_reference']?.toString() ?? json['transactionReference']?.toString();

    final dynamic amountRaw = json['amount_paid'] ?? json['amount'] ?? json['amountPaid'];
    final double amount = (amountRaw is num)
        ? amountRaw.toDouble()
        : (double.tryParse(amountRaw?.toString() ?? '') ?? 0.0);

    final String? receiptUrl = (json['receipt_image_url'] ?? json['receiptUrl'])?.toString();

    final String? statusRaw = (json['status'])?.toString().toLowerCase();
    final AccessStatus status = switch (statusRaw) {
      'approved' => AccessStatus.approved,
      'rejected' => AccessStatus.rejected,
      _ => AccessStatus.pending,
    };

    final String? adminNotes = (json['admin_notes'] ?? json['adminNotes'])?.toString();

    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    final DateTime createdAt = parseDate(json['created_at'] ?? json['requestedAt']) ?? DateTime.now();
    final DateTime? reviewedAt = parseDate(json['reviewed_at'] ?? json['reviewedAt']);
    final DateTime? updatedAt = parseDate(json['updated_at']);

    String? courseTitle;
    String? courseSlug;
    if (json['course'] is Map) {
      final cMap = json['course'] as Map;
      courseTitle = cMap['title']?.toString();
      courseSlug = cMap['slug']?.toString();
    } else {
      courseTitle = json['course_title']?.toString() ?? json['courseTitle']?.toString();
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
        'payment_method': paymentMethod,
        'payment_method_label': paymentMethodLabel,
        'sender_identifier': senderIdentifier,
        if (transactionReference != null) 'transaction_reference': transactionReference,
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

  /// Converts this DTO to [CourseAccessRequest] for full backwards-compatibility with
  /// existing Flutter UI widgets (e.g. CourseEnrollmentStatusCard, StudentRequestsStatusSection).
  CourseAccessRequest toCourseAccessRequest({String? fallbackCourseTitle}) {
    return CourseAccessRequest(
      id: id.toString(),
      studentId: (userId ?? '').toString(),
      studentName: senderIdentifier,
      studentEmail: '',
      courseId: courseId.toString(),
      courseTitle: (courseTitle != null && courseTitle!.isNotEmpty)
          ? courseTitle!
          : (fallbackCourseTitle ?? 'دورة تدريبية #$courseId'),
      paymentMethod: paymentMethodLabel.isNotEmpty ? paymentMethodLabel : paymentMethod,
      senderNumberOrRef: (transactionReference != null && transactionReference!.trim().isNotEmpty)
          ? '$senderIdentifier ($transactionReference)'
          : senderIdentifier,
      receiptUrl: receiptImageUrl ?? '',
      adminNotes: adminNotes ?? '',
      requestedAt: createdAt,
      reviewedAt: reviewedAt,
      status: status,
    );
  }

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
