import 'package:equatable/equatable.dart';

/// فئة أساس مغلقة (Sealed) تمثل جميع حالات الفشل المعرّفة عبر طبقات المجال والعرض
/// دون تسريب استثناءات البنية التحتية (مثل DioException).
sealed class AppFailure extends Equatable implements Exception {
  final String message;

  const AppFailure(this.message);

  @override
  List<Object?> get props => [message];

  @override
  String toString() => message;
}

/// فشل اتصال الشبكة أو انتهاء المهلة الزمنية.
final class NetworkFailure extends AppFailure {
  const NetworkFailure(super.message);
}

/// انتهاء صلاحية الجلسة أو عدم توفر مصادقة صالحة (401 Unauthorized).
final class UnauthorizedFailure extends AppFailure {
  const UnauthorizedFailure(super.message);
}

/// رفض الخادم للوصول (403 Forbidden).
/// حقل [reasonCode] يُملأ فقط إذا أعاد خادم Laravel رمز سبب صريح، ولا يُخمن تلقائياً.
final class ForbiddenFailure extends AppFailure {
  final String? reasonCode;

  const ForbiddenFailure(
    super.message, {
    this.reasonCode,
  });

  @override
  List<Object?> get props => [message, reasonCode];
}

/// المورد المطلوب غير موجود (404 Not Found).
final class NotFoundFailure extends AppFailure {
  const NotFoundFailure(super.message);
}

/// فشل التحقق من صحة المدخلات محلياً أو عبر الخادم (400 / 422).
final class ValidationFailure extends AppFailure {
  final Map<String, List<String>> fieldErrors;

  const ValidationFailure(
    super.message, {
    this.fieldErrors = const {},
  });

  String get firstErrorMessage {
    for (final entries in fieldErrors.values) {
      if (entries.isNotEmpty && entries.first.trim().isNotEmpty) {
        return entries.first;
      }
    }
    return message;
  }

  @override
  List<Object?> get props => [message, fieldErrors];
}

/// تجاوز الحد المسموح للطلبات (429 Too Many Requests).
final class RateLimitFailure extends AppFailure {
  final int? retryAfterSeconds;

  const RateLimitFailure(
    super.message, {
    this.retryAfterSeconds,
  });

  @override
  List<Object?> get props => [message, retryAfterSeconds];
}

/// خطأ داخلي في الخادم (500+).
final class ServerFailure extends AppFailure {
  const ServerFailure(super.message);
}

/// ميزة غير مدعومة حالياً في عقد الواجهة الخلفية أو ملف غير متاح.
final class UnsupportedFeatureFailure extends AppFailure {
  const UnsupportedFeatureFailure(super.message);
}

/// عدم توافق مزود البث مع مشغل التطبيق (مثل عدم توفر HLS).
final class PlaybackProviderFailure extends AppFailure {
  const PlaybackProviderFailure(super.message);
}

/// فشل غير مصنف مع الحفاظ على رسالة عربية واضحة.
final class UnknownFailure extends AppFailure {
  const UnknownFailure(super.message);
}
