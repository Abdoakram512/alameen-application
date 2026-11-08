import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum AccessStatus { pending, approved, rejected }

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
        'reviewedAt': reviewedAt?.toIso8601String(),
        'status': status.name,
      };

  factory CourseAccessRequest.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    DateTime? parseNullableDate(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return CourseAccessRequest(
      id: json['id'] ?? '',
      studentId: json['studentId'] ?? '',
      studentName: json['studentName'] ?? '',
      studentEmail: json['studentEmail'] ?? '',
      studentAvatar: json['studentAvatar'] ?? json['photoUrl'] ?? '',
      courseId: json['courseId'] ?? '',
      courseTitle: json['courseTitle'] ?? '',
      paymentMethod: json['paymentMethod'] ?? 'فودافون كاش',
      senderNumberOrRef: json['senderNumberOrRef'] ?? '',
      receiptUrl: json['receiptUrl'] ?? '',
      adminNotes: json['adminNotes'] ?? '',
      requestedAt: parseDate(json['requestedAt']),
      reviewedAt: parseNullableDate(json['reviewedAt']),
      status: json['status'] != null
          ? AccessStatus.values.firstWhere(
              (e) => e.name == json['status'],
              orElse: () => AccessStatus.pending,
            )
          : AccessStatus.pending,
    );
  }

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
