import 'package:equatable/equatable.dart';
import 'course.dart';
import 'course_level.dart';
import 'lesson.dart';

/// نتيجة تحليل رابط البث الآمن للمحاضرة عبر Laravel REST API.
class ResolvedLessonPlayback extends Equatable {
  final String streamUrl;
  final String thumbnailUrl;
  final String? embedUrl;
  final String? watermarkText;
  final int? expiresInSeconds;
  final int lastPositionSeconds;
  final int watchedSeconds;
  final bool isCompleted;
  final LessonPlaybackBundle? bundle;

  const ResolvedLessonPlayback({
    required this.streamUrl,
    this.thumbnailUrl = '',
    this.embedUrl,
    this.watermarkText,
    this.expiresInSeconds,
    this.lastPositionSeconds = 0,
    this.watchedSeconds = 0,
    this.isCompleted = false,
    this.bundle,
  });

  /// يتحقق من انتهاء صلاحية الرابط الموقع أو اقترابه من الانتهاء بناءً على معامل expires/exp إن وجد.
  static bool isSignedUrlExpiredOrExpiring(
    String url, {
    DateTime? now,
    Duration buffer = const Duration(seconds: 45),
  }) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return false;
    final rawExp = uri.queryParameters['expires'] ?? uri.queryParameters['exp'];
    if (rawExp == null || rawExp.isEmpty) return false;
    final epochSeconds = int.tryParse(rawExp);
    if (epochSeconds == null || epochSeconds <= 0) return false;
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(epochSeconds * 1000, isUtc: true);
    final current = (now ?? DateTime.now()).toUtc();
    return current.add(buffer).isAfter(expiresAt);
  }

  @override
  List<Object?> get props => [
        streamUrl,
        thumbnailUrl,
        embedUrl,
        watermarkText,
        expiresInSeconds,
        lastPositionSeconds,
        watchedSeconds,
        isCompleted,
        bundle,
      ];
}

/// بيانات المحاضرة الكاملة من GET /student/courses/{slug}/lessons/{lesson}.
class LessonPlaybackBundle extends Equatable {
  final Course? course;
  final Lesson currentVideo;
  final Lesson? prevVideo;
  final Lesson? nextVideo;
  final List<CourseLevel> levels;
  final List<int> completedVideoIds;
  final int progressPercent;
  final int watchedSeconds;
  final int lastPositionSeconds;
  final bool isCompleted;
  final String? embedUrl;
  final String? hlsUrl;
  final String? watermarkText;
  final int? expiresInSeconds;

  const LessonPlaybackBundle({
    this.course,
    required this.currentVideo,
    this.prevVideo,
    this.nextVideo,
    this.levels = const [],
    this.completedVideoIds = const [],
    this.progressPercent = 0,
    this.watchedSeconds = 0,
    this.lastPositionSeconds = 0,
    this.isCompleted = false,
    this.embedUrl,
    this.hlsUrl,
    this.watermarkText,
    this.expiresInSeconds,
  });

  factory LessonPlaybackBundle.fromJson(Map<String, dynamic> rawJson) {
    final data = (rawJson['data'] is Map)
        ? Map<String, dynamic>.from(rawJson['data'] as Map)
        : rawJson;

    Course? parsedCourse;
    if (data['course'] is Map) {
      parsedCourse = Course.fromLaravelSummaryJson(
        Map<String, dynamic>.from(data['course'] as Map),
      );
    }

    final currentMap = data['current_video'] is Map
        ? Map<String, dynamic>.from(data['current_video'] as Map)
        : <String, dynamic>{};
    final currentVideo = Lesson.fromLaravelVideoJson(currentMap);

    Lesson? prevVideo;
    if (data['prev_video'] is Map) {
      prevVideo = Lesson.fromLaravelVideoJson(
        Map<String, dynamic>.from(data['prev_video'] as Map),
      );
    }

    Lesson? nextVideo;
    if (data['next_video'] is Map) {
      nextVideo = Lesson.fromLaravelVideoJson(
        Map<String, dynamic>.from(data['next_video'] as Map),
      );
    }

    final rawLevels = data['levels'] as List? ?? const [];
    final levels = rawLevels
        .whereType<Map>()
        .map((m) => CourseLevel.fromLaravelJson(Map<String, dynamic>.from(m)))
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    final rawCompleted = data['completed_video_ids'] as List? ?? const [];
    final completedIds = rawCompleted
        .map((id) => id is num ? id.toInt() : int.tryParse(id.toString()) ?? 0)
        .where((id) => id > 0)
        .toList();

    final currentProgress = data['current_progress'] is Map
        ? Map<String, dynamic>.from(data['current_progress'] as Map)
        : (data['progress'] is Map
            ? Map<String, dynamic>.from(data['progress'] as Map)
            : const <String, dynamic>{});
    final videoProgress = currentMap['progress'] is Map
        ? Map<String, dynamic>.from(currentMap['progress'] as Map)
        : const <String, dynamic>{};

    final watchedSec = (currentProgress['watched_seconds'] is num)
        ? (currentProgress['watched_seconds'] as num).toInt()
        : (videoProgress['watched_seconds'] is num
            ? (videoProgress['watched_seconds'] as num).toInt()
            : currentVideo.watchedSeconds);

    final lastPosSec = (currentProgress['last_position_seconds'] is num)
        ? (currentProgress['last_position_seconds'] as num).toInt()
        : (currentProgress['position_seconds'] is num
            ? (currentProgress['position_seconds'] as num).toInt()
            : currentVideo.lastPositionSeconds);

    final isDone = currentProgress['is_completed'] == true ||
        videoProgress['is_completed'] == true ||
        currentVideo.isCompleted;

    final playbackMap = data['playback'] is Map
        ? Map<String, dynamic>.from(data['playback'] as Map)
        : const <String, dynamic>{};

    final rawEmbed = playbackMap['embed_url']?.toString().trim();
    final rawHls = playbackMap['hls_url']?.toString().trim();
    final rawWatermark =
        (playbackMap['watermark_text'] ?? playbackMap['watermark'])?.toString().trim();
    final expires = (playbackMap['expires_in'] is num)
        ? (playbackMap['expires_in'] as num).toInt()
        : null;

    return LessonPlaybackBundle(
      course: parsedCourse,
      currentVideo: currentVideo.copyWith(
        watchedSeconds: watchedSec,
        lastPositionSeconds: lastPosSec,
        isCompleted: isDone,
      ),
      prevVideo: prevVideo,
      nextVideo: nextVideo,
      levels: levels,
      completedVideoIds: completedIds,
      progressPercent: (data['progress_percent'] is num)
          ? (data['progress_percent'] as num).toInt()
          : 0,
      watchedSeconds: watchedSec,
      lastPositionSeconds: lastPosSec,
      isCompleted: isDone,
      embedUrl: (rawEmbed != null && rawEmbed.isNotEmpty) ? rawEmbed : null,
      hlsUrl: (rawHls != null && rawHls.isNotEmpty) ? rawHls : null,
      watermarkText:
          (rawWatermark != null && rawWatermark.isNotEmpty) ? rawWatermark : null,
      expiresInSeconds: expires,
    );
  }

