import 'package:equatable/equatable.dart';
import '../core/converters/firestore_date_time_converter.dart';
import 'access_request.dart';
import 'course.dart';
import 'registered_student.dart';

/// سجل جلسة مشاهدة فعلية للمتدرب من مجموعة `/watch_logs`.
class WatchLogEntry extends Equatable {
  final String id;
  final String studentId;
  final String studentName;
  final String studentEmail;
  final String courseId;
  final String lessonId;
  final String lessonTitle;
  final int durationSeconds;
  final int maxPlayheadSeconds;
  final int totalDurationSeconds;
  final double completionPercentage;
  final bool isCompleted;
  final String ipAddress;
  final String networkType;
  final String devicePlatform;
  final DateTime recordedAt;

  const WatchLogEntry({
    required this.id,
    required this.studentId,
    this.studentName = '',
    this.studentEmail = '',
    required this.courseId,
    required this.lessonId,
    this.lessonTitle = '',
    required this.durationSeconds,
    this.maxPlayheadSeconds = 0,
    this.totalDurationSeconds = 0,
    this.completionPercentage = 0.0,
    this.isCompleted = false,
    this.ipAddress = 'غير محدد',
    this.networkType = 'غير محدد',
    this.devicePlatform = 'جهاز ذكي',
    required this.recordedAt,
  });

  double get durationMinutes => durationSeconds / 60.0;

  String get durationFormatted {
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  WatchLogEntry copyWith({
    String? id,
    String? studentId,
    String? studentName,
    String? studentEmail,
    String? courseId,
    String? lessonId,
    String? lessonTitle,
    int? durationSeconds,
    int? maxPlayheadSeconds,
    int? totalDurationSeconds,
    double? completionPercentage,
    bool? isCompleted,
    String? ipAddress,
    String? networkType,
    String? devicePlatform,
    DateTime? recordedAt,
  }) {
    return WatchLogEntry(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      studentEmail: studentEmail ?? this.studentEmail,
      courseId: courseId ?? this.courseId,
      lessonId: lessonId ?? this.lessonId,
      lessonTitle: lessonTitle ?? this.lessonTitle,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      maxPlayheadSeconds: maxPlayheadSeconds ?? this.maxPlayheadSeconds,
      totalDurationSeconds: totalDurationSeconds ?? this.totalDurationSeconds,
      completionPercentage: completionPercentage ?? this.completionPercentage,
      isCompleted: isCompleted ?? this.isCompleted,
      ipAddress: ipAddress ?? this.ipAddress,
      networkType: networkType ?? this.networkType,
      devicePlatform: devicePlatform ?? this.devicePlatform,
      recordedAt: recordedAt ?? this.recordedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'studentId': studentId,
      'studentName': studentName,
      'studentEmail': studentEmail,
      'courseId': courseId,
      'lessonId': lessonId,
      'lessonTitle': lessonTitle,
      'durationSeconds': durationSeconds,
      'maxPlayheadSeconds': maxPlayheadSeconds,
      'totalDurationSeconds': totalDurationSeconds,
      'completionPercentage': completionPercentage,
      'isCompleted': isCompleted,
      'ipAddress': ipAddress,
      'networkType': networkType,
      'devicePlatform': devicePlatform,
      'recordedAt': recordedAt.toIso8601String(),
    };
  }

  factory WatchLogEntry.fromMap(Map<String, dynamic> map, {String? id}) {
    final durSec = int.tryParse(
            '${map['durationSeconds'] ?? map['secondsWatched'] ?? map['seconds'] ?? 0}') ??
        0;
    final totDur = int.tryParse('${map['totalDurationSeconds'] ?? 0}') ?? 0;
    final maxHead = int.tryParse('${map['maxPlayheadSeconds'] ?? 0}') ?? durSec;

    double completion = 0.0;
    if (map['completionPercentage'] != null) {
      completion = (map['completionPercentage'] as num).toDouble();
    } else if (totDur > 0) {
      completion = ((maxHead / totDur) * 100).clamp(0.0, 100.0);
    }

    final completed = (map['isCompleted'] as bool?) ?? (completion >= 80.0);

    return WatchLogEntry(
      id: id ?? (map['id'] as String? ?? ''),
      studentId: map['studentId'] as String? ?? '',
      studentName: map['studentName'] as String? ?? '',
      studentEmail: map['studentEmail'] as String? ?? '',
      courseId: map['courseId'] as String? ?? '',
      lessonId: map['lessonId'] as String? ?? '',
      lessonTitle: map['lessonTitle'] as String? ?? '',
      durationSeconds: durSec,
      maxPlayheadSeconds: maxHead,
      totalDurationSeconds: totDur,
      completionPercentage: completion,
      isCompleted: completed,
      ipAddress: map['ipAddress'] as String? ?? 'غير محدد',
      networkType: map['networkType'] as String? ?? 'غير محدد',
      devicePlatform: map['devicePlatform'] as String? ?? 'جهاز ذكي',
      recordedAt: FirestoreDateTimeConverter.fromValue(map['recordedAt']) ??
          DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        studentId,
        studentName,
        studentEmail,
        courseId,
        lessonId,
        lessonTitle,
        durationSeconds,
        maxPlayheadSeconds,
        totalDurationSeconds,
        completionPercentage,
        isCompleted,
        ipAddress,
        networkType,
        devicePlatform,
        recordedAt,
      ];
}

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
