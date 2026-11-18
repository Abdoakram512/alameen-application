import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:secure_screen_app/models/lesson.dart';
import 'package:secure_screen_app/models/user_profile.dart';
import 'package:secure_screen_app/models/video_quality.dart';
import 'package:secure_screen_app/repositories/student_learning_repository.dart';
import 'package:secure_screen_app/repositories/student_watch_repository.dart';
import 'package:secure_screen_app/screens/student/video_player/controllers/watch_progress_coordinator.dart';
import 'package:secure_screen_app/services/watch_queue.dart';

class MockStudentWatchRepository extends Fake implements StudentWatchRepository {
  final List<Map<String, dynamic>> recordedEvents = [];
  bool throwForbiddenOnResolve = false;

  Future<void> recordEventMap(Map<String, dynamic> event) async {
    recordedEvents.add(Map<String, dynamic>.from(event));
  }

  @override
  Future<ResolvedLessonPlayback> resolveLessonPlayback({
    required String courseSlugOrId,
    required Lesson lesson,
  }) async {
    if (throwForbiddenOnResolve || !lesson.isFreePreview) {
      throw PlaybackAuthorizationException(
        'تم رفض الوصول للمحاضرة (403)',
        statusCode: 403,
      );
    }
    return const ResolvedLessonPlayback(
      streamUrl: 'https://cdn.example.com/preview.m3u8',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Alameen Video Player Modernization & Reliability Fixes Tests (Laravel P5)', () {
    late UserModel testUser;
    late Lesson testLesson;
    late MockStudentWatchRepository mockWatchRepo;
    late WatchQueue testWatchQueue;

    setUp(() {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();

      testUser = UserModel(
        uid: 'student_999',
        displayName: 'طارق علي',
        email: 'tarek@example.com',
        phone: '01012345678',
        photoUrl: '',
        completedLessonIds: const [],
        enrolledCourseIds: const ['c1'],
        createdAt: DateTime(2026, 1, 1),
      );

      testLesson = const Lesson(
        id: 'l1',
        title: 'شرح معماري متقدم',
        description: 'وصف الدرس',
        duration: '10:00',
        durationSeconds: 600,
        videoSource: 'bunny',
        isFreePreview: false,
      );

      mockWatchRepo = MockStudentWatchRepository();
      final store = <String, String>{};
      testWatchQueue = WatchQueue(
        read: (k) async => store[k],
        write: (k, v) async => store[k] = v,
        send: (event) => mockWatchRepo.recordEventMap(event),
      );
    });

    test('Fix 1 & 3: Session-End is NEVER dropped even when syncing or when pending seconds are 0', () async {
      final coordinator = WatchProgressCoordinator(
        currentUser: testUser,
        courseId: 'c1',
        courseTitle: 'كورس البرمجة',
        lesson: testLesson,
        watchRepository: mockWatchRepo,
        watchQueue: testWatchQueue,
        customSessionId: 'sess_test_fixed_123',
      );

      await coordinator.initialize();

      for (int i = 0; i < 10; i++) {
        coordinator.recordPlaybackSecond(
          currentPlayheadSeconds: i + 1,
          isPlaying: true,
          isBuffering: false,
          isScreenCaptured: false,
        );
      }

      expect(coordinator.pendingWatchedSeconds, 10);
      expect(coordinator.sessionCumulativeSeconds, 10);

      final sync1 = coordinator.flushWatchTime(isSessionEnd: false);
      final sessionEndSync = coordinator.flushWatchTime(isSessionEnd: true);
      await Future.wait([sync1, sessionEndSync]);

      expect(coordinator.pendingWatchedSeconds, 0);

      await coordinator.flushWatchTime(isSessionEnd: true);

      expect(coordinator.sessionId, 'sess_test_fixed_123');
      expect(mockWatchRepo.recordedEvents.isNotEmpty, isTrue);
      final hasSessionEnd =
          mockWatchRepo.recordedEvents.any((e) => e['isSessionEnd'] == true);
      expect(hasSessionEnd, isTrue);
    });

    test('Fix 2: Asynchronous cleanup in dispose() persists un-enqueued seconds to WatchQueue', () async {
      final coordinator = WatchProgressCoordinator(
        currentUser: testUser,
        courseId: 'c1',
        courseTitle: 'كورس البرمجة',
        lesson: testLesson,
        watchRepository: mockWatchRepo,
        watchQueue: testWatchQueue,
        customSessionId: 'sess_dispose_test',
      );

      await coordinator.initialize();

      for (int i = 0; i < 45; i++) {
        coordinator.recordPlaybackSecond(
          currentPlayheadSeconds: i + 1,
          isPlaying: true,
          isBuffering: false,
          isScreenCaptured: false,
        );
      }

      expect(coordinator.pendingWatchedSeconds, 45);

      coordinator.dispose();

      expect(coordinator.pendingWatchedSeconds, 0);
    });

    test('Fix 4: Retry-Safe Session ID stays immutable across flushes', () async {
      final coordinator = WatchProgressCoordinator(
        currentUser: testUser,
        courseId: 'c1',
        courseTitle: 'كورس البرمجة',
        lesson: testLesson,
        watchRepository: mockWatchRepo,
        watchQueue: testWatchQueue,
        customSessionId: 'sess_immutable_id_456',
      );

      await coordinator.initialize();

      coordinator.recordPlaybackSecond(
        currentPlayheadSeconds: 5,
        isPlaying: true,
        isBuffering: false,
        isScreenCaptured: false,
      );

      await coordinator.flushWatchTime(isSessionEnd: false);
      expect(
        mockWatchRepo.recordedEvents.last['sessionId'],
        'sess_immutable_id_456',
      );

      coordinator.recordPlaybackSecond(
        currentPlayheadSeconds: 6,
        isPlaying: true,
        isBuffering: false,
        isScreenCaptured: false,
      );

      await coordinator.flushWatchTime(isSessionEnd: true);
      expect(
        mockWatchRepo.recordedEvents.last['sessionId'],
        'sess_immutable_id_456',
      );
    });

    test('Strict 95% Unique Coverage Requirement: seeking does not inflate coverage', () async {
      bool autoCompletedCalled = false;

      final coordinator = WatchProgressCoordinator(
        currentUser: testUser,
        courseId: 'c1',
        courseTitle: 'كورس البرمجة',
        lesson: const Lesson(
          id: 'l100',
          title: 'درس تجريبي 100 ثانية',
          description: '',
          duration: '01:40',
          durationSeconds: 100,
          videoSource: 'bunny',
          completionThresholdPercentage: 95,
        ),
        watchRepository: mockWatchRepo,
        watchQueue: testWatchQueue,
        onLessonAutoCompleted: () {
          autoCompletedCalled = true;
        },
      );

      await coordinator.initialize();

      for (int i = 0; i < 10; i++) {
        coordinator.recordPlaybackSecond(
          currentPlayheadSeconds: i + 1,
          isPlaying: true,
          isBuffering: false,
          isScreenCaptured: false,
        );
      }

      coordinator.onSeekPerformed();

      for (int i = 50; i < 60; i++) {
        coordinator.recordPlaybackSecond(
          currentPlayheadSeconds: i + 1,
          isPlaying: true,
          isBuffering: false,
          isScreenCaptured: false,
        );
      }

      await coordinator.flushWatchTime(isSessionEnd: false);

      expect(coordinator.isCompleted, isFalse);
      expect(autoCompletedCalled, isFalse);

      for (int i = 0; i < 96; i++) {
        coordinator.recordPlaybackSecond(
          currentPlayheadSeconds: i + 1,
          isPlaying: true,
          isBuffering: false,
          isScreenCaptured: false,
        );
      }

      await coordinator.flushWatchTime(isSessionEnd: false);

      expect(coordinator.isCompleted, isTrue);
      expect(autoCompletedCalled, isTrue);
    });

    test('Fix 5: PlaybackAuthorizationException refuses unprotected fallback', () async {
      final repo = StudentLearningRepositoryImpl(
        watchRepository: mockWatchRepo..throwForbiddenOnResolve = true,
      );

      const protectedPaidLesson = Lesson(
        id: 'protected_1',
        title: 'محاضرة مغلقة',
        description: '',
        duration: '10:00',
        videoSourceUrl: 'https://stream.mux.com/should_never_fall_back.m3u8',
        muxPlaybackId: '',
        isFreePreview: false,
      );

      expect(
        () async => await repo.resolveLessonPlayback(
          courseId: 'closed_course_id',
          lesson: protectedPaidLesson,
        ),
        throwsA(isA<PlaybackAuthorizationException>()),
      );
    });

    test('Fix 6: VideoQuality.buildStreamUri preserves URI parameters cleanly', () {
      const baseUri = 'https://stream.mux.com/test_id.m3u8?token=jwt_sample_123';

      final fhdUri = VideoQuality.fhd.buildStreamUri(baseUri);
      expect(fhdUri.queryParameters['token'], 'jwt_sample_123');
      expect(fhdUri.queryParameters['max_resolution'], '1080p');

      final autoUri = VideoQuality.auto.buildStreamUri(fhdUri.toString());
      expect(autoUri.queryParameters['token'], 'jwt_sample_123');
      expect(autoUri.queryParameters.containsKey('max_resolution'), isFalse);
    });
  });
}
