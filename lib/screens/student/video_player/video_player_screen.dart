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
import '../../../../core/responsive/responsive_layout.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../logic/auth/auth_cubit.dart';
import '../../../../logic/auth/auth_state.dart';
import '../../../../models/course_access_mode.dart';
import '../../../../models/lesson.dart';
import '../../../../models/user_profile.dart';
import '../../../../models/video_quality.dart';
import '../../../../repositories/student_learning_repository.dart';
import '../../../../services/firestore_service.dart';
import '../../security/security_protection_watcher.dart';
import '../widgets/submit_assignment_sheet.dart';
import 'controllers/watch_progress_coordinator.dart';
import 'widgets/lesson_details_panel.dart';
import 'widgets/lesson_playlist_panel.dart';
import 'widgets/player_view.dart';

/// الشاشة الرئيسية لمشغل الفيديو التعليمي في منصة مركز الأمين.
/// تم تطويرها ومعماريتها بنمط معياري يفصل بين مشهد العرض، وحساب التقدم الموثوق، والتحكم بالأجهزة المتعددة.
class VideoPlayerScreen extends StatefulWidget {
  final Lesson lesson;
  final String courseId;
  final String courseTitle;
  final CourseAccessMode courseAccessMode;
  final UserModel? currentUser;
  final List<Lesson> playlist;

