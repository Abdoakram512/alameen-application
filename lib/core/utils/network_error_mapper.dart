import 'dart:async';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';

/// Maps raw exceptions, Firebase errors, and network timeouts to clear Arabic messages.
class NetworkErrorMapper {
  NetworkErrorMapper._();

  static String toArabicMessage(dynamic error, {String defaultMessage = 'حدث خطأ غير متوقع، يرجى المحاولة مرة أخرى.'}) {
    if (error == null) return defaultMessage;

    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'تم رفض العملية: ليس لديك الصلاحية الكافية لإتمام هذا الإجراء.';
        case 'unavailable':
          return 'تعذر الاتصال بالخادم. يرجى التحقق من اتصال الإنترنت والمحاولة مرة أخرى.';
        case 'deadline-exceeded':
          return 'استغرقت الاستجابة وقتاً أطول من المتوقع، يرجى المحاولة مرة أخرى.';
        case 'not-found':
          return 'البيانات المطلوبة غير موجودة.';
        case 'already-exists':
          return 'تم إرسال هذا الطلب أو إضافة هذه البيانات مسبقاً.';
        case 'resource-exhausted':
          return 'تم تجاوز الحد المسموح من الطلبات، يرجى المحاولة بعد قليل.';
        case 'unauthenticated':
          return 'انتهت جلسة تسجيل الدخول، يرجى إعادة تسجيل الدخول والمحاولة.';
        case 'cancelled':
          return 'تم إلغاء العملية.';
        default:
          if (error.message != null && error.message!.isNotEmpty) {
            final msg = error.message!.toLowerCase();
            if (msg.contains('permission') || msg.contains('denied')) {
              return 'تم رفض العملية: تحقق من الصلاحيات أو صلاحية الحساب.';
            }
            if (msg.contains('network') || msg.contains('unavailable') || msg.contains('offline')) {
              return 'تعذر الاتصال بالخادم، يرجى التحقق من اتصال الإنترنت.';
            }
          }
      }
    }

    if (error is TimeoutException) {
      return 'انتهت مهلة الاتصال بالخادم، يرجى التحقق من سرعة الإنترنت والمحاولة ثانية.';
    }

    if (error is SocketException) {
      return 'لا يوجد اتصال بالإنترنت، يرجى التأكد من اتصالك بالشبكة والمحاولة.';
    }

    final str = error.toString().toLowerCase();
    if (str.contains('socketexception') || str.contains('network_error') || str.contains('failed host lookup')) {
      return 'لا يوجد اتصال بالإنترنت، يرجى التأكد من اتصالك بالشبكة والمحاولة.';
    }
    if (str.contains('permission-denied') || str.contains('permission denied')) {
      return 'تم رفض العملية: ليس لديك الصلاحية الكافية لإتمام هذا الإجراء.';
    }
    if (str.contains('deadline-exceeded') || str.contains('timeout')) {
      return 'استغرقت العملية وقتاً أطول من المتوقع، يرجى المحاولة ثانية.';
    }

    return defaultMessage;
  }
}

