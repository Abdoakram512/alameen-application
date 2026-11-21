import 'dart:io';

import 'package:dio/dio.dart';

import '../core/network/api_client.dart';
import '../core/network/api_exceptions.dart';
import '../features/payments/domain/entities/payment_method.dart';
import '../models/payment_receipt_model.dart';

/// عقد مصدر البيانات البعيد للعمليات المالية وإيصالات الدفع في Laravel REST API.
abstract class PaymentRemoteDataSource {
  /// إرسال إيصال سداد مالي لدورة:
  /// POST /student/courses/{slug}/receipt
  Future<PaymentReceiptModel> submitCourseReceipt({
    required String courseSlug,
    required PaymentMethod paymentMethod,
    required String senderName,
    required String senderAccount,
    required double amount,
    required String receiptFilePath,
    String? transactionReference,
  });

  /// جلب جميع إيصالات السداد الخاصة بالطالب الموثق:
  /// GET /student/receipts
  Future<List<PaymentReceiptModel>> getStudentReceipts({int? courseId});
}

class PaymentRemoteDataSourceImpl implements PaymentRemoteDataSource {
  final ApiClient _apiClient;

  PaymentRemoteDataSourceImpl({required ApiClient apiClient})
    : _apiClient = apiClient;

  @override
  Future<PaymentReceiptModel> submitCourseReceipt({
    required String courseSlug,
    required PaymentMethod paymentMethod,
    required String senderName,
    required String senderAccount,
    required double amount,
    required String receiptFilePath,
    String? transactionReference,
  }) async {
    try {
      final file = File(receiptFilePath);
      if (!await file.exists()) {
        throw const ApiException(
          'ملف إيصال السداد غير موجود على الجهاز، يرجى اختيار الصورة مجدداً.',
          statusCode: 400,
        );
      }

      final fileLength = await file.length();
      if (fileLength > 5 * 1024 * 1024) {
        throw const ApiException(
          'حجم صورة إيصال السداد يتجاوز الحد الأقصى المسموح (5 ميجابايت).',
          statusCode: 422,
        );
      }

      final ext = receiptFilePath.split('.').last.toLowerCase();
      if (!const {'jpg', 'jpeg', 'png', 'webp'}.contains(ext)) {
        throw const ApiException(
          'صيغة ملف الإيصال غير مقبولة. الصيغ المدعومة هي: JPG, JPEG, PNG, WEBP.',
          statusCode: 422,
        );
      }

      final fileName = receiptFilePath.split(Platform.pathSeparator).last;
      final cleanAmount = amount % 1 == 0 ? amount.toInt() : amount;

      final formMap = <String, dynamic>{
        'payment_method': paymentMethod.apiValue,
        'sender_name': senderName.trim(),
        'sender_account': senderAccount.trim(),
        'amount': cleanAmount,
        if (transactionReference != null &&
            transactionReference.trim().isNotEmpty)
          'transaction_reference': transactionReference.trim(),
        'receipt_image': await MultipartFile.fromFile(
          receiptFilePath,
          filename: fileName,
          contentType: DioMediaType('image', ext == 'jpg' ? 'jpeg' : ext),
        ),
      };

      final formData = FormData.fromMap(formMap);
      final encodedSlug = Uri.encodeComponent(courseSlug.trim());

      final response = await _apiClient.postMultipart(
        '/student/courses/$encodedSlug/receipt',
        formData: formData,
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        if (data['data'] is Map && (data['data'] as Map)['receipt'] is Map) {
          return PaymentReceiptModel.fromJson(
            Map<String, dynamic>.from((data['data'] as Map)['receipt'] as Map),
          );
        } else if (data['data'] is Map) {
          return PaymentReceiptModel.fromJson(
            Map<String, dynamic>.from(data['data'] as Map),
          );
        } else if (data['receipt'] is Map) {
          return PaymentReceiptModel.fromJson(
            Map<String, dynamic>.from(data['receipt'] as Map),
          );
        }
      }

      throw const ApiException(
        'تعذر معالجة بيانات الإيصال المستلمة من الخادم.',
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  @override
  Future<List<PaymentReceiptModel>> getStudentReceipts({int? courseId}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (courseId != null && courseId > 0) {
        queryParams['course_id'] = courseId;
      }

      final response = await _apiClient.get(
        '/student/receipts',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final data = response.data;
      List<dynamic>? rawList;

      if (data is Map<String, dynamic>) {
        final innerData = data['data'];
        if (innerData is Map && innerData['receipts'] is List) {
          rawList = innerData['receipts'] as List;
        } else if (innerData is List) {
          rawList = innerData;
        } else if (data['receipts'] is List) {
          rawList = data['receipts'] as List;
        }
      } else if (data is List) {
        rawList = data;
      }

      if (rawList != null) {
        return rawList
            .whereType<Map>()
            .map(
              (item) => PaymentReceiptModel.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList();
      }

      return const <PaymentReceiptModel>[];
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
