import 'package:equatable/equatable.dart';
import '../core/converters/firestore_date_time_converter.dart';

/// تمثل جلسة مشاهدة نشطة حالياً في مجموعة `/active_watch_sessions`.
class ActiveWatchSession extends Equatable {
  final String id;
  final String studentId;
  final String studentName;
  final String studentEmail;
  final String studentPhone;
  final String courseId;
  final String courseTitle;
  final String lessonId;
  final String lessonTitle;
  final int currentPositionSeconds;
  final int totalDurationSeconds;
  final double progressPercentage;
  final String ipAddress;
  final String networkType;
  final String devicePlatform;
  final bool isPlaying;
  final DateTime startedAt;
  final DateTime lastHeartbeatAt;

  const ActiveWatchSession({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
    required this.studentPhone,
    required this.courseId,
    required this.courseTitle,
    required this.lessonId,
    required this.lessonTitle,
    required this.currentPositionSeconds,
    required this.totalDurationSeconds,
    required this.progressPercentage,
    required this.ipAddress,
    required this.networkType,
    required this.devicePlatform,
    required this.isPlaying,
    required this.startedAt,
    required this.lastHeartbeatAt,
  });

  /// تعتبر الجلسة منتهية أو متوقفة إذا مرت 5 دقائق دون أي نبضة جديدة
  bool get isStale =>
      DateTime.now().difference(lastHeartbeatAt).inSeconds > 300;

  String get currentPositionFormatted {
    final m = currentPositionSeconds ~/ 60;
    final s = currentPositionSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String get totalDurationFormatted {
    final m = totalDurationSeconds ~/ 60;
    final s = totalDurationSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  factory ActiveWatchSession.fromMap(Map<String, dynamic> map, {String? id}) {
    final curPos = (map['currentPositionSeconds'] as num?)?.toInt() ?? 0;
    final totDur = (map['totalDurationSeconds'] as num?)?.toInt() ?? 0;
    double progress = 0.0;
    if (totDur > 0) {
      progress = ((curPos / totDur) * 100).clamp(0.0, 100.0);
    } else if (map['progressPercentage'] != null) {
      progress = (map['progressPercentage'] as num).toDouble();
    }

    final parsedStartedAt =
        FirestoreDateTimeConverter.fromValue(map['startedAt']) ?? DateTime.now();
    final parsedHeartbeat =
        FirestoreDateTimeConverter.fromValue(map['lastHeartbeatAt']) ?? DateTime.now();

    return ActiveWatchSession(
      id: id ?? (map['id'] as String? ?? ''),
      studentId: (map['studentId'] ?? map['studentUid']) as String? ?? '',
      studentName: map['studentName'] as String? ?? '',
      studentEmail: map['studentEmail'] as String? ?? '',
      studentPhone: map['studentPhone'] as String? ?? '',
      courseId: map['courseId'] as String? ?? '',
      courseTitle: map['courseTitle'] as String? ?? '',
      lessonId: map['lessonId'] as String? ?? '',
      lessonTitle: map['lessonTitle'] as String? ?? '',
      currentPositionSeconds: curPos,
      totalDurationSeconds: totDur,
      progressPercentage: progress,
      ipAddress: map['ipAddress'] as String? ?? 'غير محدد',
      networkType: map['networkType'] as String? ?? 'غير محدد',
      devicePlatform: map['devicePlatform'] as String? ?? 'جهاز ذكي',
      isPlaying: map['isPlaying'] as bool? ?? true,
      startedAt: parsedStartedAt,
      lastHeartbeatAt: parsedHeartbeat,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'studentId': studentId,
      'studentUid': studentId,
      'studentName': studentName,
      'studentEmail': studentEmail,
      'studentPhone': studentPhone,
      'courseId': courseId,
      'courseTitle': courseTitle,
      'lessonId': lessonId,
      'lessonTitle': lessonTitle,
      'currentPositionSeconds': currentPositionSeconds,
      'totalDurationSeconds': totalDurationSeconds,
      'progressPercentage': progressPercentage,
      'ipAddress': ipAddress,
      'networkType': networkType,
      'devicePlatform': devicePlatform,
      'isPlaying': isPlaying,
      'startedAt': startedAt.toIso8601String(),
      'lastHeartbeatAt': lastHeartbeatAt.toIso8601String(),
    };
  }

  ActiveWatchSession copyWith({
    String? id,
    String? studentId,
    String? studentName,
    String? studentEmail,
    String? studentPhone,
    String? courseId,
    String? courseTitle,
    String? lessonId,
    String? lessonTitle,
    int? currentPositionSeconds,
    int? totalDurationSeconds,
    double? progressPercentage,
    String? ipAddress,
    String? networkType,
    String? devicePlatform,
    bool? isPlaying,
    DateTime? startedAt,
    DateTime? lastHeartbeatAt,
  }) {
    return ActiveWatchSession(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      studentEmail: studentEmail ?? this.studentEmail,
      studentPhone: studentPhone ?? this.studentPhone,
      courseId: courseId ?? this.courseId,
      courseTitle: courseTitle ?? this.courseTitle,
      lessonId: lessonId ?? this.lessonId,
      lessonTitle: lessonTitle ?? this.lessonTitle,
      currentPositionSeconds: currentPositionSeconds ?? this.currentPositionSeconds,
      totalDurationSeconds: totalDurationSeconds ?? this.totalDurationSeconds,
      progressPercentage: progressPercentage ?? this.progressPercentage,
      ipAddress: ipAddress ?? this.ipAddress,
      networkType: networkType ?? this.networkType,
      devicePlatform: devicePlatform ?? this.devicePlatform,
      isPlaying: isPlaying ?? this.isPlaying,
      startedAt: startedAt ?? this.startedAt,
      lastHeartbeatAt: lastHeartbeatAt ?? this.lastHeartbeatAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        studentId,
        courseId,
        lessonId,
        currentPositionSeconds,
        totalDurationSeconds,
        ipAddress,
        isPlaying,
        lastHeartbeatAt,
      ];
}
