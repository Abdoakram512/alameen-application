import 'package:equatable/equatable.dart';
import '../core/converters/firestore_date_time_converter.dart';

/// حالة طلب الالتحاق بالدورة.
enum AccessStatus {
  pending,
  approved,
  rejected;

  static AccessStatus fromName(String? name) {
    for (final s in AccessStatus.values) {
      if (s.name == name) return s;
    }
    return AccessStatus.pending;
  }
}

/// نموذج بيانات طلب الالتحاق بالدورة الكاملة (CourseAccessRequest)
class CourseAccessRequest extends Equatable {
  final String id;
  final String studentId;
  final String studentName;
  final String studentEmail;
  final String studentAvatar;
  final String courseId;
  final String courseTitle;
  final String paymentMethod;
  final String senderNumberOrRef;
  final String receiptUrl;
  final String adminNotes;
  final DateTime requestedAt;
  final DateTime? reviewedAt;
  final AccessStatus status;

  const CourseAccessRequest({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
    this.studentAvatar = '',
    required this.courseId,
    required this.courseTitle,
    this.paymentMethod = 'فودافون كاش (Vodafone Cash)',
    this.senderNumberOrRef = '',
    this.receiptUrl = '',
    this.adminNotes = '',
    required this.requestedAt,
    this.reviewedAt,
    this.status = AccessStatus.pending,
  });

  CourseAccessRequest copyWith({
    String? id,
    String? studentId,
    String? studentName,
    String? studentEmail,
    String? studentAvatar,
    String? courseId,
    String? courseTitle,
    String? paymentMethod,
    String? senderNumberOrRef,
    String? receiptUrl,
    String? adminNotes,
    DateTime? requestedAt,
    DateTime? reviewedAt,
    AccessStatus? status,
  }) {
    return CourseAccessRequest(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      studentEmail: studentEmail ?? this.studentEmail,
      studentAvatar: studentAvatar ?? this.studentAvatar,
      courseId: courseId ?? this.courseId,
      courseTitle: courseTitle ?? this.courseTitle,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      senderNumberOrRef: senderNumberOrRef ?? this.senderNumberOrRef,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      adminNotes: adminNotes ?? this.adminNotes,
      requestedAt: requestedAt ?? this.requestedAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'studentId': studentId,
        'studentName': studentName,
        'studentEmail': studentEmail,
        'studentAvatar': studentAvatar,
        'courseId': courseId,
        'courseTitle': courseTitle,
        'paymentMethod': paymentMethod,
        'senderNumberOrRef': senderNumberOrRef,
        'receiptUrl': receiptUrl,
        'adminNotes': adminNotes,
        'requestedAt': requestedAt.toIso8601String(),
        if (reviewedAt != null) 'reviewedAt': reviewedAt!.toIso8601String(),
        'status': status.name,
      };

  Map<String, dynamic> toMap() => toJson();

  factory CourseAccessRequest.fromJson(Map<String, dynamic> json) {
    return CourseAccessRequest(
      id: json['id']?.toString() ?? '',
      studentId: json['studentId']?.toString() ?? '',
      studentName: json['studentName']?.toString() ?? '',
      studentEmail: json['studentEmail']?.toString() ?? '',
      studentAvatar: (json['studentAvatar'] ?? json['photoUrl'])?.toString() ?? '',
      courseId: json['courseId']?.toString() ?? '',
      courseTitle: json['courseTitle']?.toString() ?? '',
      paymentMethod: json['paymentMethod']?.toString() ?? 'فودافون كاش',
      senderNumberOrRef: json['senderNumberOrRef']?.toString() ?? '',
      receiptUrl: json['receiptUrl']?.toString() ?? '',
      adminNotes: json['adminNotes']?.toString() ?? '',
      requestedAt: FirestoreDateTimeConverter.fromValue(json['requestedAt']) ??
          DateTime.now(),
      reviewedAt: FirestoreDateTimeConverter.fromValue(json['reviewedAt']),
      status: json['status'] != null
          ? AccessStatus.fromName(json['status']?.toString())
          : AccessStatus.pending,
    );
  }

  factory CourseAccessRequest.fromMap(Map<String, dynamic> map) =>
      CourseAccessRequest.fromJson(map);

  @override
  List<Object?> get props => [
        id,
        studentId,
        studentName,
        studentEmail,
        studentAvatar,
        courseId,
        courseTitle,
        paymentMethod,
        senderNumberOrRef,
        receiptUrl,
        adminNotes,
        requestedAt,
        reviewedAt,
        status,
      ];
}
