import 'package:equatable/equatable.dart';

/// نموذج بيانات حدث تقدم المشاهدة (WatchProgressEvent)
/// يضمن نموذجاً قوياً ومنمطاً بنسبة 100% بدلاً من الـ Maps غير النمطية
class WatchProgressEvent extends Equatable {
  final String id;
  final String uid;
  final String courseId;
  final String lessonId;
  final String? courseSlug;
  final String? lessonSlug;
  final int seconds;
  final int watchedSeconds;
  final int positionSeconds;
  final int? sessionSeconds;
  final bool? isSessionEnd;
  final bool? isCompleted;
  final double? completionPercentage;
  final String? studentName;
  final String? studentEmail;
  final String? lessonTitle;
  final String? ipAddress;
  final String? networkType;
  final String? devicePlatform;
  final int? totalDurationSeconds;
  final int? maxPlayheadSeconds;
  final String? sessionId;
  final String? coverageRanges;

  const WatchProgressEvent({
    required this.id,
    required this.uid,
    required this.courseId,
    required this.lessonId,
    this.courseSlug,
    this.lessonSlug,
    required this.seconds,
    this.watchedSeconds = 0,
    this.positionSeconds = 0,
    this.sessionSeconds,
    this.isSessionEnd,
    this.isCompleted,
    this.completionPercentage,
    this.studentName,
    this.studentEmail,
    this.lessonTitle,
    this.ipAddress,
    this.networkType,
    this.devicePlatform,
    this.totalDurationSeconds,
    this.maxPlayheadSeconds,
    this.sessionId,
    this.coverageRanges,
  });

  /// المفتاح المستخدم للتعرف على الدورة في خادم Laravel (يفضل slug)
  String get courseKey {
    if (courseSlug != null && courseSlug!.trim().isNotEmpty) {
      return courseSlug!.trim();
    }
    return courseId;
  }

  /// المفتاح المستخدم للتعرف على الدرس في خادم Laravel (يفضل slug)
  String get lessonKey {
    if (lessonSlug != null && lessonSlug!.trim().isNotEmpty) {
      return lessonSlug!.trim();
    }
    return lessonId;
  }

  /// الثواني الفعلية المشاهدة
  int get effectiveWatchedSeconds {
    if (watchedSeconds > 0) return watchedSeconds;
    if (sessionSeconds != null && sessionSeconds! > 0) return sessionSeconds!;
    return seconds;
  }

  /// موضع مؤشر التشغيل الفعلي
  int get effectivePositionSeconds {
    if (positionSeconds > 0) return positionSeconds;
    if (maxPlayheadSeconds != null && maxPlayheadSeconds! > 0) {
      return maxPlayheadSeconds!;
    }
    return 0;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'uid': uid,
        'courseId': courseId,
        'lessonId': lessonId,
        if (courseSlug != null) 'courseSlug': courseSlug,
        if (lessonSlug != null) 'lessonSlug': lessonSlug,
        'seconds': seconds,
        'watchedSeconds': watchedSeconds,
        'positionSeconds': positionSeconds,
        if (sessionSeconds != null) 'sessionSeconds': sessionSeconds,
        if (isSessionEnd != null) 'isSessionEnd': isSessionEnd,
        if (isCompleted != null) 'isCompleted': isCompleted,
        if (completionPercentage != null)
          'completionPercentage': completionPercentage,
        if (studentName != null) 'studentName': studentName,
        if (studentEmail != null) 'studentEmail': studentEmail,
        if (lessonTitle != null) 'lessonTitle': lessonTitle,
        if (ipAddress != null) 'ipAddress': ipAddress,
        if (networkType != null) 'networkType': networkType,
        if (devicePlatform != null) 'devicePlatform': devicePlatform,
        if (totalDurationSeconds != null)
          'totalDurationSeconds': totalDurationSeconds,
        if (maxPlayheadSeconds != null)
          'maxPlayheadSeconds': maxPlayheadSeconds,
        if (sessionId != null) 'sessionId': sessionId,
        if (coverageRanges != null) 'coverageRanges': coverageRanges,
      };

