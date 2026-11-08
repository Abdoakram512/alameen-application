import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// مؤشر دائري مخصص (Radial Mastery Gauge) مستوحى من لوحات بيانات Figma & Dribbble الحديثة:
/// - حلقة علامات دقيقة خارجية (36 Micro-Ticks) تضيء تدريجياً مع تقدم المتدرب.
/// - مسار خلفي ناعم + قوس تقدم متدرج بـ StrokeCap.round.
/// - نقطة ارتكاز مضيئة عند طرف القوس.
class LearningRadialGaugePainter extends CustomPainter {
  final double progress;
  final Color primaryColor;
  final Color accentColor;
  final Color trackColor;

  const LearningRadialGaugePainter({
    required this.progress,
    this.primaryColor = AppColors.primary,
    this.accentColor = AppColors.successMint,
    this.trackColor = AppColors.surfaceLevel2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final clamped = progress.clamp(0.0, 1.0);
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = math.min(size.width, size.height) / 2;
    final arcRadius = outerRadius - 12;
    const strokeWidth = 11.0;
    const startAngle = -math.pi / 2;
    const fullSweep = 2 * math.pi;

    // 1. علامات قياس دقيقة خارجية (Outer Precision Ticks)
    const tickCount = 36;
    final activeTickLimit = (clamped * tickCount).round();
    final tickPaintActive = Paint()
      ..color = primaryColor.withValues(alpha: 0.55)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final tickPaintMuted = Paint()
      ..color = AppColors.borderHairline
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < tickCount; i++) {
      final angle = startAngle + (i / tickCount) * fullSweep;
      final isMajor = i % 9 == 0;
      final innerTick = outerRadius - (isMajor ? 5.5 : 3.5);
      final p1 = Offset(
        center.dx + innerTick * math.cos(angle),
        center.dy + innerTick * math.sin(angle),
      );
      final p2 = Offset(
        center.dx + outerRadius * math.cos(angle),
        center.dy + outerRadius * math.sin(angle),
      );
      canvas.drawLine(
        p1,
        p2,
        i < activeTickLimit ? tickPaintActive : tickPaintMuted,
      );
    }

    // 2. مسار القوس الخلفي (Track Ring)
    final arcRect = Rect.fromCircle(center: center, radius: arcRadius);
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawArc(arcRect, 0, fullSweep, false, trackPaint);

    if (clamped <= 0.002) return;

    // 3. قوس الإنجاز المتدرج (Active Gradient Arc)
    final sweepAngle = fullSweep * clamped;
    final gradient = SweepGradient(
      startAngle: 0,
      endAngle: fullSweep,
      transform: const GradientRotation(startAngle - 0.08),
      colors: [
        primaryColor,
        const Color(0xFF1D4ED8),
        clamped >= 0.75 ? accentColor : const Color(0xFF2563EB),
      ],
      stops: const [0.0, 0.65, 1.0],
    );

    final progressPaint = Paint()
      ..shader = gradient.createShader(arcRect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(arcRect, startAngle, sweepAngle, false, progressPaint);

    // 4. نقطة النهاية الدقيقة (Precision Tip Dot)
    final endAngle = startAngle + sweepAngle;
    final tipOffset = Offset(
      center.dx + arcRadius * math.cos(endAngle),
      center.dy + arcRadius * math.sin(endAngle),
    );
    canvas.drawCircle(
      tipOffset,
      6.5,
      Paint()..color = primaryColor.withValues(alpha: 0.16),
    );
    canvas.drawCircle(tipOffset, 3.2, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant LearningRadialGaugePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.accentColor != accentColor;
  }
}

/// مخطط بياني هجين (أعمدة مستديرة + منحنى Bezier انسيابي + شبكة خلفية) لنشاط 7 أيام.
class WeeklyActivityChartPainter extends CustomPainter {
  final List<double> values;
  final int highlightedIndex;
  final double animationValue;
  final Color primaryColor;
  final Color secondaryColor;

  const WeeklyActivityChartPainter({
    required this.values,
    required this.highlightedIndex,
    this.animationValue = 1.0,
    this.primaryColor = AppColors.primary,
    this.secondaryColor = const Color(0xFF3B82F6),
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty || size.width <= 0 || size.height <= 0) return;

    final anim = animationValue.clamp(0.0, 1.0);
    const topPad = 12.0;
    const bottomPad = 8.0;
    final chartHeight = math.max(16.0, size.height - topPad - bottomPad);
    final rawMax = values.fold<double>(0.0, math.max);
    final effectiveMax = rawMax <= 0 ? 30.0 : rawMax * 1.18;

    // 1. خطوط شبكة أفقية رفيعة متقطعة (Hairline Dashed Grid)
    final gridPaint = Paint()
      ..color = AppColors.borderHairline.withValues(alpha: 0.85)
      ..strokeWidth = 1.0;

    for (final ratio in const [0.0, 0.5, 1.0]) {
      final y = topPad + chartHeight * (1 - ratio);
      _drawDashedHorizontalLine(canvas, y, size.width, gridPaint);
    }

    final count = values.length;
    final slotWidth = size.width / count;
    final barWidth = math.min(20.0, slotWidth * 0.42);
    final points = <Offset>[];

    // 2. الأعمدة اليومية المستديرة (Rounded Pill Columns)
    for (var i = 0; i < count; i++) {
      final val = values[i];
      final normalized = (val / effectiveMax).clamp(0.0, 1.0) * anim;
      final barHeight = val > 0
          ? math.max(6.0, chartHeight * normalized)
          : 4.0;
      final centerX = slotWidth * i + slotWidth / 2;
      final bottomY = topPad + chartHeight;
      final topY = bottomY - barHeight;

      points.add(
        Offset(
          centerX,
          val > 0 ? topY : (bottomY - 3.0),
        ),
      );

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(centerX - barWidth / 2, topY, barWidth, barHeight),
        const Radius.circular(999),
      );

      final isToday = i == highlightedIndex;
      final barPaint = Paint()
        ..color = val <= 0
            ? AppColors.surfaceLevel2
            : (isToday
                ? primaryColor
                : secondaryColor.withValues(alpha: 0.22));
      canvas.drawRRect(rect, barPaint);
    }

    // 3. منحنى الاتجاه الانسيابي (Smooth Cubic Bezier Trend Line) عند وجود بيانات
    if (rawMax > 0 && points.length >= 2) {
      final linePath = Path()..moveTo(points.first.dx, points.first.dy);
      for (var i = 0; i < points.length - 1; i++) {
        final p0 = points[i];
        final p1 = points[i + 1];
        final controlX = (p0.dx + p1.dx) / 2;
        linePath.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
      }

      final areaPath = Path.from(linePath)
        ..lineTo(points.last.dx, topPad + chartHeight)
        ..lineTo(points.first.dx, topPad + chartHeight)
        ..close();

      final areaPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            secondaryColor.withValues(alpha: 0.14 * anim),
            secondaryColor.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, topPad, size.width, chartHeight));
      canvas.drawPath(areaPath, areaPaint);

      final strokePaint = Paint()
        ..color = primaryColor.withValues(alpha: 0.85 * anim)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(linePath, strokePaint);

      for (var i = 0; i < points.length; i++) {
        if (values[i] <= 0) continue;
        final pt = points[i];
        canvas.drawCircle(pt, 4.2, Paint()..color = Colors.white);
        canvas.drawCircle(
          pt,
          2.8,
          Paint()
            ..color = i == highlightedIndex ? primaryColor : secondaryColor,
        );
      }
    }
  }

  void _drawDashedHorizontalLine(
    Canvas canvas,
    double y,
    double width,
    Paint paint,
  ) {
    const dashWidth = 4.0;
    const dashSpace = 4.0;
    var startX = 0.0;
    while (startX < width) {
      canvas.drawLine(
        Offset(startX, y),
        Offset(math.min(startX + dashWidth, width), y),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant WeeklyActivityChartPainter oldDelegate) {
    if (oldDelegate.animationValue != animationValue ||
        oldDelegate.highlightedIndex != highlightedIndex) {
      return true;
    }
    if (oldDelegate.values.length != values.length) return true;
    for (var i = 0; i < values.length; i++) {
      if (oldDelegate.values[i] != values[i]) return true;
    }
    return false;
  }
}

