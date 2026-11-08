import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_screen_app/models/watch_log_entry.dart';
import 'package:secure_screen_app/screens/student/profile/widgets/student_analytics_painters.dart';

void main() {
  group('Student Analytics Calculator & CustomPainters Tests', () {
    test('buildLast7DaysBuckets aggregates watch minutes per day accurately', () {
      final refDate = DateTime(2026, 11, 7, 15, 0);
      final logs = [
        WatchLogEntry(
          id: 'l1',
          studentId: 's1',
          courseId: 'c1',
          lessonId: 'les1',
          durationSeconds: 1800, // 30 mins today
          recordedAt: DateTime(2026, 11, 7, 10, 0),
        ),
        WatchLogEntry(
          id: 'l2',
          studentId: 's1',
          courseId: 'c1',
          lessonId: 'les2',
          durationSeconds: 900, // +15 mins today = 45 mins
          recordedAt: DateTime(2026, 11, 7, 12, 0),
        ),
        WatchLogEntry(
          id: 'l3',
          studentId: 's1',
          courseId: 'c2',
          lessonId: 'les3',
          durationSeconds: 1200, // 20 mins 2 days ago
          recordedAt: DateTime(2026, 11, 5, 9, 0),
        ),
      ];

      final buckets = StudentAnalyticsCalculator.buildLast7DaysBuckets(
        logs,
        referenceDate: refDate,
      );

      expect(buckets.length, equals(7));
      expect(buckets.last.isToday, isTrue);
      expect(buckets.last.minutes, closeTo(45.0, 0.01));
      expect(buckets[4].minutes, closeTo(20.0, 0.01));

      final activeDays = StudentAnalyticsCalculator.countActiveDaysInLastWeek(
        logs,
        referenceDate: refDate,
      );
      expect(activeDays, equals(2));

      final byCourse = StudentAnalyticsCalculator.watchMinutesByCourse(logs);
      expect(byCourse['c1'], equals(45));
      expect(byCourse['c2'], equals(20));
    });

    testWidgets(
      'LearningRadialGaugePainter and WeeklyActivityChartPainter paint cleanly',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  SizedBox(
                    width: 130,
                    height: 130,
                    child: CustomPaint(
                      painter: LearningRadialGaugePainter(progress: 0.78),
                    ),
                  ),
                  SizedBox(
                    width: 300,
                    height: 120,
                    child: CustomPaint(
                      painter: WeeklyActivityChartPainter(
                        values: [0, 15, 30, 10, 45, 20, 60],
                        highlightedIndex: 6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.byType(CustomPaint), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );
  });
}