  Map<String, dynamic> toJson() => toMap();

  factory WatchProgressEvent.fromMap(Map<String, dynamic> map) {
    return WatchProgressEvent(
      id: map['id']?.toString() ?? '',
      uid: map['uid']?.toString() ?? '',
      courseId: map['courseId']?.toString() ?? '',
      lessonId: map['lessonId']?.toString() ?? '',
      courseSlug: map['courseSlug']?.toString(),
      lessonSlug: map['lessonSlug']?.toString(),
      seconds: (map['seconds'] as num?)?.toInt() ?? 0,
      watchedSeconds: (map['watchedSeconds'] as num?)?.toInt() ??
          (map['sessionSeconds'] as num?)?.toInt() ??
          (map['seconds'] as num?)?.toInt() ??
          0,
      positionSeconds: (map['positionSeconds'] as num?)?.toInt() ??
          (map['maxPlayheadSeconds'] as num?)?.toInt() ??
          0,
      sessionSeconds: (map['sessionSeconds'] as num?)?.toInt(),
      isSessionEnd: map['isSessionEnd'] as bool?,
      isCompleted: map['isCompleted'] as bool?,
      completionPercentage: (map['completionPercentage'] as num?)?.toDouble(),
      studentName: map['studentName']?.toString(),
      studentEmail: map['studentEmail']?.toString(),
      lessonTitle: map['lessonTitle']?.toString(),
      ipAddress: map['ipAddress']?.toString(),
      networkType: map['networkType']?.toString(),
      devicePlatform: map['devicePlatform']?.toString(),
      totalDurationSeconds: (map['totalDurationSeconds'] as num?)?.toInt(),
      maxPlayheadSeconds: (map['maxPlayheadSeconds'] as num?)?.toInt(),
      sessionId: map['sessionId']?.toString(),
      coverageRanges: map['coverageRanges']?.toString(),
    );
  }

  /// دعم المفاتيح كـ Map للحفاظ على التوافق الكامل مع أي اختبارات قديمة
  dynamic operator [](String key) {
    switch (key) {
      case 'id':
        return id;
      case 'uid':
        return uid;
      case 'courseId':
        return courseId;
      case 'lessonId':
        return lessonId;
      case 'courseSlug':
        return courseSlug;
      case 'lessonSlug':
        return lessonSlug;
      case 'seconds':
        return seconds;
      case 'watchedSeconds':
        return watchedSeconds;
      case 'positionSeconds':
        return positionSeconds;
      case 'sessionSeconds':
        return sessionSeconds;
      case 'isSessionEnd':
        return isSessionEnd;
      case 'isCompleted':
        return isCompleted;
      case 'completionPercentage':
        return completionPercentage;
      case 'studentName':
        return studentName;
      case 'studentEmail':
        return studentEmail;
      case 'lessonTitle':
        return lessonTitle;
      case 'ipAddress':
        return ipAddress;
      case 'networkType':
        return networkType;
      case 'devicePlatform':
        return devicePlatform;
      case 'totalDurationSeconds':
        return totalDurationSeconds;
      case 'maxPlayheadSeconds':
        return maxPlayheadSeconds;
      case 'sessionId':
        return sessionId;
      case 'coverageRanges':
        return coverageRanges;
      default:
        return null;
    }
  }

  @override
  List<Object?> get props => [
        id,
        uid,
        courseId,
        lessonId,
        courseSlug,
        lessonSlug,
        seconds,
        watchedSeconds,
        positionSeconds,
        sessionSeconds,
        isSessionEnd,
        isCompleted,
        completionPercentage,
        studentName,
        studentEmail,
        lessonTitle,
        ipAddress,
        networkType,
        devicePlatform,
        totalDurationSeconds,
        maxPlayheadSeconds,
        sessionId,
        coverageRanges,
      ];
}
