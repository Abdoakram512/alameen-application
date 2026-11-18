import 'package:equatable/equatable.dart';
import '../core/converters/firestore_date_time_converter.dart';

/// نموذج بيانات الدرس (Lesson)
class Lesson extends Equatable {
  final String id;
  final String title;
  final String description;
  final String duration;
  final String muxPlaybackId;
  final String? muxAssetId;
  final int order;
  final bool isFreePreview;
  final bool isCompleted;

  /// نوع العنصر المنهجي: 'video' | 'assignment'
  final String type;

  /// معرّف التكليف المرتبط بهذا الدرس (فارغ أو null = لا يوجد تكليف).
  final String? assignmentId;

  /// هل يمنع فتح الدرس التالي حتى تسليم تكليف هذا الدرس؟
  final bool lockNextUntilSubmitted;

  /// حالة معالجة الفيديو السحابية: 'ready' | 'processing' | 'error'
  final String videoStatus;

  /// نسبة تقدم معالجة الفيديو في المزود السحابي (0 إلى 100)
  final double videoProgress;

  /// رسالة الخطأ في حال فشل السحب
  final String? videoErrorMessage;

  /// الرابط السحابي الأصلي الذي تم سحب الفيديو منه
  final String? videoSourceUrl;

  /// نسبة إتمام مشاهدة الفيديو المطلوبة لاعتبار الدرس مكتملاً (افتراضياً 95%)
  final int completionThresholdPercentage;

  /// هل تم نشر المحاضرة؟ (افتراضياً true للدروس الفورية، و false للمسودة)
  final bool isPublished;

  /// موعد المحاضرة المجدول (إن تم تعيين موعد محدد للنشر التلقائي)
  final DateTime? scheduledPublishAt;

  /// رابط الغلاف/الصورة المصغرة المخصصة للدرس (اختياري)
  final String? customThumbnailUrl;

  /// معرّف السلاج الخاص بـ Laravel REST API
  final String? slug;

  /// مصدر الفيديو: bunny | mux | youtube | custom
  final String? videoSource;

  /// هل الدرس متاح لفتح وتشغيل الفيديو لهذا الطالب
  final bool isAccessible;

  /// المدة الدقيقة بالثواني القادمة من Laravel REST API
  final int? durationSeconds;

  /// إجمالي الثواني المشاهدة المسجلة على الخادم
  final int watchedSeconds;

  /// موضع الاستئناف الأخير بالثواني على الخادم
  final int lastPositionSeconds;

  /// نسبة الإكمال المسجلة على الخادم
  final double serverCompletionPercentage;

  /// آخر وقت مشاهدة مسجل على الخادم
  final DateTime? lastWatchedAt;

  const Lesson({
    required this.id,
    required this.title,
    required this.description,
    required this.duration,
    this.muxPlaybackId = '',
    this.muxAssetId,
    this.order = 1,
    this.isFreePreview = false,
    this.isCompleted = false,
    this.type = 'video',
    this.assignmentId,
    this.lockNextUntilSubmitted = false,
    this.videoStatus = 'ready',
    this.videoProgress = 100.0,
    this.videoErrorMessage,
    this.videoSourceUrl,
    this.completionThresholdPercentage = 95,
    this.isPublished = true,
    this.scheduledPublishAt,
    this.customThumbnailUrl,
    this.slug,
    this.videoSource,
    this.isAccessible = true,
    this.durationSeconds,
    this.watchedSeconds = 0,
    this.lastPositionSeconds = 0,
    this.serverCompletionPercentage = 0.0,
    this.lastWatchedAt,
  });

  bool get hasVideo =>
      muxPlaybackId.trim().isNotEmpty ||
      (videoSource != null && videoSource!.trim().isNotEmpty);

  bool get isAssignmentLesson =>
      type == 'assignment' || (!hasVideo && hasAssignment);

  bool get hasAssignment =>
      assignmentId != null && assignmentId!.trim().isNotEmpty;
  bool get isVideoProcessing => videoStatus == 'processing';
  bool get isVideoReady => videoStatus == 'ready' || videoStatus.isEmpty;
  bool get hasVideoError => videoStatus == 'error';

