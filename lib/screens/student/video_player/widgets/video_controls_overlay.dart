import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../../../core/theme/app_colors.dart';

/// طبقة أزرار التحكم المتجاوبة في مشغل المحاضرات (تدعم الوضع العادي وملء الشاشة).
class VideoControlsOverlay extends StatelessWidget {
  final VideoPlayerController controller;
  final String lessonTitle;
  final bool showTopBar;
  final bool isFullscreen;
  final bool isMuted;
  final VoidCallback onTogglePlay;
  final VoidCallback onSeekBackward;
  final VoidCallback onSeekForward;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleFullscreen;
  final VoidCallback onExitTopBar;
  final ValueChanged<double> onSelectSpeed;

  const VideoControlsOverlay({
    super.key,
    required this.controller,
    required this.lessonTitle,
    required this.showTopBar,
    required this.isFullscreen,
    required this.isMuted,
    required this.onTogglePlay,
    required this.onSeekBackward,
    required this.onSeekForward,
    required this.onToggleMute,
    required this.onToggleFullscreen,
    required this.onExitTopBar,
    required this.onSelectSpeed,
  });

  static String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    final hours = duration.inHours;
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final position = controller.value.position;
    final duration = controller.value.duration;
    final compact = MediaQuery.sizeOf(context).width < 390;

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (showTopBar)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withValues(alpha: 0.78),
                  Colors.transparent,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: onExitTopBar,
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                  ),
                  tooltip: 'رجوع',
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    lessonTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          const SizedBox.shrink(),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.86),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 6 : 12,
              vertical: 6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                VideoProgressIndicator(
                  controller,
                  allowScrubbing: true,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  colors: const VideoProgressColors(
                    playedColor: Color(0xFF3B82F6),
                    bufferedColor: Colors.white38,
                    backgroundColor: Colors.white12,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        controller.value.isPlaying
                            ? Icons.pause_circle_filled_rounded
                            : Icons.play_circle_fill_rounded,
                        size: compact ? 28 : 32,
                        color: Colors.white,
                      ),
                      onPressed: onTogglePlay,
                    ),
                    if (!compact)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'رجوع 10 ثوانٍ',
                        onPressed: onSeekBackward,
                        icon: const Icon(
                          Icons.replay_10_rounded,
                          color: Colors.white,
                          size: 21,
                        ),
                      ),
                    if (!compact)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'تقديم 10 ثوانٍ',
                        onPressed: onSeekForward,
                        icon: const Icon(
                          Icons.forward_10_rounded,
                          color: Colors.white,
                          size: 21,
                        ),
                      ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: isMuted ? 'تشغيل الصوت' : 'كتم الصوت',
                      onPressed: onToggleMute,
                      icon: Icon(
                        isMuted
                            ? Icons.volume_off_rounded
                            : Icons.volume_up_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${formatDuration(position)} / ${formatDuration(duration)}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontSize: compact ? 11 : 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    PopupMenuButton<double>(
                      initialValue: controller.value.playbackSpeed,
                      tooltip: 'سرعة التشغيل',
                      padding: EdgeInsets.zero,
                      icon: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${controller.value.playbackSpeed}x',
                          style: const TextStyle(
                            color: AppColors.textWhite,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      onSelected: onSelectSpeed,
                      itemBuilder: (_) => const [0.75, 1.0, 1.25, 1.5, 2.0]
                          .map(
                            (s) => PopupMenuItem<double>(
                              value: s,
                              child: Text('${s}x'),
                            ),
                          )
                          .toList(),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip:
                          isFullscreen ? 'إنهاء ملء الشاشة' : 'ملء الشاشة',
                      onPressed: onToggleFullscreen,
                      icon: Icon(
                        isFullscreen
                            ? Icons.fullscreen_exit_rounded
                            : Icons.fullscreen_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

