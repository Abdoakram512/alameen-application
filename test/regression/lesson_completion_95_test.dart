import 'package:flutter_test/flutter_test.dart';
import 'package:secure_screen_app/models/lesson_coverage_tracker.dart';

void main() {
  group('Regression Suite 3: 95% Unique Lesson Coverage Requirement', () {
    test('Overlapping playback intervals merge seamlessly into unique coverage', () {
      final tracker = LessonCoverageTracker();
      const totalDuration = 1000;

      // Watch from 0 to 100 seconds
      for (var s = 0; s <= 100; s++) {
        tracker.markSecond(s);
      }
      expect(tracker.uniqueSeconds, 101);

      // Rewatch from 50 to 150 seconds (overlaps 50-100s)
      for (var s = 50; s <= 150; s++) {
        tracker.markSecond(s);
      }
      expect(tracker.uniqueSeconds, 151, reason: 'Unique coverage should be 0-150s = 151 unique seconds, not 101+101=202s');

      // Check coverage percentage
      expect(tracker.coveragePercentage(totalDuration), closeTo(15.1, 0.1));
      expect(tracker.isComplete(totalDuration, 95.0), isFalse);
    });

    test('Rewatching the first 10% ten times does NOT achieve 95% completion', () {
      final tracker = LessonCoverageTracker();
      const totalDuration = 1000; // 1000-second lesson

      // Loop over 0 to 100 seconds (first 10%) 10 times
      for (var loop = 0; loop < 10; loop++) {
        for (var sec = 0; sec <= 100; sec++) {
          tracker.markSecond(sec);
        }
      }

      expect(tracker.uniqueSeconds, 101, reason: 'Repeated intervals must collapse into 101 unique seconds');
      expect(tracker.coveragePercentage(totalDuration), closeTo(10.1, 0.1));
      expect(tracker.isComplete(totalDuration, 95.0), isFalse, reason: '10% coverage cannot satisfy 95% completion');
    });

    test('Covering 95% of unique intervals satisfies completion threshold', () {
      final tracker = LessonCoverageTracker();
      const totalDuration = 1000;

      // Watch from 0 to 950 seconds (95% of total lesson)
      for (var s = 0; s < 950; s++) {
        tracker.markSecond(s);
      }

      expect(tracker.uniqueSeconds, 950);
      expect(tracker.coveragePercentage(totalDuration), 95.0);
      expect(tracker.isComplete(totalDuration, 95.0), isTrue);
    });
  });
}