  /// هل المحاضرة مجدولة لوقت مستقبلي؟
  bool get isScheduled =>
      scheduledPublishAt != null &&
      DateTime.now().isBefore(scheduledPublishAt!);

  /// هل المحاضرة متاحة حالياً للطلاب للمشاهدة؟
  bool get isAvailableNow => isPublished && !isScheduled;

  /// هل المحاضرة مسودة غير منشورة؟
  bool get isDraft => !isPublished;

  String get videoStreamUrl => muxPlaybackId.trim().isNotEmpty
      ? 'https://stream.mux.com/${muxPlaybackId.trim()}.m3u8'
      : '';

  String get thumbnailUrl {
    if (customThumbnailUrl != null && customThumbnailUrl!.trim().isNotEmpty) {
      return customThumbnailUrl!;
    }
    if (muxPlaybackId.trim().isNotEmpty) {
      return 'https://image.mux.com/${muxPlaybackId.trim()}/thumbnail.jpg?width=600&height=340&fit_mode=smart';
    }
    return '';
  }

  /// الحد الأدنى الفعلي لنسبة الإكمال (لا يقل عن قاعدة الأكاديمية الصارمة 95%).
  int get effectiveCompletionThresholdPercentage =>
      completionThresholdPercentage >= 95 ? completionThresholdPercentage : 95;

  int get durationInSeconds {
    if (durationSeconds != null && durationSeconds! > 0) {
      return durationSeconds!;
    }
    final parts = duration.split(':');
    if (parts.length == 2) {
      final m = int.tryParse(parts[0].trim()) ?? 0;
      final s = int.tryParse(parts[1].trim()) ?? 0;
      return (m * 60) + s;
    } else if (parts.length == 3) {
      final h = int.tryParse(parts[0].trim()) ?? 0;
      final m = int.tryParse(parts[1].trim()) ?? 0;
      final s = int.tryParse(parts[2].trim()) ?? 0;
      return (h * 3600) + (m * 60) + s;
    }
    final match = RegExp(r'(\d+)').firstMatch(duration);
    if (match != null && duration.contains('دقيق')) {
      return (int.tryParse(match.group(1)!) ?? 0) * 60;
    }
    return 0;
  }

  static String _formatSeconds(int totalSeconds) {
    if (totalSeconds <= 0) return '15:00';
    final hours = totalSeconds ~/ 3600;
    final mins = (totalSeconds % 3600) ~/ 60;
    final secs = totalSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'duration': duration,
        'durationSeconds': durationSeconds,
        'muxPlaybackId': muxPlaybackId,
        'muxAssetId': muxAssetId,
        'order': order,
        'isFreePreview': isFreePreview,
        'isCompleted': isCompleted,
        'type': type,
        'assignmentId': assignmentId,
        'lockNextUntilSubmitted': lockNextUntilSubmitted,
        'videoStatus': videoStatus,
        'videoProgress': videoProgress,
        'videoErrorMessage': videoErrorMessage,
        'videoSourceUrl': videoSourceUrl,
        'completionThresholdPercentage': completionThresholdPercentage,
        'isPublished': isPublished,
        'scheduledPublishAt': scheduledPublishAt?.toIso8601String(),
        'customThumbnailUrl': customThumbnailUrl,
        'slug': slug,
        'videoSource': videoSource,
        'isAccessible': isAccessible,
        'watchedSeconds': watchedSeconds,
        'lastPositionSeconds': lastPositionSeconds,
        'serverCompletionPercentage': serverCompletionPercentage,
        'lastWatchedAt': lastWatchedAt?.toIso8601String(),
      };

