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
              .map(
                (item) => CourseCertificate.fromLaravelJson(
                  Map<String, dynamic>.from(item),
                ),
              )
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
      throw const ApiException(
        'رمز الشهادة غير صالح أو فارغ.',
        statusCode: 400,
      );
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
  Future<CertificateVerificationResult> verifyCertificatePublic(
    String code,
  ) async {
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
      final uri = Uri.tryParse(trimmed);
      String? baseUrl;
      try {
        baseUrl = _apiClient.dio.options.baseUrl;
      } catch (_) {
        baseUrl = null;
      }
      final baseUri = baseUrl != null ? Uri.tryParse(baseUrl) : null;

      // حماية أمنية صارمة: إذا كان الرابط خارجياً (مثل S3 أو Cloudflare أو Bunny أو CDN خارجي)
      // يتم منع إرسال ترويسة Sanctum Authorization لمنع تسريب بيانات الاعتماد لجهات خارجية
      final bool isExternalHost =
          uri != null &&
          baseUri != null &&
          uri.hasAuthority &&
          uri.host.toLowerCase() != baseUri.host.toLowerCase();

      final response = await _apiClient.dio.get<List<int>>(
        trimmed,
        options: Options(
          responseType: ResponseType.bytes,
          extra: {if (isExternalHost) 'skipAuth': true},
          headers: {'Accept': 'application/pdf,application/octet-stream'},
        ),
      );

      if (response.data != null && response.data!.isNotEmpty) {
        final bytes = Uint8List.fromList(response.data!);

        // التحقق من صحة ترويسة الـ PDF الرسمية (%PDF)
        if (bytes.length < 4 ||
            bytes[0] != 0x25 ||
            bytes[1] != 0x50 ||
            bytes[2] != 0x44 ||
            bytes[3] != 0x46) {
          throw const CertificateFileNotAvailableException(
            'الملف المستلم ليس ملف PDF معتمداً أو قد يكون الرابط الموقّع منتهياً.',
          );
        }
        return bytes;
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
      if (e.response?.statusCode == 403 || e.response?.statusCode == 401) {
        throw const CertificateFileNotAvailableException(
          'انتهت صلاحية رابط التحميل الموقّع أو لا تملك الصلاحية لتحميل هذا الملف.',
        );
      }
      if (e.response?.statusCode == 410) {
        throw const CertificateFileNotAvailableException(
          'رابط تحميل الشهادة منتهي الصلاحية (410). يرجى تحديث الصفحة للحصول على رابط جديد.',
        );
      }
      throw ApiException.fromDioException(e);
    }
  }
}