  @override
  List<Object?> get props => [
        course,
        currentVideo,
        prevVideo,
        nextVideo,
        levels,
        completedVideoIds,
        progressPercent,
        watchedSeconds,
        lastPositionSeconds,
        isCompleted,
        embedUrl,
        hlsUrl,
        watermarkText,
        expiresInSeconds,
      ];
}

/// استجابة تجديد رابط البث القصير من POST /student/courses/{slug}/lessons/{lesson}/playback-token.
class PlaybackTokenResponse extends Equatable {
  final bool success;
  final String? embedUrl;
  final String? hlsUrl;
  final String? watermark;
  final int expiresIn;

  const PlaybackTokenResponse({
    this.success = true,
    this.embedUrl,
    this.hlsUrl,
    this.watermark,
    this.expiresIn = 900,
  });

  factory PlaybackTokenResponse.fromJson(Map<String, dynamic> rawJson) {
    final data = (rawJson['data'] is Map && rawJson['hls_url'] == null && rawJson['embed_url'] == null)
        ? Map<String, dynamic>.from(rawJson['data'] as Map)
        : rawJson;

    final rawEmbed = data['embed_url']?.toString().trim();
    final rawHls = data['hls_url']?.toString().trim();
    final rawWatermark = (data['watermark'] ?? data['watermark_text'])?.toString().trim();
    final expires = (data['expires_in'] is num)
        ? (data['expires_in'] as num).toInt()
        : 900;

    return PlaybackTokenResponse(
      success: rawJson['success'] != false,
      embedUrl: (rawEmbed != null && rawEmbed.isNotEmpty) ? rawEmbed : null,
      hlsUrl: (rawHls != null && rawHls.isNotEmpty) ? rawHls : null,
      watermark: (rawWatermark != null && rawWatermark.isNotEmpty) ? rawWatermark : null,
      expiresIn: expires > 0 ? expires : 900,
    );
  }

  @override
  List<Object?> get props => [success, embedUrl, hlsUrl, watermark, expiresIn];
}

/// استجابة تسجيل تقدم المشاهدة من POST /student/courses/{slug}/lessons/{lesson}/progress.
class WatchProgressResult extends Equatable {
  final bool success;
  final bool isCompleted;
  final int watchedSeconds;
  final bool courseCompleted;
  final String? certificateCode;

  const WatchProgressResult({
    this.success = true,
    this.isCompleted = false,
    this.watchedSeconds = 0,
    this.courseCompleted = false,
    this.certificateCode,
  });

  factory WatchProgressResult.fromJson(Map<String, dynamic> rawJson) {
    final data = (rawJson['data'] is Map && rawJson['watched_seconds'] == null && rawJson['is_completed'] == null)
        ? Map<String, dynamic>.from(rawJson['data'] as Map)
        : rawJson;

    final cert = data['certificate_code']?.toString().trim();
    return WatchProgressResult(
      success: rawJson['success'] != false,
      isCompleted: data['is_completed'] == true,
      watchedSeconds: (data['watched_seconds'] is num)
          ? (data['watched_seconds'] as num).toInt()
          : 0,
      courseCompleted: data['course_completed'] == true,
      certificateCode: (cert != null && cert.isNotEmpty) ? cert : null,
    );
  }

  @override
  List<Object?> get props => [
        success,
        isCompleted,
        watchedSeconds,
        courseCompleted,
        certificateCode,
      ];
}

