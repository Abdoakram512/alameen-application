import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../models/active_watch_session.dart';
import '../../../../models/learning_history.dart';
import '../../../../models/lesson.dart';
import '../../../../models/lesson_coverage_tracker.dart';
import '../../../../models/user_profile.dart';
import '../../../../services/firestore_service.dart';
import '../../../../services/ip_service.dart';
import '../../../../services/watch_queue.dart';

/// منسق تقدم المشاهدة وحساب وقت التعلم وفق شروط المنصة الصارمة:
/// 1. دورة المزامنة الدورية كل 300 ثانية (5 دقائق).
/// 2. احتساب الإكمال التلقائي عند بلوغ 95% من النطاقات الفريدة غير المتكررة.
/// 3. عدم إسقاط حدث نهاية الجلسة (Session-End) عند تداخل المزامنة أو عندما تكون الثواني المعلقة صفراً.
/// 4. الحفاظ على معرّف الجلسة الفريد (Session ID) لضمان عدم تكرار الزيادة أو تراجع الإحصائيات عند إعادة المحاولة.
/// 5. حفظ التقدم محلياً بصورة متينة ودعم استعادة التقدم المدمج عبر الأجهزة المتعددة.
class WatchProgressCoordinator {
  final UserModel currentUser;
  final String courseId;
  final String courseTitle;
  final Lesson lesson;
  final FirestoreService firestoreService;
  final VoidCallback? onLessonAutoCompleted;

  static const int flushThresholdSeconds = 300;

  late final String sessionId;
  final DateTime sessionStartTime;
  LessonCoverageTracker _coverageTracker = LessonCoverageTracker();

  int _pendingWatchedSeconds = 0;
  int _sessionCumulativeSeconds = 0;
  int _lastPlaybackSecond = -1;
  int _maxPlayheadSeconds = 0;
  bool _isCompleted = false;

  bool _isSyncing = false;
  bool _pendingSessionEndScheduled = false;
  Future<void>? _activeSyncFuture;

  IpInfo? _clientIpInfo;
  Timer? _tickerTimer;

  final SharedPreferencesAsync _preferences;
  final WatchQueue _watchQueue;
  static final _defaultQueuePreferences = SharedPreferencesAsync();
  static final _defaultWatchQueue = WatchQueue(
    read: _defaultQueuePreferences.getString,
    write: _defaultQueuePreferences.setString,
    send: (event) => FirestoreService().recordWatchEvent(event),
  );

  WatchProgressCoordinator({
    required this.currentUser,
    required this.courseId,
    required this.courseTitle,
    required this.lesson,
    FirestoreService? firestoreService,
    this.onLessonAutoCompleted,
    String? customSessionId,
    SharedPreferencesAsync? preferences,
    WatchQueue? watchQueue,
  })  : firestoreService = firestoreService ?? FirestoreService(),
        sessionStartTime = DateTime.now(),
        _preferences = preferences ?? SharedPreferencesAsync(),
        _watchQueue = watchQueue ?? _defaultWatchQueue {
    sessionId = customSessionId ??
        'sess_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999999)}';
    _isCompleted = currentUser.isLessonCompleted(lesson.id);
  }

  // --- Getters ---
  int get pendingWatchedSeconds => _pendingWatchedSeconds;
  int get sessionCumulativeSeconds => _sessionCumulativeSeconds;
  int get maxPlayheadSeconds => _maxPlayheadSeconds;
  bool get isCompleted => _isCompleted;
  LessonCoverageTracker get coverageTracker => _coverageTracker;
  IpInfo? get clientIpInfo => _clientIpInfo;

  String get positionKey =>
      'position.${currentUser.uid}.$courseId.${lesson.id}';
  String get coverageKey =>
      'coverage.${currentUser.uid}.$courseId.${lesson.id}';

