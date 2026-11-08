import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// خلفية معمارية مرسومة بـ CustomPainter تضيف عمقاً بصرياً هادئاً وتتحرك بنعومة مع التمرير.
class OnboardingBackdropPainter extends CustomPainter {
  final double pageProgress;

  const OnboardingBackdropPainter({required this.pageProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final shift = (pageProgress - 1.5) * 24.0;

    // هالة لونية ناعمة أعلى الشاشة
    final primaryAuraCenter = Offset(size.width * 0.5 - shift, size.height * 0.24);
    final auraRadius = math.min(size.width, size.height) * 0.62;
    final auraPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.primary.withValues(alpha: 0.075),
          const Color(0xFF2563EB).withValues(alpha: 0.03),
          Colors.transparent,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(
        Rect.fromCircle(center: primaryAuraCenter, radius: auraRadius),
      );
    canvas.drawCircle(primaryAuraCenter, auraRadius, auraPaint);

    // أقواس هندسية دقيقة (Hairline Architectural Rings)
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = AppColors.primary.withValues(alpha: 0.065);

    canvas.drawCircle(primaryAuraCenter, auraRadius * 0.56, arcPaint);
    canvas.drawCircle(
      primaryAuraCenter,
      auraRadius * 0.80,
      arcPaint..color = AppColors.primary.withValues(alpha: 0.04),
    );

    // شبكة نقاط خفيفة في الزاوية العلوية لإثراء الفراغ البصري بأسلوب Figma Editorial
    final dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = AppColors.primary.withValues(alpha: 0.07);

    const step = 22.0;
    final maxX = math.min(size.width - 20, 150.0);
    final maxY = math.min(size.height * 0.26, 140.0);
    for (double x = 24; x < maxX; x += step) {
      for (double y = 64; y < maxY; y += step) {
        canvas.drawCircle(Offset(x, y), 1.3, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant OnboardingBackdropPainter oldDelegate) {
    return (oldDelegate.pageProgress - pageProgress).abs() > 0.002;
  }
}

