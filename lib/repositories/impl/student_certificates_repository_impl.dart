import 'dart:typed_data';
import '../../core/di/injection_container.dart';
import '../../datasources/certificates_remote_data_source.dart';
import '../../models/course_certificate.dart';
import '../student_certificates_repository.dart';

class StudentCertificatesRepositoryImpl implements StudentCertificatesRepository {
  final CertificatesRemoteDataSource? _remoteDataSource;

  String? _cachedStudentId;
  List<CourseCertificate> _cachedCertificates = const [];

  StudentCertificatesRepositoryImpl({
    CertificatesRemoteDataSource? remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  CertificatesRemoteDataSource get _remote {
    if (_remoteDataSource != null) return _remoteDataSource;
    if (sl.isRegistered<CertificatesRemoteDataSource>()) {
      return sl<CertificatesRemoteDataSource>();
    }
    throw StateError('CertificatesRemoteDataSource is not registered in GetIt.');
  }

  @override
  Future<List<CourseCertificate>> getStudentCertificates({
    bool forceRefresh = false,
    String? currentStudentId,
  }) async {
    // التحقق من عزل هوية الطالب: في حال اختلاف المعرف، يتم تصفير الكاش فوراً
    if (currentStudentId != null && currentStudentId.isNotEmpty) {
      if (_cachedStudentId != currentStudentId) {
        _cachedStudentId = currentStudentId;
        _cachedCertificates = const [];
      }
    }

    if (!forceRefresh && _cachedCertificates.isNotEmpty) {
      return _cachedCertificates;
    }

    final certificates = await _remote.getStudentCertificates();
    _cachedCertificates = List.unmodifiable(certificates);
    return _cachedCertificates;
  }

  @override
  Future<CourseCertificate> getCertificateDetails(String code) async {
    return await _remote.getCertificateDetails(code);
  }

  @override
  Future<CertificateVerificationResult> verifyCertificate(String code) async {
    return await _remote.verifyCertificatePublic(code);
  }

  @override
  Future<Uint8List> downloadOfficialCertificatePdf(String fileUrl) async {
    return await _remote.downloadCertificateBytes(fileUrl);
  }

  @override
  void clearCache() {
    _cachedStudentId = null;
    _cachedCertificates = const [];
  }
}
