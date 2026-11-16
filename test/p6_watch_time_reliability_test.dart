import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:secure_screen_app/models/active_watch_session.dart';
import 'package:secure_screen_app/models/lesson.dart';
import 'package:secure_screen_app/models/lesson_coverage_tracker.dart';
import 'package:secure_screen_app/models/user_profile.dart';
import 'package:secure_screen_app/screens/student/video_player/controllers/watch_progress_coordinator.dart';
import 'package:secure_screen_app/services/watch_queue.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  final dummyUser = UserModel(
    uid: 'student_p6_concurrent',
    email: 'p6@alameen.com',
    displayName: 'P6 Student',
    photoUrl: '',
    createdAt: DateTime(2026, 1, 1),
  );

  ActiveWatchSession createSession({
    required String id,
    required String studentId,
    required DateTime startedAt,
    required DateTime lastHeartbeatAt,
  }) {
    return ActiveWatchSession(
      id: id,
      studentId: studentId,
      studentName: 'Student $studentId',
      studentEmail: '$studentId@test.com',
      studentPhone: '01012345678',
      courseId: 'c1',
      courseTitle: 'Course 1',
      lessonId: 'l1',
      lessonTitle: 'Lesson 1',
      currentPositionSeconds: 100,
      totalDurationSeconds: 1000,
      progressPercentage: 10.0,
      ipAddress: '197.34.1.1',
      networkType: 'wifi',
      devicePlatform: 'android',
      isPlaying: true,
      startedAt: startedAt,
      lastHeartbeatAt: lastHeartbeatAt,
    );
  }

  group('P6 Test Suite 1: Watch-Time Reliability & Concurrency', () {
    test('1.1 Multiple simultaneous sync events do not drop final session-end', () async {
      final flushedEvents = <Map<String, dynamic>>[];
      final storage = <String, String>{};

      final queue = WatchQueue(
        read: (k) async => storage[k],
        write: (k, v) async => storage[k] = v,
        send: (evt) async {
          flushedEvents.add(evt);
        },
      );

      final coordinator = WatchProgressCoordinator(
        currentUser: dummyUser,
        courseId: 'c_math',
        courseTitle: 'Math',
        lesson: const Lesson(
          id: 'l_101',
          title: 'Lesson 101',
          description: 'Desc',
          duration: '10:00',
          muxPlaybackId: 'mux_101',
        ),
        watchQueue: queue,
      );

      // Simulate normal playback
      for (int i = 0; i < 50; i++) {
        coordinator.recordPlaybackSecond(
          currentPlayheadSeconds: i,
          isPlaying: true,
          isBuffering: false,
          isScreenCaptured: false,
        );
      }
      expect(coordinator.pendingWatchedSeconds, 50);

      // Trigger simultaneous flush and sessionEnd
      final f1 = coordinator.flushWatchTime(isSessionEnd: false);
      final f2 = coordinator.flushWatchTime(isSessionEnd: true);
      await Future.wait([f1, f2]);

      expect(flushedEvents.isNotEmpty, isTrue);
      final lastEvent = flushedEvents.last;
      expect(lastEvent['isSessionEnd'], isTrue,
          reason: 'Session-end must never be dropped even under concurrent flush');
    });

    test('1.2 Duplicate session-end submissions increment totalWatchSeconds only once', () async {
      final databaseUsers = <String, Map<String, dynamic>>{
        'student_dup': {
          'totalWatchSeconds': 1000,
          'processedSessionEnds': <String>['sess_old_01'],
        },
      };

      Future<void> simulateTransactionSessionEnd(String uid, String eventId, int seconds) async {
        final userData = databaseUsers[uid]!;
        final processed = List<String>.from(userData['processedSessionEnds'] as List);
        if (!processed.contains(eventId)) {
          processed.add(eventId);
          if (processed.length > 50) processed.removeAt(0);
          userData['totalWatchSeconds'] = (userData['totalWatchSeconds'] as int) + seconds;
          userData['processedSessionEnds'] = processed;
        }
      }

      const duplicateEventId = 'evt_dup_session_end_999';
      // First submission
      await simulateTransactionSessionEnd('student_dup', duplicateEventId, 600);
      expect(databaseUsers['student_dup']?['totalWatchSeconds'], 1600);

      // Duplicate submission 1 (e.g. network timeout retry)
      await simulateTransactionSessionEnd('student_dup', duplicateEventId, 600);
      expect(databaseUsers['student_dup']?['totalWatchSeconds'], 1600);

      // Duplicate submission 2 (e.g. app relaunch queue replay)
      await simulateTransactionSessionEnd('student_dup', duplicateEventId, 600);
      expect(databaseUsers['student_dup']?['totalWatchSeconds'], 1600,
          reason: 'totalWatchSeconds must remain exactly 1600 after 3 duplicate attempts');
    });

    test('1.3 Repeated old event outside last 50 processed IDs: Sliding Window Analysis', () async {
      final databaseUsers = <String, Map<String, dynamic>>{
        'student_sliding': {
          'totalWatchSeconds': 0,
          'processedSessionEnds': <String>[],
        },
      };

      Future<void> processEvent(String uid, String eventId, int seconds) async {
        final userData = databaseUsers[uid]!;
        final processed = List<String>.from(userData['processedSessionEnds'] as List);
        if (!processed.contains(eventId)) {
          processed.add(eventId);
          if (processed.length > 50) processed.removeAt(0);
          userData['totalWatchSeconds'] = (userData['totalWatchSeconds'] as int) + seconds;
          userData['processedSessionEnds'] = processed;
        }
      }

      // Initial event
      const ancientEventId = 'ancient_event_000';
      await processEvent('student_sliding', ancientEventId, 100);
      expect(databaseUsers['student_sliding']?['totalWatchSeconds'], 100);

      // 50 subsequent unique sessions push ancient_event_000 out of the 50-item window
      for (int i = 1; i <= 50; i++) {
        await processEvent('student_sliding', 'subsequent_event_$i', 10);
      }
      expect(databaseUsers['student_sliding']?['totalWatchSeconds'], 100 + (50 * 10)); // 600

      final currentProcessedList = databaseUsers['student_sliding']?['processedSessionEnds'] as List<String>;
      expect(currentProcessedList.contains(ancientEventId), isFalse,
          reason: 'Sliding window of 50 evicts ancient events');

      // If an attacker replays the ancient event after window eviction:
      await processEvent('student_sliding', ancientEventId, 100);
      // Demonstrates vulnerability: sliding window eviction permits replaying events older than 50 sessions
      expect(databaseUsers['student_sliding']?['totalWatchSeconds'], 700);
    });

    test('1.4 Out-of-order delayed checkpoints do NOT regress watch duration in database', () async {
      final watchLogs = <String, Map<String, dynamic>>{};

      void simulateCheckpoint(String docId, int sessionSeconds) {
        final existing = watchLogs[docId];
        final existingDuration = (existing?['durationSeconds'] as int?) ?? 0;
        final safeDuration = sessionSeconds >= existingDuration ? sessionSeconds : existingDuration;

        watchLogs[docId] = {
          'id': docId,
          'durationSeconds': safeDuration,
        };
      }

      const logId = 'watch_student_course_lesson_sess1';
      // Normal progression: checkpoint 1 at 300s
      simulateCheckpoint(logId, 300);
      expect(watchLogs[logId]?['durationSeconds'], 300);

      // Checkpoint 2 at 600s
      simulateCheckpoint(logId, 600);
      expect(watchLogs[logId]?['durationSeconds'], 600);

      // Delayed/Stale Checkpoint 1 (arrives out of order from slow network at 300s)
      simulateCheckpoint(logId, 300);
      expect(watchLogs[logId]?['durationSeconds'], 600,
          reason: 'Monotonicity check safeSessionSeconds >= existingDuration prevents regression');
    });

    test('1.5 Playback seeking and buffering drops invalid intervals and resets playhead', () {
      final coordinator = WatchProgressCoordinator(
        currentUser: dummyUser,
        courseId: 'c_math',
        courseTitle: 'Math',
        lesson: const Lesson(
          id: 'l_seek',
          title: 'Seek Lesson',
          description: 'Desc',
          duration: '20:00',
          muxPlaybackId: 'mux_seek',
        ),
      );

      // Normal play from sec 0 to 5
      for (int sec = 0; sec <= 5; sec++) {
        coordinator.recordPlaybackSecond(
          currentPlayheadSeconds: sec,
          isPlaying: true,
          isBuffering: false,
          isScreenCaptured: false,
        );
      }
      expect(coordinator.coverageTracker.coveragePercentage(1200), closeTo(0.5, 0.1));

      // User seeks to minute 10 (sec 600)
      coordinator.onSeekPerformed();

      // Buffering occurs for 5 seconds at sec 600
      for (int i = 0; i < 5; i++) {
        coordinator.recordPlaybackSecond(
          currentPlayheadSeconds: 600,
          isPlaying: true,
          isBuffering: true, // Buffering!
          isScreenCaptured: false,
        );
      }
      // Buffering seconds MUST NOT increment pending watch time
      expect(coordinator.pendingWatchedSeconds, 6); // Only the first 0..5 seconds

      // Normal play resumes at sec 600
      coordinator.recordPlaybackSecond(
        currentPlayheadSeconds: 600,
        isPlaying: true,
        isBuffering: false,
        isScreenCaptured: false,
      );
      expect(coordinator.pendingWatchedSeconds, 7);
    });

    test('1.6 Multi-device coverage ranges merge accurately across Phone and Tablet', () {
      const totalDuration = 1000;
      final phone = LessonCoverageTracker();
      // Phone plays seconds 0 to 500 (50%)
      for (int i = 0; i <= 500; i++) {
        phone.markPlayback(currentPosition: i, lastPosition: i == 0 ? 0 : i - 1);
      }
      final phoneEncoded = phone.encodeRanges();

      // Tablet restores phone ranges and plays seconds 400 to 960
      final tablet = LessonCoverageTracker.decodeRanges(phoneEncoded);
      for (int i = 400; i <= 960; i++) {
        tablet.markPlayback(currentPosition: i, lastPosition: i == 400 ? 400 : i - 1);
      }

      // Total unique coverage: 0 to 960 = 96%
      expect(tablet.coveragePercentage(totalDuration), closeTo(96.1, 0.1));
      expect(tablet.isComplete(totalDuration, 95.0), isTrue);
    });
  });

  group('P6 Test Suite 2: Presence Radar & Grace Period Consistency', () {
    test('2.1 Model isStaleWithGrace(60) enforces effective 360-second timeout', () {
      final now = DateTime.now();

      // Session with last heartbeat 290 seconds ago (Fresh under both 300s and 360s)
      final sessionFresh = createSession(
        id: 's_fresh',
        studentId: 'st_1',
        startedAt: now.subtract(const Duration(seconds: 400)),
        lastHeartbeatAt: now.subtract(const Duration(seconds: 290)),
      );
      expect(sessionFresh.isStale, isFalse);
      expect(sessionFresh.isStaleWithGrace(60), isFalse);

      // Session with last heartbeat 320 seconds ago (Stale under 300s, but ALIVE under 60s grace period)
      final sessionGrace = createSession(
        id: 's_grace',
        studentId: 'st_2',
        startedAt: now.subtract(const Duration(seconds: 500)),
        lastHeartbeatAt: now.subtract(const Duration(seconds: 320)),
      );
      expect(sessionGrace.isStale, isTrue,
          reason: 'Raw isStale is true because 320s > 300s');
      expect(sessionGrace.isStaleWithGrace(60), isFalse,
          reason: 'Under 60s grace period, 320s <= 360s, so student remains visible on radar');

      // Session with last heartbeat 380 seconds ago (Stale even with 60s grace period)
      final sessionDead = createSession(
        id: 's_dead',
        studentId: 'st_3',
        startedAt: now.subtract(const Duration(seconds: 600)),
        lastHeartbeatAt: now.subtract(const Duration(seconds: 380)),
      );
      expect(sessionDead.isStaleWithGrace(60), isTrue,
          reason: '380s > (300 + 60), so session is correctly filtered out as stale');
    });
  });
}
