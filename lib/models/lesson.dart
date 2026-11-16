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

  /// نسبة تقدم معالجة الفيديو في Mux (0 إلى 100)
  final double videoProgress;

  /// رسالة الخطأ في حال فشل السحب في Mux
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

  const Lesson({
    required this.id,
    required this.title,
    required this.description,
    required this.duration,
    required this.muxPlaybackId,
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
  });

  bool get isAssignmentLesson =>
      type == 'assignment' || (muxPlaybackId.isEmpty && hasAssignment);
  bool get hasVideo => muxPlaybackId.trim().isNotEmpty;
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

  String get videoStreamUrl => 'https://stream.mux.com/$muxPlaybackId.m3u8';
  String get thumbnailUrl {
    if (customThumbnailUrl != null && customThumbnailUrl!.trim().isNotEmpty) {
      return customThumbnailUrl!;
    }
    if (muxPlaybackId.isNotEmpty) {
      return 'https://image.mux.com/$muxPlaybackId/thumbnail.jpg?width=600&height=340&fit_mode=smart';
    }
    return '';
  }

  int get durationInSeconds {
    final parts = duration.split(':');
    if (parts.length == 2) {
      final m = int.tryParse(parts[0]) ?? 0;
      final s = int.tryParse(parts[1]) ?? 0;
      return (m * 60) + s;
    } else if (parts.length == 3) {
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      final s = int.tryParse(parts[2]) ?? 0;
      return (h * 3600) + (m * 60) + s;
    }
    return 0;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'duration': duration,
        'muxPlaybackId': muxPlaybackId,
        'muxAssetId': muxAssetId,
        'order': order,
        'isFreePreview': isFreePreview,
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
      };

  factory Lesson.fromMap(Map<String, dynamic> map) => Lesson(
        id: map['id']?.toString() ?? '',
        title: map['title']?.toString() ?? '',
        description: map['description']?.toString() ?? '',
        duration: map['duration']?.toString() ?? '',
        muxPlaybackId: map['muxPlaybackId']?.toString() ?? '',
        muxAssetId: map['muxAssetId'] as String?,
        order: (map['order'] is num) ? (map['order'] as num).toInt() : 1,
        isFreePreview: map['isFreePreview'] == true,
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
      );

  Lesson copyWith({
    String? id,
    String? title,
    String? description,
    String? duration,
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
  }) {
    return Lesson(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      duration: duration ?? this.duration,
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
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        duration,
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
      ];
}
