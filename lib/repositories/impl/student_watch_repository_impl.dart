import '../../core/config/app_config.dart';
import '../../core/network/api_exceptions.dart';
import '../../datasources/watch_remote_data_source.dart';
import '../../models/lesson.dart';
import '../../models/lesson_playback_data.dart';
import '../student_watch_repository.dart';

class StudentWatchRepositoryImpl implements StudentWatchRepository {
  final WatchRemoteDataSource _remoteDataSource;

  StudentWatchRepositoryImpl({
    required WatchRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  @override
  Future<LessonPlaybackBundle> getLessonPlaybackBundle({
    required String courseSlugOrId,
    required String lessonSlugOrId,
  }) async {
    return await _remoteDataSource.getLessonDetails(
      courseSlugOrId: courseSlugOrId,
      lessonSlugOrId: lessonSlugOrId,
    );
  }

  @override
  Future<PlaybackTokenResponse> refreshPlaybackToken({
    required String courseSlugOrId,
    required String lessonSlugOrId,
  }) async {
    return await _remoteDataSource.refreshPlaybackToken(
      courseSlugOrId: courseSlugOrId,
      lessonSlugOrId: lessonSlugOrId,
    );
  }

  @override
  Future<ResolvedLessonPlayback> resolveLessonPlayback({
    required String courseSlugOrId,
    required Lesson lesson,
  }) async {
    final lessonKey = (lesson.slug != null && lesson.slug!.trim().isNotEmpty)
        ? lesson.slug!.trim()
        : lesson.id.trim();

    if (courseSlugOrId.trim().isEmpty || lessonKey.isEmpty) {
      throw PlaybackAuthorizationException(
        'تعذر تحديد الدورة أو المحاضرة للتحقق من الصلاحية.',
        statusCode: 400,
      );
    }

    try {
      final bundle = await _remoteDataSource.getLessonDetails(
        courseSlugOrId: courseSlugOrId.trim(),
        lessonSlugOrId: lessonKey,
      );

      if (bundle.currentVideo.isVideoProcessing || lesson.isVideoProcessing) {
        throw StateError(
          'المحاضرة قيد التجهيز والمعالجة السحابية وستكون متاحة للمشاهدة فور اكتمالها.',
        );
      }

      String? hlsUrl = bundle.hlsUrl;
      String? embedUrl = bundle.embedUrl;
      String? watermark = bundle.watermarkText;
      int? expiresIn = bundle.expiresInSeconds;

      final needsTokenRefresh = hlsUrl == null ||
          hlsUrl.trim().isEmpty ||
          ResolvedLessonPlayback.isSignedUrlExpiredOrExpiring(hlsUrl);

      if (needsTokenRefresh) {
        try {
          final refreshed = await _remoteDataSource.refreshPlaybackToken(
            courseSlugOrId: courseSlugOrId.trim(),
            lessonSlugOrId: lessonKey,
          );
          if (refreshed.hlsUrl != null && refreshed.hlsUrl!.trim().isNotEmpty) {
            hlsUrl = refreshed.hlsUrl!.trim();
          } else if (hlsUrl != null &&
              ResolvedLessonPlayback.isSignedUrlExpiredOrExpiring(hlsUrl)) {
            // URL expired and renewal did not return a fresh HLS stream
            hlsUrl = null;
          }
          if (refreshed.embedUrl != null && refreshed.embedUrl!.trim().isNotEmpty) {
            embedUrl = refreshed.embedUrl!.trim();
          }
          if (refreshed.watermark != null && refreshed.watermark!.trim().isNotEmpty) {
            watermark = refreshed.watermark!.trim();
          }
          expiresIn = refreshed.expiresIn;
        } on UnauthorizedException {
          rethrow;
        } on ForbiddenException {
          rethrow;
        } on ApiException {
          if (hlsUrl == null || hlsUrl.trim().isEmpty) {
            rethrow;
          }
          if (ResolvedLessonPlayback.isSignedUrlExpiredOrExpiring(hlsUrl)) {
            throw PlaybackAuthorizationException(
              'انتهت صلاحية رابط البث الآمن وتعذر تجديده. يرجى المحاولة مرة أخرى.',
              statusCode: 403,
            );
          }
        }
      }

      if (hlsUrl == null || hlsUrl.trim().isEmpty) {
        final effectiveSource =
            bundle.currentVideo.videoSource ?? lesson.videoSource ?? 'unknown';
        if (!bundle.currentVideo.isAccessible && !bundle.currentVideo.isFreePreview) {
          throw PlaybackAuthorizationException(
            'تم رفض الوصول: لا تملك صلاحية مشاهدة هذه المحاضرة أو لم تستكمل المستوى السابق.',
            statusCode: 403,
          );
        }
        if (embedUrl != null && embedUrl.isNotEmpty) {
          throw PlaybackProviderIncompatibleException(
            'الخادم أعاد رابط تضمين فقط دون رابط بث مباشر HLS المطلوب للمشغل الآمن (المزود: $effectiveSource).',
            videoSource: effectiveSource,
            embedUrl: embedUrl,
          );
        }
        throw PlaybackProviderIncompatibleException(
          'لم يُرجع الخادم رابط بث صالحاً (hls_url) لهذه المحاضرة (المزود: $effectiveSource).',
          videoSource: effectiveSource,
        );
      }

      final resolvedThumbnail = AppConfig.resolveMediaUrl(
        bundle.currentVideo.thumbnailUrl.isNotEmpty
            ? bundle.currentVideo.thumbnailUrl
            : (lesson.thumbnailUrl.isNotEmpty
                ? lesson.thumbnailUrl
                : bundle.course?.thumbnailUrl),
      );

      return ResolvedLessonPlayback(
        streamUrl: hlsUrl.trim(),
        thumbnailUrl: resolvedThumbnail,
        embedUrl: embedUrl,
        watermarkText: watermark,
        expiresInSeconds: expiresIn,
        lastPositionSeconds: bundle.lastPositionSeconds,
        watchedSeconds: bundle.watchedSeconds,
        isCompleted: bundle.isCompleted,
        bundle: bundle,
      );
    } on UnauthorizedException catch (e) {
      throw PlaybackAuthorizationException(
        e.message.isNotEmpty
            ? e.message
            : 'انتهت صلاحية جلسة الطالب (401). يرجى إعادة تسجيل الدخول.',
        statusCode: 401,
      );
    } on ForbiddenException catch (e) {
      throw PlaybackAuthorizationException(
        e.message.isNotEmpty
            ? e.message
            : 'تم رفض الوصول للمحاضرة (403). تأكد من صلاحية اشتراكك وإتمام المتطلبات.',
        statusCode: 403,
      );
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
    return await _remoteDataSource.recordLessonProgress(
      courseSlugOrId: courseSlugOrId,
      lessonSlugOrId: lessonSlugOrId,
      watchedSeconds: watchedSeconds,
      positionSeconds: positionSeconds,
      isCompleted: isCompleted,
    );
  }

  @override
  Future<void> reportSecurityViolation({
    required String type,
    int? videoId,
    String? details,
  }) async {
    await _remoteDataSource.reportSecurityViolation(
      type: type,
      videoId: videoId,
      details: details,
    );
  }
}
