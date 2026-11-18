import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/network/api_exceptions.dart';
import '../repositories/student_watch_repository.dart';

/// طابور متين ومستقل لكل حساب طالب لمزامنة تقدم المشاهدة بدون فقدان أو تداخل بين الحسابات.
///
/// ملاحظة معمارية: نقطة نهاية Laravel (`POST /student/courses/{slug}/lessons/{lesson}/progress`)
/// تستقبل `watched_seconds` و `position_seconds` بدون مفتاح تكرار (`idempotency_key`) من الخادم حالياً؛
/// لذا يحافظ الطابور على ثبات معرّف الحدث محلياً، ويفرز الأحداث لكل مستخدم، ويزيل أحداث الدورات التي رُفضت بـ 403.
class WatchQueue {
  final Future<String?> Function(String key) read;
  final Future<void> Function(String key, String value) write;
  final Future<void> Function(Map<String, dynamic> event) send;
  final void Function(String courseId)? onEnrollmentRevoked;
  Future<void> _tail = Future.value();

  WatchQueue({
    required this.read,
    required this.write,
    required this.send,
    this.onEnrollmentRevoked,
  });

  /// مُنشئ افتراضي يربط الطابور بمستودع Laravel REST API.
  factory WatchQueue.forRepository(
    StudentWatchRepository repository, {
    SharedPreferencesAsync? preferences,
    void Function(String courseId)? onEnrollmentRevoked,
  }) {
    final prefs = preferences ?? SharedPreferencesAsync();
    return WatchQueue(
      read: prefs.getString,
      write: prefs.setString,
      onEnrollmentRevoked: onEnrollmentRevoked,
      send: (event) async {
        final rawCourseSlug = event['courseSlug']?.toString().trim() ?? '';
        final courseKey = rawCourseSlug.isNotEmpty
            ? rawCourseSlug
            : (event['courseId']?.toString() ?? '');
        final rawLessonSlug = event['lessonSlug']?.toString().trim() ?? '';
        final lessonKey = rawLessonSlug.isNotEmpty
            ? rawLessonSlug
            : (event['lessonId']?.toString() ?? '');

        final watchedSec = (event['watchedSeconds'] as num?)?.toInt() ??
            (event['sessionSeconds'] as num?)?.toInt() ??
            (event['seconds'] as num?)?.toInt() ??
            0;
        final posSec = (event['positionSeconds'] as num?)?.toInt() ??
            (event['maxPlayheadSeconds'] as num?)?.toInt() ??
            0;

        await repository.recordLessonProgress(
          courseSlugOrId: courseKey,
          lessonSlugOrId: lessonKey,
          watchedSeconds: watchedSec,
          positionSeconds: posSec,
          isCompleted: event['isCompleted'] as bool?,
        );
      },
    );
  }

