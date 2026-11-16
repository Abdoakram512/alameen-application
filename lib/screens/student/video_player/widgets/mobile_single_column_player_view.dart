import 'package:flutter/material.dart';

import '../../../../core/responsive/responsive_layout.dart';

/// واجهة مشغل الفيديو المخصصة للهواتف والشاشات الصغيرة (عمود رأسي متتالي).
class MobileSingleColumnPlayerView extends StatelessWidget {
  final Widget stageWidget;
  final Widget detailsPanel;
  final double stageMaxHeight;

  const MobileSingleColumnPlayerView({
    super.key,
    required this.stageWidget,
    required this.detailsPanel,
    required this.stageMaxHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: Colors.black,
          alignment: Alignment.center,
          constraints: BoxConstraints(
            maxHeight: stageMaxHeight,
          ),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: stageWidget,
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
                    child: detailsPanel,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
