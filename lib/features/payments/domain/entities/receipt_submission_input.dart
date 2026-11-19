import 'dart:io';

import 'package:equatable/equatable.dart';

import '../../../../core/errors/app_failure.dart';
import 'payment_method.dart';

/// مدخلات إرسال إيصال السداد المالي نحو خادم Laravel.
class ReceiptSubmissionInput extends Equatable {
  final String courseSlug;
  final String courseId;
  final String courseTitle;
  final PaymentMethod? paymentMethod;
  final String senderName;
  final String senderAccount;
  final double? amount;
  final String receiptFilePath;
  final String? transactionReference;

  const ReceiptSubmissionInput({
    required this.courseSlug,
    required this.courseId,
    required this.courseTitle,
    required this.paymentMethod,
    required this.senderName,
    required this.senderAccount,
    required this.amount,
    required this.receiptFilePath,
    this.transactionReference,
  });

  String get effectiveCourseSlug =>
      courseSlug.trim().isNotEmpty ? courseSlug.trim() : courseId.trim();

  /// تدقيق المدخلات محلياً دون أي قيم افتراضية مزيفة (لا هاتف طالب افتراضي ولا سعر بديل).
  ValidationFailure? validate({bool checkFileOnDisk = true}) {
    if (effectiveCourseSlug.isEmpty) {
      return const ValidationFailure(
        'معرّف الدورة التدريبية غير صالح لإتمام عملية السداد.',
      );
    }

    if (paymentMethod == null) {
      return const ValidationFailure(
        'يرجى اختيار وسيلة سداد صالحة (فودافون كاش أو إنستاباي).',
      );
    }

    if (senderName.trim().isEmpty) {
      return const ValidationFailure(
        'يرجى إدخال اسم صاحب الحساب أو المحفظة المحول منها.',
      );
    }

    if (senderAccount.trim().isEmpty) {
      return const ValidationFailure(
        'يرجى إدخال رقم المحفظة أو الحساب المحول منه.',
      );
    }

    final parsedAmount = amount;
    if (parsedAmount == null || parsedAmount <= 0) {
      return ValidationFailure(
        'المبلغ المدفوع غير محدد أو غير صالح لدورة "$courseTitle".',
      );
    }

    final trimmedPath = receiptFilePath.trim();
    if (trimmedPath.isEmpty) {
      return const ValidationFailure(
        'يرجى إرفاق صورة واضحة لإيصال السداد لاعتماد الطلب من قبل الإدارة.',
      );
    }

    final ext = trimmedPath.split('.').last.toLowerCase();
    if (!const {'jpg', 'jpeg', 'png', 'webp'}.contains(ext)) {
      return const ValidationFailure(
        'صيغة ملف الإيصال غير مقبولة. الصيغ المدعومة هي: JPG, JPEG, PNG, WEBP.',
      );
    }

    if (checkFileOnDisk) {
      final file = File(trimmedPath);
      if (!file.existsSync()) {
        return const ValidationFailure(
          'ملف إيصال السداد غير موجود على الجهاز، يرجى اختيار الصورة مجدداً.',
        );
      }
      if (file.lengthSync() > 5 * 1024 * 1024) {
        return const ValidationFailure(
          'حجم صورة إيصال السداد يتجاوز الحد الأقصى المسموح (5 ميجابايت).',
        );
      }
    }

    return null;
  }

  @override
  List<Object?> get props => [
        courseSlug,
        courseId,
        courseTitle,
        paymentMethod,
        senderName,
        senderAccount,
        amount,
        receiptFilePath,
        transactionReference,
      ];
}
