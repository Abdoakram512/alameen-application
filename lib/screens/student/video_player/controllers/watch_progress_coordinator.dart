import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/network/api_exceptions.dart';
import '../../../../models/course_progress_policy.dart';
import '../../../../models/learning_history.dart';
import '../../../../models/lesson.dart';
import '../../../../models/lesson_coverage_tracker.dart';
import '../../../../models/user_profile.dart';
import '../../../../repositories/student_watch_repository.dart';
import '../../../../services/ip_service.dart';
import '../../../../services/watch_queue.dart';

/// منسق تقدم المشاهدة وحساب وقت التعلم عبر Laravel REST API:
/// 1. دورة المزامنة الدورية كل 300 ثانية (5 دقائق).
/// 2. احتساب الإكمال التلقائي عند بلوغ 95% من النطاقات الفريدة غير المتكررة (بدون احتساب القفز أو الإعادة أو التخزين المؤقت).
/// 3. عدم إسقاط حدث نهاية الجلسة (Session-End) عند تداخل المزامنة أو عندما تكون الثواني المعلقة صفراً.
/// 4. حفظ الموضع والتغطية محلياً بصورة معزولة لكل حساب طالب مع طابور عدم اتصال آمن.
/// 5. احترام إلغاء الاشتراك أو انتهاء صلاحية الجلسة (401 / 403).
class WatchProgressCoordinator {
  final UserModel currentUser;
  final String courseId;
  final String? courseSlug;
  final String courseTitle;
  final Lesson lesson;
  final StudentWatchRepository? watchRepository;
  final VoidCallback? onLessonAutoCompleted;
  final VoidCallback? onProgressSynced;
  final void Function(int statusCode, String message)? onAuthorizationLost;

  static const int flushThresholdSeconds = 300;

  late final String sessionId;
  final DateTime sessionStartTime;
  LessonCoverageTracker _coverageTracker = LessonCoverageTracker();

  int _pendingWatchedSeconds = 0;
  int _sessionCumulativeSeconds = 0;
  int _lastPlaybackSecond = -1;
  int _currentPlayheadSeconds = 0;
  int _maxPlayheadSeconds = 0;
  int _serverBaselineWatchedSeconds = 0;
  bool _isCompleted = false;

  bool _isSyncing = false;
  bool _pendingSessionEndScheduled = false;
  Future<void>? _activeSyncFuture;

  IpInfo? _clientIpInfo;
  Timer? _tickerTimer;

  final SharedPreferencesAsync _preferences;
  final WatchQueue _watchQueue;

  WatchProgressCoordinator({
    required this.currentUser,
    required this.courseId,
    this.courseSlug,
    required this.courseTitle,
    required this.lesson,
    StudentWatchRepository? watchRepository,
    this.onLessonAutoCompleted,
    this.onProgressSynced,
    this.onAuthorizationLost,
    String? customSessionId,
    SharedPreferencesAsync? preferences,
    WatchQueue? watchQueue,
  })  : watchRepository = watchRepository ??
            (sl.isRegistered<StudentWatchRepository>()
                ? sl<StudentWatchRepository>()
                : null),
        sessionStartTime = DateTime.now(),
        _preferences = preferences ?? SharedPreferencesAsync(),
        _watchQueue = watchQueue ?? _buildDefaultQueue(watchRepository) {
    sessionId = customSessionId ??
        'sess_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999999)}';
    _isCompleted =
        lesson.isCompleted || currentUser.isLessonCompleted(lesson.id);
    _serverBaselineWatchedSeconds = lesson.watchedSeconds;
    _currentPlayheadSeconds = lesson.lastPositionSeconds;
  }

