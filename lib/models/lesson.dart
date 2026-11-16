import 'package:equatable/equatable.dart';

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

  /// معرف التكليف المرتبط بالدرس (إن وجد).
  final String? assignmentId;

  /// هل يمنع فتح الدرس التالي حتى تسليم تكليف هذا الدرس؟
  final bool lockNextUntilSubmitted;

  /// حالة معالجة الفيديو السحابية: 'ready' | 'processing' | 'error'
  final String videoStatus;

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
    'completionThresholdPercentage': completionThresholdPercentage,
    'isPublished': isPublished,
    'scheduledPublishAt': scheduledPublishAt?.toIso8601String(),
    'customThumbnailUrl': customThumbnailUrl,
  };

  factory Lesson.fromMap(Map<String, dynamic> map) => Lesson(
    id: map['id'] ?? '',
    title: map['title'] ?? '',
    description: map['description'] ?? '',
    duration: map['duration'] ?? '',
    muxPlaybackId: map['muxPlaybackId'] ?? '',
    muxAssetId: map['muxAssetId'],
    order: map['order'] ?? 1,
    isFreePreview: map['isFreePreview'] ?? false,
    type: map['type'] ?? 'video',
    assignmentId: map['assignmentId'] as String?,
    lockNextUntilSubmitted: map['lockNextUntilSubmitted'] as bool? ?? false,
    videoStatus: map['videoStatus'] as String? ?? 'ready',
    completionThresholdPercentage:
        (map['completionThresholdPercentage'] as num?)?.toInt() ?? 95,
    isPublished: map['isPublished'] as bool? ?? true,
    scheduledPublishAt: _parseDate(map['scheduledPublishAt']),
    customThumbnailUrl: map['customThumbnailUrl'] as String?,
  );

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    try {
      return (value as dynamic).toDate() as DateTime;
    } catch (_) {}
    return DateTime.tryParse(value.toString());
  }

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
      completionThresholdPercentage:
          completionThresholdPercentage ?? this.completionThresholdPercentage,
      isPublished: isPublished ?? this.isPublished,
      scheduledPublishAt: scheduledPublishAt ?? this.scheduledPublishAt,
      customThumbnailUrl: customThumbnailUrl ?? this.customThumbnailUrl,
    );
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
    completionThresholdPercentage,
    isPublished,
    scheduledPublishAt,
    customThumbnailUrl,
  ];
}
