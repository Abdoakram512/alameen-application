import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:secure_screen_app/models/lesson.dart';
import 'package:secure_screen_app/models/user_profile.dart';
import 'package:secure_screen_app/screens/student/video_player/controllers/watch_progress_coordinator.dart';
import 'package:secure_screen_app/services/firestore_service.dart';
import 'package:secure_screen_app/services/watch_queue.dart';

class MockFirestoreService extends Fake implements FirestoreService {
  final List<Map<String, dynamic>> recordedEvents = [];
  bool simulateNetworkFailure = false;
  int networkFailureCount = 0;

  @override
  Future<void> recordWatchEvent(Map<String, dynamic> event) async {
    if (simulateNetworkFailure) {
      networkFailureCount++;
      throw Exception('Network unavailable (offline)');
    }
    recordedEvents.add(Map<String, dynamic>.from(event));
  }

  @override
  Future<String?> getLatestLessonCoverage({
    required String uid,
    required String courseId,
    required String lessonId,
  }) async {
    return null;
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

  group('Durable Offline Synchronization — 7 Scenario Verification Tests', () {
    late UserModel testUser;
    late Lesson testLesson;
    late MockFirestoreService mockFirestore;
    late Map<String, String> inMemoryStore;
    late WatchQueue testQueue;

    setUp(() {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();

      testUser = UserModel(
        uid: 'student_offline_test_1',
        email: 'student_offline@alameen.com',
        displayName: 'متدرب التجربة الحرة',
        phone: '01012345678',
        photoUrl: '',
        completedLessonIds: const [],
        enrolledCourseIds: const ['c_offline_1'],
        createdAt: DateTime(2026, 1, 1),
      );

      testLesson = const Lesson(
        id: 'l_offline_101',
        title: 'درس البرمجة المتقدمة والمزامنة',
        description: 'شرح تفصيلي للمزامنة',
        duration: '20:00', // 1200 seconds
        muxPlaybackId: 'fake_mux_id',
        isFreePreview: false,
      );

      mockFirestore = MockFirestoreService();
      inMemoryStore = <String, String>{};

      testQueue = WatchQueue(
        read: (k) async => inMemoryStore[k],
        write: (k, v) async => inMemoryStore[k] = v,
        send: (event) => mockFirestore.recordWatchEvent(event),
      );
    });

    // Scenario 1: Normal Navigation (PopScope / prepareToLeave)
    test('Scenario 1: Normal Navigation ensures flushWatchTime(isSessionEnd: true) completes and saves position', () async {
      final coordinator = WatchProgressCoordinator(
        currentUser: testUser,
        courseId: 'c_offline_1',
        courseTitle: 'كورس الأساسيات',
        lesson: testLesson,
        firestoreService: mockFirestore,
        watchQueue: testQueue,
      );
      await coordinator.initialize();

      // Student plays 45 seconds
      for (int i = 0; i < 45; i++) {
        coordinator.recordPlaybackSecond(
          currentPlayheadSeconds: i + 1,
          isPlaying: true,
          isBuffering: false,
          isScreenCaptured: false,
        );
      }
      expect(coordinator.pendingWatchedSeconds, 45);

      // Student navigates away (prepareToLeave)
      await coordinator.prepareToLeave(45000);

      // Check events sent
      expect(mockFirestore.recordedEvents.length, 1);
      final event = mockFirestore.recordedEvents.first;
      expect(event['seconds'], 45);
      expect(event['isSessionEnd'], true);
      expect(coordinator.pendingWatchedSeconds, 0);

      // Check position was saved asynchronously in SharedPreferencesAsync
      final savedPos = await SharedPreferencesAsync().getInt(coordinator.positionKey);
      expect(savedPos, 45000);
    });

    // Scenario 2: Immediate Pause after Checkpoint
    test('Scenario 2: Immediate Pause after checkpoint flushes session-end with zero pending seconds without dropping session', () async {
      final coordinator = WatchProgressCoordinator(
        currentUser: testUser,
        courseId: 'c_offline_1',
        courseTitle: 'كورس الأساسيات',
        lesson: testLesson,
        firestoreService: mockFirestore,
        watchQueue: testQueue,
      );
      await coordinator.initialize();

      // Student watches 300 seconds -> triggers flush
      for (int i = 0; i < 300; i++) {
        coordinator.recordPlaybackSecond(
          currentPlayheadSeconds: i + 1,
          isPlaying: true,
          isBuffering: false,
          isScreenCaptured: false,
        );
      }
      await coordinator.flushWatchTime(isSessionEnd: false);
      expect(mockFirestore.recordedEvents.length, 1);
      expect(mockFirestore.recordedEvents[0]['seconds'], 300);
      expect(mockFirestore.recordedEvents[0]['isSessionEnd'], isFalse);

      // Student immediately hits pause 1 second later (0 pending seconds)
      expect(coordinator.pendingWatchedSeconds, 0);
      await coordinator.flushWatchTime(isSessionEnd: true);

      // Session-end event is NEVER dropped even with 0 pending seconds
      expect(mockFirestore.recordedEvents.length, 2);
      expect(mockFirestore.recordedEvents[1]['seconds'], 0);
      expect(mockFirestore.recordedEvents[1]['isSessionEnd'], true);
    });

    // Scenario 3: Backgrounding / Inactive App Lifecycle
    test('Scenario 3: Backgrounding triggers prepareToLeave and persists progress and presence removal', () async {
      final coordinator = WatchProgressCoordinator(
        currentUser: testUser,
        courseId: 'c_offline_1',
        courseTitle: 'كورس الأساسيات',
        lesson: testLesson,
        firestoreService: mockFirestore,
        watchQueue: testQueue,
      );
      await coordinator.initialize();

      // Watched 80 seconds
      for (int i = 0; i < 80; i++) {
        coordinator.recordPlaybackSecond(
          currentPlayheadSeconds: i + 1,
          isPlaying: true,
          isBuffering: false,
          isScreenCaptured: false,
        );
      }

      // App goes background (lifecycle pause / prepareToLeave)
      await coordinator.prepareToLeave(80000);

      expect(mockFirestore.recordedEvents.length, 1);
      expect(mockFirestore.recordedEvents.first['seconds'], 80);
      expect(mockFirestore.recordedEvents.first['isSessionEnd'], true);

      final pos = await SharedPreferencesAsync().getInt(coordinator.positionKey);
      expect(pos, 80000);
    });

    // Scenario 4: App Termination Simulation (dispose() cleans up pending seconds into WatchQueue)
    test('Scenario 4: App Termination simulation via dispose() safely enqueues un-flushed seconds into persistent queue', () async {
      final coordinator = WatchProgressCoordinator(
        currentUser: testUser,
        courseId: 'c_offline_1',
        courseTitle: 'كورس الأساسيات',
        lesson: testLesson,
        firestoreService: mockFirestore,
        watchQueue: testQueue,
      );
      await coordinator.initialize();

      for (int i = 0; i < 35; i++) {
        coordinator.recordPlaybackSecond(
          currentPlayheadSeconds: i + 1,
          isPlaying: true,
          isBuffering: false,
          isScreenCaptured: false,
        );
      }
      expect(coordinator.pendingWatchedSeconds, 35);

      // Sudden disposal
      coordinator.dispose();
      expect(coordinator.pendingWatchedSeconds, 0);

      // Allow microtask / queue write to settle in storage
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final queueKey = 'watch.queue.v1.${testUser.uid}';
      expect(inMemoryStore[queueKey], isNotNull);
      expect(inMemoryStore[queueKey]!.contains('35'), isTrue);
    });

    // Scenario 5: Offline Exit (network failure leaves events queued locally)
    test('Scenario 5: Offline Exit retains pending events in local storage when server is unreachable', () async {
      mockFirestore.simulateNetworkFailure = true;

      final coordinator = WatchProgressCoordinator(
        currentUser: testUser,
        courseId: 'c_offline_1',
        courseTitle: 'كورس الأساسيات',
        lesson: testLesson,
        firestoreService: mockFirestore,
        watchQueue: testQueue,
      );
      await coordinator.initialize();

      for (int i = 0; i < 120; i++) {
        coordinator.recordPlaybackSecond(
          currentPlayheadSeconds: i + 1,
          isPlaying: true,
          isBuffering: false,
          isScreenCaptured: false,
        );
      }

      // Flush while offline
      await coordinator.flushWatchTime(isSessionEnd: true);

      // Zero events reached mockFirestore due to offline failure
      expect(mockFirestore.recordedEvents.isEmpty, isTrue);
      expect(mockFirestore.networkFailureCount, greaterThan(0));

      // But local storage has the queued events safe!
      final queueKey = 'watch.queue.v1.${testUser.uid}';
      expect(inMemoryStore[queueKey], isNotNull);
      expect(inMemoryStore[queueKey]!.contains('120'), isTrue);
    });

    // Scenario 6: Restart & Restoration (flushes offline events when back online)
    test('Scenario 6: App Restart restores queued offline events and successfully syncs to Firestore', () async {
      // Simulate state where 2 events were queued while offline
      mockFirestore.simulateNetworkFailure = true;
      await testQueue.enqueue(
        uid: testUser.uid,
        courseId: 'c_offline_1',
        lessonId: testLesson.id,
        seconds: 180,
        sessionId: 'sess_offline_prev',
        isSessionEnd: false,
      );
      await testQueue.enqueue(
        uid: testUser.uid,
        courseId: 'c_offline_1',
        lessonId: testLesson.id,
        seconds: 60,
        sessionId: 'sess_offline_prev',
        isSessionEnd: true,
      );

      // Confirm events are in storage
      final queueKey = 'watch.queue.v1.${testUser.uid}';
      expect(inMemoryStore[queueKey], isNotNull);

      // Now device comes online (restart / reconnection)
      mockFirestore.simulateNetworkFailure = false;
      await testQueue.flush(testUser.uid);

      // Both events are now recorded in Firestore
      expect(mockFirestore.recordedEvents.length, 2);
      expect(mockFirestore.recordedEvents[0]['seconds'], 180);
      expect(mockFirestore.recordedEvents[1]['seconds'], 60);
      expect(mockFirestore.recordedEvents[1]['isSessionEnd'], true);

      // Queue is now empty
      expect(inMemoryStore[queueKey], '[]');
    });

    // Scenario 7: Repeated Sync with Same Session ID (Idempotency)
    test('Scenario 7: Repeated Sync with identical session ID remains idempotent and safe', () async {
      final coordinator = WatchProgressCoordinator(
        currentUser: testUser,
        courseId: 'c_offline_1',
        courseTitle: 'كورس الأساسيات',
        lesson: testLesson,
        firestoreService: mockFirestore,
        watchQueue: testQueue,
        customSessionId: 'sess_idempotent_fixed_999',
      );
      await coordinator.initialize();

      for (int i = 0; i < 50; i++) {
        coordinator.recordPlaybackSecond(
          currentPlayheadSeconds: i + 1,
          isPlaying: true,
          isBuffering: false,
          isScreenCaptured: false,
        );
      }
      await coordinator.flushWatchTime(isSessionEnd: false);

      expect(mockFirestore.recordedEvents.length, 1);
      expect(mockFirestore.recordedEvents.first['sessionId'], 'sess_idempotent_fixed_999');

      // Attempting repeated flush without new seconds does not emit redundant write
      await coordinator.flushWatchTime(isSessionEnd: false);
      expect(mockFirestore.recordedEvents.length, 1);
    });
  });
}
