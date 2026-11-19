import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secure_screen_app/core/network/api_client.dart';
import 'package:secure_screen_app/datasources/watch_remote_data_source.dart';
import 'package:secure_screen_app/models/lesson.dart';
import 'package:secure_screen_app/repositories/impl/student_watch_repository_impl.dart';
import 'package:secure_screen_app/repositories/student_learning_repository.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  late MockApiClient mockApiClient;
  late WatchRemoteDataSourceImpl remoteDataSource;
  late StudentWatchRepositoryImpl watchRepository;
  late StudentLearningRepositoryImpl learningRepository;

  const baseLesson = Lesson(
    id: '43',
    slug: 'lesson-intro',
    title: 'الدرس الأول',
    description: 'مقدمة',
    duration: '10:00',
    durationSeconds: 600,
    isFreePreview: false,
    videoSource: 'bunny',
    isAccessible: true,
  );

  setUp(() {
    mockApiClient = MockApiClient();
    remoteDataSource = WatchRemoteDataSourceImpl(apiClient: mockApiClient);
    watchRepository = StudentWatchRepositoryImpl(
      remoteDataSource: remoteDataSource,
    );
    learningRepository = StudentLearningRepositoryImpl(
      watchRepository: watchRepository,
    );
  });

  group('P5 Protected Playback Resolution (Laravel REST API)', () {
    test('resolves valid HLS stream URL directly from GET lesson details', () async {
      final futureExpiry =
          DateTime.now().toUtc().add(const Duration(hours: 2)).millisecondsSinceEpoch ~/ 1000;
      final validHlsUrl =
          'https://cdn.alameen-center.online/bunny/43/playlist.m3u8?expires=$futureExpiry';

      when(() => mockApiClient.get('/student/courses/course-1/lessons/lesson-intro'))
          .thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(
            path: '/student/courses/course-1/lessons/lesson-intro',
          ),
          statusCode: 200,
          data: {
            'data': {
              'course': {'id': 10, 'slug': 'course-1', 'title': 'دورة 1'},
              'current_video': {
                'id': 43,
                'slug': 'lesson-intro',
                'title': 'الدرس الأول',
                'duration_seconds': 600,
                'video_source': 'bunny',
                'is_free_preview': true,
                'is_accessible': true,
              },
              'playback': {
                'hls_url': validHlsUrl,
                'embed_url': 'https://iframe.mediadelivery.net/embed/1/43',
                'watermark': 'ALAMEEN-101',
                'expires_in': 7200,
              },
              'progress': {
                'watched_seconds': 120,
                'last_position_seconds': 95,
                'is_completed': false,
              },
            },
          },
        ),
      );

      final resolved = await learningRepository.resolveLessonPlayback(
        courseId: 'course-1',
        lesson: baseLesson.copyWith(isFreePreview: true),
      );

      expect(resolved.streamUrl, equals(validHlsUrl));
      expect(resolved.watermarkText, equals('ALAMEEN-101'));
      expect(resolved.lastPositionSeconds, equals(95));
      expect(resolved.watchedSeconds, equals(120));
      verifyNever(() => mockApiClient.post(any()));
    });

    test('resolves Mux HLS stream URL from Mux signed playback_token JWT', () async {
      // JWT with sub=mux_sub_xyz and future exp
      const fakeToken =
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJtdXhfc3ViX3h5eiIsImF1ZCI6InYiLCJleHAiOjk5OTk5OTk5OTl9.signature';

      when(() => mockApiClient.get('/student/courses/course-1/lessons/lesson-intro'))
          .thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(
            path: '/student/courses/course-1/lessons/lesson-intro',
          ),
          statusCode: 200,
          data: {
            'data': {
              'course': {'id': 10, 'slug': 'course-1', 'title': 'دورة 1'},
              'current_video': {
                'id': 43,
                'slug': 'lesson-intro',
                'title': 'الدرس الأول',
                'duration_seconds': 600,
                'video_source': 'mux',
                'is_free_preview': false,
                'is_accessible': true,
              },
              'playback': {
                'playback_token': fakeToken,
                'watermark': {'user_id': 146, 'student_name': 'Abdo'},
              },
              'progress': {
                'watched_seconds': 10,
                'last_position_seconds': 5,
                'is_completed': false,
              },
            },
          },
        ),
      );

      final resolved = await learningRepository.resolveLessonPlayback(
        courseId: 'course-1',
        lesson: baseLesson.copyWith(videoSource: 'mux'),
      );

      expect(
        resolved.streamUrl,
        equals('https://stream.mux.com/mux_sub_xyz.m3u8?token=$fakeToken'),
      );
      expect(resolved.watermarkText, contains('Abdo'));
      expect(resolved.watermarkText, contains('146'));
      verifyNever(() => mockApiClient.post(any()));
    });

    test('automatically refreshes playback token when initial HLS URL is expired', () async {
      const expiredHls =
          'https://cdn.alameen-center.online/bunny/43/playlist.m3u8?expires=1000';
      final futureExpiry =
          DateTime.now().toUtc().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;
      final refreshedHls =
          'https://cdn.alameen-center.online/bunny/43/playlist.m3u8?expires=$futureExpiry';

      when(() => mockApiClient.get('/student/courses/course-1/lessons/lesson-intro'))
          .thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(
            path: '/student/courses/course-1/lessons/lesson-intro',
          ),
          statusCode: 200,
          data: {
            'data': {
              'current_video': {
                'id': 43,
                'slug': 'lesson-intro',
                'duration_seconds': 600,
                'is_accessible': true,
              },
              'playback': {
                'hls_url': expiredHls,
                'expires_in': 0,
              },
            },
          },
        ),
      );

      when(
        () => mockApiClient.post(
          '/student/courses/course-1/lessons/lesson-intro/playback-token',
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(
            path: '/student/courses/course-1/lessons/lesson-intro/playback-token',
          ),
          statusCode: 200,
          data: {
            'data': {
              'hls_url': refreshedHls,
              'watermark': 'ALAMEEN-RENEWED',
              'expires_in': 3600,
            },
          },
        ),
      );

      final resolved = await learningRepository.resolveLessonPlayback(
        courseId: 'course-1',
        lesson: baseLesson,
      );

      expect(resolved.streamUrl, equals(refreshedHls));
      expect(resolved.watermarkText, equals('ALAMEEN-RENEWED'));
      verify(
        () => mockApiClient.post(
          '/student/courses/course-1/lessons/lesson-intro/playback-token',
        ),
      ).called(1);
    });

    test('refreshes Mux playback token when initial token is expired', () async {
      // initial expired token (exp=1000)
      const expiredToken =
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJtdXhfc3ViXzEyMyIsImF1ZCI6InYiLCJleHAiOjEwMDB9.signature';
      // renewed token (exp in future)
      final futureExp =
          DateTime.now().toUtc().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;
      final renewedPayload = base64Url.encode(utf8.encode(jsonEncode({
        'sub': 'mux_sub_123',
        'aud': 'v',
        'exp': futureExp,
      }))).replaceAll('=', '');
      final renewedToken =
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.$renewedPayload.signature';

      when(() => mockApiClient.get('/student/courses/course-1/lessons/lesson-intro'))
          .thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(
            path: '/student/courses/course-1/lessons/lesson-intro',
          ),
          statusCode: 200,
          data: {
            'data': {
              'current_video': {
                'id': 43,
                'slug': 'lesson-intro',
                'duration_seconds': 600,
                'video_source': 'mux',
                'is_accessible': true,
              },
              'playback': {
                'playback_token': expiredToken,
              },
            },
          },
        ),
      );

      when(
        () => mockApiClient.post(
          '/student/courses/course-1/lessons/lesson-intro/playback-token',
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(
            path: '/student/courses/course-1/lessons/lesson-intro/playback-token',
          ),
          statusCode: 200,
          data: {
            'data': {
              'playback_token': renewedToken,
              'watermark': 'RENEWED-WATERMARK',
            },
          },
        ),
      );

      final resolved = await learningRepository.resolveLessonPlayback(
        courseId: 'course-1',
        lesson: baseLesson.copyWith(videoSource: 'mux'),
      );

      expect(
        resolved.streamUrl,
        equals('https://stream.mux.com/mux_sub_123.m3u8?token=$renewedToken'),
      );
      expect(resolved.watermarkText, equals('RENEWED-WATERMARK'));
    });

    test('throws PlaybackAuthorizationException on 403 without fallback URL fabrication', () async {
      final req = RequestOptions(
        path: '/student/courses/course-1/lessons/lesson-intro',
      );
      when(() => mockApiClient.get('/student/courses/course-1/lessons/lesson-intro'))
          .thenThrow(
        DioException(
          requestOptions: req,
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: req,
            statusCode: 403,
            data: {'message': 'لم يتم فتح هذا المستوى بعد.'},
          ),
        ),
      );

      await expectLater(
        () => learningRepository.resolveLessonPlayback(
          courseId: 'course-1',
          lesson: const Lesson(
            id: '43',
            slug: 'lesson-intro',
            title: 'درس مغلق',
            description: '',
            duration: '10:00',
            muxPlaybackId: 'legacy_mux_should_never_be_used',
          ),
        ),
        throwsA(
          isA<PlaybackAuthorizationException>().having(
            (e) => e.statusCode,
            'statusCode',
            403,
          ),
        ),
      );
    });

    test('throws PlaybackProviderIncompatibleException when backend returns embed_url only without hls_url', () async {
      when(() => mockApiClient.get('/student/courses/course-1/lessons/lesson-intro'))
          .thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(
            path: '/student/courses/course-1/lessons/lesson-intro',
          ),
          statusCode: 200,
          data: {
            'data': {
              'current_video': {
                'id': 43,
                'slug': 'lesson-intro',
                'duration_seconds': 600,
                'video_source': 'mux',
                'is_accessible': true,
              },
              'playback': {
                'embed_url': 'https://player.example.com/embed/43',
                'hls_url': null,
              },
            },
          },
        ),
      );

      when(
        () => mockApiClient.post(
          '/student/courses/course-1/lessons/lesson-intro/playback-token',
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(
            path: '/student/courses/course-1/lessons/lesson-intro/playback-token',
          ),
          statusCode: 200,
          data: {
            'data': {
              'embed_url': 'https://player.example.com/embed/43',
              'hls_url': '',
            },
          },
        ),
      );

      await expectLater(
        () => learningRepository.resolveLessonPlayback(
          courseId: 'course-1',
          lesson: baseLesson.copyWith(videoSource: 'mux'),
        ),
        throwsA(
          isA<PlaybackProviderIncompatibleException>()
              .having((e) => e.videoSource, 'videoSource', 'mux')
              .having(
                (e) => e.embedUrl,
                'embedUrl',
                'https://player.example.com/embed/43',
              ),
        ),
      );
    });
  });
}
