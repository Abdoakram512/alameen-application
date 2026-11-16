import 'dart:math' as math;
import 'package:flutter/material.dart';

/// رسام أمواج صوتية وهندسة تأهيلية ناعمة لخلفيات وبطاقات تطبيق مركز الأمين للتخاطب
/// يعكس هوية المركز الطبية والتأهيلية عبر تمثيل أمواج الصوت، الترددات الكلامية المتناغمة،
/// ومنحنيات الرنين الصوتي الهادئة بأعلى درجات الفخامة البصرية لعام 2026.
class GeometricBackgroundPainter extends CustomPainter {
  final Color strokeColor;
  final double strokeWidth;
  final double spacing;

  const GeometricBackgroundPainter({
    this.strokeColor = const Color(0x0FFFFFFF), // خفيف وناعم جداً
    this.strokeWidth = 1.0,
    this.spacing = 32.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final wavePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..isAntiAlias = true
      ..strokeCap = StrokeCap.round;

    final secondaryPaint = Paint()
      ..color = strokeColor.withValues(alpha: strokeColor.a * 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 0.8
      ..isAntiAlias = true;

    // 1. أمواج صوتية وتخاطب انسيابية (Speech & Acoustic Harmonic Waves)
    final waveCount = (size.height / (spacing * 1.8)).clamp(2, 5).toInt();
    for (int i = 0; i < waveCount; i++) {
      final baseY = (size.height * 0.25) + (i * spacing * 1.4);
      final path = Path();
      path.moveTo(0, baseY);

      final frequency = (i + 1) * 0.7;
      final amplitude = 8.0 + (i * 3.5);

      for (double x = 0; x <= size.width; x += 12) {
        final normalizedX = x / size.width;
        final yOffset = math.sin((normalizedX * math.pi * 2 * frequency) + (i * 0.8)) * amplitude;
        path.lineTo(x, baseY + yOffset);
      }

      canvas.drawPath(path, (i % 2 == 0) ? wavePaint : secondaryPaint);
    }

    // 2. بؤرة الرنين الصوتي والتأهيلي (Acoustic Resonance Waves) من الزاوية العلوية
    final origin = Offset(size.width * 0.88, size.height * 0.12);
    final maxRadius = math.min(size.width, size.height) * 0.75;

    for (double r = spacing * 0.8; r < maxRadius; r += spacing * 1.2) {
      final arcRect = Rect.fromCircle(center: origin, radius: r);
      canvas.drawArc(
        arcRect,
        math.pi * 0.5,
        math.pi * 1.1,
        false,
        secondaryPaint,
      );
    }

    // 3. بؤرة انبعاث صوتية معاكسة سفلية ناعمة
    final bottomOrigin = Offset(size.width * 0.1, size.height * 0.9);
    for (double r = spacing; r < size.width * 0.5; r += spacing * 1.5) {
      final arcRect = Rect.fromCircle(center: bottomOrigin, radius: r);
      canvas.drawArc(
        arcRect,
        math.pi * 1.5,
        math.pi * 0.9,
        false,
        secondaryPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant GeometricBackgroundPainter oldDelegate) =>
      oldDelegate.strokeColor != strokeColor ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.spacing != spacing;
}