  factory Lesson.fromLaravelVideoJson(Map<String, dynamic> json) {
    final durSec = (json['duration_seconds'] is num)
        ? (json['duration_seconds'] as num).toInt()
        : ((json['duration_minutes'] is num)
            ? ((json['duration_minutes'] as num).toDouble() * 60).round()
            : 0);
    final durMin = (json['duration_minutes'] is num)
        ? (json['duration_minutes'] as num).toInt()
        : 0;
    final durationStr = durMin > 0 ? '$durMin دقيقة' : _formatSeconds(durSec);

    final progressMap = json['progress'] is Map
        ? Map<String, dynamic>.from(json['progress'] as Map)
        : null;
    final isCompleted = json['is_completed'] == true ||
        (progressMap != null && progressMap['is_completed'] == true);

    final watchedSec = (progressMap?['watched_seconds'] is num)
        ? (progressMap!['watched_seconds'] as num).toInt()
        : 0;
    final lastPosSec = (progressMap?['last_position_seconds'] is num)
        ? (progressMap!['last_position_seconds'] as num).toInt()
        : ((progressMap?['position_seconds'] is num)
            ? (progressMap!['position_seconds'] as num).toInt()
            : watchedSec);
    final completionPct = (progressMap?['completion_percentage'] is num)
        ? (progressMap!['completion_percentage'] as num).toDouble()
        : 0.0;
    DateTime? watchedAt;
    if (progressMap?['last_watched_at'] != null) {
      watchedAt = DateTime.tryParse(progressMap!['last_watched_at'].toString());
    }

    final rawThreshold = (json['min_completion_percentage'] is num)
        ? (json['min_completion_percentage'] as num).toInt()
        : 95;

    final clinicalTask = json['clinical_task'] is Map
        ? Map<String, dynamic>.from(json['clinical_task'] as Map)
        : null;

    return Lesson(
      id: json['id']?.toString() ?? '',
      slug: json['slug']?.toString(),
      title: json['title']?.toString() ?? json['title_ar']?.toString() ?? '',
      description:
          json['description']?.toString() ?? json['description_ar']?.toString() ?? '',
      duration: durationStr,
      durationSeconds: durSec > 0 ? durSec : null,
      muxPlaybackId: json['mux_playback_id']?.toString() ?? '',
      videoSource: json['video_source']?.toString(),
      order: (json['sort_order'] is num)
          ? (json['sort_order'] as num).toInt()
          : ((json['order'] is num) ? (json['order'] as num).toInt() : 1),
      isFreePreview: json['is_free_preview'] == true,
      isAccessible: json.containsKey('is_accessible')
          ? json['is_accessible'] == true
          : true,
      isCompleted: isCompleted,
      completionThresholdPercentage: rawThreshold,
      isPublished: json['is_published'] != false,
      watchedSeconds: watchedSec,
      lastPositionSeconds: lastPosSec,
      serverCompletionPercentage: completionPct,
      lastWatchedAt: watchedAt,
      assignmentId: clinicalTask?['id']?.toString() ?? json['assignment_id']?.toString(),
    );
  }

  factory Lesson.fromMap(Map<String, dynamic> map) {
    if (map.containsKey('duration_seconds') || map.containsKey('video_source')) {
      return Lesson.fromLaravelVideoJson(map);
    }
    return Lesson(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      duration: map['duration']?.toString() ?? '',
      durationSeconds: (map['durationSeconds'] is num)
          ? (map['durationSeconds'] as num).toInt()
          : null,
      muxPlaybackId: map['muxPlaybackId']?.toString() ?? '',
      muxAssetId: map['muxAssetId'] as String?,
      order: (map['order'] is num) ? (map['order'] as num).toInt() : 1,
      isFreePreview: map['isFreePreview'] == true,
      isCompleted: map['isCompleted'] == true || map['is_completed'] == true,
      type: map['type']?.toString() ?? 'video',
      assignmentId: map['assignmentId'] as String?,
      lockNextUntilSubmitted: map['lockNextUntilSubmitted'] == true,
      videoStatus: map['videoStatus']?.toString() ?? 'ready',
      videoProgress: (map['videoProgress'] is num)
          ? (map['videoProgress'] as num).toDouble()
          : 100.0,
      videoErrorMessage: map['videoErrorMessage'] as String?,
      videoSourceUrl: map['videoSourceUrl'] as String?,
      completionThresholdPercentage:
          (map['completionThresholdPercentage'] is num)
              ? (map['completionThresholdPercentage'] as num).toInt()
              : 95,
      isPublished: map['isPublished'] != false,
      scheduledPublishAt:
          FirestoreDateTimeConverter.fromValue(map['scheduledPublishAt']),
      customThumbnailUrl: map['customThumbnailUrl'] as String?,
      slug: map['slug']?.toString(),
      videoSource:
          map['videoSource']?.toString() ?? map['video_source']?.toString(),
      isAccessible: map['isAccessible'] != false && map['is_accessible'] != false,
      watchedSeconds: (map['watchedSeconds'] is num)
          ? (map['watchedSeconds'] as num).toInt()
          : 0,
      lastPositionSeconds: (map['lastPositionSeconds'] is num)
          ? (map['lastPositionSeconds'] as num).toInt()
          : 0,
      serverCompletionPercentage: (map['serverCompletionPercentage'] is num)
          ? (map['serverCompletionPercentage'] as num).toDouble()
          : 0.0,
      lastWatchedAt: FirestoreDateTimeConverter.fromValue(map['lastWatchedAt']),
    );
  }

