import 'package:equatable/equatable.dart';
import 'package:alameen_core/alameen_core.dart';
import 'registered_student.dart';

// Re-export WatchLogEntry from shared package
export 'package:alameen_core/alameen_core.dart' show WatchLogEntry;

class DailyMetricPoint extends Equatable {
  final DateTime date;
  final String shortLabel;
  final double value;
  final bool isToday;

  const DailyMetricPoint({
    required this.date,
    required this.shortLabel,
    required this.value,
    required this.isToday,
  });

  @override
  List<Object?> get props => [date, shortLabel, value, isToday];
}

class DonutSegmentData extends Equatable {
  final String label;
  final double value;
  final int colorHex;

  const DonutSegmentData({
    required this.label,
    required this.value,
    required this.colorHex,
  });

  @override
  List<Object?> get props => [label, value, colorHex];
}

/// حاسبة تحليلية للإدارة لاستخراج المؤشرات العامة ومؤشرات كل متدرب بدقة.
class AdminAnalyticsCalculator {
  const AdminAnalyticsCalculator._();

  static const Map<int, String> _arabicShortWeekdays = {
    DateTime.monday: 'اثنين',
    DateTime.tuesday: 'ثلاثاء',
    DateTime.wednesday: 'أربعاء',
    DateTime.thursday: 'خميس',
    DateTime.friday: 'جمعة',
    DateTime.saturday: 'سبت',
    DateTime.sunday: 'أحد',
  };

  /// دقائق المشاهدة اليومية خلال آخر 7 أيام (عامة أو لطالب محدد).
  static List<DailyMetricPoint> build7DayWatchMinutes(
    List<WatchLogEntry> logs, {
    DateTime? referenceDate,
  }) {
    final now = referenceDate ?? DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final secondsPerSlot = List<int>.filled(7, 0);

    for (final log in logs) {
      if (log.durationSeconds <= 0) continue;
      final local = log.recordedAt.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      final diff = todayStart.difference(day).inDays;
      if (diff >= 0 && diff < 7) {
        secondsPerSlot[6 - diff] += log.durationSeconds;
      }
    }

    return List<DailyMetricPoint>.generate(7, (idx) {
      final d = todayStart.subtract(Duration(days: 6 - idx));
      return DailyMetricPoint(
        date: d,
        shortLabel: _arabicShortWeekdays[d.weekday] ?? '',
        value: secondsPerSlot[idx] / 60.0,
        isToday: idx == 6,
      );
    });
  }

  /// تقدير إجمالي القيمة السوقية للاشتراكات المفعّلة (سعر كل دورة × عدد المشتركين الفعليين بها).
  static double calculateActiveEnrollmentsValue({
    required List<Course> courses,
    required List<RegisteredStudent> students,
  }) {
    final coursePrices = {for (final c in courses) c.id: c.price};
    var total = 0.0;
    for (final s in students) {
      for (final cid in s.enrolledCourseIds.toSet()) {
        final price = coursePrices[cid] ?? 0.0;
        if (price > 0) total += price;
      }
    }
    return total;
  }

  /// توزيع المشتركين على أعلى الدورات نشاطاً لرسم مخطط الـ Donut.
  static List<DonutSegmentData> buildCourseEnrollmentDistribution({
    required List<Course> courses,
    required List<RegisteredStudent> students,
  }) {
    const palette = <int>[
      0xFF012383,
      0xFF2563EB,
      0xFF10B981,
      0xFFF59E0B,
      0xFF6366F1,
    ];

    final counts = <String, int>{};
    for (final student in students) {
      for (final cid in student.enrolledCourseIds.toSet()) {
        counts[cid] = (counts[cid] ?? 0) + 1;
      }
    }

    final sortedCourses = List<Course>.from(courses)
      ..sort(
        (a, b) => (counts[b.id] ?? b.enrolledCount).compareTo(
          counts[a.id] ?? a.enrolledCount,
        ),
      );

    final top = sortedCourses.take(4).toList();
    final segments = <DonutSegmentData>[];
    for (var i = 0; i < top.length; i++) {
      final c = top[i];
      final val = (counts[c.id] ?? c.enrolledCount).toDouble();
      if (val > 0) {
        segments.add(
          DonutSegmentData(
            label: c.title,
            value: val,
            colorHex: palette[i % palette.length],
          ),
        );
      }
    }

    if (sortedCourses.length > 4) {
      var othersSum = 0.0;
      for (final c in sortedCourses.skip(4)) {
        othersSum += (counts[c.id] ?? c.enrolledCount).toDouble();
      }
      if (othersSum > 0) {
        segments.add(
          DonutSegmentData(
            label: 'دورات أخرى',
            value: othersSum,
            colorHex: palette[4],
          ),
        );
      }
    }

    return segments;
  }

  /// توزيع وسائل السداد من طلبات الالتحاق الفعلية.
  static Map<String, int> countPaymentMethods(
    List<CourseAccessRequest> requests,
  ) {
    final result = <String, int>{};
    for (final r in requests) {
      final key = r.paymentMethod.trim().isNotEmpty
          ? r.paymentMethod.trim()
          : 'أخرى';
      result[key] = (result[key] ?? 0) + 1;
    }
    return result;
  }
}
