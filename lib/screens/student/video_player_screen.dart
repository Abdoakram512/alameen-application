import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import '../../core/di/injection_container.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../core/theme/app_colors.dart';
import '../../logic/auth/auth_cubit.dart';
import '../../logic/auth/auth_state.dart';
import '../../models/active_watch_session.dart';
import '../../models/learning_history.dart';
import '../../models/lesson.dart';
import '../../models/user_profile.dart';
import '../../repositories/student_learning_repository.dart';
import '../../services/firestore_service.dart';
import '../../services/ip_service.dart';
import '../../services/watch_queue.dart';
import '../security/security_protection_watcher.dart';
import 'lesson_playlist.dart';
import 'video_player/widgets/lesson_details_panel.dart';
import 'video_player/widgets/video_stage_player.dart';

class VideoPlayerScreen extends StatefulWidget {
  final Lesson lesson;
  final String courseId;
  final String courseTitle;
  final UserModel? currentUser;
  final List<Lesson> playlist;

  const VideoPlayerScreen({
    super.key,
    required this.lesson,
    required this.courseId,
    this.courseTitle = '',
    this.currentUser,
    this.playlist = const [],
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  String _errorMessage = '';
  String _resolvedThumbnailUrl = '';
  late bool _isCompleted;
  bool _isMuted = false;

  StreamSubscription<AuthState>? _accessSubscription;
  ValueNotifier<bool>? _screenCaptureNotifier;

  bool _savingCompletion = false;
  bool _syncing = false;
  bool _fullscreen = false;
  bool _changingLesson = false;
  bool _closingForAccess = false;
  bool _showControls = true;

  Timer? _hideControlsTimer;
  int _seekFeedbackSeconds = 0;
  bool _isSeekingRight = true;
  Timer? _seekFeedbackTimer;
  Timer? _watchTrackerTimer;
  int _pendingWatchedSeconds = 0;
  Timer? _presenceHeartbeatTimer;
  IpInfo? _clientIpInfo;
  DateTime _sessionStartTime = DateTime.now();
  int _maxPlayheadSeconds = 0;

  Timer? _watermarkTimer;
  Alignment _watermarkAlignment = const Alignment(0.7, -0.7);
  static const List<Alignment> _watermarkPositions = [
    Alignment(0.7, -0.7),
    Alignment(-0.7, -0.7),
    Alignment(0.65, 0.55),
    Alignment(-0.65, 0.55),
    Alignment(0.0, -0.35),
    Alignment(0.0, 0.4),
  ];

  final _preferences = SharedPreferencesAsync();
  static final _queuePreferences = SharedPreferencesAsync();
  static final _watchQueue = WatchQueue(
    read: _queuePreferences.getString,
    write: _queuePreferences.setString,
    send: (event) => FirestoreService().recordWatchEvent(event),
  );

  StudentLearningRepository get _learningRepository =>
      sl.isRegistered<StudentLearningRepository>()
          ? sl<StudentLearningRepository>()
          : StudentLearningRepositoryImpl();

  String get _positionKey =>
      'position.${widget.currentUser?.uid}.${widget.courseId}.${widget.lesson.id}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sessionStartTime = DateTime.now();
    IpService().getClientIpInfo().then((info) {
      if (mounted) setState(() => _clientIpInfo = info);
    }).catchError((_) {});
    _startPresenceHeartbeat();

    _accessSubscription = context.read<AuthCubit>().stream.listen((state) {
      final revoked = state is Unauthenticated ||
          state is AuthError ||
          (state is Authenticated &&
              (state.user.uid != widget.currentUser?.uid ||
                  (!widget.lesson.isFreePreview &&
                      !state.user.isEnrolled(widget.courseId))));
      if (revoked && mounted && !_closingForAccess) {
        _closingForAccess = true;
        if (_isInitialized) _controller?.pause();
        Navigator.of(context).pop();
      }
    });

    _isCompleted =
        widget.currentUser?.isLessonCompleted(widget.lesson.id) ?? false;
    _activateScreenProtection();
    _initializeVideo();
    _startWatchTimeTracking();

    final uid = widget.currentUser?.uid;
    if (uid != null) {
      _watchQueue.flush(uid).catchError((Object _) {});
    }
    _startWatermarkAnimation();
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
      _savePosition();
      _flushWatchTime();
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
        setState(() {
          _watermarkAlignment =
              _watermarkPositions[rand.nextInt(_watermarkPositions.length)];
        });
      }
    });
  }

  void _startPresenceHeartbeat() {
    _presenceHeartbeatTimer?.cancel();
    _presenceHeartbeatTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _sendPresenceHeartbeat(),
    );
  }

  void _sendPresenceHeartbeat() {
    final user = widget.currentUser;
    final ctrl = _controller;
    if (user == null || ctrl == null || !ctrl.value.isInitialized) return;
    if (!ctrl.value.isPlaying) {
      _removePresenceHeartbeat();
      return;
    }

    final currentPos = ctrl.value.position.inSeconds;
    final totalDur = ctrl.value.duration.inSeconds;
    if (currentPos > _maxPlayheadSeconds) {
      _maxPlayheadSeconds = currentPos;
    }

    final progressPct = totalDur > 0
        ? ((currentPos / totalDur) * 100).clamp(0.0, 100.0)
        : 0.0;

    final session = ActiveWatchSession(
      id: 'sess_${user.uid}_${widget.lesson.id}',
      studentId: user.uid,
      studentName: user.displayName,
      studentEmail: user.email,
      studentPhone: user.phone,
      courseId: widget.courseId,
      courseTitle: widget.courseTitle,
      lessonId: widget.lesson.id,
      lessonTitle: widget.lesson.title,
      currentPositionSeconds: currentPos,
      totalDurationSeconds: totalDur,
      progressPercentage: progressPct,
      isPlaying: true,
      ipAddress: _clientIpInfo?.ip ?? '',
      networkType: _clientIpInfo?.networkType ?? 'unknown',
      devicePlatform: _clientIpInfo?.devicePlatform ?? 'android',
      startedAt: _sessionStartTime,
      lastHeartbeatAt: DateTime.now(),
    );

    FirestoreService().updateActiveWatchSession(session).catchError((_) {});
  }

  void _removePresenceHeartbeat() {
    final user = widget.currentUser;
    if (user == null) return;
    FirestoreService()
        .removeActiveWatchSession('sess_${user.uid}_${widget.lesson.id}')
        .catchError((_) {});
  }

  void _startWatchTimeTracking() {
    _watchTrackerTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final isCaptured = _screenCaptureNotifier?.value ?? false;
      final ctrl = _controller;
      if (!isCaptured &&
          _isInitialized &&
          ctrl != null &&
          ctrl.value.isPlaying &&
          !ctrl.value.isBuffering) {
        final posSec = ctrl.value.position.inSeconds;
        if (posSec > _maxPlayheadSeconds) {
          _maxPlayheadSeconds = posSec;
        }
        _pendingWatchedSeconds++;
        if (_pendingWatchedSeconds >= 30) {
          _savePosition();
          _flushWatchTime();
        }
      }
    });
  }

  Future<void> _savePosition() async {
    final ctrl = _controller;
    if (!_isInitialized || ctrl == null || widget.currentUser == null) return;
    try {
      final position = ctrl.value.position.inMilliseconds;
      await _preferences.setInt(_positionKey, position);
      await _preferences.setString(
        'learning.recent.${widget.currentUser!.uid}',
        RecentLesson(
          courseId: widget.courseId,
          lessonId: widget.lesson.id,
          positionMs: position,
        ).encode(),
      );
      learningHistoryRevision.value++;
    } catch (_) {}
  }

  Future<void> _flushWatchTime() async {
    if (_syncing || _pendingWatchedSeconds <= 0 || widget.currentUser == null) {
      return;
    }
    _syncing = true;
    final seconds = _pendingWatchedSeconds;
    final ctrl = _controller;
    final totalDur = (ctrl != null && ctrl.value.isInitialized)
        ? ctrl.value.duration.inSeconds
        : widget.lesson.durationInSeconds;
    final completionPct = totalDur > 0
        ? ((_maxPlayheadSeconds / totalDur) * 100).clamp(0.0, 100.0)
        : 0.0;
    final isCompleted = completionPct >= 80.0 || _isCompleted;

    try {
      await _watchQueue.enqueue(
        uid: widget.currentUser!.uid,
        courseId: widget.courseId,
        lessonId: widget.lesson.id,
        seconds: seconds,
        studentName: widget.currentUser!.displayName,
        studentEmail: widget.currentUser!.email,
        lessonTitle: widget.lesson.title,
        totalDurationSeconds: totalDur,
        maxPlayheadSeconds: _maxPlayheadSeconds,
        completionPercentage: completionPct,
        isCompleted: isCompleted,
        ipAddress: _clientIpInfo?.ip ?? '',
        networkType: _clientIpInfo?.networkType ?? '',
        devicePlatform: _clientIpInfo?.devicePlatform ?? '',
      );
      _pendingWatchedSeconds -= seconds;
      await _watchQueue.flush(widget.currentUser!.uid);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تعذرت مزامنة وقت المشاهدة حالياً، ستتم المزامنة تلقائياً عند توفر الاتصال.',
            ),
          ),
        );
      }
    } finally {
      _syncing = false;
    }
  }

  Future<void> _initializeVideo() async {
    String streamUrl = widget.lesson.videoStreamUrl;
    try {
      final resolved = await _learningRepository.resolveLessonPlayback(
        courseId: widget.courseId,
        lesson: widget.lesson,
      );
      if (!mounted) return;
      streamUrl = resolved.streamUrl;
      _resolvedThumbnailUrl = resolved.thumbnailUrl;
    } catch (_) {
      if (!mounted) return;
      if (widget.lesson.muxPlaybackId.trim().isEmpty) {
        setState(() {
          _hasError = true;
          _errorMessage =
              'تعذر التحقق من صلاحية الوصول إلى هذه المحاضرة. تأكد من تفعيل اشتراكك ثم أعد المحاولة.';
        });
        return;
      }
      _resolvedThumbnailUrl = widget.lesson.thumbnailUrl;
    }

    final ctrl = VideoPlayerController.networkUrl(
      Uri.parse(streamUrl),
      httpHeaders: const {'User-Agent': 'AlameenPlayer/1.0 (Flutter)'},
    );
    _controller = ctrl;

    try {
      await ctrl.initialize();
      if (!mounted) return;
      final saved = await _preferences.getInt(_positionKey) ?? 0;
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
    ctrl.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _isInitialized) {
      _controller?.pause();
      _savePosition();
      _flushWatchTime();
      _removePresenceHeartbeat();
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

  Future<void> _openLesson(Lesson lesson) async {
    if (_changingLesson) return;
    final state = context.read<AuthCubit>().state;
    if (state is! Authenticated ||
        (!lesson.isFreePreview && !state.user.isEnrolled(widget.courseId))) {
      return;
    }
    _changingLesson = true;
    try {
      if (_isInitialized) await _controller?.pause();
      await _savePosition();
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
            currentUser: state.user,
            playlist: widget.playlist,
          ),
        ),
      );
    } catch (_) {
      _changingLesson = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح المحاضرة، حاول مرة أخرى.')),
        );
      }
    }
  }

  Future<void> _toggleCompletion() async {
    if (_savingCompletion || widget.currentUser == null) return;
    setState(() => _savingCompletion = true);
    final target = !_isCompleted;
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
    _presenceHeartbeatTimer?.cancel();
    _removePresenceHeartbeat();
    _savePosition();
    _flushWatchTime();
    _watchTrackerTimer?.cancel();
    _watermarkTimer?.cancel();
    _restoreSystemUiAndOrientation();
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

    return VideoStagePlayer(
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
      seekFeedbackSeconds: _seekFeedbackSeconds,
      isSeekingRight: _isSeekingRight,
      watermarkAlignment: _watermarkAlignment,
      studentName: studentName,
      studentEmail: studentEmail,
      studentUid: studentUid,
      studentIp: _clientIpInfo?.ip ?? '',
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
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _fullscreen) {
          _setFullscreenMode(false);
        }
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
                                child: BlocBuilder<AuthCubit, AuthState>(
                                  builder: (context, state) {
                                    final user = state is Authenticated
                                        ? state.user
                                        : null;
                                    return LessonPlaylist(
                                      lessons: widget.playlist,
                                      selectedId: widget.lesson.id,
                                      enrolled:
                                          user?.isEnrolled(widget.courseId) ??
                                              false,
                                      completedIds: {
                                        ...?user?.completedLessonIds,
                                      },
                                      onSelected: _openLesson,
                                    );
                                  },
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
                            maxHeight: (size.height * 0.40).clamp(190.0, 380.0),
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
                              padding: EdgeInsets.symmetric(
                                horizontal: context.horizontalPagePadding,
                                vertical: 20,
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
