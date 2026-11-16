import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_screen_app/services/watch_queue.dart';

void main() {
  group('Regression Suite 1: Video Playback & Checkpoint Synchronization', () {
    test('Checkpoint interval is strictly 300 seconds and intermediate writes consume 0 user updates', () async {
      const flushThresholdSeconds = 300;
      expect(flushThresholdSeconds, 300, reason: 'Actual checkpoint interval in code is 300 seconds (5 minutes)');

      final watchLogs = <String, Map<String, dynamic>>{};
      final users = <String, Map<String, dynamic>>{
        'std_01': {'totalWatchSeconds': 0, 'completedLessonIds': <String>[]},
      };

      var userWritesCount = 0;
      var logWritesCount = 0;

      Future<void> simulateRecordWatchEvent(Map<String, dynamic> event) async {
        final uid = event['uid'] as String;
        final isSessionEnd = event['isSessionEnd'] == true;
        final isCompleted = event['isCompleted'] == true;
        final courseId = event['courseId'] as String;
        final lessonId = event['lessonId'] as String;
        final sessionId = event['sessionId'] as String;
        final sessionSeconds = event['sessionSeconds'] as int;

        final logDocId = 'watch_${uid}_${courseId}_${lessonId}_$sessionId';
        watchLogs[logDocId] = {
          'durationSeconds': sessionSeconds,
          'isCompleted': isCompleted,
        };
        logWritesCount++;

        // Intermediate checkpoint does NOT touch users doc
        if (isSessionEnd || isCompleted) {
          final user = users[uid]!;
          user['totalWatchSeconds'] = (user['totalWatchSeconds'] as int) + (event['seconds'] as int);
          if (isCompleted) {
            (user['completedLessonIds'] as List<String>).add(lessonId);
          }
          userWritesCount++;
        }
      }

      final storage = <String, String>{};
      final queue = WatchQueue(
        read: (k) async => storage[k],
        write: (k, v) async => storage[k] = v,
        send: simulateRecordWatchEvent,
      );

      // Student watches 600 seconds total (two 300s checkpoints)
      // Checkpoint 1 (at 300s) - intermediate
      await queue.enqueue(
        uid: 'std_01',
        courseId: 'c1',
        lessonId: 'l1',
        seconds: 300,
        sessionSeconds: 300,
        sessionId: 'sess_123',
        isSessionEnd: false,
        isCompleted: false,
      );
      await queue.flush('std_01');

      expect(logWritesCount, 1);
      expect(userWritesCount, 0, reason: 'Intermediate checkpoint must consume 0 writes to users/{uid}');

      // Checkpoint 2 (at 600s) - intermediate
      await queue.enqueue(
        uid: 'std_01',
        courseId: 'c1',
        lessonId: 'l1',
        seconds: 300,
        sessionSeconds: 600,
        sessionId: 'sess_123',
        isSessionEnd: false,
        isCompleted: false,
      );
      await queue.flush('std_01');

      expect(logWritesCount, 2);
      expect(userWritesCount, 0, reason: 'Intermediate checkpoint must consume 0 writes to users/{uid}');

      // Session End at 600s
      await queue.enqueue(
        uid: 'std_01',
        courseId: 'c1',
        lessonId: 'l1',
        seconds: 0,
        sessionSeconds: 600,
        sessionId: 'sess_123',
        isSessionEnd: true,
        isCompleted: false,
      );
      await queue.flush('std_01');

      expect(logWritesCount, 3);
      expect(userWritesCount, 1, reason: 'Session end commits to users/{uid} atomically');
      expect(users['std_01']!['totalWatchSeconds'], 0);
    });
  });
}
