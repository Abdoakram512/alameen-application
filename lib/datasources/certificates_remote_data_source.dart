import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../core/network/api_client.dart';
import '../core/network/api_exceptions.dart';
import '../models/course_certificate.dart';

class CertificateFileNotAvailableException implements Exception {
  final String message;
  const CertificateFileNotAvailableException(this.message);

  @override
  String toString() => message;
}

/// مصدر البيانات البعيد لشهادات إتمام الدورات والتحقق العام عبر Laravel REST API
abstract class CertificatesRemoteDataSource {
  /// GET /student/certificates
  Future<List<CourseCertificate>> getStudentCertificates();

  /// GET /student/certificates/{code}
  Future<CourseCertificate> getCertificateDetails(String code);

  /// GET /public/certificates/verify/{code}
  Future<CertificateVerificationResult> verifyCertificatePublic(String code);

  /// تحميل ملف الـ PDF الرسمي الصادر من الخادم
  Future<Uint8List> downloadCertificateBytes(String fileUrl);
}

class CertificatesRemoteDataSourceImpl implements CertificatesRemoteDataSource {
  final ApiClient _apiClient;

  CertificatesRemoteDataSourceImpl({required ApiClient apiClient})
      : _apiClient = apiClient;

  @override
  Future<List<CourseCertificate>> getStudentCertificates() async {
    try {
      final response = await _apiClient.get('/student/certificates');
      final raw = response.data;
      if (raw is Map<String, dynamic>) {
        final data = raw['data'];
        if (data is Map<String, dynamic> && data['certificates'] is List) {
          final list = data['certificates'] as List;
          return list
              .whereType<Map>()
              .map((item) => CourseCertificate.fromLaravelJson(
                    Map<String, dynamic>.from(item),
                  ))
              .toList();
        }
      }
      return const [];
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  @override
  Future<CourseCertificate> getCertificateDetails(String code) async {
    final cleanCode = code.trim();
    if (cleanCode.isEmpty) {
      throw const ApiException('رمز الشهادة غير صالح أو فارغ.', statusCode: 400);
    }

    try {
      final response = await _apiClient.get('/student/certificates/$cleanCode');
      final raw = response.data;
      if (raw is Map<String, dynamic>) {
        final data = raw['data'];
        if (data is Map<String, dynamic> && data['certificate'] is Map) {
          return CourseCertificate.fromLaravelJson(
            Map<String, dynamic>.from(data['certificate'] as Map),
          );
        }
      }
      throw const ApiException(
        'تعذر قراءة تفاصيل الشهادة من رد الخادم.',
        statusCode: 500,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  @override
  Future<CertificateVerificationResult> verifyCertificatePublic(String code) async {
    final cleanCode = code.trim();
    if (cleanCode.isEmpty) {
      return const CertificateVerificationResult(
        success: false,
        valid: false,
        message: 'رمز التحقق فارغ، يرجى كتابة رمز شهادة صحيح.',
      );
    }

    try {
      final response = await _apiClient.get(
        '/public/certificates/verify/$cleanCode',
        options: Options(
          headers: {
            // endpoint عام لا يحتاج توكن الطالب
            'Accept': 'application/json',
          },
        ),
      );

      final raw = response.data;
      if (raw is Map<String, dynamic>) {
        return CertificateVerificationResult.fromJson(raw);
      }
      return const CertificateVerificationResult(
        success: false,
        valid: false,
        message: 'تعذر التحقق من الشهادة حالياً.',
      );
    } on DioException catch (e) {
      if (e.response != null && e.response!.statusCode == 404) {
        final raw = e.response!.data;
        if (raw is Map<String, dynamic>) {
          return CertificateVerificationResult.fromJson(raw);
        }
        return const CertificateVerificationResult(
          success: false,
          valid: false,
          message: 'رمز الشهادة غير صالح أو غير مسجل في المنصة.',
        );
      }
      throw ApiException.fromDioException(e);
    }
  }

  @override
  Future<Uint8List> downloadCertificateBytes(String fileUrl) async {
    final trimmed = fileUrl.trim();
    if (trimmed.isEmpty) {
      throw const CertificateFileNotAvailableException(
        'ملف الشهادة الرسمي غير متوفر للتحميل من الخادم حالياً. يرجى مراجعة إدارة المركز.',
      );
    }

    try {
      final response = await _apiClient.dio.get<List<int>>(
        trimmed,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {
            'Accept': 'application/pdf,application/octet-stream',
          },
        ),
      );

      if (response.data != null && response.data!.isNotEmpty) {
        return Uint8List.fromList(response.data!);
      }
      throw const CertificateFileNotAvailableException(
        'محتوى ملف الشهادة المستلم من الخادم فارغ.',
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw const CertificateFileNotAvailableException(
          'ملف الشهادة غير موجود على خادم التخزين (404). يرجى التواصل مع الدعم الأكاديمي لإعادة توليده.',
        );
      }
      if (e.response?.statusCode == 403) {
        throw const CertificateFileNotAvailableException(
          'لا تملك الصلاحية للوصول إلى ملف الشهادة (403).',
        );
      }
      throw ApiException.fromDioException(e);
    }
  }
}