  /// تهيئة المنسق واسترجاع التقدم المحفوظ محلياً أو سحابياً عبر الأجهزة
  Future<void> initialize() async {
    // جلب معلومات عنوان الـ IP
    try {
      _clientIpInfo = await IpService().getClientIpInfo();
    } catch (_) {}

    // تفريغ أي أحداث متراكمة في طابور عدم الاتصال
    _watchQueue.flush(currentUser.uid).catchError((Object _) {});

    // استعادة نطاقات التغطية
    final savedCoverage = await _preferences.getString(coverageKey);
    if (savedCoverage != null && savedCoverage.isNotEmpty) {
      _coverageTracker = LessonCoverageTracker.decodeRanges(savedCoverage);
    } else {
      try {
        final remoteCoverage = await firestoreService.getLatestLessonCoverage(
          uid: currentUser.uid,
          courseId: courseId,
          lessonId: lesson.id,
        );
        if (remoteCoverage != null && remoteCoverage.isNotEmpty) {
          _coverageTracker = LessonCoverageTracker.decodeRanges(remoteCoverage);
          await _preferences.setString(coverageKey, remoteCoverage);
        }
      } catch (_) {}
    }

    _startWatchTimer();
  }

  void _startWatchTimer() {
    _tickerTimer?.cancel();
    _tickerTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      // نبضات عداد الثواني تُقاد بواسطة مشغل الفيديو عبر [recordPlaybackSecond]
    });
  }

  /// تسجيل ثانية تشغيل فعلية أثناء التشغيل العادي (بدون كتم أمني أو تخزين مؤقت)
  void recordPlaybackSecond({
    required int currentPlayheadSeconds,
    required bool isPlaying,
    required bool isBuffering,
    required bool isScreenCaptured,
  }) {
    if (!isPlaying || isBuffering || isScreenCaptured) return;

    if (currentPlayheadSeconds > _maxPlayheadSeconds) {
      _maxPlayheadSeconds = currentPlayheadSeconds;
    }

    _coverageTracker.markPlayback(
      currentPosition: currentPlayheadSeconds,
      lastPosition: _lastPlaybackSecond,
    );
    _lastPlaybackSecond = currentPlayheadSeconds;
    _pendingWatchedSeconds++;
    _sessionCumulativeSeconds++;

    if (_pendingWatchedSeconds >= flushThresholdSeconds) {
      savePosition(currentPlayheadSeconds * 1000);
      flushWatchTime(isSessionEnd: false);
      sendPresenceHeartbeat(currentPlayheadSeconds, isPlaying: true);
    }
  }

  /// إعادة تعيين playhead الأخير عند تنفيذ القفز (Seek) لمنع احتساب القفزة كوقت مشاهدة متصل
  void onSeekPerformed() {
    _lastPlaybackSecond = -1;
    if (_pendingWatchedSeconds > 0) {
      flushWatchTime(isSessionEnd: false);
    }
  }

  /// حفظ الموضع الأخير وتحديث سجل التعلم الأخير في الذاكرة المحلية
  Future<void> savePosition(int positionMs) async {
    try {
      await _preferences.setInt(positionKey, positionMs);
      await _preferences.setString(coverageKey, _coverageTracker.encodeRanges());
      await _preferences.setString(
        'learning.recent.${currentUser.uid}',
        RecentLesson(
          courseId: courseId,
          lessonId: lesson.id,
          positionMs: positionMs,
        ).encode(),
      );
      learningHistoryRevision.value++;
    } catch (_) {}
  }

  /// إرسال نبضة التواجد المباشر للإدارة
  void sendPresenceHeartbeat(int currentPosSeconds, {required bool isPlaying}) {
    if (!isPlaying) {
      removePresenceHeartbeat();
      return;
    }

    final totalDur = lesson.durationInSeconds;
    final progressPct = totalDur > 0
        ? ((currentPosSeconds / totalDur) * 100).clamp(0.0, 100.0)
        : 0.0;

    final session = ActiveWatchSession(
      id: 'sess_${currentUser.uid}_${lesson.id}',
      studentId: currentUser.uid,
      studentName: currentUser.displayName,
      studentEmail: currentUser.email,
      studentPhone: currentUser.phone,
      courseId: courseId,
      courseTitle: courseTitle,
      lessonId: lesson.id,
      lessonTitle: lesson.title,
      currentPositionSeconds: currentPosSeconds,
      totalDurationSeconds: totalDur,
      progressPercentage: progressPct,
      isPlaying: true,
      ipAddress: _clientIpInfo?.ip ?? '',
      networkType: _clientIpInfo?.networkType ?? 'unknown',
      devicePlatform: _clientIpInfo?.devicePlatform ?? 'android',
      startedAt: sessionStartTime,
      lastHeartbeatAt: DateTime.now(),
    );

    firestoreService.updateActiveWatchSession(session).catchError((_) {});
  }

  /// حذف جلسة التواجد المباشر عند الإيقاف أو الخروج
  void removePresenceHeartbeat() {
    firestoreService
        .removeActiveWatchSession('sess_${currentUser.uid}_${lesson.id}')
        .catchError((_) {});
  }

  /// مزامنة وقت المشاهدة مع معالجة آمنة لجميع حالات الحافة (Reliability Bug Fixes 1, 2, 3, 4):
  /// - إذا كانت المزامنة جارية حالياً وطلب إغلاق الجلسة، تُجدول لتُنفذ فوراً بعد المزامنة النشطة ولا تُهمل أبداً.
  /// - حتى لو كانت الثواني المعلقة صفراً، إذا كانت [isSessionEnd] صحيحة، يُسجل إنهاء الجلسة والحالة النهائية.
  /// - يُمرر [sessionId] الثابت لضمان عدم ازدواجية الاحتساب عند إعادة المحاولة.
  Future<void> flushWatchTime({bool isSessionEnd = false}) async {
    if (_isSyncing) {
      if (isSessionEnd) {
        _pendingSessionEndScheduled = true;
      }
      return _activeSyncFuture;
    }

    // إذا لم تكن هناك ثوانٍ ولم يكن إنهاء جلسة، لا داعي لاستهلاك المزامنة
    if (_pendingWatchedSeconds <= 0 && !isSessionEnd) {
      return;
    }

    _isSyncing = true;
    final completer = Completer<void>();
    _activeSyncFuture = completer.future;

    final secondsToFlush = _pendingWatchedSeconds;
    final totalDur = lesson.durationInSeconds;
    final requiredThreshold = lesson.completionThresholdPercentage;
    final actualCoveragePct = _coverageTracker.coveragePercentage(totalDur);

    // شرط الإكمال الصارم 95% من النطاقات الفريدة
    final newlyCompleted = _coverageTracker.isComplete(totalDur, requiredThreshold);
    final completionFlag = newlyCompleted || _isCompleted;

    try {
      await _watchQueue.enqueue(
        uid: currentUser.uid,
        courseId: courseId,
        lessonId: lesson.id,
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

      if (newlyCompleted && !_isCompleted) {
        _isCompleted = true;
        onLessonAutoCompleted?.call();
      }
    } catch (_) {
      // يحتفظ _watchQueue بالحدث لإعادة المحاولة التلقائية
    } finally {
      _isSyncing = false;
      completer.complete();
      _activeSyncFuture = null;

      // تنفيذ إنهاء الجلسة المعلق إن وُجد
      if (_pendingSessionEndScheduled) {
        _pendingSessionEndScheduled = false;
        await flushWatchTime(isSessionEnd: true);
      }
    }
  }

  /// التحضير لمغادرة الشاشة أو الانتقال لدرس آخر مع انتظار اكتمال المزامنة
  Future<void> prepareToLeave(int currentPositionMs) async {
    removePresenceHeartbeat();
    await savePosition(currentPositionMs);
    await flushWatchTime(isSessionEnd: true);
  }

  /// التخلص من الموارد وحفظ أي ثوانٍ متبقية في الطابور المحلي المتين
  void dispose() {
    _tickerTimer?.cancel();
    removePresenceHeartbeat();

    // في حال وجود ثوانٍ متبقية لحظة التدمير، تُحفظ فوراً في الطابور
    if (_pendingWatchedSeconds > 0) {
      _watchQueue.enqueue(
        uid: currentUser.uid,
        courseId: courseId,
        lessonId: lesson.id,
        seconds: _pendingWatchedSeconds,
        sessionSeconds: _sessionCumulativeSeconds,
        studentName: currentUser.displayName,
        studentEmail: currentUser.email,
        lessonTitle: lesson.title,
        totalDurationSeconds: lesson.durationInSeconds,
        maxPlayheadSeconds: _maxPlayheadSeconds,
        completionPercentage: _coverageTracker.coveragePercentage(lesson.durationInSeconds),
        isCompleted: _isCompleted,
        isSessionEnd: true,
        ipAddress: _clientIpInfo?.ip ?? '',
        networkType: _clientIpInfo?.networkType ?? '',
        devicePlatform: _clientIpInfo?.devicePlatform ?? '',
        sessionId: sessionId,
        coverageRanges: _coverageTracker.encodeRanges(),
      ).catchError((_) {});
      _pendingWatchedSeconds = 0;
    }
  }
}
