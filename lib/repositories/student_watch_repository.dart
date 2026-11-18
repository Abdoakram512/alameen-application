import '../models/lesson.dart';
import '../models/lesson_playback_data.dart';

/// استثناء أمني يُطلق عند فشل التحقق من صلاحية وصول الطالب للمحاضرة (401 / 403) لمنع التراجع لروابط غير محمية.
class PlaybackAuthorizationException extends StateError {
  final int? statusCode;

  PlaybackAuthorizationException(
    super.message, {
    this.statusCode,
  });

  bool get isUnauthenticated => statusCode == 401;
  bool get isForbidden => statusCode == 403;

  @override
  String toString() => message;
}

/// استثناء يُطلق عندما لا يوفّر الخادم رابط HLS متوافق مع المشغل (مثلاً وجود mux/iframe فقط بدون hls_url).
class PlaybackProviderIncompatibleException extends StateError {
  final String? videoSource;
  final String? embedUrl;

  PlaybackProviderIncompatibleException(
    super.message, {
    this.videoSource,
    this.embedUrl,
  });

  @override
  String toString() => message;
}

/// واجهة مستودع تشغيل الفيديو المحمي، تتبع التقدم، والإبلاغ الأمني عبر Laravel REST API.
abstract class StudentWatchRepository {
  Future<LessonPlaybackBundle> getLessonPlaybackBundle({
    required String courseSlugOrId,
    required String lessonSlugOrId,
  });

  Future<PlaybackTokenResponse> refreshPlaybackToken({
    required String courseSlugOrId,
    required String lessonSlugOrId,
  });

  Future<ResolvedLessonPlayback> resolveLessonPlayback({
    required String courseSlugOrId,
    required Lesson lesson,
  });

  Future<WatchProgressResult> recordLessonProgress({
    required String courseSlugOrId,
    required String lessonSlugOrId,
    required int watchedSeconds,
    required int positionSeconds,
    bool? isCompleted,
  });

  Future<void> reportSecurityViolation({
    required String type,
    int? videoId,
    String? details,
  });
}
