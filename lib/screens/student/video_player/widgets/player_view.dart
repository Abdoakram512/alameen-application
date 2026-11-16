import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../../../models/video_quality.dart';
import 'video_stage_player.dart';

export 'video_stage_player.dart';

/// واجهة مشهد مشغل الفيديو المحدثة والموحدة في مسار المكونات النمطية.
class PlayerView extends StatelessWidget {
  final VideoPlayerController? controller;
  final ChewieController? chewieController;
  final bool isInitialized;
  final bool hasError;
  final String errorMessage;
  final String thumbnailUrl;
  final String lessonTitle;
  final bool showControls;
  final bool showTopBar;
  final bool isFullscreen;
  final bool isMuted;
  final VideoQuality selectedQuality;
  final bool isChangingQuality;
  final int seekFeedbackSeconds;
  final bool isSeekingRight;
  final Alignment watermarkAlignment;
  final ValueNotifier<Alignment>? watermarkNotifier;
  final String studentName;
  final String studentEmail;
  final String studentUid;
  final String studentIp;
  final VoidCallback onRetry;
  final VoidCallback onToggleControls;
  final ValueChanged<bool> onDoubleTapSeek;
  final VoidCallback onTogglePlay;
  final VoidCallback onSeekBackward;
  final VoidCallback onSeekForward;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleFullscreen;
  final VoidCallback onExitTopBar;
  final ValueChanged<double> onSelectSpeed;
  final ValueChanged<VideoQuality>? onSelectQuality;

  const PlayerView({
    super.key,
    required this.controller,
    this.chewieController,
    required this.isInitialized,
    required this.hasError,
    required this.errorMessage,
    required this.thumbnailUrl,
    required this.lessonTitle,
    required this.showControls,
    required this.showTopBar,
    required this.isFullscreen,
    required this.isMuted,
    this.selectedQuality = VideoQuality.auto,
    this.isChangingQuality = false,
    required this.seekFeedbackSeconds,
    required this.isSeekingRight,
    required this.watermarkAlignment,
    this.watermarkNotifier,
    required this.studentName,
    required this.studentEmail,
    required this.studentUid,
    this.studentIp = '',
    required this.onRetry,
    required this.onToggleControls,
    required this.onDoubleTapSeek,
    required this.onTogglePlay,
    required this.onSeekBackward,
    required this.onSeekForward,
    required this.onToggleMute,
    required this.onToggleFullscreen,
    required this.onExitTopBar,
    required this.onSelectSpeed,
    this.onSelectQuality,
  });

  @override
  Widget build(BuildContext context) {
    return VideoStagePlayer(
      controller: controller,
      chewieController: chewieController,
      isInitialized: isInitialized,
      hasError: hasError,
      errorMessage: errorMessage,
      thumbnailUrl: thumbnailUrl,
      lessonTitle: lessonTitle,
      showControls: showControls,
      showTopBar: showTopBar,
      isFullscreen: isFullscreen,
      isMuted: isMuted,
      selectedQuality: selectedQuality,
      isChangingQuality: isChangingQuality,
      seekFeedbackSeconds: seekFeedbackSeconds,
      isSeekingRight: isSeekingRight,
      watermarkAlignment: watermarkAlignment,
      watermarkNotifier: watermarkNotifier,
      studentName: studentName,
      studentEmail: studentEmail,
      studentUid: studentUid,
      studentIp: studentIp,
      onRetry: onRetry,
      onToggleControls: onToggleControls,
      onDoubleTapSeek: onDoubleTapSeek,
      onTogglePlay: onTogglePlay,
      onSeekBackward: onSeekBackward,
      onSeekForward: onSeekForward,
      onToggleMute: onToggleMute,
      onToggleFullscreen: onToggleFullscreen,
      onExitTopBar: onExitTopBar,
      onSelectSpeed: onSelectSpeed,
      onSelectQuality: onSelectQuality,
    );
  }
}
