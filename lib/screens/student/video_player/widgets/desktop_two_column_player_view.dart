import 'package:flutter/material.dart';

import '../../../../core/responsive/responsive_layout.dart';
import '../../../../core/theme/app_colors.dart';

/// واجهة مشغل الفيديو المخصصة للشاشات العريضة وسطح المكتب (عمودان متوازيان).
class DesktopTwoColumnPlayerView extends StatelessWidget {
  final Widget stageWidget;
  final Widget detailsPanel;
  final Widget playlistPanel;
  final double stageMaxHeight;

  const DesktopTwoColumnPlayerView({
    super.key,
    required this.stageWidget,
    required this.detailsPanel,
    required this.playlistPanel,
    required this.stageMaxHeight,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveCenter(
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
                    constraints: BoxConstraints(maxHeight: stageMaxHeight),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: stageWidget,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.borderHairline),
                    ),
                    child: detailsPanel,
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
                border: Border.all(color: AppColors.borderHairline),
              ),
              child: SingleChildScrollView(
                child: playlistPanel,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
