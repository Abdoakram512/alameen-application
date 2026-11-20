import 'package:equatable/equatable.dart';

class UserModel extends Equatable {
  final String uid;
  final int? id;
  final String displayName;
  final String email;
  final String photoUrl;
  final String phone;
  final String role;
  final String status;
  final String? country;
  final String? city;
  final String? address;
  final String? locale;
  final bool emailVerified;
  final List<String> enrolledCourseIds;
  final List<String> fullCourseEntitlements;
  final List<String> levelEntitlements;
  final List<String> unlockedLevelIds;
  final List<String> completedLessonIds;
  final int totalWatchSeconds;
  final DateTime createdAt;
  final DateTime? lastActiveAt;
  final bool isSuspended;
  final String? suspensionReason;
  final Map<String, DateTime> courseExpiryDates; // تاريخ انتهاء الاشتراك لكل كورس

  const UserModel({
    required this.uid,
    this.id,
    required this.displayName,
    required this.email,
    required this.photoUrl,
    this.phone = '',
    this.role = 'student',
    this.status = 'active',
    this.country,
    this.city,
    this.address,
    this.locale,
    this.emailVerified = true,
    this.enrolledCourseIds = const [],
    this.fullCourseEntitlements = const [],
    this.levelEntitlements = const [],
    this.unlockedLevelIds = const [],
    this.completedLessonIds = const [],
    this.totalWatchSeconds = 0,
    required this.createdAt,
    this.lastActiveAt,
    this.isSuspended = false,
    this.suspensionReason,
    this.courseExpiryDates = const {},
  });

  bool get isPending => status.toLowerCase() == 'pending';
  bool get isSuspendedAccount => isSuspended || status.toLowerCase() == 'suspended';

