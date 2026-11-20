import 'dart:async';
import 'dart:math';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/network/api_exceptions.dart';
import '../../../../core/responsive/responsive_layout.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/network_error_mapper.dart';
import '../../../../logic/auth/auth_cubit.dart';
import '../../../../logic/auth/auth_state.dart';
import '../../../../logic/courses/courses_cubit.dart';
import '../../../../models/course_access_mode.dart';
import '../../../../models/course_level.dart';
import '../../../../models/course_progress_policy.dart';
import '../../../../models/lesson.dart';
import '../../../../models/user_profile.dart';
import '../../../../models/video_quality.dart';
import '../../../../repositories/student_learning_repository.dart';
import '../../../../repositories/student_assignments_repository.dart';
import '../../security/security_protection_watcher.dart';
import '../widgets/submit_assignment_sheet.dart';
import 'controllers/watch_progress_coordinator.dart';
import 'widgets/desktop_two_column_player_view.dart';
import 'widgets/lesson_details_panel.dart';
import 'widgets/lesson_playlist_panel.dart';
import 'widgets/mobile_single_column_player_view.dart';
import 'widgets/player_view.dart';

/// الشاشة الرئيسية لمشغل الفيديو التعليمي المحمي في منصة مركز الأمين (P5 Laravel API).
class VideoPlayerScreen extends StatefulWidget {
  final Lesson lesson;
  final String courseId;
  final String? courseSlug;
  final String courseTitle;
  final CourseAccessMode courseAccessMode;
  final UserModel? currentUser;
  final List<Lesson> playlist;
  final List<CourseLevel> levels;

  const VideoPlayerScreen({
    super.key,
    required this.lesson,
    required this.courseId,
    this.courseSlug,
    this.courseTitle = '',
    this.courseAccessMode = CourseAccessMode.closed,
    this.currentUser,
    this.playlist = const [],
    this.levels = const [],
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  WatchProgressCoordinator? _progressCoordinator;

  bool _isInitialized = false;
  bool _hasError = false;
  String _errorMessage = '';
  String _resolvedThumbnailUrl = '';
  late bool _isCompleted;
  bool _isMuted = false;
  VideoQuality _selectedQuality = VideoQuality.auto;
  bool _isChangingQuality = false;
  bool _isRenewingToken = false;
  bool _hasAttemptedExpiredTokenRetry = false;
  String _baseStreamUrl = '';

  StreamSubscription<AuthState>? _accessSubscription;
  Set<String> _submittedAssignmentIds = <String>{};
  ValueNotifier<bool>? _screenCaptureNotifier;
  ValueNotifier<int?>? _activeVideoIdNotifier;

  bool _savingCompletion = false;
  bool _fullscreen = false;
  bool _changingLesson = false;
  bool _closingForAccess = false;
  bool _showControls = true;
  bool _wasPlaying = false;

  Timer? _hideControlsTimer;
  int _seekFeedbackSeconds = 0;
  bool _isSeekingRight = true;
  Timer? _seekFeedbackTimer;
  Timer? _watchTickTimer;
  Timer? _tokenRenewalTimer;

  Timer? _watermarkTimer;
  final ValueNotifier<Alignment> _watermarkAlignmentNotifier =
      ValueNotifier<Alignment>(const Alignment(0.7, -0.7));
  static const List<Alignment> _watermarkPositions = [
    Alignment(0.7, -0.7),
    Alignment(-0.7, -0.7),
    Alignment(0.65, 0.55),
    Alignment(-0.65, 0.55),
    Alignment(0.0, -0.35),
    Alignment(0.0, 0.4),
  ];

  final _preferences = SharedPreferencesAsync();

  StudentLearningRepository get _learningRepository =>
      sl.isRegistered<StudentLearningRepository>()
          ? sl<StudentLearningRepository>()
          : StudentLearningRepositoryImpl();

  String get _effectiveCourseSlug =>
      (widget.courseSlug != null && widget.courseSlug!.trim().isNotEmpty)
      ? widget.courseSlug!.trim()
      : widget.courseId;

  String get _effectiveLessonSlug =>
      (widget.lesson.slug != null && widget.lesson.slug!.trim().isNotEmpty)
      ? widget.lesson.slug!.trim()
      : widget.lesson.id;

  Map<String, String> get _lockedReasons {
    final panel = LessonPlaylistPanel(
      playlist: widget.playlist,
      levels: widget.levels,
      currentLessonId: widget.lesson.id,
      courseId: widget.courseId,
      courseAccessMode: widget.courseAccessMode,
      submittedAssignmentIds: _submittedAssignmentIds,
      onSelectLesson: (_) {},
    );
    return panel.lockedReasons;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _isCompleted =
        widget.lesson.isCompleted ||
        (widget.currentUser?.isLessonCompleted(widget.lesson.id) ?? false);

    if (widget.currentUser != null) {
      _progressCoordinator = WatchProgressCoordinator(
        currentUser: widget.currentUser!,
        courseId: widget.courseId,
        courseSlug: _effectiveCourseSlug,
        courseTitle: widget.courseTitle,
        lesson: widget.lesson,
        onLessonAutoCompleted: _onAutoCompletedEarned,
        onAuthorizationLost: _handleAuthorizationLost,
      );
      _progressCoordinator!.initialize();
      _loadStudentSubmissions();
    }

    _activateScreenProtection();
    _listenToAuthAccess();
    _initializeVideo();
    _startWatermarkAnimation();
    _startPlaybackTicker();
  }

  void _handleAuthorizationLost(int statusCode, String message) {
    if (!mounted) return;
    _tokenRenewalTimer?.cancel();
    _controller?.pause();
    try {
      final authCubit = context.read<AuthCubit>();
      context.read<CoursesCubit>().syncStudentState(authCubit: authCubit);
    } catch (_) {}

    setState(() {
      _hasError = true;
      _isInitialized = false;
      _errorMessage = statusCode == 401
          ? 'انتهت صلاحية الجلسة (401). يرجى إعادة تسجيل الدخول لمتابعة المشاهدة.'
          : (message.isNotEmpty
                ? message
                : 'تم رفض الوصول للمحاضرة (403): تم سحب صلاحية الاشتراك أو انتهت مدته.');
    });
  }

  void _onAutoCompletedEarned() {
    if (!mounted) return;
    setState(() => _isCompleted = true);
    try {
      context.read<AuthCubit>().markLessonCompleted(widget.lesson.id);
    } catch (_) {}
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.success,
        content: Text('player.lesson_auto_completed_earned'.tr()),
      ),
    );
  }

