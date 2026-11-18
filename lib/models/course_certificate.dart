import 'package:equatable/equatable.dart';

/// نموذج بيانات الشهادة المعتمدة الصادرة رسمياً من خادم Laravel REST API
///
/// مطابق لمواصفات OpenAPI 3.0.3 (مخطط Certificate) ومتحرر بالكامل من أي اعتماد على Firebase Firestore.
class CourseCertificate extends Equatable {
  final String id;
  final int? userId;
  final String courseId;
  final String courseTitle;
  final String studentId;
  final String studentName;
  final String studentEmail;
  final String certificateCode;
  final DateTime issuedAt;
  final double completionPercentage;
  final String verificationUrl;
  final String? fileUrl;
  final String? fileType;
  final String? signatoryName;
  final String? signatoryTitle;

  const CourseCertificate({
    required this.id,
    this.userId,
    required this.courseId,
    required this.courseTitle,
    required this.studentId,
    required this.studentName,
    this.studentEmail = '',
    String? certificateCode,
    String? serialNumber,
    required this.issuedAt,
    this.completionPercentage = 100.0,
    this.verificationUrl = '',
    this.fileUrl,
    this.fileType = 'pdf',
    String? signatoryName,
    String? instructorName,
    this.signatoryTitle,
  })  : certificateCode = certificateCode ?? serialNumber ?? '',
        signatoryName = signatoryName ?? instructorName;

  /// مواءمة برمجية للرجوع إلى رقم الاعتماد (Code) بالاسم القديم
  String get serialNumber => certificateCode;

  /// مواءمة اسم المشرف أو الموقع
  String get instructorName =>
      (signatoryName != null && signatoryName!.trim().isNotEmpty)
          ? signatoryName!
          : 'المشرف الأكاديمي العام';

  /// هل يتوفر ملف PDF رسمي صادر من الخادم قابل للتحميل المباشر؟
  bool get hasDownloadableFile =>
      fileUrl != null && fileUrl!.trim().isNotEmpty;

  factory CourseCertificate.fromLaravelJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    final idStr = json['id']?.toString() ?? '';
    final code = json['certificate_code']?.toString().trim() ??
        json['serialNumber']?.toString().trim() ??
        idStr;

    // استخراج معلومات الدورة التدريبية إن وُجدت كمصفوفة فرعية أو حقل مباشر
    String resolvedCourseId = json['course_id']?.toString() ??
        json['courseId']?.toString() ??
        '';
    String resolvedCourseTitle = json['course_title']?.toString() ??
        json['courseTitle']?.toString() ??
        '';
    if (json['course'] is Map) {
      final courseMap = json['course'] as Map;
      if (resolvedCourseId.isEmpty) {
        resolvedCourseId = courseMap['id']?.toString() ?? '';
      }
      if (resolvedCourseTitle.isEmpty) {
        resolvedCourseTitle = courseMap['title']?.toString() ??
            courseMap['name']?.toString() ??
            '';
      }
    }

    // استخراج معلومات الطالب إن وُجدت
    int? resolvedUserId;
    if (json['user_id'] is int) {
      resolvedUserId = json['user_id'] as int;
    } else if (json['user_id'] != null) {
      resolvedUserId = int.tryParse(json['user_id'].toString());
    }

    String resolvedStudentId = resolvedUserId?.toString() ??
        json['studentId']?.toString() ??
        '';
    String resolvedStudentName = json['student_name']?.toString() ??
        json['studentName']?.toString() ??
        '';
    String resolvedStudentEmail = json['student_email']?.toString() ??
        json['studentEmail']?.toString() ??
        '';

    if (json['user'] is Map) {
      final userMap = json['user'] as Map;
      if (resolvedUserId == null && userMap['id'] is int) {
        resolvedUserId = userMap['id'] as int;
        resolvedStudentId = resolvedUserId.toString();
      }
      if (resolvedStudentName.isEmpty) {
        resolvedStudentName = userMap['name']?.toString() ?? '';
      }
      if (resolvedStudentEmail.isEmpty) {
        resolvedStudentEmail = userMap['email']?.toString() ?? '';
      }
    }

