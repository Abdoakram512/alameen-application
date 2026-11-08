import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../../../core/widgets/app_cached_image.dart';
import 'video_controls_overlay.dart';
import 'video_seek_feedback_badge.dart';
import 'video_watermark_overlay.dart';

/// مسرح عرض الفيديو مع الحفاظ الصارم على النسبة الأصلية لأبعاد الفيديو دون تمدد أو تشويه.
class VideoStagePlayer extends StatelessWidget {
  final VideoPlayerController? controller;
  final bool isInitialized;
  final bool hasError;
  final String errorMessage;
  final String thumbnailUrl;
  final String lessonTitle;
  final bool showControls;
  final bool showTopBar;
  final bool isFullscreen;
  final bool isMuted;
  final int seekFeedbackSeconds;
  final bool isSeekingRight;
  final Alignment watermarkAlignment;
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

  const VideoStagePlayer({
    super.key,
    required this.controller,
    required this.isInitialized,
    required this.hasError,
    required this.errorMessage,
    required this.thumbnailUrl,
    required this.lessonTitle,
    required this.showControls,
    required this.showTopBar,
    required this.isFullscreen,
    required this.isMuted,
    required this.seekFeedbackSeconds,
    required this.isSeekingRight,
    required this.watermarkAlignment,
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
  });

  double get _safeIntrinsicAspectRatio {
    final activeController = controller;
    if (!isInitialized || activeController == null) return 16 / 9;
    final raw = activeController.value.aspectRatio;
    if (raw <= 0 || !raw.isFinite) return 16 / 9;
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final activeController = controller;
    final ready = isInitialized && activeController != null;

    return ColoredBox(
      color: Colors.black,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (ready)
              Center(
                child: AspectRatio(
                  aspectRatio: _safeIntrinsicAspectRatio,
                  child: VideoPlayer(activeController),
                ),
              )
            else if (hasError)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: Colors.white70,
                        size: 36,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        errorMessage,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white38),
                        ),
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                ),
              )
            else
              Stack(
                fit: StackFit.expand,
                children: [
                  if (thumbnailUrl.isNotEmpty)
                    AppCachedImage(
                      imageUrl: thumbnailUrl,
                      fit: BoxFit.cover,
                    ),
                  Container(color: Colors.black.withValues(alpha: 0.56)),
                  const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.6,
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'جارٍ تحضير المحاضرة...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            if (ready)
              Positioned.fill(
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTap: onToggleControls,
                          onDoubleTap: () => onDoubleTapSeek(false),
                          child: const SizedBox.expand(),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTap: onToggleControls,
                          onDoubleTap: () => onDoubleTapSeek(true),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            VideoSeekFeedbackBadge(
              isForward: isSeekingRight,
              seconds: seekFeedbackSeconds,
            ),
            if (ready && activeController.value.isBuffering)
              const IgnorePointer(
                child: Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
            VideoWatermarkOverlay(
              alignment: watermarkAlignment,
              studentName: studentName,
              studentEmail: studentEmail,
              studentUid: studentUid,
              studentIp: studentIp,
            ),
            if (ready)
              Positioned.fill(
                child: AnimatedOpacity(
                  opacity: showControls ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 220),
                  child: IgnorePointer(
                    ignoring: !showControls,
                    child: VideoControlsOverlay(
                      controller: activeController,
                      lessonTitle: lessonTitle,
                      showTopBar: showTopBar,
                      isFullscreen: isFullscreen,
                      isMuted: isMuted,
                      onTogglePlay: onTogglePlay,
                      onSeekBackward: onSeekBackward,
                      onSeekForward: onSeekForward,
                      onToggleMute: onToggleMute,
                      onToggleFullscreen: onToggleFullscreen,
                      onExitTopBar: onExitTopBar,
                      onSelectSpeed: onSelectSpeed,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

