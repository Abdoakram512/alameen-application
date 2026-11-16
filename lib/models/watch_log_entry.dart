import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

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

  factory WatchLogEntry.fromMap(Map<String, dynamic> map, {String? id}) {
    DateTime parseDate(dynamic raw) {
      if (raw is Timestamp) return raw.toDate();
      if (raw is DateTime) return raw;
      if (raw is String) {
        return DateTime.tryParse(raw) ?? DateTime.now();
      }
      return DateTime.now();
    }

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
      recordedAt: parseDate(map['recordedAt']),
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
      'recordedAt': Timestamp.fromDate(recordedAt),
    };
  }

  @override
  List<Object?> get props => [
        id,
        studentId,
        courseId,
        lessonId,
        durationSeconds,
        maxPlayheadSeconds,
        totalDurationSeconds,
        ipAddress,
        recordedAt,
      ];
}

/// حاسبة تحليلية نقية لاستخراج مؤشرات نشاط المتدرب الأسبوعية واليومية بدقة.
class StudentAnalyticsCalculator {
  const StudentAnalyticsCalculator._();

  static const Map<int, String> _arabicShortWeekdays = {
    DateTime.monday: 'اثنين',
    DateTime.tuesday: 'ثلاثاء',
    DateTime.wednesday: 'أربعاء',
    DateTime.thursday: 'خميس',
    DateTime.friday: 'جمعة',
    DateTime.saturday: 'سبت',
    DateTime.sunday: 'أحد',
  };

  /// يعيد دقائق التعلم لكل يوم من آخر 7 أيام (من الأقدم للأحدث - اليوم الأخير هو اليوم الحالي).
  static List<DailyStudyBucket> buildLast7DaysBuckets(
    List<WatchLogEntry> logs, {
    DateTime? referenceDate,
  }) {
    final now = referenceDate ?? DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    final secondsByDayOffset = List<int>.filled(7, 0);

    for (final log in logs) {
      if (log.durationSeconds <= 0) continue;
      final local = log.recordedAt.toLocal();
      final logDay = DateTime(local.year, local.month, local.day);
      final diffDays = todayStart.difference(logDay).inDays;
      if (diffDays >= 0 && diffDays < 7) {
        final index = 6 - diffDays;
        secondsByDayOffset[index] += log.durationSeconds;
      }
    }

    return List<DailyStudyBucket>.generate(7, (index) {
      final date = todayStart.subtract(Duration(days: 6 - index));
      final secs = secondsByDayOffset[index];
      final mins = secs == 0 ? 0.0 : (secs / 60.0);
      return DailyStudyBucket(
        date: date,
        shortLabel: _arabicShortWeekdays[date.weekday] ?? '',
        minutes: mins,
        isToday: index == 6,
      );
    });
  }

  /// عدد الأيام النشطة خلال آخر 7 أيام.
  static int countActiveDaysInLastWeek(
    List<WatchLogEntry> logs, {
    DateTime? referenceDate,
  }) {
    final buckets = buildLast7DaysBuckets(logs, referenceDate: referenceDate);
    return buckets.where((b) => b.minutes > 0).length;
  }

  /// توزيع دقائق المشاهدة حسب الدورة التدريبية.
  static Map<String, int> watchMinutesByCourse(List<WatchLogEntry> logs) {
    final secondsMap = <String, int>{};
    for (final log in logs) {
      if (log.courseId.isEmpty || log.durationSeconds <= 0) continue;
      secondsMap[log.courseId] =
          (secondsMap[log.courseId] ?? 0) + log.durationSeconds;
    }
    return secondsMap.map(
      (courseId, secs) => MapEntry(courseId, (secs / 60).ceil()),
    );
  }
}

class DailyStudyBucket extends Equatable {
  final DateTime date;
  final String shortLabel;
  final double minutes;
  final bool isToday;

  const DailyStudyBucket({
    required this.date,
    required this.shortLabel,
    required this.minutes,
    required this.isToday,
  });

  @override
  List<Object?> get props => [date, shortLabel, minutes, isToday];
}
