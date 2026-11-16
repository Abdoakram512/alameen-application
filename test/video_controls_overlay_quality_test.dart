import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_screen_app/models/video_quality.dart';
import 'package:secure_screen_app/screens/student/video_player/widgets/video_controls_overlay.dart';
import 'package:video_player/video_player.dart';

void main() {
  group('VideoControlsOverlay Quality Controls Tests', () {
    late VideoPlayerController controller;

    setUp(() {
      controller = VideoPlayerController.networkUrl(
        Uri.parse('https://stream.mux.com/test.m3u8'),
      );
    });

    tearDown(() async {
      await controller.dispose();
    });

    testWidgets('renders quality button with selected quality label',
        (tester) async {
      VideoQuality currentQuality = VideoQuality.auto;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoControlsOverlay(
              controller: controller,
              lessonTitle: 'محاضرة تجريبية',
              showTopBar: true,
              isFullscreen: false,
              isMuted: false,
              selectedQuality: currentQuality,
              isChangingQuality: false,
              onTogglePlay: () {},
              onSeekBackward: () {},
              onSeekForward: () {},
              onToggleMute: () {},
              onToggleFullscreen: () {},
              onExitTopBar: () {},
              onSelectSpeed: (_) {},
              onSelectQuality: (q) {
                currentQuality = q;
              },
            ),
          ),
        ),
      );

      // Verify quality button displays 'Auto'
      expect(find.text('Auto'), findsOneWidget);
      expect(find.byIcon(Icons.tune_rounded), findsOneWidget);

      // Tap on the quality button to open popup
      await tester.tap(find.text('Auto'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Verify all quality options are listed in popup
      expect(find.text('تلقائي (Auto)'), findsOneWidget);
      expect(find.text('1080p (فائق الدقة)'), findsOneWidget);
      expect(find.text('720p (عالي الدقة)'), findsOneWidget);
      expect(find.text('480p (جودة متوسطة)'), findsOneWidget);
      expect(find.text('360p (توفير البيانات)'), findsOneWidget);

      // Select 720p
      await tester.tap(find.text('720p (عالي الدقة)'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(currentQuality, VideoQuality.hd);
    });

    testWidgets('displays loading indicator when isChangingQuality is true',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoControlsOverlay(
              controller: controller,
              lessonTitle: 'محاضرة تجريبية',
              showTopBar: true,
              isFullscreen: false,
              isMuted: false,
              selectedQuality: VideoQuality.fhd,
              isChangingQuality: true,
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

      // CircularProgressIndicator is displayed for changing quality
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('1080p'), findsNothing);
    });
  });
}
