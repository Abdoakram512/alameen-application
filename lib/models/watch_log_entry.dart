import 'package:equatable/equatable.dart';
import 'package:alameen_core/alameen_core.dart';

// Re-export WatchLogEntry from shared package
export 'package:alameen_core/alameen_core.dart' show WatchLogEntry;

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