    final verUrl = json['verification_url']?.toString().trim() ??
        (code.isNotEmpty
            ? 'https://alameen-center.online/certificates/verify/$code'
            : '');

    return CourseCertificate(
      id: idStr,
      userId: resolvedUserId,
      courseId: resolvedCourseId,
      courseTitle: resolvedCourseTitle.isNotEmpty
          ? resolvedCourseTitle
          : 'برنامج تدريبي معتمد',
      studentId: resolvedStudentId,
      studentName: resolvedStudentName.isNotEmpty
          ? resolvedStudentName
          : 'متدرب مركز الأمين',
      studentEmail: resolvedStudentEmail,
      certificateCode: code,
      issuedAt: parseDate(json['issued_at'] ?? json['created_at']),
      completionPercentage: (json['completion_percentage'] as num?)?.toDouble() ??
          (json['completionPercentage'] as num?)?.toDouble() ??
          (json['progress'] as num?)?.toDouble() ??
          100.0,
      verificationUrl: verUrl,
      fileUrl: json['file_url']?.toString(),
      fileType: json['file_type']?.toString() ?? 'pdf',
      signatoryName: json['signatory_name']?.toString() ??
          json['instructorName']?.toString(),
      signatoryTitle: json['signatory_title']?.toString(),
    );
  }

  factory CourseCertificate.fromMap(Map<String, dynamic> map, {String? id}) {
    return CourseCertificate.fromLaravelJson({
      ...map,
      'id': ?id,
    });
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'course_id': courseId,
        'courseId': courseId,
        'course_title': courseTitle,
        'courseTitle': courseTitle,
        'student_id': studentId,
        'studentId': studentId,
        'student_name': studentName,
        'studentName': studentName,
        'student_email': studentEmail,
        'studentEmail': studentEmail,
        'certificate_code': certificateCode,
        'serialNumber': certificateCode,
        'issued_at': issuedAt.toIso8601String(),
        'issuedAt': issuedAt.toIso8601String(),
        'completion_percentage': completionPercentage,
        'completionPercentage': completionPercentage,
        'verification_url': verificationUrl,
        'verificationUrl': verificationUrl,
        'file_url': fileUrl,
        'fileType': fileType,
        'file_type': fileType,
        'signatory_name': signatoryName,
        'instructorName': instructorName,
        'signatory_title': signatoryTitle,
      };

  @override
  List<Object?> get props => [
        id,
        userId,
        courseId,
        studentId,
        certificateCode,
        issuedAt,
        fileUrl,
      ];
}

/// نتيجة التحقق العام من الشهادة عبر نقطة النهاية الرسمية
/// GET /public/certificates/verify/{code}
class CertificateVerificationResult extends Equatable {
  final bool success;
  final bool valid;
  final String message;
  final CourseCertificate? certificate;

  const CertificateVerificationResult({
    required this.success,
    required this.valid,
    required this.message,
    this.certificate,
  });

  factory CertificateVerificationResult.fromJson(Map<String, dynamic> json) {
    final isSuccess = json['success'] == true;
    final isValid = json['valid'] == true;
    final msg = json['message']?.toString() ??
        (isValid ? 'الشهادة موثقة وصالحة في مركز الأمين.' : 'رمز الشهادة غير صالح.');

    CourseCertificate? cert;
    if (json['data'] is Map && (json['data'] as Map)['certificate'] is Map) {
      cert = CourseCertificate.fromLaravelJson(
        Map<String, dynamic>.from((json['data'] as Map)['certificate'] as Map),
      );
    }

    return CertificateVerificationResult(
      success: isSuccess,
      valid: isValid,
      message: msg,
      certificate: cert,
    );
  }

  @override
  List<Object?> get props => [success, valid, message, certificate];
}
