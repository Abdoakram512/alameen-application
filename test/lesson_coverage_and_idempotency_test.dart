import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_screen_app/models/lesson_coverage_tracker.dart';
import 'package:secure_screen_app/services/watch_queue.dart';

void main() {
  group('LessonCoverageTracker - Strict 95% Coverage Verification', () {
    test('Continuous playback accurately accumulates unique seconds', () {
      final tracker = LessonCoverageTracker();

      // Simulate playing from 0s to 10s second by second
      int lastPos = 0;
      for (int sec = 0; sec <= 10; sec++) {
        tracker.markPlayback(currentPosition: sec, lastPosition: lastPos);
        lastPos = sec;
      }

      expect(tracker.uniqueSeconds, 11);
      expect(tracker.coveragePercentage(100), closeTo(11.0, 0.1));
    });

    test('Forward seek does NOT count skipped intervals', () {
      final tracker = LessonCoverageTracker();

      // Student plays 0s -> 5s
      int lastPos = 0;
      for (int sec = 0; sec <= 5; sec++) {
        tracker.markPlayback(currentPosition: sec, lastPosition: lastPos);
        lastPos = sec;
      }
      expect(tracker.uniqueSeconds, 6); // 0, 1, 2, 3, 4, 5

      // Student skips forward from 5s to 80s (with isSeeking: true)
      tracker.markPlayback(currentPosition: 80, lastPosition: 5, isSeeking: true);

      // Total watched should only be 6 + 1 = 7 seconds, NOT 80 seconds!
      expect(tracker.uniqueSeconds, 7);
      expect(tracker.isSecondWatched(30), isFalse);
      expect(tracker.isSecondWatched(50), isFalse);
      expect(tracker.isSecondWatched(80), isTrue);
    });

    test('Rewatching identical segments does NOT increase watched coverage', () {
      final tracker = LessonCoverageTracker();

      // Student watches 0s -> 20s three times in a loop
      for (int loop = 0; loop < 3; loop++) {
        int lastPos = 0;
        for (int sec = 0; sec <= 20; sec++) {
          tracker.markPlayback(currentPosition: sec, lastPosition: lastPos);
          lastPos = sec;
        }
      }

      // Even after 3 loops (63 ticks), unique seconds watched MUST remain exactly 21
      expect(tracker.uniqueSeconds, 21);
      expect(tracker.coveragePercentage(100), closeTo(21.0, 0.1));
    });

    test('Strict 95% threshold requirement is accurately enforced', () {
      final tracker = LessonCoverageTracker();
      const totalLessonSeconds = 1000;

      // Watch 940 seconds (94.0%)
      int lastPos = 0;
      for (int sec = 0; sec < 940; sec++) {
        tracker.markPlayback(currentPosition: sec, lastPosition: lastPos);
        lastPos = sec;
      }
      expect(tracker.coveragePercentage(totalLessonSeconds), closeTo(94.0, 0.01));
      expect(tracker.isComplete(totalLessonSeconds, 95.0), isFalse);

      // Watch 10 more seconds to reach 950 seconds (95.0%)
      for (int sec = 940; sec < 950; sec++) {
        tracker.markPlayback(currentPosition: sec, lastPosition: lastPos);
        lastPos = sec;
      }
      expect(tracker.coveragePercentage(totalLessonSeconds), closeTo(95.0, 0.01));
      expect(tracker.isComplete(totalLessonSeconds, 95.0), isTrue);

      // Watch up to 1000 seconds (100.0%)
      for (int sec = 950; sec < 1000; sec++) {
        tracker.markPlayback(currentPosition: sec, lastPosition: lastPos);
        lastPos = sec;
      }
      expect(tracker.coveragePercentage(totalLessonSeconds), closeTo(100.0, 0.01));
      expect(tracker.isComplete(totalLessonSeconds, 95.0), isTrue);
    });

    test('Range compression and decompression preserves exact intervals', () {
      final original = LessonCoverageTracker();

      // Mark [0..10], [50..60], [100..105]
      for (int sec = 0; sec <= 10; sec++) {
        original.markSecond(sec);
      }
      for (int sec = 50; sec <= 60; sec++) {
        original.markSecond(sec);
      }
      for (int sec = 100; sec <= 105; sec++) {
        original.markSecond(sec);
      }

      final encoded = original.encodeRanges();
      // Should encode JSON array of ranges: [[0,10],[50,60],[100,105]]
      expect(encoded, '[[0,10],[50,60],[100,105]]');

      // Reconstruct into a new tracker
      final restored = LessonCoverageTracker.decodeRanges(encoded);
      expect(restored.uniqueSeconds, original.uniqueSeconds);
      expect(restored.isSecondWatched(5), isTrue);
      expect(restored.isSecondWatched(30), isFalse);
      expect(restored.isSecondWatched(55), isTrue);
      expect(restored.isSecondWatched(102), isTrue);
      expect(restored.isSecondWatched(106), isFalse);
    });

    test('Speed playback up to 2.0x correctly marks intermediate skipped ticks', () {
      final tracker = LessonCoverageTracker();

      // At 2x speed, timer ticks every 1s wall-clock, but player advances by 2s (e.g. 10 -> 12)
      tracker.markPlayback(currentPosition: 12, lastPosition: 10);
      expect(tracker.isSecondWatched(10), isTrue);
      expect(tracker.isSecondWatched(11), isTrue);
      expect(tracker.isSecondWatched(12), isTrue);
    });
  });

  group('Idempotent Watch-Time Synchronization', () {
    test('Retrying network flush does not duplicate durationSeconds', () async {
      final persistentStorage = <String, String>{};
      final sentEvents = <Map<String, dynamic>>[];
      bool networkShouldFail = true;

      WatchQueue createQueue() => WatchQueue(
            read: (key) async => persistentStorage[key],
            write: (key, val) async {
              persistentStorage[key] = val;
            },
            send: (event) async {
              sentEvents.add(Map<String, dynamic>.from(event.toMap()));
              if (networkShouldFail) {
                throw Exception('Simulated network timeout (transient failure)');
              }
            },
          );

      final queue1 = createQueue();

      // Enqueue a 300s checkpoint with sessionSeconds = 300
      await queue1.enqueue(
        uid: 'student_123',
        courseId: 'course_algebra',
        lessonId: 'lesson_quadratics',
        seconds: 300,
        sessionSeconds: 300,
        isSessionEnd: false,
      );

      // Attempt 1: Fails due to network timeout
      await expectLater(queue1.flush('student_123'), throwsException);
      expect(sentEvents.length, 1);
      final firstAttemptEvent = sentEvents.first;
      expect(firstAttemptEvent['sessionSeconds'], 300);
      expect(firstAttemptEvent['seconds'], 300);

      // Queue still contains the event in persistent storage
      final storedRaw = jsonDecode(persistentStorage.values.single) as List;
      expect(storedRaw.length, 1);

      // Recover network and retry via freshly instantiated queue (simulating app restart or retry)
      networkShouldFail = false;
      final queue2 = createQueue();
      await queue2.flush('student_123');

      // Attempt 2 succeeds
      expect(sentEvents.length, 2);
      final secondAttemptEvent = sentEvents.last;

      // Event ID and sessionSeconds MUST be identical across retries
      expect(secondAttemptEvent['id'], firstAttemptEvent['id']);
      expect(secondAttemptEvent['sessionSeconds'], 300);

      // Queue is now empty in persistent storage
      final storedAfterSuccess = jsonDecode(persistentStorage.values.single) as List;
      expect(storedAfterSuccess, isEmpty);

      // Simulate Firestore Document State receiving both events
      // A retry writes absolute durationSeconds to the session doc:
      final firestoreSessionDoc = <String, dynamic>{};

      void applyFirestoreWrite(Map<String, dynamic> evt) {
        firestoreSessionDoc['durationSeconds'] = evt['sessionSeconds'];
        firestoreSessionDoc['lastCheckpointId'] = evt['id'];
      }

      // First write applied
      applyFirestoreWrite(firstAttemptEvent);
      expect(firestoreSessionDoc['durationSeconds'], 300);

      // Duplicate / retried write applied
      applyFirestoreWrite(secondAttemptEvent);
      // Absolute durationSeconds remains exactly 300, completely eliminating double-counting!
      expect(firestoreSessionDoc['durationSeconds'], 300);
      expect(firestoreSessionDoc['lastCheckpointId'], firstAttemptEvent['id']);
    });

    test('Simultaneous sync requests preserve event integrity without corrupting queues', () async {
      final persistentStorage = <String, String>{};
      final sentEvents = <Map<String, dynamic>>[];

      final queue = WatchQueue(
        read: (key) async => persistentStorage[key],
        write: (key, val) async {
          persistentStorage[key] = val;
        },
        send: (event) async {
          sentEvents.add(event.toMap());
        },
      );

      // Enqueue multiple distinct checkpoints concurrently
      await Future.wait([
        queue.enqueue(
          uid: 'student_A',
          courseId: 'c1',
          lessonId: 'l1',
          seconds: 300,
          sessionSeconds: 300,
        ),
        queue.enqueue(
          uid: 'student_A',
          courseId: 'c1',
          lessonId: 'l1',
          seconds: 300,
          sessionSeconds: 600,
        ),
        queue.enqueue(
          uid: 'student_B',
          courseId: 'c2',
          lessonId: 'l2',
          seconds: 150,
          sessionSeconds: 150,
        ),
      ]);

      await queue.flush('student_A');
      expect(sentEvents.length, 2);
      expect(sentEvents[0]['sessionSeconds'], 300);
      expect(sentEvents[1]['sessionSeconds'], 600);

      await queue.flush('student_B');
      expect(sentEvents.length, 3);
      expect(sentEvents[2]['sessionSeconds'], 150);
    });
  });
}
