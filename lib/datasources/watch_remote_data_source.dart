import 'package:dio/dio.dart';
import '../core/network/api_client.dart';
import '../core/network/api_exceptions.dart';
import '../models/lesson_playback_data.dart';

/// مصدر البيانات البعيد لتشغيل الدروس المحمية، تتبع التقدم، والإبلاغ الأمني عبر Laravel REST API.
abstract class WatchRemoteDataSource {
  /// GET /student/courses/{slug}/lessons/{lesson}
  Future<LessonPlaybackBundle> getLessonDetails({
    required String courseSlugOrId,
    required String lessonSlugOrId,
  });

  /// POST /student/courses/{slug}/lessons/{lesson}/playback-token
  Future<PlaybackTokenResponse> refreshPlaybackToken({
    required String courseSlugOrId,
    required String lessonSlugOrId,
  });

  /// POST /student/courses/{slug}/lessons/{lesson}/progress
  Future<WatchProgressResult> recordLessonProgress({
    required String courseSlugOrId,
    required String lessonSlugOrId,
    required int watchedSeconds,
    required int positionSeconds,
    bool? isCompleted,
  });

  /// POST /student/security/violation
  Future<void> reportSecurityViolation({
    required String type,
    int? videoId,
    String? details,
  });
}

class WatchRemoteDataSourceImpl implements WatchRemoteDataSource {
  final ApiClient _apiClient;

  WatchRemoteDataSourceImpl({required ApiClient apiClient})
      : _apiClient = apiClient;

  @override
  Future<LessonPlaybackBundle> getLessonDetails({
    required String courseSlugOrId,
    required String lessonSlugOrId,
  }) async {
    try {
      final response = await _apiClient.get(
        '/student/courses/$courseSlugOrId/lessons/$lessonSlugOrId',
      );
      final raw = response.data;
      if (raw is Map<String, dynamic>) {
        return LessonPlaybackBundle.fromJson(raw);
      }
      throw const ApiException(
        'تعذر قراءة بيانات المحاضرة من الخادم.',
        statusCode: 500,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  @override
  Future<PlaybackTokenResponse> refreshPlaybackToken({
    required String courseSlugOrId,
    required String lessonSlugOrId,
  }) async {
    try {
      final response = await _apiClient.post(
        '/student/courses/$courseSlugOrId/lessons/$lessonSlugOrId/playback-token',
      );
      final raw = response.data;
      if (raw is Map<String, dynamic>) {
        return PlaybackTokenResponse.fromJson(raw);
      }
      throw const ApiException(
        'تعذر تجديد رابط البث الآمن من الخادم.',
        statusCode: 500,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  @override
  Future<WatchProgressResult> recordLessonProgress({
    required String courseSlugOrId,
    required String lessonSlugOrId,
    required int watchedSeconds,
    required int positionSeconds,
    bool? isCompleted,
  }) async {
    try {
      final payload = <String, dynamic>{
        'watched_seconds': watchedSeconds < 0 ? 0 : watchedSeconds,
        'position_seconds': positionSeconds < 0 ? 0 : positionSeconds,
        'is_completed': ?isCompleted,
      };
      final response = await _apiClient.post(
        '/student/courses/$courseSlugOrId/lessons/$lessonSlugOrId/progress',
        data: payload,
      );
      final raw = response.data;
      if (raw is Map<String, dynamic>) {
        return WatchProgressResult.fromJson(raw);
      }
      return WatchProgressResult(
        success: true,
        isCompleted: isCompleted ?? false,
        watchedSeconds: watchedSeconds,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  @override
  Future<void> reportSecurityViolation({
    required String type,
    int? videoId,
    String? details,
  }) async {
    try {
      await _apiClient.post(
        '/student/security/violation',
        data: <String, dynamic>{
          'type': type,
          'video_id': ?videoId,
          if (details != null && details.trim().isNotEmpty)
            'details': details.trim(),
        },
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
