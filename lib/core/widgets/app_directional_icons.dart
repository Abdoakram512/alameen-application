import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// موجه الأيقونات الذكي لضبط اتجاه الأسهم وعلامات الصح وفقاً للملاحة الطبيعية
class AppDirectionalIcons {
  AppDirectionalIcons._();

  /// أيقونة الرجوع القياسية
  static IconData backIcon(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return isRtl ? PhosphorIconsRegular.arrowRight : PhosphorIconsRegular.arrowLeft;
  }

  /// سهم تفاصيل القائمة ومؤشر الدخول للعناصر الفرعية (موجه نحو اليمين بالعربية وفق التفضيل البصري الطبيعي)
  static IconData chevronDetail(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return isRtl ? PhosphorIconsRegular.caretRight : PhosphorIconsRegular.caretLeft;
  }

  /// سهم تفاصيل القائمة للخلف
  static IconData backCaret(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return isRtl ? PhosphorIconsRegular.caretRight : PhosphorIconsRegular.caretLeft;
  }

  /// سهم تفاصيل القائمة للأمام
  static IconData forwardCaret(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return isRtl ? PhosphorIconsRegular.caretLeft : PhosphorIconsRegular.caretRight;
  }

  /// سهم التقدم للأمام (يسار في العربية لاتباع مسار التقدم الطبيعي، يمين في الإنجليزية)
  static IconData forwardIcon(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return isRtl ? PhosphorIconsRegular.arrowLeft : PhosphorIconsRegular.arrowRight;
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

