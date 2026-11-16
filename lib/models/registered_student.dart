import 'package:cloud_firestore/cloud_firestore.dart';

class RegisteredStudent {
  final String id;
  final String name;
  final String email;
  final String avatarUrl;
  final String phone;
  final String role;
  final DateTime joinedAt;
  final DateTime? lastActiveAt;
  final List<String> enrolledCourseIds;
  final Set<String> completedLessonIds;
  final int totalWatchSeconds;
  final bool isSuspended;
  final String? suspensionReason;
  final String appOrigin;
  final Map<String, DateTime> courseExpiryDates; // تاريخ انتهاء الاشتراك لكل كورس

  RegisteredStudent({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl = '',
    this.phone = '',
    this.role = 'student',
    required this.joinedAt,
    this.lastActiveAt,
    required this.enrolledCourseIds,
    required this.completedLessonIds,
    this.totalWatchSeconds = 0,
    this.isSuspended = false,
    this.suspensionReason,
    this.appOrigin = 'alameen_speech_center',
    Map<String, DateTime>? courseExpiryDates,
  }) : courseExpiryDates = courseExpiryDates != null ? Map.from(courseExpiryDates) : <String, DateTime>{};

  bool isCourseExpired(String courseId) {
    if (!courseExpiryDates.containsKey(courseId)) return false;
    final expiry = courseExpiryDates[courseId];
    if (expiry == null) return false;
    return DateTime.now().isAfter(expiry);
  }

  bool isEnrolled(String courseId) {
    if (!enrolledCourseIds.contains(courseId)) return false;
    return !isCourseExpired(courseId);
  }

  bool isLessonCompleted(String lessonId) => completedLessonIds.contains(lessonId);

  double calculateCourseProgress(List<String> courseLessonIds) {
    if (courseLessonIds.isEmpty) return 0.0;
    final int completed = courseLessonIds.where(completedLessonIds.contains).length;
    return completed / courseLessonIds.length;
  }

  int get watchTimeMinutes => (totalWatchSeconds / 60).round();
  double get watchTimeHours => (totalWatchSeconds / 3600);

  String get watchTimeFormatted {
    final totalMinutes = (totalWatchSeconds / 60).floor();
    final hours = (totalMinutes / 60).floor();
    final remainingMinutes = totalMinutes % 60;
    if (hours > 0) {
      return '$hours س و $remainingMinutes د';
    }
    return '$totalMinutes دقيقة';
  }

  String localizedWatchTime({bool isAr = true}) {
    final totalMinutes = (totalWatchSeconds / 60).floor();
    final hours = (totalMinutes / 60).floor();
    final remainingMinutes = totalMinutes % 60;
    if (hours > 0) {
      return isAr
          ? '$hours س و $remainingMinutes د'
          : '${hours}h ${remainingMinutes}m';
    }
    return isAr ? '$totalMinutes دقيقة' : '$totalMinutes min';
  }

  void grantAccess(String courseId, {DateTime? expiryDate}) {
    if (!enrolledCourseIds.contains(courseId)) {
      enrolledCourseIds.add(courseId);
    }
    if (expiryDate != null) {
      courseExpiryDates[courseId] = expiryDate;
    }
  }

  void revokeAccess(String courseId) {
    enrolledCourseIds.remove(courseId);
    courseExpiryDates.remove(courseId);
  }

  RegisteredStudent copyWith({
    String? id,
    String? name,
    String? email,
    String? avatarUrl,
    String? phone,
    String? role,
    DateTime? joinedAt,
    DateTime? lastActiveAt,
    List<String>? enrolledCourseIds,
    Set<String>? completedLessonIds,
    int? totalWatchSeconds,
    bool? isSuspended,
    String? suspensionReason,
    String? appOrigin,
    Map<String, DateTime>? courseExpiryDates,
  }) {
    return RegisteredStudent(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      enrolledCourseIds: enrolledCourseIds ?? List.from(this.enrolledCourseIds),
      completedLessonIds: completedLessonIds ?? Set.from(this.completedLessonIds),
      totalWatchSeconds: totalWatchSeconds ?? this.totalWatchSeconds,
      isSuspended: isSuspended ?? this.isSuspended,
      suspensionReason: suspensionReason ?? this.suspensionReason,
      appOrigin: appOrigin ?? this.appOrigin,
      courseExpiryDates: courseExpiryDates ?? Map.from(this.courseExpiryDates),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'uid': id,
        'name': name,
        'displayName': name,
        'email': email,
        'avatarUrl': avatarUrl,
        'photoUrl': avatarUrl,
        'phone': phone,
        'role': role,
        'joinedAt': joinedAt.toIso8601String(),
        'createdAt': joinedAt.toIso8601String(),
        'lastActiveAt': lastActiveAt?.toIso8601String(),
        'enrolledCourseIds': enrolledCourseIds,
        'completedLessonIds': completedLessonIds.toList(),
        'totalWatchSeconds': totalWatchSeconds,
        'isSuspended': isSuspended,
        'suspensionReason': suspensionReason,
        'appOrigin': appOrigin,
        'courseExpiryDates': courseExpiryDates.map((k, v) => MapEntry(k, v.toIso8601String())),
      };

  factory RegisteredStudent.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    DateTime? parseNullableDate(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    final rawExpiry = json['courseExpiryDates'] as Map<String, dynamic>? ?? {};
    final expiryDates = <String, DateTime>{};
    rawExpiry.forEach((k, v) {
      final parsed = parseNullableDate(v);
      if (parsed != null) expiryDates[k] = parsed;
    });

    return RegisteredStudent(
      id: json['id'] ?? json['uid'] ?? '',
      name: json['displayName'] ?? json['name'] ?? 'طالب الأمين سنتر',
      email: json['email'] ?? '',
      avatarUrl: json['photoUrl'] ?? json['avatarUrl'] ?? '',
      phone: json['phone'] ?? '',
      role: json['role'] ?? 'student',
      joinedAt: parseDate(json['createdAt'] ?? json['joinedAt']),
      lastActiveAt: parseNullableDate(json['lastActiveAt']),
      enrolledCourseIds: List<String>.from(json['enrolledCourseIds'] ?? []),
      completedLessonIds: Set<String>.from(json['completedLessonIds'] ?? []),
      totalWatchSeconds: json['totalWatchSeconds'] != null
          ? int.tryParse(json['totalWatchSeconds'].toString()) ?? 0
          : 0,
      isSuspended: json['isSuspended'] as bool? ?? false,
      suspensionReason: json['suspensionReason'] as String?,
      appOrigin: json['appOrigin'] as String? ?? 'alameen_speech_center',
      courseExpiryDates: expiryDates,
    );
  }
}
