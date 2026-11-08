import 'package:flutter/material.dart';

/// رسام هندسي ناعم لرسم نقوش هندسية ملكية خفيفة على الخلفيات والبطاقات
/// يضفي طابع الأصالة والفخامة لهوية "الأمين سنتر".
class GeometricBackgroundPainter extends CustomPainter {
  final Color strokeColor;
  final double strokeWidth;
  final double spacing;

  const GeometricBackgroundPainter({
    this.strokeColor = const Color(0x0FFFFFFF), // خفيف جداً
    this.strokeWidth = 1.0,
    this.spacing = 32.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..isAntiAlias = true;

    // رسم أقواس متحدة المركز في الزاوية العلوية اليسرى
    for (double r = 20; r < size.width + size.height; r += spacing * 1.5) {
      canvas.drawCircle(Offset(size.width, 0), r, paint);
    }

    // رسم أقواس متداخلة معاكسة في الزاوية السفلية اليمنى
    for (double r = 30; r < size.width * 0.7; r += spacing * 2) {
      canvas.drawCircle(Offset(0, size.height), r, paint);
    }

    // رسم نمط ماسي خفيف متكرر
    final diamondPaint = Paint()
      ..color = strokeColor.withValues(alpha: strokeColor.a * 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    for (double x = 0; x < size.width; x += spacing * 2) {
      for (double y = 0; y < size.height; y += spacing * 2) {
        final path = Path();
        path.moveTo(x, y - 8);
        path.lineTo(x + 8, y);
        path.lineTo(x, y + 8);
        path.lineTo(x - 8, y);
        path.close();
        canvas.drawPath(path, diamondPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant GeometricBackgroundPainter oldDelegate) =>
      oldDelegate.strokeColor != strokeColor ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.spacing != spacing;
}
