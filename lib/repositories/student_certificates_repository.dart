import 'dart:typed_data';
import '../models/course_certificate.dart';

export '../datasources/certificates_remote_data_source.dart'
    show CertificateFileNotAvailableException;
export 'impl/student_certificates_repository_impl.dart'
    show StudentCertificatesRepositoryImpl;

/// واجهة مستودع شهادات إتمام الدورات والتحقق الأكاديمي عبر Laravel REST API
abstract class StudentCertificatesRepository {
  /// جلب كافة الشهادات المعتمدة للطالب المصرح له عبر Laravel REST API.
  /// GET /student/certificates
  Future<List<CourseCertificate>> getStudentCertificates({
    bool forceRefresh = false,
    String? currentStudentId,
  });

  /// جلب تفاصيل شهادة معينة باستخدام رمز الشهادة الرسمي.
  /// GET /student/certificates/{code}
  Future<CourseCertificate> getCertificateDetails(String code);

  /// التحقق العام من صحة الشهادة واعتمادها رسمياً من سنتر الأمين (عام متاح للجميع).
  /// GET /public/certificates/verify/{code}
  Future<CertificateVerificationResult> verifyCertificate(String code);

  /// تحميل ملف الـ PDF الرسمي المعتمد الصادر من الخادم
  Future<Uint8List> downloadOfficialCertificatePdf(String fileUrl);

  /// مسح الذاكرة المؤقتة لضمان عزل الحسابات عند تسجيل الخروج
  void clearCache();
}
