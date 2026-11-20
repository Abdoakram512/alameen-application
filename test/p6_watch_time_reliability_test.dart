import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:secure_screen_app/models/lesson.dart';
import 'package:secure_screen_app/models/lesson_coverage_tracker.dart';
import 'package:secure_screen_app/models/lesson_playback_data.dart';
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
    uid: 'student_p5_concurrent',
    email: 'p5@alameen.com',
    displayName: 'P5 Student',
    photoUrl: '',
    createdAt: DateTime(2026, 1, 1),
  );

  group('Test Suite 1: Watch-Time Reliability & Concurrency', () {
    test('1.1 Multiple simultaneous sync events do not drop final session-end', () async {
      final flushedEvents = <Map<String, dynamic>>[];
      final storage = <String, String>{};

      final queue = WatchQueue(
        read: (k) async => storage[k],
        write: (k, v) async => storage[k] = v,
        send: (evt) async {
          flushedEvents.add(evt.toMap());
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
          durationSeconds: 600,
          videoSource: 'bunny',
        ),
        watchQueue: queue,
      );

      for (int i = 0; i < 50; i++) {
        coordinator.recordPlaybackSecond(
          currentPlayheadSeconds: i,
          isPlaying: true,
          isBuffering: false,
          isScreenCaptured: false,
        );
      }
      expect(coordinator.pendingWatchedSeconds, 50);

      final f1 = coordinator.flushWatchTime(isSessionEnd: false);
      final f2 = coordinator.flushWatchTime(isSessionEnd: true);
      await Future.wait([f1, f2]);

      expect(flushedEvents.isNotEmpty, isTrue);
      final lastEvent = flushedEvents.last;
      expect(lastEvent['isSessionEnd'], isTrue,
          reason: 'Session-end must never be dropped even under concurrent flush');
    });

    test('1.2 Playback seeking and buffering drops invalid intervals and resets playhead', () {
      final coordinator = WatchProgressCoordinator(
        currentUser: dummyUser,
        courseId: 'c_math',
        courseTitle: 'Math',
        lesson: const Lesson(
          id: 'l_seek',
          title: 'Seek Lesson',
          description: 'Desc',
          duration: '20:00',
          durationSeconds: 1200,
          videoSource: 'bunny',
        ),
      );

      for (int sec = 0; sec <= 5; sec++) {
        coordinator.recordPlaybackSecond(
          currentPlayheadSeconds: sec,
          isPlaying: true,
          isBuffering: false,
          isScreenCaptured: false,
        );
      }
      expect(coordinator.coverageTracker.coveragePercentage(1200), closeTo(0.5, 0.1));

      coordinator.onSeekPerformed(targetPositionSeconds: 600);

      for (int i = 0; i < 5; i++) {
        coordinator.recordPlaybackSecond(
          currentPlayheadSeconds: 600,
          isPlaying: true,
          isBuffering: true,
          isScreenCaptured: false,
        );
      }
      expect(coordinator.pendingWatchedSeconds, 6);

      coordinator.recordPlaybackSecond(
        currentPlayheadSeconds: 600,
        isPlaying: true,
        isBuffering: false,
        isScreenCaptured: false,
      );
      expect(coordinator.pendingWatchedSeconds, 7);
    });

    test('1.3 Multi-device coverage ranges merge accurately across Phone and Tablet', () {
      const totalDuration = 1000;
      final phone = LessonCoverageTracker();
      for (int i = 0; i <= 500; i++) {
        phone.markPlayback(currentPosition: i, lastPosition: i == 0 ? 0 : i - 1);
      }
      final phoneEncoded = phone.encodeRanges();

      final tablet = LessonCoverageTracker.decodeRanges(phoneEncoded);
      for (int i = 400; i <= 960; i++) {
        tablet.markPlayback(currentPosition: i, lastPosition: i == 400 ? 400 : i - 1);
      }

      expect(tablet.coveragePercentage(totalDuration), closeTo(96.1, 0.1));
      expect(tablet.isComplete(totalDuration, 95.0), isTrue);
    });
  });

  group('Test Suite 2: Signed Playback Expiration & Laravel Progress Monotonicity', () {
    test('2.1 Signed HLS URL expiry check triggers accurately within buffer window', () {
      final now = DateTime.utc(2026, 11, 18, 12, 0, 0);
      final validExp = now.add(const Duration(minutes: 10)).millisecondsSinceEpoch ~/ 1000;
      final soonExp = now.add(const Duration(seconds: 20)).millisecondsSinceEpoch ~/ 1000;
      final pastExp = now.subtract(const Duration(minutes: 5)).millisecondsSinceEpoch ~/ 1000;

      expect(
        ResolvedLessonPlayback.isSignedUrlExpiredOrExpiring(
          'https://cdn.example.com/v.m3u8?expires=$validExp',
          now: now,
        ),
        isFalse,
      );
      expect(
        ResolvedLessonPlayback.isSignedUrlExpiredOrExpiring(
          'https://cdn.example.com/v.m3u8?expires=$soonExp',
          now: now,
        ),
        isTrue,
      );
      expect(
        ResolvedLessonPlayback.isSignedUrlExpiredOrExpiring(
          'https://cdn.example.com/v.m3u8?exp=$pastExp',
          now: now,
        ),
        isTrue,
      );
    });

    test('2.2 WatchProgressCoordinator preserves server baseline watched seconds across devices', () {
      final coordinator = WatchProgressCoordinator(
        currentUser: dummyUser,
        courseId: 'c_1',
        courseTitle: 'Course 1',
        lesson: const Lesson(
          id: '10',
          title: 'Lesson 10',
          description: '',
          duration: '30:00',
          durationSeconds: 1800,
          watchedSeconds: 420,
          lastPositionSeconds: 420,
        ),
      );

      expect(coordinator.effectiveWatchedSeconds, 420);

      // Watch only 10 seconds from 0..9 on a new device -> should NOT regress below 420!
      for (int s = 0; s < 10; s++) {
        coordinator.recordPlaybackSecond(
          currentPlayheadSeconds: s,
          isPlaying: true,
          isBuffering: false,
          isScreenCaptured: false,
        );
      }
      expect(coordinator.effectiveWatchedSeconds, 420);
    });
  });
}
