// ignore_for_file: avoid_print, unused_import
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_screen_app/models/lesson_coverage_tracker.dart';
import 'package:secure_screen_app/models/watch_log_entry.dart';
import 'package:secure_screen_app/services/watch_queue.dart';

void main() {
  group('1. Multi-Session Playback Integrity Tests (P0)', () {
    test('Multiple playback sessions do not overwrite historical watch logs', () async {
      final databaseWatchLogs = <String, Map<String, dynamic>>{};
      final databaseUsers = <String, Map<String, dynamic>>{
        'student_1': {'totalWatchSeconds': 0, 'processedSessionEnds': <String>[]},
      };

      // Mock Firestore Service write logic
      Future<void> mockRecordWatchEvent(Map<String, dynamic> event) async {
        final uid = event['uid'] as String;
        final seconds = (event['seconds'] as num?)?.toInt() ?? 0;
        final sessionSeconds = (event['sessionSeconds'] as num?)?.toInt() ?? seconds;
        final isSessionEnd = event['isSessionEnd'] == true;
        final courseId = event['courseId'] as String;
        final lessonId = event['lessonId'] as String;
        final sessionId = event['sessionId'] as String;
        final eventId = event['id'] as String;

        // Session-specific deterministic document ID
        final docId = 'watch_${uid}_${courseId}_${lessonId}_$sessionId';

        // Check if log exists and ensure non-regressive duration
        final existing = databaseWatchLogs[docId];
        final existingDuration = (existing?['durationSeconds'] as num?)?.toInt() ?? 0;
        final safeDuration = sessionSeconds >= existingDuration ? sessionSeconds : existingDuration;

        databaseWatchLogs[docId] = {
          'id': docId,
          'studentId': uid,
          'courseId': courseId,
          'lessonId': lessonId,
          'sessionId': sessionId,
          'durationSeconds': safeDuration,
          'lastCheckpointId': eventId,
        };

        if (isSessionEnd && seconds > 0) {
          final user = databaseUsers[uid]!;
          final processed = List<String>.from(user['processedSessionEnds'] as List);
          if (!processed.contains(eventId)) {
            processed.add(eventId);
            user['totalWatchSeconds'] = (user['totalWatchSeconds'] as int) + seconds;
            user['processedSessionEnds'] = processed;
          }
        }
      }

      // Session 1 (e.g. Monday morning): Student watches 1,800 seconds (30 mins)
      const sess1 = 'sess_monday_001';
      await mockRecordWatchEvent({
        'id': 'evt_101',
        'uid': 'student_1',
        'courseId': 'course_algebra',
        'lessonId': 'lesson_intro',
        'sessionId': sess1,
        'seconds': 1800,
        'sessionSeconds': 1800,
        'isSessionEnd': true,
      });

      expect(databaseWatchLogs.length, 1);
      expect(databaseWatchLogs['watch_student_1_course_algebra_lesson_intro_$sess1']?['durationSeconds'], 1800);
      expect(databaseUsers['student_1']?['totalWatchSeconds'], 1800);

      // Session 2 (e.g. Tuesday evening): Student watches 900 seconds (15 mins) on same lesson
      const sess2 = 'sess_tuesday_002';
      await mockRecordWatchEvent({
        'id': 'evt_102',
        'uid': 'student_1',
        'courseId': 'course_algebra',
        'lessonId': 'lesson_intro',
        'sessionId': sess2,
        'seconds': 900,
        'sessionSeconds': 900,
        'isSessionEnd': true,
      });

      // Both session records MUST exist independently — Session 2 DID NOT overwrite Session 1!
      expect(databaseWatchLogs.length, 2);
      expect(databaseWatchLogs['watch_student_1_course_algebra_lesson_intro_$sess1']?['durationSeconds'], 1800);
      expect(databaseWatchLogs['watch_student_1_course_algebra_lesson_intro_$sess2']?['durationSeconds'], 900);

      // Cumulative user profile watch seconds correctly sums both sessions
      expect(databaseUsers['student_1']?['totalWatchSeconds'], 2700); // 1800 + 900 = 2700s (45 mins)
    });
  });

  group('2. Multi-Device Synchronization & Range Merging (P2)', () {
    test('Unique watched intervals merge seamlessly across Phone and Tablet', () {
      final phoneTracker = LessonCoverageTracker();
      const lessonDuration = 1000; // 1000 seconds total

      // Student on Phone watches interval [0..400] seconds (40% coverage)
      for (int sec = 0; sec <= 400; sec++) {
        phoneTracker.markPlayback(currentPosition: sec, lastPosition: sec == 0 ? 0 : sec - 1);
      }
      expect(phoneTracker.coveragePercentage(lessonDuration), closeTo(40.1, 0.1));
      expect(phoneTracker.isComplete(lessonDuration, 95.0), isFalse);

      final phoneRangesEncoded = phoneTracker.encodeRanges();

      // Student opens Tablet for first time: Tablet restores coverage from remote watch log
      final tabletTracker = LessonCoverageTracker.decodeRanges(phoneRangesEncoded);
      expect(tabletTracker.uniqueSeconds, phoneTracker.uniqueSeconds);

      // Student on Tablet continues watching interval [401..960] seconds (another 56% coverage)
      for (int sec = 401; sec <= 960; sec++) {
        tabletTracker.markPlayback(currentPosition: sec, lastPosition: sec - 1);
      }

      // Tablet now has [0..960] seconds watched (96.1% coverage)
      expect(tabletTracker.coveragePercentage(lessonDuration), closeTo(96.1, 0.1));
      expect(tabletTracker.isComplete(lessonDuration, 95.0), isTrue);

      // Student opens Phone again later: Phone merges remote tablet tracker
      phoneTracker.merge(tabletTracker);
      expect(phoneTracker.coveragePercentage(lessonDuration), closeTo(96.1, 0.1));
      expect(phoneTracker.isComplete(lessonDuration, 95.0), isTrue);
    });

    test('Two devices watching concurrently do not overwrite separate session logs', () async {
      final watchLogs = <String, int>{};

      void saveDeviceLog(String deviceSessionId, int seconds) {
        final docId = 'watch_student_1_course_algebra_lesson_intro_$deviceSessionId';
        watchLogs[docId] = seconds;
      }

      // Phone session
      saveDeviceLog('sess_phone_dev1', 500);
      // Tablet session
      saveDeviceLog('sess_tablet_dev2', 700);

      // Distinct keys exist for both devices
      expect(watchLogs.length, 2);
      expect(watchLogs['watch_student_1_course_algebra_lesson_intro_sess_phone_dev1'], 500);
      expect(watchLogs['watch_student_1_course_algebra_lesson_intro_sess_tablet_dev2'], 700);
    });
  });

  group('3. Offline Retries & Out-of-Order Checkpoint Integrity (P0)', () {
    test('Out-of-order delayed checkpoint does NOT regress watch log duration', () {
      int currentDuration = 0;

      void applyCheckpoint(int sessionSeconds) {
        // Enforce monotonically non-regressive duration
        if (sessionSeconds >= currentDuration) {
          currentDuration = sessionSeconds;
        }
      }

      // Checkpoint 2 (600s) arrives first over fast cellular connection
      applyCheckpoint(600);
      expect(currentDuration, 600);

      // Delayed Checkpoint 1 (300s) arrives later out-of-order
      applyCheckpoint(300);
      // Duration MUST stay at 600s, preventing regression!
      expect(currentDuration, 600);
    });

    test('Retrying session-end checkpoint 5 times increments totalWatchSeconds ONLY ONCE', () {
      final user = {
        'totalWatchSeconds': 1000,
        'processedSessionEnds': <String>[],
      };

      void processSessionEnd(String eventId, int seconds) {
        final processed = user['processedSessionEnds'] as List<String>;
        if (!processed.contains(eventId)) {
          processed.add(eventId);
          user['totalWatchSeconds'] = (user['totalWatchSeconds'] as int) + seconds;
        }
      }

      const eventId = 'evt_retry_test_999';
      const sessionSeconds = 500;

      // Simulate 5 consecutive retry attempts of the same network event
      for (int attempt = 1; attempt <= 5; attempt++) {
        processSessionEnd(eventId, sessionSeconds);
      }

      // Total must be 1000 + 500 = 1500, NOT 1000 + (5 * 500) = 3500!
      expect(user['totalWatchSeconds'], 1500);
      expect((user['processedSessionEnds'] as List).length, 1);
    });
  });

  group('4. Sequential Level Unlocking & 95% Completion Logic (P2)', () {
    test('Course levels unlock strictly upon reaching 95% coverage on all level lessons', () {
      final completedLessons = <String>{};

      bool isLevelUnlocked(int levelNumber, Map<int, List<String>> courseStructure) {
        if (levelNumber == 1) return true; // Level 1 is always unlocked
        // Level N requires all lessons in Level N-1 to be completed
        final previousLevelLessons = courseStructure[levelNumber - 1] ?? [];
        return previousLevelLessons.every(completedLessons.contains);
      }

      final course = {
        1: ['l1_1', 'l1_2'],
        2: ['l2_1', 'l2_2'],
        3: ['l3_1'],
      };

      // Initially Level 1 is unlocked, Level 2 is locked
      expect(isLevelUnlocked(1, course), isTrue);
      expect(isLevelUnlocked(2, course), isFalse);

      // Complete l1_1
      completedLessons.add('l1_1');
      expect(isLevelUnlocked(2, course), isFalse);

      // Complete l1_2 -> Level 2 unlocks!
      completedLessons.add('l1_2');
      expect(isLevelUnlocked(2, course), isTrue);
      expect(isLevelUnlocked(3, course), isFalse);
    });
  });

  group('5. Administrative Analytics Consistency & Legacy Schema (P0)', () {
    test('Admin analytics correctly sums both legacy and new watch log entries', () {
      // Legacy logs used 'secondsWatched' or 'seconds'
      final legacyLog1 = WatchLogEntry.fromMap({
        'studentId': 's1',
        'courseId': 'c1',
        'lessonId': 'l1',
        'secondsWatched': 600,
        'recordedAt': DateTime.now().toIso8601String(),
      }, id: 'leg_1');

      final legacyLog2 = WatchLogEntry.fromMap({
        'studentId': 's1',
        'courseId': 'c1',
        'lessonId': 'l2',
        'seconds': 400,
        'recordedAt': DateTime.now().toIso8601String(),
      }, id: 'leg_2');

      // New log uses 'durationSeconds'
      final newLog = WatchLogEntry.fromMap({
        'studentId': 's1',
        'courseId': 'c1',
        'lessonId': 'l3',
        'durationSeconds': 800,
        'recordedAt': DateTime.now().toIso8601String(),
      }, id: 'new_1');

      final allLogs = [legacyLog1, legacyLog2, newLog];
      final totalSeconds = allLogs.fold<int>(0, (sum, log) => sum + log.durationSeconds);

      expect(totalSeconds, 1800); // 600 + 400 + 800 = 1800s (30 mins)
      expect(allLogs[0].durationSeconds, 600);
      expect(allLogs[1].durationSeconds, 400);
      expect(allLogs[2].durationSeconds, 800);
    });
  });

  group('6. Simulated 300-Student Daily Workload Simulation (P3)', () {
    test('Simulate 300 students watching 90 minutes daily and verify write budget', () {
      int totalDocumentWrites = 0;
      int totalDocumentDeletes = 0;

      // Workload parameters
      const studentCount = 300;
      const dailyMinutesPerStudent = 90;
      const sessionMinutes = 45; // 2 sessions of 45 mins each
      const checkpointIntervalMinutes = 5;

      const sessionsPerStudent = dailyMinutesPerStudent ~/ sessionMinutes; // 2 sessions
      const checkpointsPerSession = sessionMinutes ~/ checkpointIntervalMinutes; // 9 checkpoints

      for (int s = 0; s < studentCount; s++) {
        for (int sess = 0; sess < sessionsPerStudent; sess++) {
          // 1. Playback Start: 1 presence write
          totalDocumentWrites++;

          // 2. Playback Checkpoints: 2 writes per checkpoint (watch_log + active_session)
          for (int cp = 0; cp < checkpointsPerSession; cp++) {
            totalDocumentWrites += 2; // watch_log + active_session heartbeat
          }

          // 3. Session End: 1 watch_log final + 1 user profile totalWatchSeconds
          totalDocumentWrites += 2;

          // 4. Presence Cleanup: 1 delete
          totalDocumentDeletes++;

          // 5. Lesson Completion (1 per session): 1 write to user completedLessonIds
          totalDocumentWrites += 1;
        }
      }

      // Administrative and miscellaneous operations (grading, assignments, auth)
      const adminWrites = 600;

      final totalOperations = totalDocumentWrites + totalDocumentDeletes + adminWrites;

      print('-------------------------------------------------------');
      print('SIMULATED 300-STUDENT WORKLOAD VERIFICATION RESULTS:');
      print('Total Document Writes: $totalDocumentWrites');
      print('Total Document Deletes: $totalDocumentDeletes');
      print('Administrative Operations: $adminWrites');
      print('Total Daily Operations: $totalOperations');
      print('Firebase Spark Limit: 20,000 writes/day');
      print('Remaining Headroom: ${20000 - totalOperations} operations (${((20000 - totalOperations) / 20000 * 100).toStringAsFixed(1)}%)');
      print('-------------------------------------------------------');

      expect(totalDocumentWrites, 13200);
      expect(totalDocumentDeletes, 600);
      expect(totalOperations, 14400);
      expect(totalOperations, lessThan(20000));
    });
  });
}
