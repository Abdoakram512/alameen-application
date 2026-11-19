import 'package:equatable/equatable.dart';

/// حالات أهلية وصول الطالب للدورة المؤكدة حصرياً من خادم Laravel.
/// يميز بوضوح بين انقطاع الشبكة المؤقت ورفض الخادم المؤكد وعدم الاشتراك.
enum CourseAccessState {
  unknown,
  loading,
  enrolled,
  notEnrolled,
  unauthorized,
  forbidden,
  networkUnavailable,
  failure;

  bool get isAuthorized => this == CourseAccessState.enrolled;
}

/// نموذج غير قابل للتغيير يمثل حالة أهلية الطالب في دورة معينة.
class CourseEntitlement extends Equatable {
  final String courseId;
  final CourseAccessState status;
  final String? message;
  final String? forbiddenReasonCode;
  final DateTime? expiresAt;
  final DateTime? checkedAt;

  const CourseEntitlement({
    required this.courseId,
    required this.status,
    this.message,
    this.forbiddenReasonCode,
    this.expiresAt,
    this.checkedAt,
  });

  const CourseEntitlement.unknown(String courseId)
      : this(
          courseId: courseId,
          status: CourseAccessState.unknown,
        );

  const CourseEntitlement.loading(String courseId)
      : this(
          courseId: courseId,
          status: CourseAccessState.loading,
        );

  const CourseEntitlement.enrolled(
    String courseId, {
    String? message,
    DateTime? expiresAt,
    DateTime? checkedAt,
  }) : this(
          courseId: courseId,
          status: CourseAccessState.enrolled,
          message: message,
          expiresAt: expiresAt,
          checkedAt: checkedAt,
        );

  const CourseEntitlement.notEnrolled(
    String courseId, {
    String? message,
    DateTime? checkedAt,
  }) : this(
          courseId: courseId,
          status: CourseAccessState.notEnrolled,
          message: message,
          checkedAt: checkedAt,
        );

  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());

  bool get canAccessProtectedContent => status.isAuthorized && !isExpired;

  @override
  List<Object?> get props => [
        courseId,
        status,
        message,
        forbiddenReasonCode,
        expiresAt,
        checkedAt,
      ];
}
