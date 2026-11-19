import 'package:equatable/equatable.dart';
import '../../models/access_request.dart';

/// حالة استحقاق وأهلية الطالب بالدورة وفقاً لخادم Laravel الموثق (Server Entitlement).
///
/// قاعدة معمارية:
/// خادم Laravel هو المصدر الأوحد للحقيقة للأهلية؛ ولا يجوز تحت أي ظرف
/// استنتاج الأهلية من وجود إيصال دفع سابق أو حالة مالية محلية.
enum CourseEntitlementStatus {
  /// اشتراك مؤكد ومفعل من خادم Laravel (has_enrolled: true).
  enrolled,

  /// مؤكد غير مسجل من خادم Laravel (has_enrolled: false).
  notEnrolled,

  /// تم سحب الصلاحية أو حظر الحساب من قِبل إدارة الأكاديمية (403 Forbidden).
  revoked,

  /// غير مصرح له أو انتهت صلاحية جلسة تسجيل الدخول (401 Unauthorized).
  unauthorized,

  /// تعذر التحقق بسبب انقطاع اتصال الشبكة (Network Connection Failure).
  networkError,

  /// حالة غير محددة أو قيد الفحص (Unknown / Fail-Closed).
  unknown;

  /// هل الطالب مرخص له بدخول الدورة ومحتواها؟
  bool get isAuthorized => this == CourseEntitlementStatus.enrolled;
}

abstract class AccessState extends Equatable {
  const AccessState();
  @override
  List<Object?> get props => [];
}

class AccessInitial extends AccessState {}

class AccessLoading extends AccessState {
  final Map<String, AccessStatus> receiptStatuses;
  final Map<String, CourseEntitlementStatus> courseEntitlements;
  final Map<String, CourseAccessRequest> requestsByCourse;
  final List<CourseAccessRequest> allRequests;

  const AccessLoading({
    Map<String, AccessStatus> receiptStatuses = const {},
    this.courseEntitlements = const {},
    this.requestsByCourse = const {},
    this.allRequests = const [],
    Map<String, AccessStatus>? courseStatuses,
  }) : receiptStatuses = courseStatuses ?? receiptStatuses;

  /// توافق خلفي مع الواجهات الحالية لسجل الإيصالات
  Map<String, AccessStatus> get courseStatuses => receiptStatuses;

  @override
  List<Object?> get props => [
        receiptStatuses,
        courseEntitlements,
        requestsByCourse,
        allRequests,
      ];
}

class AccessLoaded extends AccessState {
  final Map<String, AccessStatus> receiptStatuses;
  final Map<String, CourseEntitlementStatus> courseEntitlements;
  final Map<String, CourseAccessRequest> requestsByCourse;
  final List<CourseAccessRequest> allRequests;

  const AccessLoaded(
    Map<String, AccessStatus> receiptStatusesOrCourseStatuses, {
    this.courseEntitlements = const {},
    this.requestsByCourse = const {},
    this.allRequests = const [],
  }) : receiptStatuses = receiptStatusesOrCourseStatuses;

  const AccessLoaded.detailed({
    this.receiptStatuses = const {},
    this.courseEntitlements = const {},
    this.requestsByCourse = const {},
    this.allRequests = const [],
  });

  /// توافق خلفي مع الواجهات الحالية لقراءة حالة الإيصالات المالية
  Map<String, AccessStatus> get courseStatuses => receiptStatuses;

  /// استرجاع حالة إيصال السداد المالي (pending / approved / rejected)
  AccessStatus? getStatus(String courseId) => receiptStatuses[courseId];

  /// استرجاع حالة الأهلية الحقيقية المعتمدة من خادم Laravel (enrolled / notEnrolled / revoked / ...)
  CourseEntitlementStatus getEntitlement(String courseId) =>
      courseEntitlements[courseId] ?? CourseEntitlementStatus.unknown;

  /// هل الدورة مرخص الدخول لها من الخادم؟
  bool isCourseAuthorized(String courseId) =>
      getEntitlement(courseId).isAuthorized;

  CourseAccessRequest? getRequest(String courseId) =>
      requestsByCourse[courseId];

  @override
  List<Object?> get props => [
        receiptStatuses,
        courseEntitlements,
        requestsByCourse,
        allRequests,
      ];
}

class AccessActionSuccess extends AccessLoaded {
  final String message;

  const AccessActionSuccess(
    this.message, {
    Map<String, AccessStatus> receiptStatuses = const {},
    Map<String, CourseEntitlementStatus> courseEntitlements = const {},
    Map<String, CourseAccessRequest> requestsByCourse = const {},
    List<CourseAccessRequest> allRequests = const [],
    Map<String, AccessStatus>? courseStatuses,
  }) : super(
          courseStatuses ?? receiptStatuses,
          courseEntitlements: courseEntitlements,
          requestsByCourse: requestsByCourse,
          allRequests: allRequests,
        );

  @override
  List<Object?> get props => [
        message,
        receiptStatuses,
        courseEntitlements,
        requestsByCourse,
        allRequests,
      ];
}

class AccessError extends AccessLoaded {
  final String message;
  final CourseEntitlementStatus entitlementStatus;

  const AccessError(
    this.message, {
    Map<String, AccessStatus> receiptStatuses = const {},
    Map<String, CourseEntitlementStatus> courseEntitlements = const {},
    Map<String, CourseAccessRequest> requestsByCourse = const {},
    List<CourseAccessRequest> allRequests = const [],
    Map<String, AccessStatus>? courseStatuses,
    this.entitlementStatus = CourseEntitlementStatus.unknown,
  }) : super(
          courseStatuses ?? receiptStatuses,
          courseEntitlements: courseEntitlements,
          requestsByCourse: requestsByCourse,
          allRequests: allRequests,
        );

  @override
  List<Object?> get props => [
        message,
        receiptStatuses,
        courseEntitlements,
        requestsByCourse,
        allRequests,
        entitlementStatus,
      ];
}
