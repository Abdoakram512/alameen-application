import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../models/watch_log_entry.dart';

/// مخطط اتجاه مساحي وأعمدة مدمج (Hybrid Cubic Bezier Area + Pill Columns) لنشاط المنصة الأسبوعي.
class AdminTrendAreaPainter extends CustomPainter {
  final List<double> values;
  final int highlightedIndex;
  final double animationValue;
  final Color primaryColor;
  final Color accentColor;

  const AdminTrendAreaPainter({
    required this.values,
    required this.highlightedIndex,
    this.animationValue = 1.0,
    this.primaryColor = AppColors.primary,
    this.accentColor = const Color(0xFF2563EB),
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty || size.width <= 0 || size.height <= 0) return;

    final anim = animationValue.clamp(0.0, 1.0);
    const topPad = 14.0;
    const bottomPad = 8.0;
    final chartHeight = math.max(20.0, size.height - topPad - bottomPad);
    final rawMax = values.fold<double>(0.0, math.max);
    final maxVal = rawMax <= 0 ? 60.0 : rawMax * 1.18;

    final gridPaint = Paint()
      ..color = AppColors.borderHairline
      ..strokeWidth = 1.0;

    for (final r in const [0.0, 0.5, 1.0]) {
      final y = topPad + chartHeight * (1 - r);
      _drawDashed(canvas, y, size.width, gridPaint);
    }

    final n = values.length;
    final slotW = size.width / n;
    final barW = math.min(22.0, slotW * 0.4);
    final points = <Offset>[];

    for (var i = 0; i < n; i++) {
      final v = values[i];
      final norm = (v / maxVal).clamp(0.0, 1.0) * anim;
      final barH = v > 0 ? math.max(6.0, chartHeight * norm) : 4.0;
      final cx = slotW * i + slotW / 2;
      final bottomY = topPad + chartHeight;
      final topY = bottomY - barH;
      points.add(Offset(cx, v > 0 ? topY : (bottomY - 3)));

      final isToday = i == highlightedIndex;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - barW / 2, topY, barW, barH),
          const Radius.circular(999),
        ),
        Paint()
          ..color = v <= 0
              ? AppColors.surfaceLevel2
              : (isToday ? primaryColor : accentColor.withValues(alpha: 0.2)),
      );
    }

    if (rawMax > 0 && points.length >= 2) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (var i = 0; i < points.length - 1; i++) {
        final p0 = points[i];
        final p1 = points[i + 1];
        final midX = (p0.dx + p1.dx) / 2;
        path.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
      }

      final fillPath = Path.from(path)
        ..lineTo(points.last.dx, topPad + chartHeight)
        ..lineTo(points.first.dx, topPad + chartHeight)
        ..close();

      canvas.drawPath(
        fillPath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              accentColor.withValues(alpha: 0.16 * anim),
              accentColor.withValues(alpha: 0.0),
            ],
          ).createShader(Rect.fromLTWH(0, topPad, size.width, chartHeight)),
      );

      canvas.drawPath(
        path,
        Paint()
          ..color = primaryColor.withValues(alpha: 0.9 * anim)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.3
          ..strokeCap = StrokeCap.round,
      );

      for (var i = 0; i < points.length; i++) {
        if (values[i] <= 0) continue;
        canvas.drawCircle(points[i], 4.4, Paint()..color = Colors.white);
        canvas.drawCircle(
          points[i],
          2.9,
          Paint()..color = i == highlightedIndex ? primaryColor : accentColor,
        );
      }
    }
  }

  void _drawDashed(Canvas canvas, double y, double width, Paint paint) {
    var x = 0.0;
    while (x < width) {
      canvas.drawLine(Offset(x, y), Offset(math.min(x + 4, width), y), paint);
      x += 8;
    }
  }

  @override
  bool shouldRepaint(covariant AdminTrendAreaPainter oldDelegate) {
    if (oldDelegate.animationValue != animationValue ||
        oldDelegate.highlightedIndex != highlightedIndex ||
        oldDelegate.values.length != values.length) {
      return true;
    }
    for (var i = 0; i < values.length; i++) {
      if (oldDelegate.values[i] != values[i]) return true;
    }
    return false;
  }
}

/// مخطط حلقي متعدد القطاعات (Multi-Segment Donut Chart) لتوزيع الاشتراكات حسب الدورة.
class DistributionDonutPainter extends CustomPainter {
  final List<DonutSegmentData> segments;
  final double animationValue;

  const DistributionDonutPainter({
    required this.segments,
    this.animationValue = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 10;
    const strokeWidth = 16.0;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawArc(
      rect,
      0,
      2 * math.pi,
      false,
      Paint()
        ..color = AppColors.surfaceLevel2
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    final total = segments.fold<double>(0.0, (s, item) => s + item.value);
    if (total <= 0 || segments.isEmpty) return;

    final anim = animationValue.clamp(0.0, 1.0);
    final gapRadians = segments.length > 1 ? 0.055 : 0.0;
    var currentStart = -math.pi / 2;
    final usableSweep = (2 * math.pi - gapRadians * segments.length) * anim;

    for (final seg in segments) {
      final sweep = usableSweep * (seg.value / total);
      if (sweep <= 0.005) continue;

      final paint = Paint()
        ..color = Color(seg.colorHex)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = segments.length == 1 ? StrokeCap.round : StrokeCap.butt;

      canvas.drawArc(rect, currentStart, sweep, false, paint);
      currentStart += sweep + gapRadians;
    }
  }

  @override
  bool shouldRepaint(covariant DistributionDonutPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.segments != segments;
  }
}

/// مؤشر إتقان دائري مخصص لملف المتدرب الفردي في تطبيق الإدارة.
class StudentMasteryRingPainter extends CustomPainter {
  final double progress;
  final Color primaryColor;

  const StudentMasteryRingPainter({
    required this.progress,
    this.primaryColor = AppColors.primary,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final clamped = progress.clamp(0.0, 1.0);
    final center = Offset(size.width / 2, size.height / 2);
    final outer = math.min(size.width, size.height) / 2;
    final radius = outer - 11;
    const stroke = 10.5;
    const startAngle = -math.pi / 2;

    const ticks = 32;
    final litTicks = (clamped * ticks).round();
    for (var i = 0; i < ticks; i++) {
      final a = startAngle + (i / ticks) * 2 * math.pi;
      final inner = outer - (i % 8 == 0 ? 5.0 : 3.0);
      canvas.drawLine(
        Offset(center.dx + inner * math.cos(a), center.dy + inner * math.sin(a)),
        Offset(outer * math.cos(a) + center.dx, outer * math.sin(a) + center.dy),
        Paint()
          ..color = i < litTicks
              ? primaryColor.withValues(alpha: 0.55)
              : AppColors.borderHairline
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round,
      );
    }

    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(
      rect,
      0,
      2 * math.pi,
      false,
      Paint()
        ..color = AppColors.surfaceLevel2
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );

    if (clamped <= 0.002) return;

    final sweep = 2 * math.pi * clamped;
    canvas.drawArc(
      rect,
      startAngle,
      sweep,
      false,
      Paint()
        ..shader = SweepGradient(
          transform: const GradientRotation(startAngle - 0.08),
          colors: [
            primaryColor,
            const Color(0xFF2563EB),
            clamped >= 0.75 ? AppColors.successMint : const Color(0xFF1D4ED8),
          ],
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant StudentMasteryRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.primaryColor != primaryColor;
  }
}

