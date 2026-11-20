import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// موجه الأيقونات الذكي لضبط اتجاه الأسهم وعلامات الصح وفقاً للملاحة الطبيعية
class AppDirectionalIcons {
  AppDirectionalIcons._();

  /// أيقونة الرجوع القياسية (تشير دائماً لليسار في مشغلات الفيديو والواجهات لمنع الانعكاس غير المرغوب)
  static IconData backIcon(BuildContext context) {
    return PhosphorIconsRegular.arrowLeft;
  }

  /// سهم تفاصيل القائمة (مؤشر الدخول للعناصر الفرعية: يسار في العربي، يمين في الإنجليزي)
  static IconData chevronDetail(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return isRtl ? PhosphorIconsRegular.caretLeft : PhosphorIconsRegular.caretRight;
  }

  /// سهم تفاصيل القائمة للخلف (يشير لليسار)
  static IconData backCaret(BuildContext context) {
    return PhosphorIconsRegular.caretLeft;
  }

  /// سهم تفاصيل القائمة للأمام (يشير لليمين)
  static IconData forwardCaret(BuildContext context) {
    return PhosphorIconsRegular.caretRight;
  }

  /// سهم التقدم للأمام (يشير دائماً للأمام / اليمين لعلامات التالي والروابط)
  static IconData forwardIcon(BuildContext context) {
    return PhosphorIconsRegular.arrowRight;
  }

  /// علامة الصح القياسية (✓) محمية دائماً من الانعكاس المعكوس
  static Widget check({
    BuildContext? context,
    double size = 18,
    Color? color,
  }) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Icon(Icons.check_rounded, size: size, color: color),
    );
  }

  /// دائرة الصح الممتلئة المعتمدة رسمياً دون انعكاس
  static Widget checkCircle({
    BuildContext? context,
    double size = 20,
    Color? color,
  }) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Icon(PhosphorIconsFill.checkCircle, size: size, color: color),
    );
  }
}

