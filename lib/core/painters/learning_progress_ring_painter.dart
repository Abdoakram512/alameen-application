import 'dart:math' as math;
import 'package:flutter/material.dart';

class LearningProgressRingPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0
  final Color trackColor;
  final List<Color> gradientColors;
  final double strokeWidth;

  LearningProgressRingPainter({
    required this.progress,
    this.trackColor = const Color(0xFFE2E8F0),
    this.gradientColors = const [Color(0xFF012383), Color(0xFF0EA5E9), Color(0xFF10B981)],
    this.strokeWidth = 8.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // 1. مسار الخلفية (Track)
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0) return;

    // 2. تدرج قوس التقدم (Gradient Arc)
    final rect = Rect.fromCircle(center: center, radius: radius);
    final sweepGradient = SweepGradient(
      startAngle: -math.pi / 2,
      endAngle: (3 * math.pi) / 2,
      colors: gradientColors,
      transform: const GradientRotation(-math.pi / 2),
    );

    final progressPaint = Paint()
      ..shader = sweepGradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant LearningProgressRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.trackColor != trackColor;
}

class AnimatedLearningProgressRing extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final double size;
  final double strokeWidth;
  final Widget? centerChild;

  const AnimatedLearningProgressRing({
    super.key,
    required this.progress,
    this.size = 72,
    this.strokeWidth = 7,
    this.centerChild,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: progress),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(size, size),
                painter: LearningProgressRingPainter(
                  progress: value,
                  strokeWidth: strokeWidth,
                ),
              ),
              if (centerChild != null)
                centerChild!
              else
                Text(
                  '${(value * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: size * 0.22,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF012383),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

