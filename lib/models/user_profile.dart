import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class UserModel extends Equatable {
  final String uid;
  final String displayName;
  final String email;
  final String photoUrl;
  final String phone;
  final String role;
  final List<String> enrolledCourseIds;
  final List<String> completedLessonIds;
  final int totalWatchSeconds;
  final DateTime createdAt;
  final DateTime? lastActiveAt;
  final bool isSuspended;
  final String? suspensionReason;
  final Map<String, DateTime> courseExpiryDates; // تاريخ انتهاء الاشتراك لكل كورس

  const UserModel({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.photoUrl,
    this.phone = '',
    this.role = 'student',
    this.enrolledCourseIds = const [],
    this.completedLessonIds = const [],
    this.totalWatchSeconds = 0,
    required this.createdAt,
    this.lastActiveAt,
    this.isSuspended = false,
    this.suspensionReason,
    this.courseExpiryDates = const {},
  });

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
    int completed = courseLessonIds.where((id) => completedLessonIds.contains(id)).length;
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

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'displayName': displayName,
        'email': email,
        'photoUrl': photoUrl,
        'phone': phone,
        'role': role,
        'enrolledCourseIds': enrolledCourseIds,
        'completedLessonIds': completedLessonIds,
        'totalWatchSeconds': totalWatchSeconds,
        'createdAt': createdAt.toIso8601String(),
        'lastActiveAt': lastActiveAt?.toIso8601String(),
        'isSuspended': isSuspended,
        'suspensionReason': suspensionReason,
        'courseExpiryDates': courseExpiryDates.map((k, v) => MapEntry(k, v.toIso8601String())),
      };

  factory UserModel.fromMap(Map<String, dynamic> map, {String? uid}) {
    DateTime? parseNullableDate(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    final rawExpiry = map['courseExpiryDates'] as Map<String, dynamic>? ?? {};
    final expiryDates = <String, DateTime>{};
    rawExpiry.forEach((k, v) {
      final parsed = parseNullableDate(v);
      if (parsed != null) expiryDates[k] = parsed;
    });

    return UserModel(
      uid: uid ?? map['uid'] ?? '',
      displayName: map['displayName'] ?? map['name'] ?? 'طالب الأمين سنتر',
      email: map['email'] ?? '',
      photoUrl: map['photoUrl'] ?? map['avatarUrl'] ?? '',
      phone: map['phone'] ?? '',
      role: map['role'] ?? 'student',
      enrolledCourseIds: List<String>.from(map['enrolledCourseIds'] ?? []),
      completedLessonIds: List<String>.from(map['completedLessonIds'] ?? []),
      totalWatchSeconds: map['totalWatchSeconds'] != null
          ? int.tryParse(map['totalWatchSeconds'].toString()) ?? 0
          : 0,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] is Timestamp ? (map['createdAt'] as Timestamp).toDate() : DateTime.tryParse(map['createdAt'].toString())) ?? DateTime.now()
          : DateTime.now(),
      lastActiveAt: parseNullableDate(map['lastActiveAt']),
      isSuspended: map['isSuspended'] as bool? ?? false,
      suspensionReason: map['suspensionReason'] as String?,
      courseExpiryDates: expiryDates,
    );
  }

  UserModel copyWith({
    String? uid,
    String? displayName,
    String? email,
    String? photoUrl,
    String? phone,
    String? role,
    List<String>? enrolledCourseIds,
    List<String>? completedLessonIds,
    int? totalWatchSeconds,
    DateTime? createdAt,
    DateTime? lastActiveAt,
    bool? isSuspended,
    String? suspensionReason,
    Map<String, DateTime>? courseExpiryDates,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      enrolledCourseIds: enrolledCourseIds ?? List.from(this.enrolledCourseIds),
      completedLessonIds: completedLessonIds ?? List.from(this.completedLessonIds),
      totalWatchSeconds: totalWatchSeconds ?? this.totalWatchSeconds,
      createdAt: createdAt ?? this.createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      isSuspended: isSuspended ?? this.isSuspended,
      suspensionReason: suspensionReason ?? this.suspensionReason,
      courseExpiryDates: courseExpiryDates ?? Map.from(this.courseExpiryDates),
    );
  }

  @override
  List<Object?> get props => [
        uid,
        displayName,
        email,
        photoUrl,
        phone,
        role,
        enrolledCourseIds,
        completedLessonIds,
        totalWatchSeconds,
        createdAt,
        lastActiveAt,
        isSuspended,
        suspensionReason,
        courseExpiryDates,
      ];
}