  Lesson copyWith({
    String? id,
    String? title,
    String? description,
    String? duration,
    int? durationSeconds,
    String? muxPlaybackId,
    String? muxAssetId,
    int? order,
    bool? isFreePreview,
    bool? isCompleted,
    String? type,
    String? assignmentId,
    bool? lockNextUntilSubmitted,
    String? videoStatus,
    double? videoProgress,
    String? videoErrorMessage,
    String? videoSourceUrl,
    int? completionThresholdPercentage,
    bool? isPublished,
    DateTime? scheduledPublishAt,
    String? customThumbnailUrl,
    String? slug,
    String? videoSource,
    bool? isAccessible,
    int? watchedSeconds,
    int? lastPositionSeconds,
    double? serverCompletionPercentage,
    DateTime? lastWatchedAt,
  }) {
    return Lesson(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      duration: duration ?? this.duration,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      muxPlaybackId: muxPlaybackId ?? this.muxPlaybackId,
      muxAssetId: muxAssetId ?? this.muxAssetId,
      order: order ?? this.order,
      isFreePreview: isFreePreview ?? this.isFreePreview,
      isCompleted: isCompleted ?? this.isCompleted,
      type: type ?? this.type,
      assignmentId: assignmentId ?? this.assignmentId,
      lockNextUntilSubmitted:
          lockNextUntilSubmitted ?? this.lockNextUntilSubmitted,
      videoStatus: videoStatus ?? this.videoStatus,
      videoProgress: videoProgress ?? this.videoProgress,
      videoErrorMessage: videoErrorMessage ?? this.videoErrorMessage,
      videoSourceUrl: videoSourceUrl ?? this.videoSourceUrl,
      completionThresholdPercentage:
          completionThresholdPercentage ?? this.completionThresholdPercentage,
      isPublished: isPublished ?? this.isPublished,
      scheduledPublishAt: scheduledPublishAt ?? this.scheduledPublishAt,
      customThumbnailUrl: customThumbnailUrl ?? this.customThumbnailUrl,
      slug: slug ?? this.slug,
      videoSource: videoSource ?? this.videoSource,
      isAccessible: isAccessible ?? this.isAccessible,
      watchedSeconds: watchedSeconds ?? this.watchedSeconds,
      lastPositionSeconds: lastPositionSeconds ?? this.lastPositionSeconds,
      serverCompletionPercentage:
          serverCompletionPercentage ?? this.serverCompletionPercentage,
      lastWatchedAt: lastWatchedAt ?? this.lastWatchedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        duration,
        durationSeconds,
        muxPlaybackId,
        muxAssetId,
        order,
        isFreePreview,
        isCompleted,
        type,
        assignmentId,
        lockNextUntilSubmitted,
        videoStatus,
        videoProgress,
        videoErrorMessage,
        videoSourceUrl,
        completionThresholdPercentage,
        isPublished,
        scheduledPublishAt,
        customThumbnailUrl,
        slug,
        videoSource,
        isAccessible,
        watchedSeconds,
        lastPositionSeconds,
        serverCompletionPercentage,
        lastWatchedAt,
      ];
}