  static WatchQueue _buildDefaultQueue(StudentWatchRepository? repo) {
    if (repo != null) {
      return WatchQueue.forRepository(repo);
    }
    if (sl.isRegistered<WatchQueue>()) {
      return sl<WatchQueue>();
    }
    if (sl.isRegistered<StudentWatchRepository>()) {
      return WatchQueue.forRepository(sl<StudentWatchRepository>());
    }
    final prefs = SharedPreferencesAsync();
    return WatchQueue(
      read: prefs.getString,
      write: prefs.setString,
      send: (_) async {},
    );
  }

  // --- Getters ---
  int get pendingWatchedSeconds => _pendingWatchedSeconds;
  int get sessionCumulativeSeconds => _sessionCumulativeSeconds;
  int get maxPlayheadSeconds => _maxPlayheadSeconds;
  int get currentPlayheadSeconds => _currentPlayheadSeconds;
  int get serverBaselineWatchedSeconds => _serverBaselineWatchedSeconds;
  int get effectiveWatchedSeconds =>
      max(_serverBaselineWatchedSeconds, _coverageTracker.uniqueSeconds);
  bool get isCompleted => _isCompleted;
  LessonCoverageTracker get coverageTracker => _coverageTracker;
  IpInfo? get clientIpInfo => _clientIpInfo;

  String get _effectiveCourseSlug =>
      (courseSlug != null && courseSlug!.trim().isNotEmpty)
          ? courseSlug!.trim()
          : courseId;

  String get _effectiveLessonSlug =>
      (lesson.slug != null && lesson.slug!.trim().isNotEmpty)
          ? lesson.slug!.trim()
          : lesson.id;

  String get positionKey =>
      'position.${currentUser.uid}.$courseId.${lesson.id}';
  String get coverageKey =>
      'coverage.${currentUser.uid}.$courseId.${lesson.id}';

  /// تحديث خط الأساس القادم من الخادم بعد جلب بيانات المحاضرة الموثقة.
  void seedServerProgress({
    int watchedSeconds = 0,
    int lastPositionSeconds = 0,
    bool isCompleted = false,
  }) {
    if (watchedSeconds > _serverBaselineWatchedSeconds) {
      _serverBaselineWatchedSeconds = watchedSeconds;
    }
    if (lastPositionSeconds > 0 && _currentPlayheadSeconds == 0) {
      _currentPlayheadSeconds = lastPositionSeconds;
    }
    if (isCompleted && !_isCompleted) {
      _isCompleted = true;
    }
  }

  /// تهيئة المنسق، تفريغ الطابور المتراكم، واستعادة نطاقات التغطية المحلية المعزولة للمستخدم.
  Future<void> initialize() async {
    try {
      _clientIpInfo = await IpService().getClientIpInfo();
    } catch (_) {}

    _watchQueue.flush(currentUser.uid).catchError((Object _) {});

    final savedCoverage = await _preferences.getString(coverageKey);
    if (savedCoverage != null && savedCoverage.isNotEmpty) {
      _coverageTracker = LessonCoverageTracker.decodeRanges(savedCoverage);
    }

    _startWatchTimer();
  }

