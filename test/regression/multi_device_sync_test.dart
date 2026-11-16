import 'package:flutter_test/flutter_test.dart';
import 'package:secure_screen_app/models/lesson_coverage_tracker.dart';

void main() {
  group('Regression Suite 4: Multi-Device Synchronization & Range Merging', () {
    test('Coverage ranges encode to compact string and decode losslessly', () {
      final tracker = LessonCoverageTracker();
      for (var s = 0; s <= 120; s++) {
        tracker.markSecond(s);
      }
      for (var s = 300; s <= 500; s++) {
        tracker.markSecond(s);
      }

      final encoded = tracker.encodeRanges();
      expect(encoded, isNotEmpty);

      final restored = LessonCoverageTracker.decodeRanges(encoded);
      expect(restored.uniqueSeconds, tracker.uniqueSeconds);
      expect(restored.coveragePercentage(1000), tracker.coveragePercentage(1000));
    });

    test('Progress on Device A and Device B merge seamlessly into complete lesson coverage', () {
      // Device A (Phone): Student watches first half (0 to 500s)
      final phoneTracker = LessonCoverageTracker();
      for (var s = 0; s <= 500; s++) {
        phoneTracker.markSecond(s);
      }
      final phoneEncoded = phoneTracker.encodeRanges();

      // Student switches to Device B (Tablet): Decodes Phone's coverage
      final tabletTracker = LessonCoverageTracker.decodeRanges(phoneEncoded);
      expect(tabletTracker.uniqueSeconds, 501);

      // Student finishes watching second half on Tablet (501 to 1000s)
      for (var s = 501; s <= 1000; s++) {
        tabletTracker.markSecond(s);
      }

      expect(tabletTracker.uniqueSeconds, 1001);
      expect(tabletTracker.coveragePercentage(1000), 100.0);
      expect(tabletTracker.isComplete(1000, 95.0), isTrue);
    });
  });
}