  const VideoPlayerScreen({
    super.key,
    required this.lesson,
    required this.courseId,
    this.courseTitle = '',
    this.courseAccessMode = CourseAccessMode.closed,
    this.currentUser,
    this.playlist = const [],
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
  String _baseStreamUrl = '';

  StreamSubscription<AuthState>? _accessSubscription;
  Set<String> _submittedAssignmentIds = <String>{};
  ValueNotifier<bool>? _screenCaptureNotifier;

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

  Map<String, String> get _lockedReasons {
    final panel = LessonPlaylistPanel(
      playlist: widget.playlist,
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
        widget.currentUser?.isLessonCompleted(widget.lesson.id) ?? false;

    if (widget.currentUser != null) {
      _progressCoordinator = WatchProgressCoordinator(
        currentUser: widget.currentUser!,
        courseId: widget.courseId,
        courseTitle: widget.courseTitle,
        lesson: widget.lesson,
        onLessonAutoCompleted: _onAutoCompletedEarned,
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

  void _onAutoCompletedEarned() {
    if (mounted) {
      setState(() => _isCompleted = true);
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.success,
          content: Text('player.lesson_auto_completed_earned'.tr()),
        ),
      );
    }
  }

  void _listenToAuthAccess() {
    _accessSubscription = context.read<AuthCubit>().stream.listen((state) {
      final isOpenCourse = widget.courseAccessMode == CourseAccessMode.open;
      final revoked = state is Unauthenticated ||
          state is AuthError ||
          (state is Authenticated &&
              (state.user.uid != widget.currentUser?.uid ||
                  (!widget.lesson.isFreePreview &&
                      !isOpenCourse &&
                      !state.user.isEnrolled(widget.courseId))));
      if (revoked && mounted && !_closingForAccess) {
        _closingForAccess = true;
        if (_isInitialized) _controller?.pause();
        Navigator.of(context).pop();
      }
    });
  }

  Future<void> _loadStudentSubmissions() async {
    final uid = widget.currentUser?.uid;
    if (uid == null) return;
    try {
      final subs = await FirestoreService().getStudentSubmissions(uid);
      if (mounted) {
        setState(() {
          _submittedAssignmentIds =
              subs.map((s) => s.assignmentId).toSet();
        });
      }
    } catch (_) {}
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final notifier = ScreenProtectionScope.notifierOf(context);
    if (_screenCaptureNotifier != notifier) {
      _screenCaptureNotifier?.removeListener(_handleScreenCaptureChanged);
      _screenCaptureNotifier = notifier;
      _screenCaptureNotifier?.addListener(_handleScreenCaptureChanged);
      if (notifier?.value == true) {
        _handleScreenCaptureChanged();
      }
    }
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
        await SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.immersiveSticky,
        );
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

    String streamUrl = widget.lesson.videoStreamUrl;
    try {
      final resolved = await _learningRepository.resolveLessonPlayback(
        courseId: widget.courseId,
        lesson: widget.lesson,
      );
      if (!mounted) return;
      streamUrl = resolved.streamUrl;
      _resolvedThumbnailUrl = resolved.thumbnailUrl;
    } on PlaybackAuthorizationException catch (authEx) {
      // حماية صارمة: منع التراجع لروابط غير محمية عند فشل التحقق من الصلاحية
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorMessage = authEx.message;
      });
      return;
    } catch (_) {
      // خطأ شبكة عابر
      if (!mounted) return;
      if (widget.lesson.muxPlaybackId.trim().isEmpty &&
          !widget.lesson.isFreePreview) {
        setState(() {
          _hasError = true;
          _errorMessage =
              'تعذر التحقق من صلاحية الوصول إلى هذه المحاضرة. تأكد من تفعيل اشتراكك ثم أعد المحاولة.';
        });
        return;
      }
      _resolvedThumbnailUrl = widget.lesson.thumbnailUrl;
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

      final saved =
          await _preferences.getInt(_progressCoordinator?.positionKey ?? '') ?? 0;

      if (!mounted) return;
      if (saved > 0 && saved < ctrl.value.duration.inMilliseconds - 2000) {
        await ctrl.seekTo(Duration(milliseconds: saved));
      }
      if (_screenCaptureNotifier?.value == true) {
        await ctrl.setVolume(0.0);
      }
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
    final isPlaying = ctrl.value.isPlaying;
    if (isPlaying != _wasPlaying) {
      _wasPlaying = isPlaying;
      if (isPlaying) {
        _progressCoordinator?.sendPresenceHeartbeat(
          ctrl.value.position.inSeconds,
          isPlaying: true,
        );
      } else {
        // موثوقية عالية: عند الإيقاف المؤقت، يُحفظ الموضع وتُسجل حالة نهاية الجلسة حتى لو كانت الثواني المعلقة صفراً
        _progressCoordinator?.savePosition(ctrl.value.position.inMilliseconds);
        _progressCoordinator?.flushWatchTime(isSessionEnd: true);
        _progressCoordinator?.removePresenceHeartbeat();
      }
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

    final currentPosition = oldCtrl.value.position;
    final wasPlaying = oldCtrl.value.isPlaying;
    final currentSpeed = oldCtrl.value.playbackSpeed;

    // كتم مؤقت للقديم لمنع تداخل الصوت
    oldCtrl.setVolume(0.0);

    try {
      final newUri = quality.buildStreamUri(_baseStreamUrl);
      final newCtrl = VideoPlayerController.networkUrl(
        newUri,
        httpHeaders: const {'User-Agent': 'AlameenPlayer/1.0 (Flutter)'},
      );

      await newCtrl.initialize();
      if (!mounted) {
        await newCtrl.dispose();
        return;
      }

      if (currentPosition > Duration.zero &&
          currentPosition < newCtrl.value.duration) {
        await newCtrl.seekTo(currentPosition);
      }
      await newCtrl.setPlaybackSpeed(currentSpeed);
      final isVolumeZero =
          _isMuted || (_screenCaptureNotifier?.value == true);
      await newCtrl.setVolume(isVolumeZero ? 0.0 : 1.0);

      if (wasPlaying && _screenCaptureNotifier?.value != true) {
        await newCtrl.play();
      }

      newCtrl.addListener(_onControllerStateChanged);
      oldCtrl.removeListener(_onControllerStateChanged);

      if (mounted) {
        setState(() {
          _controller = newCtrl;
          _selectedQuality = quality;
          _isChangingQuality = false;
        });
        _scheduleHideControls();
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            content: Text('تم ضبط جودة الفيديو: ${quality.label}'),
          ),
        );
      }
      await oldCtrl.dispose();
    } catch (_) {
      if (mounted) {
        setState(() {
          _isChangingQuality = false;
        });
        _scheduleHideControls();
        oldCtrl.setVolume(_isMuted ? 0.0 : 1.0);
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.error,
            content:
                Text('تعذر تغيير جودة الفيديو، تم الإبقاء على الجودة الحالية.'),
          ),
        );
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _isInitialized) {
      _controller?.pause();
      final ctrl = _controller;
      if (ctrl != null) {
        _progressCoordinator?.prepareToLeave(ctrl.value.position.inMilliseconds);
      }
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
    _progressCoordinator?.onSeekPerformed();
    final value = (ctrl.value.position.inSeconds + seconds).clamp(
      0,
      ctrl.value.duration.inSeconds,
    );
    await ctrl.seekTo(Duration(seconds: value));
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
      final assignment = await FirestoreService().getAssignment(assignmentId);
      if (assignment == null || !mounted) return;
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        builder: (_) => SubmitAssignmentSheet(
          assignment: assignment,
          user: user,
        ),
      );
      if (mounted) {
        _loadStudentSubmissions();
      }
    } catch (_) {}
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
    final isOpenCourse = widget.courseAccessMode == CourseAccessMode.open;
    if (state is! Authenticated ||
        (!lesson.isFreePreview &&
            !isOpenCourse &&
            !state.user.isEnrolled(widget.courseId))) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('player.no_permission'.tr())),
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
            courseTitle: widget.courseTitle,
            courseAccessMode: widget.courseAccessMode,
            currentUser: state.user,
            playlist: widget.playlist,
          ),
        ),
      );
    } catch (_) {
      _changingLesson = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('player.open_error'.tr())),
        );
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
    final threshold = widget.lesson.completionThresholdPercentage;
    final tracker = _progressCoordinator?.coverageTracker;
    final actualCoveragePct =
        tracker?.coveragePercentage(totalDur) ?? 0.0;

    // اشتراط بلوغ نسبة 95% على الأقل يدوياً
    if (target &&
        tracker != null &&
        !tracker.isComplete(totalDur, threshold)) {
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
        uid: widget.currentUser!.uid,
        lessonId: widget.lesson.id,
        isCompleted: target,
      );
      if (!mounted) return;
      setState(() => _isCompleted = target);
      if (target) HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor:
              target ? AppColors.primary : const Color(0xFF334155),
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
    _screenCaptureNotifier?.removeListener(_handleScreenCaptureChanged);
    _accessSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _hideControlsTimer?.cancel();
    _seekFeedbackTimer?.cancel();
    _watchTickTimer?.cancel();
    _watermarkTimer?.cancel();
    _watermarkAlignmentNotifier.dispose();
    _restoreSystemUiAndOrientation();

    // حفظ الموضع والثواني المعلقة بأمان
    final pos = _controller?.value.position.inMilliseconds ?? 0;
    _progressCoordinator?.savePosition(pos);
    _progressCoordinator?.flushWatchTime(isSessionEnd: true);
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
        : (widget.lesson.muxPlaybackId.trim().isNotEmpty
            ? widget.lesson.thumbnailUrl
            : '');

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
        backgroundColor:
            useImmersiveStage ? Colors.black : AppColors.scaffoldBackground,
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
                  ? ResponsiveCenter(
                      maxWidth: 1280,
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 7,
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxHeight: size.height * 0.62,
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(18),
                                      child: AspectRatio(
                                        aspectRatio: 16 / 9,
                                        child: _buildStage(showTopBar: false),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: AppColors.borderHairline,
                                      ),
                                    ),
                                    child: LessonDetailsPanel(
                                      lesson: widget.lesson,
                                      courseId: widget.courseId,
                                      isCompleted: _isCompleted,
                                      savingCompletion: _savingCompletion,
                                      canComplete: widget.currentUser != null,
                                      playlist: widget.playlist,
                                      showInlinePlaylist: false,
                                      lockedReasons: _lockedReasons,
                                      isAssignmentSubmitted: _submittedAssignmentIds
                                          .contains(widget.lesson.assignmentId),
                                      onOpenAssignmentSheet:
                                          widget.lesson.hasAssignment
                                              ? _showAssignmentModal
                                              : null,
                                      onToggleCompletion: _toggleCompletion,
                                      onSelectLesson: _openLesson,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          SizedBox(
                            width: 350,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: AppColors.borderHairline,
                                ),
                              ),
                              child: SingleChildScrollView(
                                child: LessonPlaylistPanel(
                                  playlist: widget.playlist,
                                  currentLessonId: widget.lesson.id,
                                  courseId: widget.courseId,
                                  courseAccessMode: widget.courseAccessMode,
                                  submittedAssignmentIds: _submittedAssignmentIds,
                                  onSelectLesson: _openLesson,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        Container(
                          width: double.infinity,
                          color: Colors.black,
                          alignment: Alignment.center,
                          constraints: BoxConstraints(
                            maxHeight:
                                (size.height * 0.40).clamp(190.0, 380.0),
                          ),
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: _buildStage(showTopBar: false),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            color: Colors.white,
                            child: ListView(
                              padding: EdgeInsets.fromLTRB(
                                context.horizontalPagePadding,
                                20,
                                context.horizontalPagePadding,
                                MediaQuery.paddingOf(context).bottom + 28,
                              ),
                              children: [
                                Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 780,
                                    ),
                                    child: LessonDetailsPanel(
                                      lesson: widget.lesson,
                                      courseId: widget.courseId,
                                      isCompleted: _isCompleted,
                                      savingCompletion: _savingCompletion,
                                      canComplete: widget.currentUser != null,
                                      playlist: widget.playlist,
                                      showInlinePlaylist: true,
                                      lockedReasons: _lockedReasons,
                                      isAssignmentSubmitted: _submittedAssignmentIds
                                          .contains(widget.lesson.assignmentId),
                                      onOpenAssignmentSheet:
                                          widget.lesson.hasAssignment
                                              ? _showAssignmentModal
                                              : null,
                                      onToggleCompletion: _toggleCompletion,
                                      onSelectLesson: _openLesson,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}