  void _listenToAuthAccess() {
    _accessSubscription = context.read<AuthCubit>().stream.listen((state) {
      // لا يُمنح الوصول لمجرد كون الدورة open؛ المصدر المعتمد هو اشتراك الطالب أو معاينة معتمدة من الخادم
      final revoked =
          state is Unauthenticated ||
          state is AuthSuspended ||
          state is AuthPendingApproval ||
          state is AuthError ||
          (state is Authenticated &&
              (state.user.uid != widget.currentUser?.uid ||
                  (!widget.lesson.isFreePreview &&
                      !state.user.isEnrolled(widget.courseId))));
      if (revoked && mounted && !_closingForAccess) {
        _closingForAccess = true;
        _tokenRenewalTimer?.cancel();
        if (_isInitialized) _controller?.pause();
        Navigator.of(context).pop();
      }
    });
  }

  Future<void> _loadStudentSubmissions() async {
    final uid = widget.currentUser?.uid;
    if (uid == null) return;
    try {
      final assignmentsRepo = sl.isRegistered<StudentAssignmentsRepository>()
          ? sl<StudentAssignmentsRepository>()
          : null;
      if (assignmentsRepo == null) return;
      final subs = await assignmentsRepo
          .getAssignments()
          .then((data) => data.submissions);
      if (mounted) {
        setState(() {
          _submittedAssignmentIds = subs.map((s) => s.assignmentId).toSet();
        });
      }
    } catch (_) {}
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = context
        .getInheritedWidgetOfExactType<ScreenProtectionScope>();
    final notifier = scope?.notifier;
    if (_screenCaptureNotifier != notifier) {
      _screenCaptureNotifier?.removeListener(_handleScreenCaptureChanged);
      _screenCaptureNotifier = notifier;
      _screenCaptureNotifier?.addListener(_handleScreenCaptureChanged);
      if (notifier?.value == true) {
        _handleScreenCaptureChanged();
      }
    }

    _activeVideoIdNotifier = scope?.activeVideoIdNotifier;
    _activeVideoIdNotifier?.value = int.tryParse(widget.lesson.id);
  }

