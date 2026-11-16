import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_screen_app/models/video_quality.dart';
import 'package:secure_screen_app/screens/student/video_player/widgets/video_stage_player.dart';
import 'package:video_player/video_player.dart';

void main() {
  group('VideoStagePlayer Quality Badge & Controls Tests', () {
    late VideoPlayerController controller;

    setUp(() {
      controller = VideoPlayerController.networkUrl(
        Uri.parse('https://stream.mux.com/test_stage.m3u8'),
      );
    });

    tearDown(() async {
      await controller.dispose();
    });

    testWidgets(
        'renders switching quality indicator when isChangingQuality is true',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoStagePlayer(
              controller: controller,
              isInitialized: true,
              hasError: false,
              errorMessage: '',
              thumbnailUrl: '',
              lessonTitle: 'مراجعة شاملة',
              showControls: true,
              showTopBar: true,
              isFullscreen: false,
              isMuted: false,
              selectedQuality: VideoQuality.fhd,
              isChangingQuality: true,
              seekFeedbackSeconds: 0,
              isSeekingRight: true,
              watermarkAlignment: Alignment.center,
              studentName: 'أحمد محمود',
              studentEmail: 'ahmed@example.com',
              studentUid: 'u123',
              onRetry: () {},
              onToggleControls: () {},
              onDoubleTapSeek: (_) {},
              onTogglePlay: () {},
              onSeekBackward: () {},
              onSeekForward: () {},
              onToggleMute: () {},
              onToggleFullscreen: () {},
              onExitTopBar: () {},
              onSelectSpeed: (_) {},
              onSelectQuality: (_) {},
            ),
          ),
        ),
      );

      // Verify the center banner for quality adjustment appears
      expect(find.text('جارٍ ضبط دقة الفيديو...'), findsOneWidget);
    });
  });
}

