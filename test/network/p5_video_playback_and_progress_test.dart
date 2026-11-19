import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:secure_screen_app/core/di/injection_container.dart';
import 'package:secure_screen_app/core/network/api_client.dart';
import 'package:secure_screen_app/datasources/watch_remote_data_source.dart';
import 'package:secure_screen_app/features/courses/domain/entities/course_entitlement.dart';
import 'package:secure_screen_app/features/courses/presentation/cubits/course_entitlement/course_entitlement_cubit.dart';
import 'package:secure_screen_app/logic/auth/auth_cubit.dart';
import 'package:secure_screen_app/logic/auth/auth_state.dart';
import 'package:secure_screen_app/logic/courses/courses_cubit.dart';
import 'package:secure_screen_app/logic/courses/courses_state.dart';
import 'package:secure_screen_app/models/course.dart';
import 'package:secure_screen_app/models/course_access_mode.dart';
import 'package:secure_screen_app/models/course_level.dart';
import 'package:secure_screen_app/models/course_progress_policy.dart';
import 'package:secure_screen_app/models/lesson.dart';
import 'package:secure_screen_app/models/lesson_playback_data.dart';
import 'package:secure_screen_app/models/student_courses_data.dart';
import 'package:secure_screen_app/models/student_dashboard_data.dart';
import 'package:secure_screen_app/models/user_profile.dart';
import 'package:secure_screen_app/repositories/impl/student_watch_repository_impl.dart';
import 'package:secure_screen_app/repositories/student_auth_repository.dart';
import 'package:secure_screen_app/repositories/student_courses_repository.dart';
import 'package:secure_screen_app/repositories/student_payment_repository.dart';
import 'package:secure_screen_app/repositories/student_watch_repository.dart';
import 'package:secure_screen_app/screens/security/security_protection_watcher.dart';
import 'package:secure_screen_app/screens/student/video_player/controllers/watch_progress_coordinator.dart';
import 'package:secure_screen_app/services/watch_queue.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockStudentCoursesRepository extends Mock
    implements StudentCoursesRepository {}

class MockStudentPaymentRepository extends Mock
    implements StudentPaymentRepository {}

class MockStudentAuthRepository extends Mock implements StudentAuthRepository {}