  void _handleScreenCaptureChanged() {
    final captured = _screenCaptureNotifier?.value ?? false;
    final ctrl = _controller;
    if (!_isInitialized || ctrl == null) return;
    if (captured) {
      ctrl.pause();
      ctrl.setVolume(0.0);
      _progressCoordinator?.prepareToLeave(ctrl.value.position.inMilliseconds);
      if (mounted) setState(() {});
    } else {
      ctrl.setVolume(_isMuted ? 0.0 : 1.0);
      if (mounted) setState(() {});
    }
  }

  Future<void> _activateScreenProtection() async {
    try {
      await ScreenProtector.preventScreenshotOn();
      await ScreenProtector.protectDataLeakageWithColor(Colors.black);
    } catch (_) {}
  }

  Future<void> _setFullscreenMode(bool enable) async {
    if (_fullscreen == enable) return;
    setState(() {
      _fullscreen = enable;
      _showControls = true;
    });
    try {
      if (enable) {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        if (mounted && context.screenWidth < 900) {
          await SystemChrome.setPreferredOrientations(const [
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ]);
        }
      } else {
        await _restoreSystemUiAndOrientation();
      }
    } catch (_) {}
  }

  Future<void> _restoreSystemUiAndOrientation() async {
    try {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    } catch (_) {}
  }

