import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// مكون موحد لعرض رسوم Lottie المتجهية مع احترام تفضيلات تقليل الحركة وبيئة الاختبار.
class AppLottieBox extends StatelessWidget {
  final String assetPath;
  final double size;
  final double? width;
  final double? height;
  final bool repeat;
  final IconData fallbackIcon;
  final Color? fallbackColor;

  const AppLottieBox({
    super.key,
    required this.assetPath,
    this.size = 72,
    this.width,
    this.height,
    this.repeat = true,
    this.fallbackIcon = Icons.auto_graph_rounded,
    this.fallbackColor,
  });

  bool _shouldAnimate(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      return false;
    }
    if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
      return false;
    }
    final bindingName = WidgetsBinding.instance.runtimeType.toString();
    if (bindingName.contains('Test')) {
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final animate = _shouldAnimate(context);
    final w = width ?? size;
    final h = height ?? size;
    return SizedBox(
      width: w,
      height: h,
      child: Lottie.asset(
        assetPath,
        width: w,
        height: h,
        fit: BoxFit.contain,
        animate: animate,
        repeat: animate && repeat,
        errorBuilder: (context, error, stackTrace) => Icon(
          fallbackIcon,
          size: (w < h ? w : h) * 0.55,
          color: fallbackColor ?? Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
