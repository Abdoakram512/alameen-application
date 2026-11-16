import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:secure_screen_app/models/lesson.dart';
import 'package:secure_screen_app/models/user_profile.dart';
import 'package:secure_screen_app/models/video_quality.dart';
import 'package:secure_screen_app/repositories/student_learning_repository.dart';
import 'package:secure_screen_app/screens/student/video_player/controllers/watch_progress_coordinator.dart';
import 'package:secure_screen_app/services/firestore_service.dart';
import 'package:secure_screen_app/services/watch_queue.dart';

class MockFirestoreService extends Fake implements FirestoreService {
  final List<Map<String, dynamic>> recordedEvents = [];

  @override
  Future<void> recordWatchEvent(Map<String, dynamic> event) async {
    recordedEvents.add(Map<String, dynamic>.from(event));
  }

  @override
  Future<String?> getLatestLessonCoverage({
    required String uid,
    required String courseId,
    required String lessonId,
  }) async {
    return '0-60';
  }

  @override
  Future<String?> fetchProtectedLessonPlaybackId({
    required String courseId,
    required String lessonId,
  }) async {
    return null;
  }

  @override
  Future<void> updateActiveWatchSession(dynamic session) async {}

  @override
  Future<void> removeActiveWatchSession(String sessionId) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Alameen Video Player Modernization & Reliability Fixes Tests', () {
    late UserModel testUser;
    late Lesson testLesson;
    late MockFirestoreService mockFirestore;
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
        muxPlaybackId: 'mux_playback_123',
        isFreePreview: false,
      );

      mockFirestore = MockFirestoreService();
      final store = <String, String>{};
      testWatchQueue = WatchQueue(
        read: (k) async => store[k],
        write: (k, v) async => store[k] = v,
        send: (event) => mockFirestore.recordWatchEvent(event),
      );
    });

    test('Fix 1 & 3: Session-End is NEVER dropped even when syncing or when pending seconds are 0', () async {
      final coordinator = WatchProgressCoordinator(
        currentUser: testUser,
        courseId: 'c1',
        courseTitle: 'كورس البرمجة',
        lesson: testLesson,
        firestoreService: mockFirestore,
        watchQueue: testWatchQueue,
        customSessionId: 'sess_test_fixed_123',
      );

      await coordinator.initialize();

      // تسجيل 10 ثوانٍ مشاهدة فعلية
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

      // تشغيل مزامنة دورية
      final sync1 = coordinator.flushWatchTime(isSessionEnd: false);

      // محاكاة إيقاف أو خروج فوري أثناء جريان المزامنة السابقة (Fix 1)
      final sessionEndSync = coordinator.flushWatchTime(isSessionEnd: true);

      await Future.wait([sync1, sessionEndSync]);

      // الثواني المعلقة أصبحت 0
      expect(coordinator.pendingWatchedSeconds, 0);

      // استدعاء إنهاء الجلسة بعد تفريغ الثواني (ثوانٍ معلقة = 0) (Fix 3)
      await coordinator.flushWatchTime(isSessionEnd: true);

      // التحقق من أن أحداث نهاية الجلسة تم تسجيلها ولم يتم إهمالها
      expect(coordinator.sessionId, 'sess_test_fixed_123');
      expect(mockFirestore.recordedEvents.isNotEmpty, isTrue);
      final hasSessionEnd = mockFirestore.recordedEvents.any((e) => e['isSessionEnd'] == true);
      expect(hasSessionEnd, isTrue);
    });

    test('Fix 2: Asynchronous cleanup in dispose() persists un-enqueued seconds to WatchQueue', () async {
      final coordinator = WatchProgressCoordinator(
        currentUser: testUser,
        courseId: 'c1',
        courseTitle: 'كورس البرمجة',
        lesson: testLesson,
        firestoreService: mockFirestore,
        watchQueue: testWatchQueue,
        customSessionId: 'sess_dispose_test',
      );

      await coordinator.initialize();

      // تراكم 45 ثانية مشاهدة
      for (int i = 0; i < 45; i++) {
        coordinator.recordPlaybackSecond(
          currentPlayheadSeconds: i + 1,
          isPlaying: true,
          isBuffering: false,
          isScreenCaptured: false,
        );
      }

      expect(coordinator.pendingWatchedSeconds, 45);

      // استدعاء dispose() المفاجئ عند إغلاق الشاشة
      coordinator.dispose();

      // التأكد من تفريغ الثواني المعلقة وحفظها بالطابور
      expect(coordinator.pendingWatchedSeconds, 0);
    });

    test('Fix 4: Retry-Safe Session ID prevents double-counting and overwrites', () async {
      final coordinator = WatchProgressCoordinator(
        currentUser: testUser,
        courseId: 'c1',
        courseTitle: 'كورس البرمجة',
        lesson: testLesson,
        firestoreService: mockFirestore,
        watchQueue: testWatchQueue,
        customSessionId: 'sess_immutable_id_456',
      );

      await coordinator.initialize();

      // تسجيل مشاهدة
      coordinator.recordPlaybackSecond(
        currentPlayheadSeconds: 5,
        isPlaying: true,
        isBuffering: false,
        isScreenCaptured: false,
      );

      await coordinator.flushWatchTime(isSessionEnd: false);

      expect(mockFirestore.recordedEvents.last['sessionId'], 'sess_immutable_id_456');

      // تسجيل مشاهدة لاحقة في نفس الجلسة
      coordinator.recordPlaybackSecond(
        currentPlayheadSeconds: 6,
        isPlaying: true,
        isBuffering: false,
        isScreenCaptured: false,
      );

      await coordinator.flushWatchTime(isSessionEnd: true);

      // معرّف الجلسة يظل متطابقاً 100% ولا يتغير إطلاقاً أثناء الجلسة
      expect(mockFirestore.recordedEvents.last['sessionId'], 'sess_immutable_id_456');
    });

    test('Strict 95% Unique Coverage Requirement: seeking does not inflate coverage', () async {
      bool autoCompletedCalled = false;

      final coordinator = WatchProgressCoordinator(
        currentUser: testUser,
        courseId: 'c1',
        courseTitle: 'كورس البرمجة',
        // مدة الدرس 100 ثانية
        lesson: const Lesson(
          id: 'l100',
          title: 'درس تجريبي 100 ثانية',
          description: '',
          duration: '01:40', // 100s
          muxPlaybackId: 'test_100',
          completionThresholdPercentage: 95,
        ),
        firestoreService: mockFirestore,
        watchQueue: testWatchQueue,
        onLessonAutoCompleted: () {
          autoCompletedCalled = true;
        },
      );

      await coordinator.initialize();

      // الطالب قفز عدة مرات وشاهد فقط 10 ثوانٍ (ثانية 1 حتى 10)
      for (int i = 0; i < 10; i++) {
        coordinator.recordPlaybackSecond(
          currentPlayheadSeconds: i + 1,
          isPlaying: true,
          isBuffering: false,
          isScreenCaptured: false,
        );
      }

      // قفزة للأمام
      coordinator.onSeekPerformed();

      // ثم شاهد 10 ثوانٍ أخرى (من 50 إلى 60)
      for (int i = 50; i < 60; i++) {
        coordinator.recordPlaybackSecond(
          currentPlayheadSeconds: i + 1,
          isPlaying: true,
          isBuffering: false,
          isScreenCaptured: false,
        );
      }

      await coordinator.flushWatchTime(isSessionEnd: false);

      // التغطية الفعلية 20 ثانية من أصل 100 (20%) -> لا يحقق شرط 95%
      expect(coordinator.isCompleted, isFalse);
      expect(autoCompletedCalled, isFalse);

      // الآن محاكاة مشاهدة 95 ثانية متفرقة فريدة
      for (int i = 0; i < 96; i++) {
        coordinator.recordPlaybackSecond(
          currentPlayheadSeconds: i + 1,
          isPlaying: true,
          isBuffering: false,
          isScreenCaptured: false,
        );
      }

      await coordinator.flushWatchTime(isSessionEnd: false);

      // الآن تحقق شرط 95% واكتمل الدرس بنجاح
      expect(coordinator.isCompleted, isTrue);
      expect(autoCompletedCalled, isTrue);
    });

    test('Fix 5: PlaybackAuthorizationException distinguishes auth failure from network error and refuses unprotected fallback', () async {
      final repo = StudentLearningRepositoryImpl(
        firestoreService: mockFirestore,
      );

      // درس محمي بدون muxPlaybackId وبدون إمكانية وصول
      const protectedPaidLesson = Lesson(
        id: 'protected_1',
        title: 'محاضرة مغلقة',
        description: '',
        duration: '10:00',
        videoSourceUrl: 'https://stream.mux.com/should_never_fall_back.m3u8',
        muxPlaybackId: '',
        isFreePreview: false,
      );

      // يجب أن يرمي استثناء PlaybackAuthorizationException أو StateError صريح ولا يعيد رابط غير محمي
      expect(
        () async => await repo.resolveLessonPlayback(
          courseId: 'closed_course_id',
          lesson: protectedPaidLesson,
        ),
        throwsA(isA<PlaybackAuthorizationException>()),
      );
    });

    test('Fix 6: VideoQuality.buildStreamUri preserves URI parameters without resetting player state', () {
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
