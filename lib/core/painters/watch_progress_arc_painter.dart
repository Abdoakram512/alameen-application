import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// راسم كانفاس مخصص يعرض نسبة إنجاز مشاهدة الدرس بدقة انسيابية (0% إلى 100%) مع مؤشر متوهج.
class WatchProgressArcPainter extends CustomPainter {
  final double percentage; // 0.0 to 100.0
  final double strokeWidth;
  final bool isCompleted;

  WatchProgressArcPainter({
    required this.percentage,
    this.strokeWidth = 4.5,
    this.isCompleted = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (min(size.width, size.height) - strokeWidth) / 2;

    // 1. Background full circle track
    final trackPaint = Paint()
      ..color = AppColors.borderHairline
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, trackPaint);

    if (percentage <= 0) return;

    // 2. Active arc
    final sweepAngle = (percentage / 100.0).clamp(0.0, 1.0) * 2 * pi;
    final activeColor = isCompleted || percentage >= 80.0
        ? AppColors.successDark
        : AppColors.royalNavy;

    final arcPaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2, // start from top (12 o'clock)
      sweepAngle,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant WatchProgressArcPainter oldDelegate) {
    return oldDelegate.percentage != percentage ||
        oldDelegate.isCompleted != isCompleted ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

