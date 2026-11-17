import 'package:dio/dio.dart';

/// Base exception class for all API-related network errors.
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic rawResponse;

  const ApiException(
    this.message, {
    this.statusCode,
    this.rawResponse,
  });

  @override
  String toString() => 'ApiException(statusCode: $statusCode, message: $message)';

  /// Factory constructor to convert [DioException] into specific [ApiException] subclasses.
  factory ApiException.fromDioException(DioException dioException) {
    final response = dioException.response;
    final statusCode = response?.statusCode;
    final dynamic data = response?.data;

    String? extractedMessage;
    Map<String, List<String>> validationErrors = {};

    if (data is Map<String, dynamic>) {
      if (data['message'] is String && (data['message'] as String).isNotEmpty) {
        extractedMessage = data['message'] as String;
      } else if (data['error'] is String && (data['error'] as String).isNotEmpty) {
        extractedMessage = data['error'] as String;
      }

      // Parse Laravel validation errors
      if (data['errors'] is Map) {
        final errorsMap = data['errors'] as Map;
        errorsMap.forEach((key, value) {
          if (value is List) {
            validationErrors[key.toString()] = value.map((e) => e.toString()).toList();
          } else if (value is String) {
            validationErrors[key.toString()] = [value];
          }
        });
      }
    }

    switch (dioException.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return NetworkTimeoutException(
          extractedMessage ?? 'انتهت مهلة الاتصال بالخادم. يرجى التحقق من اتصال الإنترنت والمحاولة مرة أخرى.',
          statusCode: statusCode,
          rawResponse: data,
        );

      case DioExceptionType.connectionError:
        return NetworkTimeoutException(
          extractedMessage ?? 'تعذر الاتصال بالخادم. يرجى التحقق من اتصال الإنترنت.',
          statusCode: statusCode,
          rawResponse: data,
        );

      case DioExceptionType.badCertificate:
        return ApiException(
          'خطأ في شهادة أمان الاتصال بالخادم.',
          statusCode: statusCode,
          rawResponse: data,
        );

      case DioExceptionType.cancel:
        return const ApiException(
          'تم إلغاء الطلب.',
        );

      case DioExceptionType.badResponse:
        switch (statusCode) {
          case 400:
            return BadRequestException(
              extractedMessage ?? 'طلب غير صالح. يرجى التأكد من صحة البيانات المرسلة.',
              statusCode: 400,
              rawResponse: data,
            );

          case 401:
            return UnauthorizedException(
              extractedMessage ?? 'انتهت جلسة تسجيل الدخول أو أن بيانات الدخول غير صحيحة.',
              statusCode: 401,
              rawResponse: data,
            );

          case 403:
            return ForbiddenException(
              extractedMessage ?? 'ليس لديك صلاحية للوصول إلى هذا المحتوى أو أن حسابك قيد المراجعة.',
              statusCode: 403,
              rawResponse: data,
            );

          case 404:
            return NotFoundException(
              extractedMessage ?? 'المورد المطلوب غير موجود.',
              statusCode: 404,
              rawResponse: data,
            );

          case 422:
            return ValidationException(
              extractedMessage ?? 'بيانات الإدخال غير صالحة. يرجى مراجعة الحقول.',
              statusCode: 422,
              errors: validationErrors,
              rawResponse: data,
            );

          case 429:
            int? retryAfter;
            final retryHeader = response?.headers.value('retry-after');
            if (retryHeader != null) {
              retryAfter = int.tryParse(retryHeader);
            }
            return RateLimitException(
              extractedMessage ?? 'تجاوزت الحد المسموح من الطلبات. يرجى الانتظار قليلاً ثم المحاولة مرة أخرى.',
              statusCode: 429,
              retryAfterSeconds: retryAfter,
              rawResponse: data,
            );

          case 500:
          case 502:
          case 503:
          case 504:
            return ServerException(
              extractedMessage ?? 'حدث خطأ في خادم المنصة. يرجى المحاولة لاحقاً.',
              statusCode: statusCode,
              rawResponse: data,
            );

          default:
            return ApiException(
              extractedMessage ?? 'حدث خطأ غير متوقع أثناء معالجة الطلب (رمز: $statusCode).',
              statusCode: statusCode,
              rawResponse: data,
            );
        }

      case DioExceptionType.unknown:
      default:
        return ApiException(
          extractedMessage ?? dioException.message ?? 'حدث خطأ غير متوقع أثناء الاتصال بالخادم.',
          statusCode: statusCode,
          rawResponse: data,
        );
    }
  }
}

/// 400 Bad Request
class BadRequestException extends ApiException {
  const BadRequestException(
    super.message, {
    super.statusCode = 400,
    super.rawResponse,
  });
}

/// 401 Unauthorized (Expired or missing token, invalid credentials)
class UnauthorizedException extends ApiException {
  const UnauthorizedException(
    super.message, {
    super.statusCode = 401,
    super.rawResponse,
  });
}

/// 403 Forbidden (Banned account, pending approval, or unpurchased content)
class ForbiddenException extends ApiException {
  const ForbiddenException(
    super.message, {
    super.statusCode = 403,
    super.rawResponse,
  });
}

/// 404 Not Found
class NotFoundException extends ApiException {
  const NotFoundException(
    super.message, {
    super.statusCode = 404,
    super.rawResponse,
  });
}

/// 422 Unprocessable Entity (Form validation errors)
class ValidationException extends ApiException {
  final Map<String, List<String>> errors;

  const ValidationException(
    super.message, {
    super.statusCode = 422,
    this.errors = const {},
    super.rawResponse,
  });

  /// Returns the first validation error message if available, otherwise returns the general message.
  String get firstErrorMessage {
    if (errors.isNotEmpty) {
      final firstEntry = errors.values.first;
      if (firstEntry.isNotEmpty) {
        return firstEntry.first;
      }
    }
    return message;
  }

  /// Get errors for a specific field name.
  List<String> getFieldErrors(String field) => errors[field] ?? [];
}

/// 429 Too Many Requests (Rate limiting)
class RateLimitException extends ApiException {
  final int? retryAfterSeconds;

  const RateLimitException(
    super.message, {
    super.statusCode = 429,
    this.retryAfterSeconds,
    super.rawResponse,
  });
}

/// Network connection timeout or send/receive timeout
class NetworkTimeoutException extends ApiException {
  const NetworkTimeoutException(
    super.message, {
    super.statusCode,
    super.rawResponse,
  });
}

/// 500+ Internal Server Error
class ServerException extends ApiException {
  const ServerException(
    super.message, {
    super.statusCode = 500,
    super.rawResponse,
  });
}
