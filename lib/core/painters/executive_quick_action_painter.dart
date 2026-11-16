import 'package:flutter/material.dart';

/// كاستم بينتر تنفيذي لبطاقات العمليات السريعة (Executive Quick Action Cards)
/// يرسم شبكة هندسية دقيقة (Isometric Micro-Grid) وشعاع ضوئي زجاجي عاكس (Prism Highlight).
class ExecutiveQuickActionPainter extends CustomPainter {
  final Color baseColor;
  final bool isPressed;

  const ExecutiveQuickActionPainter({
    required this.baseColor,
    this.isPressed = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(16));

    // Clip to card rounded boundaries
    canvas.save();
    canvas.clipRRect(rrect);

    // 1. Subtle Radial Ambient Glow from Top-Right (or Top-Left in RTL)
    final glowPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.7, -0.8),
        radius: 1.1,
        colors: [
          baseColor.withValues(alpha: isPressed ? 0.16 : 0.09),
          baseColor.withValues(alpha: 0.02),
          Colors.transparent,
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, glowPaint);

    // 2. Micro Isometric Grid Pattern (4% opacity)
    final gridPaint = Paint()
      ..color = baseColor.withValues(alpha: 0.045)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    const double step = 16.0;
    for (double x = -size.height; x < size.width + size.height; x += step) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height * 0.7, size.height),
        gridPaint,
      );
    }

    // 3. Diagonal Light Ray (Prism Sheen)
    final sheenPath = Path()
      ..moveTo(size.width * 0.45, 0)
      ..lineTo(size.width * 0.85, 0)
      ..lineTo(size.width * 0.40, size.height)
      ..lineTo(0, size.height)
      ..close();

    final sheenPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.12),
          Colors.white.withValues(alpha: 0.02),
          Colors.transparent,
        ],
      ).createShader(rect);
    canvas.drawPath(sheenPath, sheenPaint);

    // 4. Subtle Top Edge Highlight (Acrylic Glass Rim)
    final topRimPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          baseColor.withValues(alpha: 0.4),
          baseColor.withValues(alpha: 0.05),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, 2))
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      const Offset(16, 1),
      Offset(size.width - 16, 1),
      topRimPaint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ExecutiveQuickActionPainter oldDelegate) {
    return oldDelegate.baseColor != baseColor || oldDelegate.isPressed != isPressed;
  }
}