  void _startWatermarkAnimation() {
    final rand = Random();
    _watermarkTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (mounted) {
        _watermarkAlignmentNotifier.value =
            _watermarkPositions[rand.nextInt(_watermarkPositions.length)];
      }
    });
  }

  void _startPlaybackTicker() {
    _watchTickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final ctrl = _controller;
      if (ctrl != null && _isInitialized && ctrl.value.isPlaying) {
        final isCaptured = _screenCaptureNotifier?.value ?? false;
        _progressCoordinator?.recordPlaybackSecond(
          currentPlayheadSeconds: ctrl.value.position.inSeconds,
          isPlaying: ctrl.value.isPlaying,
          isBuffering: ctrl.value.isBuffering,
          isScreenCaptured: isCaptured,
        );
      }
    });
  }

  int? _extractSecondsUntilExpiry(String url, int? explicitExpiresIn) {
    if (explicitExpiresIn != null && explicitExpiresIn > 0) {
      return explicitExpiresIn;
    }
    final uri = Uri.tryParse(url.trim());
    final rawExp =
        uri?.queryParameters['expires'] ?? uri?.queryParameters['exp'];
    final epoch = rawExp != null ? int.tryParse(rawExp) : null;
    if (epoch != null && epoch > 0) {
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(
        epoch * 1000,
        isUtc: true,
      );
      final diff = expiresAt.difference(DateTime.now().toUtc()).inSeconds;
      return diff > 0 ? diff : 1;
    }
    return null;
  }

  void _scheduleTokenRenewal(String url, int? explicitExpiresIn) {
    _tokenRenewalTimer?.cancel();
    final ttl = _extractSecondsUntilExpiry(url, explicitExpiresIn);
    if (ttl == null) return;

    // جدولة التجديد الاستباقي قبل انتهاء صلاحية الرابط الموقع بـ 60 ثانية
    final delaySec = max(30, ttl - 60);
    _tokenRenewalTimer = Timer(Duration(seconds: delaySec), () {
      if (mounted && !_hasError) {
        unawaited(_renewPlaybackToken(fromPlaybackError: false));
      }
    });
  }

  Future<void> _renewPlaybackToken({bool fromPlaybackError = false}) async {
    if (_isRenewingToken || !mounted) return;
    _isRenewingToken = true;
    try {
      final resp = await _learningRepository.refreshPlaybackToken(
        courseSlugOrId: _effectiveCourseSlug,
        lessonSlugOrId: _effectiveLessonSlug,
      );
      if (!mounted) return;

      final nextUrl = resp.hlsUrl?.trim() ?? '';
      if (nextUrl.isEmpty) {
        if (fromPlaybackError) {
          setState(() {
            _hasError = true;
            _isInitialized = false;
            _errorMessage =
                'انتهت صلاحية رابط البث الآمن وتعذر الحصول على رابط HLS جديد من الخادم.';
          });
        }
        return;
      }

      _scheduleTokenRenewal(nextUrl, resp.expiresIn);

      if (nextUrl != _baseStreamUrl || fromPlaybackError) {
        await _swapControllerStream(
          newBaseUrl: nextUrl,
          targetQuality: _selectedQuality,
        );
      }
    } on UnauthorizedException catch (e) {
      _handleAuthorizationLost(401, e.message);
    } on ForbiddenException catch (e) {
      _handleAuthorizationLost(403, e.message);
    } on PlaybackAuthorizationException catch (e) {
      _handleAuthorizationLost(e.statusCode ?? 403, e.message);
    } catch (_) {
      if (fromPlaybackError && mounted) {
        setState(() {
          _hasError = true;
          _isInitialized = false;
          _errorMessage =
              'تعذر تجديد تصريح البث بعد انتهاء صلاحيته. يرجى التحقق من الإنترنت وإعادة المحاولة.';
        });
      }
    } finally {
      _isRenewingToken = false;
    }
  }

  Future<void> _initializeVideo() async {
    if (!widget.lesson.isAvailableNow) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = widget.lesson.isScheduled
              ? 'هذه المحاضرة مجدولة وستتاح تلقائياً للطلاب في موعدها المحدد.'
              : 'هذه المحاضرة غير متاحة حالياً (قيد الإعداد والمراجعة).';
        });
      }
      return;
    }

    _hasAttemptedExpiredTokenRetry = false;
    String streamUrl = '';
    int serverLastPosSec = 0;
    int? expiresInSec;

    try {
      final resolved = await _learningRepository.resolveLessonPlayback(
        courseId: _effectiveCourseSlug,
        lesson: widget.lesson,
      );
      if (!mounted) return;
      streamUrl = resolved.streamUrl;
      _resolvedThumbnailUrl = resolved.thumbnailUrl;
      serverLastPosSec = resolved.lastPositionSeconds;
      expiresInSec = resolved.expiresInSeconds;

      _progressCoordinator?.seedServerProgress(
        watchedSeconds: resolved.watchedSeconds,
        lastPositionSeconds: resolved.lastPositionSeconds,
        isCompleted: resolved.isCompleted,
      );
      if (resolved.isCompleted && !_isCompleted) {
        _isCompleted = true;
      }
    } on PlaybackAuthorizationException catch (authEx) {
      _handleAuthorizationLost(authEx.statusCode ?? 403, authEx.message);
      return;
    } on PlaybackProviderIncompatibleException catch (compatEx) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorMessage = compatEx.message;
      });
      return;
    } on ApiException catch (apiEx) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorMessage = NetworkErrorMapper.toArabicMessage(
          apiEx,
          defaultMessage: 'تعذر تحميل بيانات البث المحمي للمحاضرة.',
        );
      });
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorMessage =
            'تعذر التحقق من صلاحية الوصول إلى هذه المحاضرة. تأكد من اتصالك وتفعيل اشتراكك ثم أعد المحاولة.';
      });
      return;
    }

    if (streamUrl.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'لم يصدر الخادم رابط بث صالحاً لهذه المحاضرة.';
        });
      }
      return;
    }

    _baseStreamUrl = streamUrl;
    final targetUri = _selectedQuality.buildStreamUri(streamUrl);

    final ctrl = VideoPlayerController.networkUrl(
      targetUri,
      httpHeaders: const {'User-Agent': 'AlameenPlayer/1.0 (Flutter)'},
    );
    _controller = ctrl;

    try {
      await ctrl.initialize();
      if (!mounted) return;

      final localSavedMs = await _preferences.getInt(
        _progressCoordinator?.positionKey ?? '',
      );
      final serverSavedMs = serverLastPosSec * 1000;
      final resumeMs = (localSavedMs != null && localSavedMs > 0)
          ? localSavedMs
          : serverSavedMs;

      if (!mounted) return;
      final durMs = ctrl.value.duration.inMilliseconds;
      if (resumeMs > 0 && durMs > 2000 && resumeMs < durMs - 2000) {
        await ctrl.seekTo(Duration(milliseconds: resumeMs));
      }
      if (_screenCaptureNotifier?.value == true) {
        await ctrl.setVolume(0.0);
      }

      _scheduleTokenRenewal(_baseStreamUrl, expiresInSec);

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage =
              'تعذر تشغيل المحاضرة. يرجى التحقق من اتصال الإنترنت والمحاولة مرة أخرى.';
        });
      }
    }

    if (!mounted) return;
    ctrl.addListener(_onControllerStateChanged);
  }

  void _onControllerStateChanged() {
    final ctrl = _controller;
    if (ctrl == null) return;

    if (ctrl.value.hasError && !_hasAttemptedExpiredTokenRetry && !_hasError) {
      _hasAttemptedExpiredTokenRetry = true;
      unawaited(_renewPlaybackToken(fromPlaybackError: true));
      return;
    }

    final isPlaying = ctrl.value.isPlaying;
    if (isPlaying != _wasPlaying) {
      _wasPlaying = isPlaying;
      if (isPlaying) {
        _hasAttemptedExpiredTokenRetry = false;
      } else {
        _progressCoordinator?.savePosition(ctrl.value.position.inMilliseconds);
        _progressCoordinator?.flushWatchTime(
          isSessionEnd: true,
          currentPositionSeconds: ctrl.value.position.inSeconds,
        );
      }
    }
  }

  /// مساعد مشترك لتبديل مصدر البث (تغيير الجودة أو تجديد الرمز الموقع) بدون فقدان موضع التشغيل.
  Future<bool> _swapControllerStream({
    required String newBaseUrl,
    required VideoQuality targetQuality,
  }) async {
    final oldCtrl = _controller;
    if (oldCtrl == null) return false;

    final currentPosition = oldCtrl.value.isInitialized
        ? oldCtrl.value.position
        : Duration.zero;
    final wasPlaying = oldCtrl.value.isInitialized && oldCtrl.value.isPlaying;
    final currentSpeed = oldCtrl.value.isInitialized
        ? oldCtrl.value.playbackSpeed
        : 1.0;

    oldCtrl.setVolume(0.0);

    try {
      final newUri = targetQuality.buildStreamUri(newBaseUrl);
      final newCtrl = VideoPlayerController.networkUrl(
        newUri,
        httpHeaders: const {'User-Agent': 'AlameenPlayer/1.0 (Flutter)'},
      );

      await newCtrl.initialize();
      if (!mounted) {
        await newCtrl.dispose();
        return false;
      }

      if (currentPosition > Duration.zero &&
          currentPosition < newCtrl.value.duration) {
        await newCtrl.seekTo(currentPosition);
      }
      await newCtrl.setPlaybackSpeed(currentSpeed);
      final isVolumeZero = _isMuted || (_screenCaptureNotifier?.value == true);
      await newCtrl.setVolume(isVolumeZero ? 0.0 : 1.0);

      if (wasPlaying && _screenCaptureNotifier?.value != true) {
        await newCtrl.play();
      }

      newCtrl.addListener(_onControllerStateChanged);
      oldCtrl.removeListener(_onControllerStateChanged);

      if (mounted) {
        setState(() {
          _baseStreamUrl = newBaseUrl;
          _controller = newCtrl;
          _selectedQuality = targetQuality;
          _isInitialized = true;
          _hasError = false;
        });
      }
      await oldCtrl.dispose();
      return true;
    } catch (_) {
      oldCtrl.setVolume(_isMuted ? 0.0 : 1.0);
      return false;
    }
  }

  Future<void> _changeQuality(VideoQuality quality) async {
    if (quality == _selectedQuality || _isChangingQuality) return;
    final oldCtrl = _controller;
    if (!_isInitialized || oldCtrl == null || _baseStreamUrl.isEmpty) return;

    HapticFeedback.selectionClick();
    _hideControlsTimer?.cancel();

    setState(() {
      _isChangingQuality = true;
    });

    final swapped = await _swapControllerStream(
      newBaseUrl: _baseStreamUrl,
      targetQuality: quality,
    );

    if (!mounted) return;
    setState(() {
      _isChangingQuality = false;
    });
    _scheduleHideControls();

    if (swapped) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          content: Text('تم ضبط جودة الفيديو: ${quality.label}'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
          content: Text(
            'تعذر تغيير جودة الفيديو، تم الإبقاء على الجودة الحالية.',
          ),
        ),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _isInitialized) {
      _controller?.pause();
      final ctrl = _controller;
      if (ctrl != null) {
        _progressCoordinator?.prepareToLeave(
          ctrl.value.position.inMilliseconds,
        );
      }
    } else if (state == AppLifecycleState.resumed &&
        _baseStreamUrl.isNotEmpty &&
        ResolvedLessonPlayback.isSignedUrlExpiredOrExpiring(_baseStreamUrl)) {
      unawaited(_renewPlaybackToken(fromPlaybackError: false));
    }
  }

  void _onDoubleTapSeek(bool forward) {
    HapticFeedback.lightImpact();
    final delta = forward ? 10 : -10;
    _seek(delta);
    _seekFeedbackTimer?.cancel();
    setState(() {
      _seekFeedbackSeconds = delta;
      _isSeekingRight = forward;
    });
    _seekFeedbackTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) {
        setState(() => _seekFeedbackSeconds = 0);
      }
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls && (_controller?.value.isPlaying ?? false)) {
      _scheduleHideControls();
    }
  }

  void _scheduleHideControls() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && (_controller?.value.isPlaying ?? false)) {
        setState(() => _showControls = false);
      }
    });
  }

  Future<void> _seek(int seconds) async {
    final ctrl = _controller;
    if (!_isInitialized || ctrl == null) return;
    final target = (ctrl.value.position.inSeconds + seconds).clamp(
      0,
      ctrl.value.duration.inSeconds,
    );
    _progressCoordinator?.onSeekPerformed(targetPositionSeconds: target);
    await ctrl.seekTo(Duration(seconds: target));
  }

  void _togglePlay() {
    final ctrl = _controller;
    if (!_isInitialized || ctrl == null) return;
    if (_screenCaptureNotifier?.value == true) return;
    HapticFeedback.selectionClick();
    setState(() {
      if (ctrl.value.isPlaying) {
        ctrl.pause();
        _hideControlsTimer?.cancel();
      } else {
        if (_baseStreamUrl.isNotEmpty &&
            ResolvedLessonPlayback.isSignedUrlExpiredOrExpiring(
              _baseStreamUrl,
            )) {
          unawaited(_renewPlaybackToken(fromPlaybackError: false));
        }
        ctrl.play();
        _scheduleHideControls();
      }
    });
  }

  void _toggleMute() {
    final ctrl = _controller;
    if (!_isInitialized || ctrl == null) return;
    HapticFeedback.selectionClick();
    final nextMuted = !_isMuted;
    ctrl.setVolume(nextMuted ? 0.0 : 1.0);
    setState(() => _isMuted = nextMuted);
  }

  Future<void> _showAssignmentModal() async {
    final user = widget.currentUser;
    final assignmentId = widget.lesson.assignmentId;
    if (user == null || assignmentId == null || assignmentId.isEmpty) return;
    try {
      final assignmentsRepo = sl.isRegistered<StudentAssignmentsRepository>()
          ? sl<StudentAssignmentsRepository>()
          : null;
      if (assignmentsRepo == null) return;
      final assignment = await assignmentsRepo.getAssignment(
        assignmentId,
      );
      if (assignment == null || !mounted) return;
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        builder: (_) =>
            SubmitAssignmentSheet(assignment: assignment, user: user),
      );
      if (mounted) {
        _loadStudentSubmissions();
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is ApiException
                ? error.message
                : '\u062a\u0639\u0630\u0631 \u062a\u062d\u0645\u064a\u0644 \u0627\u0644\u062a\u0643\u0644\u064a\u0641. \u062d\u0627\u0648\u0644 \u0645\u062c\u062f\u062f\u0627.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _openLesson(Lesson lesson) async {
    if (_changingLesson) return;
    if (_lockedReasons.containsKey(lesson.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'course_details.must_submit_assignment_for_lesson'.tr(
              args: [_lockedReasons[lesson.id] ?? ''],
            ),
          ),
          backgroundColor: const Color(0xFFB45309),
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    final state = context.read<AuthCubit>().state;
    final isEnrolled =
        state is Authenticated && state.user.isEnrolled(widget.courseId);
    final completedSet = <String>{
      if (state is Authenticated) ...state.user.completedLessonIds,
      for (final l in widget.playlist)
        if (l.isCompleted) l.id,
      if (_isCompleted) widget.lesson.id,
    };

    final policyReason = CourseProgressPolicy.lessonLockReason(
      levels: widget.levels,
      lesson: lesson,
      isEnrolled: isEnrolled,
      completedLessonIds: completedSet,
      assignmentLockReasons: _lockedReasons,
    );

    if (state is! Authenticated || policyReason != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(policyReason ?? 'player.no_permission'.tr())),
      );
      return;
    }

    _changingLesson = true;
    try {
      if (_isInitialized) await _controller?.pause();
      final pos = _controller?.value.position.inMilliseconds ?? 0;
      await _progressCoordinator?.prepareToLeave(pos);
      if (_fullscreen) {
        await _setFullscreenMode(false);
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => VideoPlayerScreen(
            lesson: lesson,
            courseId: widget.courseId,
            courseSlug: widget.courseSlug,
            courseTitle: widget.courseTitle,
            courseAccessMode: widget.courseAccessMode,
            currentUser: state.user,
            playlist: widget.playlist,
            levels: widget.levels,
          ),
        ),
      );
    } catch (_) {
      _changingLesson = false;
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('player.open_error'.tr())));
      }
    }
  }

  Future<void> _toggleCompletion() async {
    if (_savingCompletion || widget.currentUser == null) return;
    final target = !_isCompleted;

    final ctrl = _controller;
    final totalDur = (ctrl != null && ctrl.value.isInitialized)
        ? ctrl.value.duration.inSeconds
        : widget.lesson.durationInSeconds;
    final threshold = max(
      CourseProgressPolicy.strictLevelThresholdPercent.toInt(),
      widget.lesson.effectiveCompletionThresholdPercentage,
    );
    final tracker = _progressCoordinator?.coverageTracker;
    final actualCoveragePct = tracker?.coveragePercentage(totalDur) ?? 0.0;

    if (target && tracker != null && !tracker.isComplete(totalDur, threshold)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
          content: Text(
            'يجب إكمال مشاهدة $threshold% على الأقل من المحاضرة فعلياً لاحتسابها مكتملة والتأهل للشهادة (أنجزت ${actualCoveragePct.toStringAsFixed(0)}%).',
          ),
        ),
      );
      return;
    }

    setState(() => _savingCompletion = true);
    try {
      await _learningRepository.toggleLessonCompletion(
        courseSlugOrId: _effectiveCourseSlug,
        lesson: widget.lesson,
        isCompleted: target,
      );
      if (!mounted) return;
      setState(() => _isCompleted = target);
      if (target) {
        context.read<AuthCubit>().markLessonCompleted(widget.lesson.id);
        HapticFeedback.mediumImpact();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: target ? AppColors.primary : const Color(0xFF334155),
          content: Text(
            target
                ? 'تم تسجيل إكمال المحاضرة وحفظ تقدمك التدريبي.'
                : 'تم إلغاء علامة إكمال المحاضرة.',
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر حفظ حالة الإكمال، حاول مرة أخرى.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingCompletion = false);
    }
  }

  @override
  void dispose() {
    if (_activeVideoIdNotifier?.value == int.tryParse(widget.lesson.id)) {
      _activeVideoIdNotifier?.value = null;
    }
    _screenCaptureNotifier?.removeListener(_handleScreenCaptureChanged);
    _accessSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _hideControlsTimer?.cancel();
    _seekFeedbackTimer?.cancel();
    _watchTickTimer?.cancel();
    _tokenRenewalTimer?.cancel();
    _watermarkTimer?.cancel();
    _watermarkAlignmentNotifier.dispose();
    _restoreSystemUiAndOrientation();

    final pos = _controller?.value.position.inMilliseconds ?? 0;
    _progressCoordinator?.savePosition(pos);
    _progressCoordinator?.flushWatchTime(
      isSessionEnd: true,
      currentPositionSeconds: pos ~/ 1000,
    );
    _progressCoordinator?.dispose();

    _controller?.removeListener(_onControllerStateChanged);
    _controller?.dispose();
    super.dispose();
  }

  Widget _buildStage({required bool showTopBar}) {
    final studentName = widget.currentUser?.displayName ?? 'متدرب مركز الأمين';
    final studentEmail = widget.currentUser?.email ?? '';
    final studentUid = widget.currentUser?.uid ?? '';
    final effectiveThumb = _resolvedThumbnailUrl.isNotEmpty
        ? _resolvedThumbnailUrl
        : widget.lesson.thumbnailUrl;

    return PlayerView(
      controller: _controller,
      isInitialized: _isInitialized,
      hasError: _hasError,
      errorMessage: _errorMessage,
      thumbnailUrl: effectiveThumb,
      lessonTitle: widget.lesson.title,
      showControls: _showControls,
      showTopBar: showTopBar,
      isFullscreen: _fullscreen,
      isMuted: _isMuted,
      selectedQuality: _selectedQuality,
      isChangingQuality: _isChangingQuality,
      seekFeedbackSeconds: _seekFeedbackSeconds,
      isSeekingRight: _isSeekingRight,
      watermarkAlignment: _watermarkAlignmentNotifier.value,
      watermarkNotifier: _watermarkAlignmentNotifier,
      studentName: studentName,
      studentEmail: studentEmail,
      studentUid: studentUid,
      studentIp: _progressCoordinator?.clientIpInfo?.ip ?? '',
      onRetry: () async {
        setState(() {
          _hasError = false;
          _isInitialized = false;
        });
        final old = _controller;
        _controller = null;
        await old?.dispose();
        if (!mounted) return;
        _initializeVideo();
      },
      onToggleControls: _toggleControls,
      onDoubleTapSeek: _onDoubleTapSeek,
      onTogglePlay: _togglePlay,
      onSeekBackward: () {
        HapticFeedback.selectionClick();
        _seek(-10);
        _scheduleHideControls();
      },
      onSeekForward: () {
        HapticFeedback.selectionClick();
        _seek(10);
        _scheduleHideControls();
      },
      onToggleMute: _toggleMute,
      onToggleFullscreen: () {
        HapticFeedback.selectionClick();
        _setFullscreenMode(!_fullscreen);
      },
      onExitTopBar: () {
        if (_fullscreen) {
          _setFullscreenMode(false);
        } else {
          Navigator.of(context).maybePop();
        }
      },
      onSelectSpeed: (speed) {
        HapticFeedback.selectionClick();
        _controller?.setPlaybackSpeed(speed);
        _scheduleHideControls();
      },
      onSelectQuality: _changeQuality,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isCompactPhoneLandscape =
        size.width > size.height && size.height < 480;
    final useImmersiveStage = _fullscreen || isCompactPhoneLandscape;
    final useDesktopTwoColumn =
        !useImmersiveStage && size.width >= 900 && widget.playlist.isNotEmpty;

    return PopScope(
      canPop: !_fullscreen,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop && _fullscreen) {
          _setFullscreenMode(false);
          return;
        }
        final pos = _controller?.value.position.inMilliseconds ?? 0;
        await _progressCoordinator?.prepareToLeave(pos);
      },
      child: Scaffold(
        backgroundColor: useImmersiveStage
            ? Colors.black
            : AppColors.scaffoldBackground,
        appBar: useImmersiveStage
            ? null
            : AppBar(
                backgroundColor: AppColors.primaryDark,
                foregroundColor: Colors.white,
                iconTheme: const IconThemeData(color: Colors.white),
                title: Text(
                  widget.lesson.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
        body: SafeArea(
          bottom: !useImmersiveStage,
          child: useImmersiveStage
              ? SizedBox.expand(child: _buildStage(showTopBar: true))
              : useDesktopTwoColumn
              ? DesktopTwoColumnPlayerView(
                  stageWidget: _buildStage(showTopBar: false),
                  stageMaxHeight: size.height * 0.62,
                  detailsPanel: LessonDetailsPanel(
                    lesson: widget.lesson,
                    courseId: widget.courseId,
                    isCompleted: _isCompleted,
                    savingCompletion: _savingCompletion,
                    canComplete: widget.currentUser != null,
                    playlist: widget.playlist,
                    levels: widget.levels,
                    showInlinePlaylist: false,
                    lockedReasons: _lockedReasons,
                    isAssignmentSubmitted: _submittedAssignmentIds.contains(
                      widget.lesson.assignmentId,
                    ),
                    onOpenAssignmentSheet: widget.lesson.hasAssignment
                        ? _showAssignmentModal
                        : null,
                    onToggleCompletion: _toggleCompletion,
                    onSelectLesson: _openLesson,
                  ),
                  playlistPanel: LessonPlaylistPanel(
                    playlist: widget.playlist,
                    levels: widget.levels,
                    currentLessonId: widget.lesson.id,
                    courseId: widget.courseId,
                    courseAccessMode: widget.courseAccessMode,
                    submittedAssignmentIds: _submittedAssignmentIds,
                    onSelectLesson: _openLesson,
                  ),
                )
              : MobileSingleColumnPlayerView(
                  stageWidget: _buildStage(showTopBar: false),
                  stageMaxHeight: (size.height * 0.40).clamp(190.0, 380.0),
                  detailsPanel: LessonDetailsPanel(
                    lesson: widget.lesson,
                    courseId: widget.courseId,
                    isCompleted: _isCompleted,
                    savingCompletion: _savingCompletion,
                    canComplete: widget.currentUser != null,
                    playlist: widget.playlist,
                    levels: widget.levels,
                    showInlinePlaylist: true,
                    lockedReasons: _lockedReasons,
                    isAssignmentSubmitted: _submittedAssignmentIds.contains(
                      widget.lesson.assignmentId,
                    ),
                    onOpenAssignmentSheet: widget.lesson.hasAssignment
                        ? _showAssignmentModal
                        : null,
                    onToggleCompletion: _toggleCompletion,
                    onSelectLesson: _openLesson,
                  ),
                ),
        ),
      ),
    );
  }
}