  bool isLevelUnlocked(String courseId, String levelId) {
    if (fullCourseEntitlements.contains(courseId)) return true;
    final token = '$courseId:$levelId';
    return levelEntitlements.contains(token) || unlockedLevelIds.contains(token);
  }

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
        'id': id,
        'displayName': displayName,
        'email': email,
        'photoUrl': photoUrl,
        'phone': phone,
        'role': role,
        'status': status,
        'country': country,
        'city': city,
        'address': address,
        'locale': locale,
        'emailVerified': emailVerified,
        'enrolledCourseIds': enrolledCourseIds,
        'fullCourseEntitlements': fullCourseEntitlements,
        'levelEntitlements': levelEntitlements,
        'unlockedLevelIds': unlockedLevelIds,
        'completedLessonIds': completedLessonIds,
        'totalWatchSeconds': totalWatchSeconds,
        'createdAt': createdAt.toIso8601String(),
        'lastActiveAt': lastActiveAt?.toIso8601String(),
        'isSuspended': isSuspended,
        'suspensionReason': suspensionReason,
        'courseExpiryDates': courseExpiryDates.map((k, v) => MapEntry(k, v.toIso8601String())),
      };

  factory UserModel.fromLaravelJson(Map<String, dynamic> json) {
    final dynamic idVal = json['id'] ?? json['user_id'];
    int? numericId;
    if (idVal is int) {
      numericId = idVal;
    } else if (idVal != null) {
      numericId = int.tryParse(idVal.toString());
    }
    // Only accept uid if it parses to a valid positive integer ID
    if (numericId == null && json['uid'] != null) {
      numericId = int.tryParse(json['uid'].toString());
    }

    if (numericId == null || numericId <= 0) {
      throw FormatException(
        'Authenticated Laravel user identity is missing or invalid: id=$idVal, uid=${json['uid']}',
      );
    }
    final String resolvedUid = numericId.toString();

    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    final String statusStr = (json['status']?.toString() ?? 'active').toLowerCase();
    final bool suspended = statusStr == 'suspended' || json['is_suspended'] == true;

    return UserModel(
      uid: resolvedUid,
      id: numericId,
      displayName: json['name']?.toString() ?? 'طالب الأمين سنتر',
      email: json['email']?.toString() ?? '',
      photoUrl: json['avatar_url']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      role: json['role']?.toString() ?? 'student',
      status: statusStr,
      country: json['country']?.toString(),
      city: json['city']?.toString(),
      address: json['address']?.toString(),
      locale: json['locale']?.toString() ?? 'ar',
      emailVerified: json['email_verified'] == true || json['email_verified_at'] != null,
      createdAt: parseDate(json['created_at']),
      isSuspended: suspended,
      suspensionReason: json['suspension_reason']?.toString(),
    );
  }

  factory UserModel.fromMap(Map<String, dynamic> map, {String? uid}) {
    DateTime? parseNullableDate(dynamic val) {
      if (val == null) return null;
      if (val is DateTime) return val;
      try {
        final dynamic d = val;
        final toDate = d.toDate;
        if (toDate is Function) {
          final res = toDate();
          if (res is DateTime) return res;
        }
      } catch (_) {}
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    final rawExpiry = map['courseExpiryDates'] as Map<String, dynamic>? ?? {};
    final expiryDates = <String, DateTime>{};
    rawExpiry.forEach((k, v) {
      final parsed = parseNullableDate(v);
      if (parsed != null) expiryDates[k] = parsed;
    });

    final dynamic idVal = map['id'];
    final int? numericId = idVal is int ? idVal : int.tryParse(idVal?.toString() ?? '');

    return UserModel(
      uid: uid ?? map['uid'] ?? numericId?.toString() ?? '',
      id: numericId,
      displayName: map['displayName'] ?? map['name'] ?? 'طالب الأمين سنتر',
      email: map['email'] ?? '',
      photoUrl: map['photoUrl'] ?? map['avatarUrl'] ?? map['avatar_url'] ?? '',
      phone: map['phone'] ?? '',
      role: map['role'] ?? 'student',
      status: (map['status']?.toString() ?? 'active').toLowerCase(),
      country: map['country']?.toString(),
      city: map['city']?.toString(),
      address: map['address']?.toString(),
      locale: map['locale']?.toString() ?? 'ar',
      emailVerified: map['emailVerified'] == true || map['email_verified'] == true,
      enrolledCourseIds: List<String>.from(map['enrolledCourseIds'] ?? []),
      fullCourseEntitlements: List<String>.from(map['fullCourseEntitlements'] ?? []),
      levelEntitlements: List<String>.from(map['levelEntitlements'] ?? []),
      unlockedLevelIds: List<String>.from(map['unlockedLevelIds'] ?? []),
      completedLessonIds: List<String>.from(map['completedLessonIds'] ?? []),
      totalWatchSeconds: map['totalWatchSeconds'] != null
          ? int.tryParse(map['totalWatchSeconds'].toString()) ?? 0
          : 0,
      createdAt: parseNullableDate(map['createdAt']) ?? DateTime.now(),
      lastActiveAt: parseNullableDate(map['lastActiveAt']),
      isSuspended: (map['isSuspended'] as bool? ?? false) || (map['status'] == 'suspended'),
      suspensionReason: map['suspensionReason'] as String?,
      courseExpiryDates: expiryDates,
    );
  }

  UserModel copyWith({
    String? uid,
    int? id,
    String? displayName,
    String? email,
    String? photoUrl,
    String? phone,
    String? role,
    String? status,
    String? country,
    String? city,
    String? address,
    String? locale,
    bool? emailVerified,
    List<String>? enrolledCourseIds,
    List<String>? fullCourseEntitlements,
    List<String>? levelEntitlements,
    List<String>? unlockedLevelIds,
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
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      status: status ?? this.status,
      country: country ?? this.country,
      city: city ?? this.city,
      address: address ?? this.address,
      locale: locale ?? this.locale,
      emailVerified: emailVerified ?? this.emailVerified,
      enrolledCourseIds: enrolledCourseIds ?? List.from(this.enrolledCourseIds),
      fullCourseEntitlements: fullCourseEntitlements ?? List.from(this.fullCourseEntitlements),
      levelEntitlements: levelEntitlements ?? List.from(this.levelEntitlements),
      unlockedLevelIds: unlockedLevelIds ?? List.from(this.unlockedLevelIds),
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
        id,
        displayName,
        email,
        photoUrl,
        phone,
        role,
        status,
        country,
        city,
        address,
        locale,
        emailVerified,
        enrolledCourseIds,
        fullCourseEntitlements,
        levelEntitlements,
        unlockedLevelIds,
        completedLessonIds,
        totalWatchSeconds,
        createdAt,
        lastActiveAt,
        isSuspended,
        suspensionReason,
        courseExpiryDates,
      ];
}