void main() {
  late SharedPreferencesAsync prefs;

  UserModel makeUser({
    String uid = '101',
    List<String> enrolledCourseIds = const ['10'],
    List<String> completedLessonIds = const [],
  }) {
    return UserModel(
      uid: uid,
      id: int.tryParse(uid) ?? 101,
      displayName: 'طالب تجريبي',
      email: 'student$uid@alameen-center.online',
      photoUrl: '',
      enrolledCourseIds: enrolledCourseIds,
      completedLessonIds: completedLessonIds,
      createdAt: DateTime(2026, 1, 1),
    );
  }

  Lesson makeLesson({
    String id = '43',
    String slug = 'lesson-43',
    int durationSeconds = 200,
    bool isFreePreview = false,
    bool isCompleted = false,
    bool isAccessible = true,
    int watchedSeconds = 0,
    int lastPositionSeconds = 0,
  }) {
    return Lesson(
      id: id,
      slug: slug,
      title: 'درس $id',
      description: 'وصف',
      duration: '03:20',
      durationSeconds: durationSeconds,
      isFreePreview: isFreePreview,
      isCompleted: isCompleted,
      isAccessible: isAccessible,
      watchedSeconds: watchedSeconds,
      lastPositionSeconds: lastPositionSeconds,
      videoSource: 'bunny',
    );
  }

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    prefs = SharedPreferencesAsync();
    await sl.reset();
  });

  tearDown(() async {
    await sl.reset();
  });

  group('Phase P5 — 15 Comprehensive Video Playback, Progress & Security Regression Tests', () {
    // 1. Authorized lesson playback via Laravel
    test('01. Authorized lesson playback resolves signed HLS URL and progress metadata via Laravel', () async {
      final mockApiClient = MockApiClient();
      final remote = WatchRemoteDataSourceImpl(apiClient: mockApiClient);
      final watchRepo = StudentWatchRepositoryImpl(remoteDataSource: remote);
      final futureExp = DateTime.now()
              .toUtc()
              .add(const Duration(hours: 2))
              .millisecondsSinceEpoch ~/
          1000;
      final hlsUrl =
          'https://cdn.alameen-center.online/bunny/43/playlist.m3u8?expires=$futureExp';

      when(() => mockApiClient.get('/student/courses/course-10/lessons/lesson-43'))
          .thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(
            path: '/student/courses/course-10/lessons/lesson-43',
          ),
          statusCode: 200,
          data: {
            'data': {
              'course': {'id': 10, 'slug': 'course-10', 'title': 'الأساسيات'},
              'current_video': {
                'id': 43,
                'slug': 'lesson-43',
                'title': 'مقدمة',
                'duration_seconds': 200,
                'video_source': 'bunny',
                'is_accessible': true,
              },
              'playback': {
                'hls_url': hlsUrl,
                'watermark_text': 'STU-101',
                'expires_in': 7200,
              },
              'current_progress': {
                'watched_seconds': 50,
                'last_position_seconds': 48,
                'is_completed': false,
              },
            },
          },
        ),
      );

      final result = await watchRepo.resolveLessonPlayback(
        courseSlugOrId: 'course-10',
        lesson: makeLesson(),
      );

      expect(result.streamUrl, equals(hlsUrl));
      expect(result.watermarkText, equals('STU-101'));
      expect(result.watchedSeconds, equals(50));
      expect(result.lastPositionSeconds, equals(48));
      expect(result.isCompleted, isFalse);
    });

    // 2. Unauthorized playback rejection (401 & 403)
    test('02. Unauthorized or forbidden lesson playback throws PlaybackAuthorizationException without fallback', () async {
      final mockApiClient = MockApiClient();
      final remote = WatchRemoteDataSourceImpl(apiClient: mockApiClient);
      final watchRepo = StudentWatchRepositoryImpl(remoteDataSource: remote);

      for (final statusCode in [401, 403]) {
        final req = RequestOptions(
          path: '/student/courses/course-10/lessons/lesson-locked',
        );
        when(
          () => mockApiClient.get(
            '/student/courses/course-10/lessons/lesson-locked',
          ),
        ).thenThrow(
          DioException(
            requestOptions: req,
            type: DioExceptionType.badResponse,
            response: Response(
              requestOptions: req,
              statusCode: statusCode,
              data: {'message': 'Denied $statusCode'},
            ),
          ),
        );

        await expectLater(
          () => watchRepo.resolveLessonPlayback(
            courseSlugOrId: 'course-10',
            lesson: makeLesson(slug: 'lesson-locked'),
          ),
          throwsA(
            isA<PlaybackAuthorizationException>()
                .having((e) => e.statusCode, 'statusCode', statusCode),
          ),
        );
      }
    });

    // 3. Handling expired signed playback URLs
    test('03. Expired signed playback URL is detected by expiry helper and rejected if renewal also fails/expires', () async {
      final mockApiClient = MockApiClient();
      final remote = WatchRemoteDataSourceImpl(apiClient: mockApiClient);
      final watchRepo = StudentWatchRepositoryImpl(remoteDataSource: remote);

      const expiredUrl =
          'https://cdn.alameen-center.online/bunny/43/playlist.m3u8?expires=1700000000';
      expect(
        ResolvedLessonPlayback.isSignedUrlExpiredOrExpiring(expiredUrl),
        isTrue,
      );

      when(() => mockApiClient.get('/student/courses/course-10/lessons/lesson-43'))
          .thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(
            path: '/student/courses/course-10/lessons/lesson-43',
          ),
          statusCode: 200,
          data: {
            'data': {
              'current_video': {
                'id': 43,
                'slug': 'lesson-43',
                'video_source': 'bunny',
                'is_accessible': true,
              },
              'playback': {'hls_url': expiredUrl},
            },
          },
        ),
      );

      // Token renewal fails with 403
      final tokenReq = RequestOptions(
        path: '/student/courses/course-10/lessons/lesson-43/playback-token',
      );
      when(
        () => mockApiClient.post(
          '/student/courses/course-10/lessons/lesson-43/playback-token',
        ),
      ).thenThrow(
        DioException(
          requestOptions: tokenReq,
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: tokenReq,
            statusCode: 403,
            data: {'message': 'Expired session'},
          ),
        ),
      );

      await expectLater(
        () => watchRepo.resolveLessonPlayback(
          courseSlugOrId: 'course-10',
          lesson: makeLesson(),
        ),
        throwsA(
          isA<PlaybackAuthorizationException>()
              .having((e) => e.statusCode, 'statusCode', 403),
        ),
      );
    });

    // 4. Playback token renewal flow
    test('04. Playback token renewal via POST /playback-token returns fresh signed HLS URL', () async {
      final mockApiClient = MockApiClient();
      final remote = WatchRemoteDataSourceImpl(apiClient: mockApiClient);
      final watchRepo = StudentWatchRepositoryImpl(remoteDataSource: remote);

      final futureExp = DateTime.now()
              .toUtc()
              .add(const Duration(minutes: 45))
              .millisecondsSinceEpoch ~/
          1000;
      final freshHls =
          'https://cdn.alameen-center.online/bunny/43/playlist.m3u8?expires=$futureExp';

      when(
        () => mockApiClient.post(
          '/student/courses/course-10/lessons/lesson-43/playback-token',
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(
            path: '/student/courses/course-10/lessons/lesson-43/playback-token',
          ),
          statusCode: 200,
          data: {
            'data': {
              'hls_url': freshHls,
              'embed_url': 'https://iframe.mediadelivery.net/embed/1/43',
              'watermark': 'ALAMEEN-NEW',
              'expires_in': 2700,
            },
          },
        ),
      );

      final token = await watchRepo.refreshPlaybackToken(
        courseSlugOrId: 'course-10',
        lessonSlugOrId: 'lesson-43',
      );

      expect(token.hlsUrl, equals(freshHls));
      expect(token.watermark, equals('ALAMEEN-NEW'));
      expect(token.expiresIn, equals(2700));
    });

    // 5. Resume playback from saved position (server + user-isolated local)
    test('05. Coordinator resumes position from Laravel server progress and isolates local position per uid', () async {
      final mockApiClient = MockApiClient();
      final remote = WatchRemoteDataSourceImpl(apiClient: mockApiClient);
      final watchRepo = StudentWatchRepositoryImpl(remoteDataSource: remote);

      final userA = makeUser(uid: '101');
      final coordinator = WatchProgressCoordinator(
        currentUser: userA,
        courseId: '10',
        courseSlug: 'course-10',
        courseTitle: 'دورة',
        lesson: makeLesson(id: '43', durationSeconds: 200),
        watchRepository: watchRepo,
        preferences: prefs,
        watchQueue: WatchQueue.forRepository(watchRepo, preferences: prefs),
      );
      addTearDown(coordinator.dispose);

      coordinator.seedServerProgress(
        watchedSeconds: 80,
        lastPositionSeconds: 75,
        isCompleted: false,
      );
      expect(coordinator.currentPlayheadSeconds, equals(75));
      expect(coordinator.effectiveWatchedSeconds, equals(80));

      await coordinator.savePosition(125000);
      final savedMsA = await prefs.getInt('position.101.10.43');
      final savedMsB = await prefs.getInt('position.202.10.43');
      expect(savedMsA, equals(125000));
      expect(savedMsB, isNull);
    });

    // 6. Duplicate watched intervals prevention
    test('06. Rewatching already covered seconds does NOT inflate watchedSeconds', () async {
      final mockApiClient = MockApiClient();
      final remote = WatchRemoteDataSourceImpl(apiClient: mockApiClient);
      final watchRepo = StudentWatchRepositoryImpl(remoteDataSource: remote);

      final coordinator = WatchProgressCoordinator(
        currentUser: makeUser(),
        courseId: '10',
        courseSlug: 'course-10',
        courseTitle: 'دورة',
        lesson: makeLesson(durationSeconds: 100),
        watchRepository: watchRepo,
        preferences: prefs,
        watchQueue: WatchQueue.forRepository(watchRepo, preferences: prefs),
      );
      addTearDown(coordinator.dispose);

      // Watch seconds 0..29 (30 unique seconds)
      for (int sec = 0; sec < 30; sec++) {
        coordinator.recordPlaybackSecond(
          currentPlayheadSeconds: sec,
          isPlaying: true,
          isBuffering: false,
          isScreenCaptured: false,
        );
      }
      expect(coordinator.effectiveWatchedSeconds, equals(30));

      // Seek back to 0 and rewatch 0..29 again
      coordinator.onSeekPerformed(targetPositionSeconds: 0);
      for (int sec = 0; sec < 30; sec++) {
        coordinator.recordPlaybackSecond(
          currentPlayheadSeconds: sec,
          isPlaying: true,
          isBuffering: false,
          isScreenCaptured: false,
        );
      }
      // Unique covered seconds remain strictly 30
      expect(coordinator.effectiveWatchedSeconds, equals(30));
      expect(coordinator.pendingWatchedSeconds, equals(30));
    });

    // 7. Seeking/skipped & buffering/captured intervals exclusion
    test('07. Seek jumps, buffering stalls, and screen capture intervals do not inflate watch progress', () async {
      final mockApiClient = MockApiClient();
      final remote = WatchRemoteDataSourceImpl(apiClient: mockApiClient);
      final watchRepo = StudentWatchRepositoryImpl(remoteDataSource: remote);

      final coordinator = WatchProgressCoordinator(
        currentUser: makeUser(),
        courseId: '10',
        courseSlug: 'course-10',
        courseTitle: 'دورة',
        lesson: makeLesson(durationSeconds: 100),
        watchRepository: watchRepo,
        preferences: prefs,
        watchQueue: WatchQueue.forRepository(watchRepo, preferences: prefs),
      );
      addTearDown(coordinator.dispose);

      // 1..5 valid
      for (int sec = 1; sec <= 5; sec++) {
        coordinator.recordPlaybackSecond(
          currentPlayheadSeconds: sec,
          isPlaying: true,
          isBuffering: false,
          isScreenCaptured: false,
        );
      }
      // Buffering during 6..15 -> ignored
      for (int sec = 6; sec <= 15; sec++) {
        coordinator.recordPlaybackSecond(
          currentPlayheadSeconds: sec,
          isPlaying: true,
          isBuffering: true,
          isScreenCaptured: false,
        );
      }
      // Screen capture active during 16..25 -> ignored
      for (int sec = 16; sec <= 25; sec++) {
        coordinator.recordPlaybackSecond(
          currentPlayheadSeconds: sec,
          isPlaying: true,
          isBuffering: false,
          isScreenCaptured: true,
        );
      }
      // Big seek jump directly to 99 -> skipped segment 26..98 must NOT be bridged
      coordinator.onSeekPerformed(targetPositionSeconds: 99);
      coordinator.recordPlaybackSecond(
        currentPlayheadSeconds: 99,
        isPlaying: true,
        isBuffering: false,
        isScreenCaptured: false,
      );

      expect(coordinator.effectiveWatchedSeconds, lessThanOrEqualTo(6));
      expect(coordinator.isCompleted, isFalse);
    });

    // 8. Offline progress sync & recovery (timeout & 429 retention)
    test('08. WatchQueue preserves failed offline/timeout/429 events and flushes cleanly once online', () async {
      int attempts = 0;
      final sentEvents = <Map<String, dynamic>>[];

      final queue = WatchQueue(
        read: prefs.getString,
        write: prefs.setString,
        send: (event) async {
          attempts++;
          if (attempts == 1) {
            throw DioException(
              requestOptions: RequestOptions(path: '/progress'),
              type: DioExceptionType.connectionTimeout,
            );
          }
          sentEvents.add(event);
        },
      );

      await queue.enqueue(
        uid: '101',
        courseId: '10',
        lessonId: '43',
        courseSlug: 'course-10',
        lessonSlug: 'lesson-43',
        watchedSeconds: 65,
        positionSeconds: 65,
        seconds: 65,
      );

      await expectLater(queue.flush('101'), throwsA(isA<DioException>()));
      expect(await queue.pendingCount('101'), equals(1));

      await queue.flush('101');
      expect(await queue.pendingCount('101'), equals(0));
      expect(sentEvents, hasLength(1));
      expect(sentEvents.first['watchedSeconds'], equals(65));
    });

    // 9. Logout queue clearing & multi-account isolation
    test('09. Logout clears outgoing student WatchQueue and isolates concurrent/switched accounts', () async {
      final queue = WatchQueue(
        read: prefs.getString,
        write: prefs.setString,
        send: (_) async {},
      );
      sl.registerSingleton<WatchQueue>(queue);

      await queue.enqueue(
        uid: '101',
        courseId: '10',
        lessonId: '43',
        watchedSeconds: 40,
        positionSeconds: 40,
        seconds: 40,
      );
      await queue.enqueue(
        uid: '202',
        courseId: '11',
        lessonId: '50',
        watchedSeconds: 20,
        positionSeconds: 20,
        seconds: 20,
      );

      expect(await queue.pendingCount('101'), equals(1));
      expect(await queue.pendingCount('202'), equals(1));

      final mockAuthRepo = MockStudentAuthRepository();
      when(() => mockAuthRepo.restoreSession())
          .thenAnswer((_) async => makeUser(uid: '101'));
      when(() => mockAuthRepo.logout()).thenAnswer((_) async {});

      final authCubit = AuthCubit(authRepository: mockAuthRepo);
      addTearDown(authCubit.close);
      await Future<void>.delayed(Duration.zero);
      expect(authCubit.state, isA<Authenticated>());

      await authCubit.signOut();

      expect(authCubit.state, isA<Unauthenticated>());
      expect(await queue.pendingCount('101'), equals(0));
      // Other account's queue remains untouched
      expect(await queue.pendingCount('202'), equals(1));
    });

    // 10. Sequential level unlocking enforcement
    test('10. CourseProgressPolicy locks level 2 until level 1 reaches >=95% AND server marks isAccessible true', () {
      final lvl1 = CourseLevel(
        id: '1',
        title: 'المستوى الأول',
        description: '',
        order: 1,
        isAccessible: true,
        lessons: [
          makeLesson(id: '101', isCompleted: true),
          makeLesson(id: '102', isCompleted: false),
        ],
      );
      final lvl2ServerAccessible = CourseLevel(
        id: '2',
        title: 'المستوى الثاني',
        description: '',
        order: 2,
        isAccessible: true,
        lessons: [
          makeLesson(id: '201', isAccessible: true),
        ],
      );
      final lvl2ServerLocked = lvl2ServerAccessible.copyWith(isAccessible: false);

      // Level 1 only 50% complete -> Level 2 locked
      expect(
        CourseProgressPolicy.isLevelUnlocked(
          levels: [lvl1, lvl2ServerAccessible],
          levelIndex: 1,
          isEnrolled: true,
          completedLessonIds: const {'101'},
        ),
        isFalse,
      );

      // Level 1 100% complete, server level.isAccessible == false -> STILL locked
      expect(
        CourseProgressPolicy.isLevelUnlocked(
          levels: [lvl1, lvl2ServerLocked],
          levelIndex: 1,
          isEnrolled: true,
          completedLessonIds: const {'101', '102'},
        ),
        isFalse,
      );

      // Level 1 100% complete AND server isAccessible == true -> Unlocked
      expect(
        CourseProgressPolicy.isLevelUnlocked(
          levels: [lvl1, lvl2ServerAccessible],
          levelIndex: 1,
          isEnrolled: true,
          completedLessonIds: const {'101', '102'},
        ),
        isTrue,
      );
    });

    // 11. Exact 95% threshold boundary testing (94.9% vs 95.0%)
    test('11. Strict 95% boundary: 94.9% stays incomplete/locked while 95.0% completes & unlocks next level', () async {
      // A) Course-level boundary: 18/19 = 94.73%, 19/20 = 95.0%
      final twentyLessons = List.generate(
        20,
        (i) => makeLesson(id: 'L$i', durationSeconds: 200),
      );
      final level1 = CourseLevel(
        id: '1',
        title: 'المستوى 1',
        description: '',
        order: 1,
        isAccessible: true,
        lessons: twentyLessons,
      );
      final level2 = CourseLevel(
        id: '2',
        title: 'المستوى 2',
        description: '',
        order: 2,
        isAccessible: true,
        lessons: [makeLesson(id: 'L2_1')],
      );

      final eighteenCompleted = {for (int i = 0; i < 18; i++) 'L$i'};
      expect(
        CourseProgressPolicy.isLevelUnlocked(
          levels: [level1, level2],
          levelIndex: 1,
          isEnrolled: true,
          completedLessonIds: eighteenCompleted, // 90%
        ),
        isFalse,
      );

      final nineteenCompleted = {for (int i = 0; i < 19; i++) 'L$i'};
      expect(
        CourseProgressPolicy.levelCompletionPercentage(
          level1,
          completedLessonIds: nineteenCompleted,
        ),
        equals(95.0),
      );
      expect(
        CourseProgressPolicy.isLevelUnlocked(
          levels: [level1, level2],
          levelIndex: 1,
          isEnrolled: true,
          completedLessonIds: nineteenCompleted,
        ),
        isTrue,
      );

      // B) Video-level boundary: 189/200s (94.5%) vs 190/200s (95.0%)
      final mockApiClient = MockApiClient();
      when(
        () => mockApiClient.post(
          '/student/courses/course-10/lessons/lesson-43/progress',
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/progress'),
          statusCode: 200,
          data: {
            'data': {
              'watched_seconds': 190,
              'position_seconds': 189,
              'is_completed': true,
            },
          },
        ),
      );

      final remote = WatchRemoteDataSourceImpl(apiClient: mockApiClient);
      final watchRepo = StudentWatchRepositoryImpl(remoteDataSource: remote);
      int autoCompletedCount = 0;

      final coordinator = WatchProgressCoordinator(
        currentUser: makeUser(),
        courseId: '10',
        courseSlug: 'course-10',
        courseTitle: 'دورة',
        lesson: makeLesson(durationSeconds: 200),
        watchRepository: watchRepo,
        preferences: prefs,
        watchQueue: WatchQueue.forRepository(watchRepo, preferences: prefs),
        onLessonAutoCompleted: () => autoCompletedCount++,
      );
      addTearDown(coordinator.dispose);

      // Cover seconds 0..188 => 189 unique seconds = 94.5% (< 95%)
      for (int sec = 0; sec <= 188; sec++) {
        coordinator.recordPlaybackSecond(
          currentPlayheadSeconds: sec,
          isPlaying: true,
          isBuffering: false,
          isScreenCaptured: false,
        );
      }
      await coordinator.flushWatchTime(isSessionEnd: false);
      expect(coordinator.isCompleted, isFalse);
      expect(autoCompletedCount, equals(0));

      // Watch 189 => 190 unique seconds = 95.0%
      coordinator.recordPlaybackSecond(
        currentPlayheadSeconds: 189,
        isPlaying: true,
        isBuffering: false,
        isScreenCaptured: false,
      );
      await coordinator.flushWatchTime(isSessionEnd: true);
      expect(coordinator.isCompleted, isTrue);
      expect(autoCompletedCount, equals(1));
    });

    // 12. Revoked course entitlement stops queued sync & local stale entitlement
    test('12. Revoked enrollment (403) purges WatchQueue course events and clears stale UserModel enrollment', () async {
      final mockApiClient = MockApiClient();
      final remote = WatchRemoteDataSourceImpl(apiClient: mockApiClient);
      final watchRepo = StudentWatchRepositoryImpl(remoteDataSource: remote);

      final req = RequestOptions(
        path: '/student/courses/course-10/lessons/lesson-43/progress',
      );
      when(
        () => mockApiClient.post(
          '/student/courses/course-10/lessons/lesson-43/progress',
          data: any(named: 'data'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: req,
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: req,
            statusCode: 403,
            data: {'message': 'Subscription revoked'},
          ),
        ),
      );

      final revokedIds = <String>[];
      final queue = WatchQueue.forRepository(
        watchRepo,
        preferences: prefs,
        onEnrollmentRevoked: revokedIds.add,
      );

      await queue.enqueue(
        uid: '101',
        courseId: '10',
        courseSlug: 'course-10',
        lessonId: '43',
        lessonSlug: 'lesson-43',
        watchedSeconds: 50,
        positionSeconds: 50,
        seconds: 50,
      );
      await queue.enqueue(
        uid: '101',
        courseId: '99',
        courseSlug: 'course-99',
        lessonId: '77',
        lessonSlug: 'lesson-77',
        watchedSeconds: 20,
        positionSeconds: 20,
        seconds: 20,
      );

      await expectLater(
        queue.flush('101'),
        throwsA(isA<Exception>()),
      );
      expect(revokedIds, equals(['10']));
      // Event for course 10 removed; course 99 stays queued
      expect(await queue.pendingCount('101'), equals(1));

      // AuthCubit revokes course 10 when detailed course confirms hasEnrolled == false
      final mockAuthRepo = MockStudentAuthRepository();
      when(() => mockAuthRepo.restoreSession())
          .thenAnswer((_) async => makeUser(uid: '101', enrolledCourseIds: ['10']));
      final authCubit = AuthCubit(authRepository: mockAuthRepo);
      addTearDown(authCubit.close);
      await Future<void>.delayed(Duration.zero);
      expect((authCubit.state as Authenticated).user.isEnrolled('10'), isTrue);

      authCubit.markCourseDetailEntitlement(
        const Course(
          id: '10',
          title: 'دورة مسحوبة',
          description: '',
          instructor: '',
          category: '',
          thumbnailUrl: '',
          levels: [],
          hasEnrolled: false,
          isDetailedFromAuthServer: true,
        ),
      );
      expect((authCubit.state as Authenticated).user.isEnrolled('10'), isFalse);

      // CoursesCubit syncStudentState & clearStudentSession clear active student entitlements
      final mockCoursesRepo = MockStudentCoursesRepository();
      const baseCourse = Course(
        id: '99',
        slug: 'course-99',
        title: 'دورة 99',
        description: '',
        instructor: '',
        category: '',
        thumbnailUrl: '',
        levels: [],
      );
      when(() => mockCoursesRepo.streamCourses())
          .thenAnswer((_) => const Stream.empty());
      when(() => mockCoursesRepo.getPublicCourses(forceRefresh: any(named: 'forceRefresh')))
          .thenAnswer((_) async => [baseCourse]);
      when(() => mockCoursesRepo.getStudentCourses()).thenAnswer(
        (_) async => StudentCoursesData(
          enrolledCourses: [
            EnrolledCourseItem(
              course: baseCourse,
              status: 'active',
            ),
          ],
        ),
      );
      when(() => mockCoursesRepo.getStudentDashboard()).thenAnswer(
        (_) async => const StudentDashboardData(
          enrolledCourses: [baseCourse],
          totalWatchSeconds: 420,
        ),
      );

      final coursesCubit = CoursesCubit(coursesRepository: mockCoursesRepo);
      addTearDown(coursesCubit.close);
      await Future<void>.delayed(Duration.zero);
      await coursesCubit.syncStudentState(authCubit: authCubit);
      expect((authCubit.state as Authenticated).user.isEnrolled('99'), isTrue);
      expect(
        (coursesCubit.state as CoursesLoaded).allCourses.first.hasEnrolled,
        isTrue,
      );

      coursesCubit.clearStudentSession();
      final clearedState = coursesCubit.state as CoursesLoaded;
      expect(clearedState.studentCourses, isNull);
      expect(clearedState.allCourses.first.hasEnrolled, isFalse);
    });

    // 13. Free auto-enrolled students & free preview without payment receipts + ZERO isOpenCourse bypass
    test('13. Free auto-enrolled students confirm access without receipts; CourseAccessMode.open never bypasses enrollment', () async {
      final mockCoursesRepo = MockStudentCoursesRepository();

      const autoEnrolledCourse = Course(
        id: '20',
        slug: 'free-course',
        title: 'دورة مجانية',
        description: '',
        instructor: '',
        category: '',
        thumbnailUrl: '',
        levels: [],
        price: 0,
        accessMode: CourseAccessMode.open,
        autoEnrollStudents: true,
        hasEnrolled: true,
        isDetailedFromAuthServer: true,
      );

      when(() => mockCoursesRepo.verifyStudentCourseDetails('free-course'))
          .thenAnswer((_) async => autoEnrolledCourse);

      final entitlementCubit = CourseEntitlementCubit(
        coursesRepository: mockCoursesRepo,
      );
      addTearDown(entitlementCubit.close);

      final result = await entitlementCubit.verifyCourseEntitlement(
        courseId: autoEnrolledCourse.id,
        courseSlug: autoEnrolledCourse.slug!,
        studentId: '101',
      );

      expect(result.status, equals(CourseAccessState.enrolled));
      expect(entitlementCubit.state.isCourseAuthorized('20'), isTrue);

      // Meanwhile, CourseProgressPolicy must NOT unlock non-preview lessons merely because accessMode == open
      final nonPreviewLesson = makeLesson(id: '44', isFreePreview: false);
      final previewLesson = makeLesson(id: '45', isFreePreview: true, isAccessible: true);

      expect(
        CourseProgressPolicy.lessonLockReason(
          levels: [
            CourseLevel(
              id: '1',
              title: 'L1',
              description: '',
              order: 1,
              lessons: [nonPreviewLesson, previewLesson],
            ),
          ],
          lesson: nonPreviewLesson,
          isEnrolled: false,
          completedLessonIds: const {},
        ),
        isNotNull,
      );
      expect(
        CourseProgressPolicy.lessonLockReason(
          levels: [
            CourseLevel(
              id: '1',
              title: 'L1',
              description: '',
              order: 1,
              lessons: [nonPreviewLesson, previewLesson],
            ),
          ],
          lesson: previewLesson,
          isEnrolled: false,
          completedLessonIds: const {},
        ),
        isNull,
      );
    });

    // 14. Zero obsolete Firebase video/watch calls in P5 runtime code paths
    test('14. P5 repositories, datasources, watch coordinator, and courses cubit contain zero legacy Firebase video/watch calls', () {
      final filesToInspect = [
        'lib/datasources/watch_remote_data_source.dart',
        'lib/repositories/impl/student_watch_repository_impl.dart',
        'lib/repositories/impl/student_courses_repository_impl.dart',
        'lib/screens/student/video_player/controllers/watch_progress_coordinator.dart',
        'lib/logic/courses/courses_cubit.dart',
      ];

      final forbiddenLegacyPatterns = [
        'cloud_firestore',
        'watch_logs',
        'active_watch_sessions',
        'protected_lessons',
        'getSignedPlaybackUrl',
        'security_alerts',
        'FirestoreService',
      ];

      for (final relativePath in filesToInspect) {
        final content = File(relativePath).readAsStringSync();
        for (final pattern in forbiddenLegacyPatterns) {
          expect(
            content.contains(pattern),
            isFalse,
            reason: '$relativePath should not reference legacy P5 symbol "$pattern"',
          );
        }
      }
    });

    // 15. Security violation reporting via POST /student/security/violation
    testWidgets('15. SecurityProtectionWatcher sends violation payload with type, video_id, and non-PII details', (tester) async {
      final mockApiClient = MockApiClient();
      when(
        () => mockApiClient.post(
          '/student/security/violation',
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/student/security/violation'),
          statusCode: 200,
          data: {'message': 'Recorded'},
        ),
      );

      final key = GlobalKey<SecurityProtectionWatcherState>();
      await tester.pumpWidget(
        MaterialApp(
          home: SecurityProtectionWatcher(
            key: key,
            studentId: '101',
            studentEmail: 'student101@alameen-center.online',
            apiClient: mockApiClient,
            child: Builder(
              builder: (context) {
                ScreenProtectionScope.setActiveVideoId(context, 43);
                return const Scaffold(body: Text('مشغل محمي'));
              },
            ),
          ),
        ),
      );
      await tester.pump();

      await key.currentState?.reportSecurityViolationForTesting('screen_recording');

      verify(
        () => mockApiClient.post(
          '/student/security/violation',
          data: any(
            named: 'data',
            that: isA<Map<String, dynamic>>()
                .having((m) => m['type'], 'type', 'screen_recording')
                .having((m) => m['video_id'], 'video_id', 43)
                .having(
                  (m) => m['details'],
                  'details',
                  allOf(contains('platform:'), isNot(contains('@'))),
                ),
          ),
        ),
      ).called(1);
    });
  });
}
