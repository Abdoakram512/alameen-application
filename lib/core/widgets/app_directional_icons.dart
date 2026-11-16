import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// موجه الأيقونات الذكي لضبط الاتجاهات والأسهم وعلامات الصح وفقاً للـ RTL / LTR
class AppDirectionalIcons {
  AppDirectionalIcons._();

  /// أيقونة الرجوع المتوافقة مع اتجاه الواجهة (يمين في العربية، يسار في الإنجليزية)
  static IconData backIcon(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return isRtl ? PhosphorIconsRegular.arrowRight : PhosphorIconsRegular.arrowLeft;
  }

  /// سهم تفاصيل القائمة (مؤشر الدخول للعناصر الفرعية: يسار في العربي، يمين في الإنجليزي)
  static IconData chevronDetail(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return isRtl ? PhosphorIconsRegular.caretLeft : PhosphorIconsRegular.caretRight;
  }

  /// سهم التقدم للأمام
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