  void _startWatchTimer() {
    _tickerTimer?.cancel();
    _tickerTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      // نبضات عداد الثواني تُقاد بواسطة مشغل الفيديو عبر [recordPlaybackSecond]
    });
  }

  /// تسجيل ثانية تشغيل فعلية أثناء التشغيل العادي (بدون كتم أمني أو تخزين مؤقت أو إيقاف)
  void recordPlaybackSecond({
    required int currentPlayheadSeconds,
    required bool isPlaying,
    required bool isBuffering,
    required bool isScreenCaptured,
  }) {
    if (!isPlaying || isBuffering || isScreenCaptured) return;

    _currentPlayheadSeconds = currentPlayheadSeconds;
    if (currentPlayheadSeconds > _maxPlayheadSeconds) {
      _maxPlayheadSeconds = currentPlayheadSeconds;
    }

    final beforeUnique = _coverageTracker.uniqueSeconds;
    _coverageTracker.markPlayback(
      currentPosition: currentPlayheadSeconds,
      lastPosition: _lastPlaybackSecond,
    );
    _lastPlaybackSecond = currentPlayheadSeconds;

    final addedUnique = _coverageTracker.uniqueSeconds - beforeUnique;
    if (addedUnique > 0) {
      _pendingWatchedSeconds += addedUnique;
      _sessionCumulativeSeconds += addedUnique;
    }

    if (_pendingWatchedSeconds >= flushThresholdSeconds) {
      savePosition(currentPlayheadSeconds * 1000);
      flushWatchTime(isSessionEnd: false);
    }
  }

  /// إعادة تعيين playhead الأخير عند القفز (Seek) لمنع احتساب المقاطع المتجاوزة كوقت مشاهدة
  void onSeekPerformed({int? targetPositionSeconds}) {
    _lastPlaybackSecond = -1;
    if (targetPositionSeconds != null && targetPositionSeconds >= 0) {
      _currentPlayheadSeconds = targetPositionSeconds;
    }
  }

  /// حفظ موضع الاستئناف ونطاقات التغطية محلياً بشكل معزول للحساب الحالي.
  Future<void> savePosition(int positionMs) async {
    final safeMs = positionMs < 0 ? 0 : positionMs;
    _currentPlayheadSeconds = safeMs ~/ 1000;
    try {
      await _preferences.setInt(positionKey, safeMs);
      await _preferences.setString(coverageKey, _coverageTracker.encodeRanges());
      await _preferences.setString(
        'learning.recent.${currentUser.uid}',
        RecentLesson(
          courseId: courseId,
          lessonId: lesson.id,
          positionMs: safeMs,
        ).encode(),
      );
      learningHistoryRevision.value++;
    } catch (_) {}
  }

  /// مزامنة التقدم مع Laravel REST API عبر WatchQueue:
  /// - تضمن عدم ضياع حدث نهاية الجلسة عند التداخل أو عند كون الثواني المعلقة 0.
  /// - تطبق قاعدة 95% الصارمة من النطاقات الفريدة.
  /// - توقف المشغل وتُخطر الواجهة إذا استجاب الخادم بـ 401 أو 403.
  Future<void> flushWatchTime({
    bool isSessionEnd = false,
    int? currentPositionSeconds,
  }) async {
    if (_isSyncing) {
      if (isSessionEnd) {
        _pendingSessionEndScheduled = true;
      }
      return _activeSyncFuture;
    }

    if (_pendingWatchedSeconds <= 0 && !isSessionEnd) {
      return;
    }

    _isSyncing = true;
    final completer = Completer<void>();
    _activeSyncFuture = completer.future;

    final secondsToFlush = _pendingWatchedSeconds;
    final totalDur = lesson.durationInSeconds;
    final requiredThreshold = max(
      CourseProgressPolicy.strictLevelThresholdPercent.toInt(),
      lesson.effectiveCompletionThresholdPercentage,
    );
    final actualCoveragePct = _coverageTracker.coveragePercentage(totalDur);

    final newlyCompleted = _coverageTracker.isComplete(totalDur, requiredThreshold);
    final completionFlag = newlyCompleted || _isCompleted;
    final positionToSend = currentPositionSeconds ??
        (_currentPlayheadSeconds > 0
            ? _currentPlayheadSeconds
            : _maxPlayheadSeconds);
    final totalWatchedToSend = effectiveWatchedSeconds;

    try {
      await _watchQueue.enqueue(
        uid: currentUser.uid,
        courseId: courseId,
        lessonId: lesson.id,
        courseSlug: _effectiveCourseSlug,
        lessonSlug: _effectiveLessonSlug,
        watchedSeconds: totalWatchedToSend,
        positionSeconds: positionToSend,
        seconds: secondsToFlush,
        sessionSeconds: _sessionCumulativeSeconds,
        studentName: currentUser.displayName,
        studentEmail: currentUser.email,
        lessonTitle: lesson.title,
        totalDurationSeconds: totalDur,
        maxPlayheadSeconds: _maxPlayheadSeconds,
        completionPercentage: actualCoveragePct,
        isCompleted: completionFlag,
        isSessionEnd: isSessionEnd,
        ipAddress: _clientIpInfo?.ip ?? '',
        networkType: _clientIpInfo?.networkType ?? '',
        devicePlatform: _clientIpInfo?.devicePlatform ?? '',
        sessionId: sessionId,
        coverageRanges: _coverageTracker.encodeRanges(),
      );

      _pendingWatchedSeconds -= secondsToFlush;
      if (_pendingWatchedSeconds < 0) _pendingWatchedSeconds = 0;

      await _watchQueue.flush(currentUser.uid);

      if (totalWatchedToSend > _serverBaselineWatchedSeconds) {
        _serverBaselineWatchedSeconds = totalWatchedToSend;
      }

      if (newlyCompleted && !_isCompleted) {
        _isCompleted = true;
        onLessonAutoCompleted?.call();
      }
      onProgressSynced?.call();
    } on UnauthorizedException catch (e) {
      onAuthorizationLost?.call(401, e.message);
    } on ForbiddenException catch (e) {
      onAuthorizationLost?.call(403, e.message);
    } on PlaybackAuthorizationException catch (e) {
      onAuthorizationLost?.call(e.statusCode ?? 403, e.message);
    } catch (_) {
      // يحتفظ WatchQueue بالأحداث في التخزين المحلي لإعادة المحاولة عند عودة الشبكة
    } finally {
      _isSyncing = false;
      completer.complete();
      _activeSyncFuture = null;

      if (_pendingSessionEndScheduled) {
        _pendingSessionEndScheduled = false;
        await flushWatchTime(
          isSessionEnd: true,
          currentPositionSeconds: positionToSend,
        );
      }
    }
  }

  /// التحضير لمغادرة الشاشة أو الانتقال لدرس آخر مع حفظ الموضع ومزامنة نهاية الجلسة.
  Future<void> prepareToLeave(int currentPositionMs) async {
    await savePosition(currentPositionMs);
    await flushWatchTime(
      isSessionEnd: true,
      currentPositionSeconds: currentPositionMs ~/ 1000,
    );
  }

  /// التخلص من الموارد وحفظ أي ثوانٍ متبقية غير متزامنة في الطابور المحلي.
  void dispose() {
    _tickerTimer?.cancel();

    if (_pendingWatchedSeconds > 0) {
      final totalWatchedToSend = effectiveWatchedSeconds;
      _watchQueue
          .enqueue(
            uid: currentUser.uid,
            courseId: courseId,
            lessonId: lesson.id,
            courseSlug: _effectiveCourseSlug,
            lessonSlug: _effectiveLessonSlug,
            watchedSeconds: totalWatchedToSend,
            positionSeconds: _currentPlayheadSeconds,
            seconds: _pendingWatchedSeconds,
            sessionSeconds: _sessionCumulativeSeconds,
            studentName: currentUser.displayName,
            studentEmail: currentUser.email,
            lessonTitle: lesson.title,
            totalDurationSeconds: lesson.durationInSeconds,
            maxPlayheadSeconds: _maxPlayheadSeconds,
            completionPercentage:
                _coverageTracker.coveragePercentage(lesson.durationInSeconds),
            isCompleted: _isCompleted,
            isSessionEnd: true,
            ipAddress: _clientIpInfo?.ip ?? '',
            networkType: _clientIpInfo?.networkType ?? '',
            devicePlatform: _clientIpInfo?.devicePlatform ?? '',
            sessionId: sessionId,
            coverageRanges: _coverageTracker.encodeRanges(),
          )
          .catchError((_) {});
      _pendingWatchedSeconds = 0;
    }
  }
}