  Future<T> _serial<T>(Future<T> Function() work) {
    final result = _tail.then((_) => work());
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  static bool isValidUid(String uid) {
    final trimmed = uid.trim();
    if (trimmed.isEmpty ||
        trimmed.toLowerCase() == 'uid' ||
        trimmed.toLowerCase() == 'null' ||
        trimmed == '0') {
      return false;
    }
    return true;
  }

  static String storageKeyForUser(String uid) {
    if (!isValidUid(uid)) {
      throw ArgumentError('Invalid user ID for watch queue storage key: "$uid"');
    }
    return 'watch.queue.v1.${uid.trim()}';
  }

  String _key(String uid) => storageKeyForUser(uid);

  Future<List<Map<String, dynamic>>> _load(String uid) async {
    if (!isValidUid(uid)) return [];
    final raw = await read(_key(uid));
    if (raw == null || raw.trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// مسح الطابور المحلي لمستخدم محدد (يُستدعى عند تسجيل الخروج أو حذف الحساب لمنع التسرب).
  Future<void> clearUser(String uid) => _serial(() async {
        if (!isValidUid(uid)) return;
        await write(_key(uid), '[]');
      });

  /// مسح مباشر من التخزين عند تسجيل الخروج من AuthCubit.
  static Future<void> clearStorageForUser(
    String uid, {
    SharedPreferencesAsync? preferences,
  }) async {
    if (!isValidUid(uid)) return;
    try {
      final prefs = preferences ?? SharedPreferencesAsync();
      await prefs.remove(storageKeyForUser(uid));
    } catch (_) {}
  }

  Future<int> pendingCount(String uid) => _serial<int>(() async {
        if (!isValidUid(uid)) return 0;
        final events = await _load(uid);
        return events.length;
      });

  Future<void> enqueue({
    required String uid,
    required String courseId,
    required String lessonId,
    required int seconds,
    String? courseSlug,
    String? lessonSlug,
    int? watchedSeconds,
    int? positionSeconds,
    int? sessionSeconds,
    bool? isSessionEnd,
    String? studentName,
    String? studentEmail,
    String? lessonTitle,
    String? ipAddress,
    String? networkType,
    String? devicePlatform,
    int? totalDurationSeconds,
    int? maxPlayheadSeconds,
    double? completionPercentage,
    bool? isCompleted,
    String? sessionId,
    String? coverageRanges,
  }) =>
      _serial(() async {
        if (!isValidUid(uid)) return;
        if (seconds <= 0 &&
            (watchedSeconds ?? 0) <= 0 &&
            isSessionEnd != true &&
            isCompleted != true) {
          return;
        }
        final events = await _load(uid);
        events.add({
          'id':
              '${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 32)}',
          'uid': uid,
          'courseId': courseId,
          'lessonId': lessonId,
          'courseSlug': ?courseSlug,
          'lessonSlug': ?lessonSlug,
          'watchedSeconds': ?watchedSeconds,
          'positionSeconds': ?positionSeconds,
          'seconds': seconds,
          'sessionSeconds': ?sessionSeconds,
          'isSessionEnd': ?isSessionEnd,
          'studentName': ?studentName,
          'studentEmail': ?studentEmail,
          'lessonTitle': ?lessonTitle,
          'ipAddress': ?ipAddress,
          'networkType': ?networkType,
          'devicePlatform': ?devicePlatform,
          'totalDurationSeconds': ?totalDurationSeconds,
          'maxPlayheadSeconds': ?maxPlayheadSeconds,
          'completionPercentage': ?completionPercentage,
          'isCompleted': ?isCompleted,
          'sessionId': ?sessionId,
          'coverageRanges': ?coverageRanges,
        });
        await write(_key(uid), jsonEncode(events));
      });

  bool _isForbiddenError(Object error) {
    if (error is ForbiddenException) return true;
    if (error is PlaybackAuthorizationException && error.statusCode == 403) {
      return true;
    }
    return false;
  }

  bool _isUnauthorizedError(Object error) {
    if (error is UnauthorizedException) return true;
    if (error is PlaybackAuthorizationException && error.statusCode == 401) {
      return true;
    }
    return false;
  }

  Future<void> flush(String uid) => _serial(() async {
        if (!isValidUid(uid)) return;
        final events = await _load(uid);
        while (events.isNotEmpty) {
          final current = events.first;
          // عزل صارم: لا يُسمح بإرسال حدث يخص حساباً آخر
          if (current['uid']?.toString() != uid) {
            events.removeAt(0);
            await write(_key(uid), jsonEncode(events));
            continue;
          }

          try {
            await send(current);
            events.removeAt(0);
            await write(_key(uid), jsonEncode(events));
          } catch (e) {
            if (_isForbiddenError(e)) {
              // تم إلغاء أو انتهاء صلاحية الاشتراك لهذه الدورة على الخادم:
              // إزالة أحداث هذه الدورة فوراً حتى لا تعطل بقية الدورات ولا تستنزف البطارية.
              final revokedCourseId = current['courseId']?.toString() ?? '';
              events.removeWhere(
                (item) => item['courseId']?.toString() == revokedCourseId,
              );
              await write(_key(uid), jsonEncode(events));
              if (revokedCourseId.isNotEmpty) {
                onEnrollmentRevoked?.call(revokedCourseId);
              }
              rethrow;
            }
            if (_isUnauthorizedError(e)) {
              // توقف آمن عند انتهاء جلسة Sanctum مع بقاء الطابور معزولاً لصاحبه
              rethrow;
            }
            rethrow;
          }
        }
      });
}
