import 'package:flutter_test/flutter_test.dart';
import 'package:secure_screen_app/models/lesson.dart';
import 'package:secure_screen_app/models/watch_log_entry.dart';

void main() {
  group('Regression Suite 6: Laravel Watch Analytics & Duration Consistency', () {
    test('StudentAnalyticsCalculator aggregates watch minutes by course accurately', () {
      final now = DateTime.now();
      final logs = [
        WatchLogEntry(
          id: 'l1',
          studentId: '15',
          courseId: '2',
          lessonId: '43',
          durationSeconds: 1800,
          recordedAt: now,
        ),
        WatchLogEntry(
          id: 'l2',
          studentId: '15',
          courseId: '2',
          lessonId: '45',
          durationSeconds: 1200,
          recordedAt: now,
        ),
        WatchLogEntry(
          id: 'l3',
          studentId: '15',
          courseId: '3',
          lessonId: '44',
          durationSeconds: 600,
          recordedAt: now.subtract(const Duration(days: 1)),
        ),
      ];

      final byCourse = StudentAnalyticsCalculator.watchMinutesByCourse(logs);
      expect(byCourse['2'], 50); // (1800 + 1200) / 60
      expect(byCourse['3'], 10); // 600 / 60

      final buckets = StudentAnalyticsCalculator.buildLast7DaysBuckets(logs);
      expect(buckets.length, 7);
      expect(StudentAnalyticsCalculator.countActiveDaysInLastWeek(logs), 2);
    });

    test('Lesson.fromLaravelVideoJson preserves exact durationSeconds for 95% calculations', () {
      final lesson = Lesson.fromLaravelVideoJson({
        'id': 43,
        'slug': 'lesson-7i8eif',
        'title': 'محاضرة تقييم اعضاء النطق',
        'video_source': 'mux',
        'duration_seconds': 1639,
        'duration_minutes': 27,
        'min_completion_percentage': 90,
        'is_accessible': true,
        'is_completed': false,
      });

      expect(lesson.durationInSeconds, 1639);
      expect(lesson.effectiveCompletionThresholdPercentage, 95);
      // Should never invent a fake muxPlaybackId from slug!
      expect(lesson.muxPlaybackId, isEmpty);
      expect(lesson.videoStreamUrl, isEmpty);
      expect(lesson.hasVideo, isTrue);
    });
  });
}
