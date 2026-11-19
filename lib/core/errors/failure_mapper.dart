import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../datasources/certificates_remote_data_source.dart';
import '../../repositories/impl/student_assignments_repository_impl.dart';
import '../../repositories/student_watch_repository.dart';
import '../network/api_exceptions.dart';
import 'app_failure.dart';

/// محوّل موحد على حدود طبقة البيانات/المستودعات لترجمة استثناءات الشبكة والبنية التحتية
/// إلى حالات فشل معرّفة النوع ([AppFailure]).
class FailureMapper {
  const FailureMapper._();

  static AppFailure fromException(
    Object error, {
    String? fallbackMessage,
  }) {
    if (error is AppFailure) return error;

    if (error is SocketException || error is TimeoutException) {
      return NetworkFailure(
        fallbackMessage ??
            'تعذر الاتصال بالخادم. يرجى التحقق من اتصال الإنترنت والمحاولة مرة أخرى.',
      );
    }

    if (error is DioException) {
      return fromException(
        ApiException.fromDioException(error),
        fallbackMessage: fallbackMessage,
      );
    }

    if (error is PlaybackProviderIncompatibleException) {
      return PlaybackProviderFailure(error.message);
    }

    if (error is PlaybackAuthorizationException) {
      if (error.statusCode == 401) {
        return UnauthorizedFailure(error.message);
      }
      if (error.statusCode == 400) {
        return ValidationFailure(error.message);
      }
      return ForbiddenFailure(error.message);
    }

    if (error is UnsupportedFileAttachmentException) {
      return UnsupportedFeatureFailure(error.message);
    }

    if (error is CertificateFileNotAvailableException) {
      return UnsupportedFeatureFailure(error.message);
    }

    if (error is NetworkTimeoutException) {
      return NetworkFailure(error.message);
    }

    if (error is UnauthorizedException) {
      return UnauthorizedFailure(error.message);
    }

    if (error is ForbiddenException) {
      return ForbiddenFailure(
        error.message,
        reasonCode: _extractReasonCode(error.rawResponse),
      );
    }

    if (error is NotFoundException) {
      return NotFoundFailure(error.message);
    }

    if (error is ValidationException) {
      return ValidationFailure(
        error.firstErrorMessage,
        fieldErrors: error.errors,
      );
    }

    if (error is RateLimitException) {
      return RateLimitFailure(
        error.message,
        retryAfterSeconds: error.retryAfterSeconds,
      );
    }

    if (error is ServerException) {
      return ServerFailure(error.message);
    }

    if (error is ApiException) {
      final code = error.statusCode;
      if (code == 400 || code == 422) {
        return ValidationFailure(error.message);
      }
      if (code == 401) {
        return UnauthorizedFailure(error.message);
      }
      if (code == 403) {
        return ForbiddenFailure(
          error.message,
          reasonCode: _extractReasonCode(error.rawResponse),
        );
      }
      if (code == 404) {
        return NotFoundFailure(error.message);
      }
      if (code == 429) {
        return RateLimitFailure(error.message);
      }
      if (code != null && code >= 500) {
        return ServerFailure(error.message);
      }
      return UnknownFailure(error.message);
    }

    if (error is FirebaseException) {
      final code = error.code.toLowerCase();
      if (code.contains('network') ||
          code.contains('unavailable') ||
          code.contains('timeout')) {
        return NetworkFailure(
          fallbackMessage ?? 'تعذر الاتصال بالشبكة، يرجى المحاولة مرة أخرى.',
        );
      }
      if (code.contains('unauthenticated')) {
        return const UnauthorizedFailure(
          'انتهت صلاحية الجلسة، يرجى تسجيل الدخول مجدداً.',
        );
      }
      if (code.contains('permission')) {
        return const ForbiddenFailure('ليس لديك صلاحية للوصول إلى هذه الخدمة.');
      }
      return UnknownFailure(error.message ?? fallbackMessage ?? error.toString());
    }

    final rawMsg = error.toString().trim();
    return UnknownFailure(
      fallbackMessage ?? (rawMsg.isNotEmpty ? rawMsg : 'حدث خطأ غير متوقع.'),
    );
  }

  static String? _extractReasonCode(dynamic rawResponse) {
    if (rawResponse is Map) {
      final code = rawResponse['reason_code'] ??
          rawResponse['error_code'] ??
          rawResponse['code'];
      if (code != null) {
        final trimmed = code.toString().trim();
        if (trimmed.isNotEmpty) return trimmed;
      }
    }
    return null;
  }
}
