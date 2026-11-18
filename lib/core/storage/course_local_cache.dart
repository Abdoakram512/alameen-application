import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/bootstrap_data.dart';
import '../../models/contact_info_data.dart';
import '../../models/course.dart';
import '../../models/student_courses_data.dart';
import '../../models/student_dashboard_data.dart';

/// Contract for isolated, user-specific and public offline caching of Laravel REST API data.
abstract class CourseLocalCache {
  Future<void> savePublicCourses(List<Course> courses);
  Future<List<Course>?> getPublicCourses({Duration maxAge = const Duration(days: 7)});

  Future<void> saveCourseDetails(String slug, Course course, {String? userId});
  Future<Course?> getCourseDetails(String slug, {String? userId, Duration maxAge = const Duration(days: 7)});

  Future<void> saveStudentDashboard(String userId, StudentDashboardData data);
  Future<StudentDashboardData?> getStudentDashboard(String userId, {Duration maxAge = const Duration(days: 7)});

  Future<void> saveStudentCourses(String userId, StudentCoursesData data);
  Future<StudentCoursesData?> getStudentCourses(String userId, {Duration maxAge = const Duration(days: 7)});

  Future<void> saveBootstrap(BootstrapData data);
  Future<BootstrapData?> getBootstrap({Duration maxAge = const Duration(days: 7)});

  Future<void> saveContactInfo(ContactInfoData data);
  Future<ContactInfoData?> getContactInfo({Duration maxAge = const Duration(days: 7)});

  Future<void> clearUserCache(String userId);
  Future<void> clearAllUserCaches();
  Future<void> clearAll();
}

/// Persistent implementation of [CourseLocalCache] backed by [SharedPreferences]
/// and an in-memory cache layer to guarantee offline stability and zero Firestore fallbacks.
class CourseLocalCacheImpl implements CourseLocalCache {
  static const String _publicCoursesKey = 'alameen_cache_public_courses';
  static const String _bootstrapKey = 'alameen_cache_bootstrap';
  static const String _contactKey = 'alameen_cache_contact';

  final SharedPreferences? _prefs;
  final Map<String, String> _memoryCache = {};

  CourseLocalCacheImpl({SharedPreferences? prefs}) : _prefs = prefs;

