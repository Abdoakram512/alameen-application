import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// راسم كانفاس مخصص عالي الأداء يرسم موجات رادار وسونار دائرية متوسعة ومشعاع دوار بزاوية 360 درجة.
class RadarPulsePainter extends CustomPainter {
  final double animationValue; // 0.0 to 1.0 from AnimationController
  final Color baseColor;
  final int waveCount;

  RadarPulsePainter({
    required this.animationValue,
    this.baseColor = AppColors.royalNavy,
    this.waveCount = 3,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = min(size.width, size.height) / 2;

    // 1. Grid rings
    final gridPaint = Paint()
      ..color = baseColor.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (var i = 1; i <= 3; i++) {
      canvas.drawCircle(center, maxRadius * (i / 3), gridPaint);
    }

    // Crosshairs
    final crossHairPaint = Paint()
      ..color = baseColor.withValues(alpha: 0.06)
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(center.dx - maxRadius, center.dy),
      Offset(center.dx + maxRadius, center.dy),
      crossHairPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - maxRadius),
      Offset(center.dx, center.dy + maxRadius),
      crossHairPaint,
    );

    // 2. Concentric expanding sonar wave rings
    for (var i = 0; i < waveCount; i++) {
      final waveProgress = (animationValue + (i / waveCount)) % 1.0;
      final currentRadius = maxRadius * waveProgress;
      final opacity = (1.0 - waveProgress).clamp(0.0, 1.0) * 0.45;

      final wavePaint = Paint()
        ..color = baseColor.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 * (1.0 - waveProgress * 0.5);

      canvas.drawCircle(center, currentRadius, wavePaint);
    }

    // 3. Rotating Sweep beam
    final sweepAngle = animationValue * 2 * pi;
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        center: FractionalOffset.center,
        startAngle: 0.0,
        endAngle: pi / 2,
        colors: [
          baseColor.withValues(alpha: 0.0),
          baseColor.withValues(alpha: 0.22),
        ],
        transform: GradientRotation(sweepAngle - pi / 2),
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, maxRadius, sweepPaint);

    // 4. Center Glowing Hub
    final hubGlow = Paint()
      ..color = baseColor.withValues(alpha: 0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(center, 8, hubGlow);

    final hubCore = Paint()
      ..color = baseColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 4, hubCore);
  }

  @override
  bool shouldRepaint(covariant RadarPulsePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.baseColor != baseColor;
  }
}