  Future<SharedPreferences?> _getPrefs() async {
    if (_prefs != null) return _prefs;
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeString(String key, String value) async {
    _memoryCache[key] = value;
    final prefs = await _getPrefs();
    await prefs?.setString(key, value);
  }

  Future<String?> _readString(String key) async {
    if (_memoryCache.containsKey(key)) {
      return _memoryCache[key];
    }
    final prefs = await _getPrefs();
    final value = prefs?.getString(key);
    if (value != null) {
      _memoryCache[key] = value;
    }
    return value;
  }

  Future<void> _removeKey(String key) async {
    _memoryCache.remove(key);
    final prefs = await _getPrefs();
    await prefs?.remove(key);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PUBLIC CATALOG & COURSES
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Future<void> savePublicCourses(List<Course> courses) async {
    final payload = {
      'cached_at': DateTime.now().toIso8601String(),
      'courses': courses.map((c) => c.toMap()).toList(),
    };
    await _writeString(_publicCoursesKey, jsonEncode(payload));
  }

  @override
  Future<List<Course>?> getPublicCourses({Duration maxAge = const Duration(days: 7)}) async {
    final raw = await _readString(_publicCoursesKey);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final rawList = decoded['courses'] as List? ?? [];
      return rawList
          .map((item) => Course.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveCourseDetails(String slug, Course course, {String? userId}) async {
    final key = (userId != null && userId.isNotEmpty)
        ? 'alameen_cache_course_${userId}_$slug'
        : 'alameen_cache_course_public_$slug';
    final payload = {
      'cached_at': DateTime.now().toIso8601String(),
      'user_id': userId,
      'course': course.toMap(),
    };
    await _writeString(key, jsonEncode(payload));
  }

  @override
  Future<Course?> getCourseDetails(String slug, {String? userId, Duration maxAge = const Duration(days: 7)}) async {
    // 1. Try user-specific course details first if userId provided
    if (userId != null && userId.isNotEmpty) {
      final userKey = 'alameen_cache_course_${userId}_$slug';
      final rawUser = await _readString(userKey);
      if (rawUser != null) {
        try {
          final decoded = jsonDecode(rawUser) as Map<String, dynamic>;
          if (decoded['user_id'] == userId && decoded['course'] != null) {
            return Course.fromMap(Map<String, dynamic>.from(decoded['course'] as Map));
          }
        } catch (_) {}
      }
    }

    // 2. Fall back to public course details
    final publicKey = 'alameen_cache_course_public_$slug';
    final rawPublic = await _readString(publicKey);
    if (rawPublic != null) {
      try {
        final decoded = jsonDecode(rawPublic) as Map<String, dynamic>;
        if (decoded['course'] != null) {
          return Course.fromMap(Map<String, dynamic>.from(decoded['course'] as Map));
        }
      } catch (_) {}
    }
    return null;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // USER-ISOLATED DASHBOARD & ENROLLED COURSES
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Future<void> saveStudentDashboard(String userId, StudentDashboardData data) async {
    final key = 'alameen_cache_dashboard_$userId';
    final payload = {
      'cached_at': DateTime.now().toIso8601String(),
      'user_id': userId,
      'enrolled_courses': data.enrolledCourses.map((c) => c.toMap()).toList(),
      'pending_courses': data.pendingCourses.map((c) => c.toMap()).toList(),
      'available_courses': data.availableCourses.map((c) => c.toMap()).toList(),
      'total_watched_videos': data.totalWatchedVideos,
      'total_watch_seconds': data.totalWatchSeconds,
      'total_watch_hours': data.totalWatchHours,
      'average_progress': data.averageProgress,
      'resume_course': data.resumeCourse?.toMap(),
      'resume_video': data.resumeVideo?.toMap(),
    };
    await _writeString(key, jsonEncode(payload));
  }

  @override
  Future<StudentDashboardData?> getStudentDashboard(String userId, {Duration maxAge = const Duration(days: 7)}) async {
    final key = 'alameen_cache_dashboard_$userId';
    final raw = await _readString(key);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      if (decoded['user_id'] != userId) return null; // Prevent account leakage!
      return StudentDashboardData.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveStudentCourses(String userId, StudentCoursesData data) async {
    final key = 'alameen_cache_student_courses_$userId';
    final payload = {
      'cached_at': DateTime.now().toIso8601String(),
      'user_id': userId,
      'stats': {
        'enrolled_count': data.enrolledCount,
        'completed_count': data.completedCount,
        'in_progress_count': data.inProgressCount,
        'certificates_count': data.certificatesCount,
      },
      'enrolled_course_ids': data.enrolledCourseIds,
      'enrolled_courses': data.enrolledCourses.map((e) => {
        'course': e.course.toMap(),
        'status': e.status,
        'expires_at': e.expiresAt?.toIso8601String(),
        'is_eligible_for_cert': e.isEligibleForCert,
        'progress': {
          'completed_count': e.completedCount,
          'total_count': e.totalCount,
          'percentage': e.percentage,
          'last_watched_at': e.lastWatchedAt?.toIso8601String(),
        }
      }).toList(),
    };
    await _writeString(key, jsonEncode(payload));
  }

  @override
  Future<StudentCoursesData?> getStudentCourses(String userId, {Duration maxAge = const Duration(days: 7)}) async {
    final key = 'alameen_cache_student_courses_$userId';
    final raw = await _readString(key);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      if (decoded['user_id'] != userId) return null; // Prevent account leakage!
      return StudentCoursesData.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BOOTSTRAP & CONTACT INFO
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Future<void> saveBootstrap(BootstrapData data) async {
    final payload = {
      'cached_at': DateTime.now().toIso8601String(),
      'branding': {
        'site_name': data.siteName,
        'site_tagline': data.siteTagline,
        'logo_url': data.logoUrl,
      },
      'currency': {
        'symbol': data.currencySymbol,
        'name': data.currencyName,
      },
      'theme': data.theme,
      'features': data.features,
      'contact': data.contact,
    };
    await _writeString(_bootstrapKey, jsonEncode(payload));
  }

  @override
  Future<BootstrapData?> getBootstrap({Duration maxAge = const Duration(days: 7)}) async {
    final raw = await _readString(_bootstrapKey);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return BootstrapData.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveContactInfo(ContactInfoData data) async {
    final payload = {
      'cached_at': DateTime.now().toIso8601String(),
      'email': data.email,
      'phone': data.phone,
      'whatsapp': data.whatsapp,
      'address': data.address,
    };
    await _writeString(_contactKey, jsonEncode(payload));
  }

  @override
  Future<ContactInfoData?> getContactInfo({Duration maxAge = const Duration(days: 7)}) async {
    final raw = await _readString(_contactKey);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return ContactInfoData.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CACHE INVALIDATION & LOGOUT CLEANUP
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Future<void> clearUserCache(String userId) async {
    await _removeKey('alameen_cache_dashboard_$userId');
    await _removeKey('alameen_cache_student_courses_$userId');

    final keysToRemove = <String>[];
    _memoryCache.forEach((k, _) {
      if (k.startsWith('alameen_cache_course_${userId}_')) {
        keysToRemove.add(k);
      }
    });
    for (final k in keysToRemove) {
      await _removeKey(k);
    }
  }

  @override
  Future<void> clearAllUserCaches() async {
    final keysToRemove = <String>[];
    _memoryCache.forEach((k, _) {
      if (k.contains('dashboard_') || k.contains('student_courses_') || k.contains('alameen_cache_course_')) {
        keysToRemove.add(k);
      }
    });
    for (final k in keysToRemove) {
      await _removeKey(k);
    }

    final prefs = await _getPrefs();
    if (prefs != null) {
      final allKeys = prefs.getKeys();
      for (final k in allKeys) {
        if (k.contains('dashboard_') || k.contains('student_courses_') || k.contains('alameen_cache_course_')) {
          await prefs.remove(k);
        }
      }
    }
  }

  @override
  Future<void> clearAll() async {
    _memoryCache.clear();
    final prefs = await _getPrefs();
    await prefs?.clear();
  }
}
