import 'package:flutter/material.dart';

/// نقاط التوقف القياسية للتجاوب عبر الهواتف والتابلت وسطح المكتب.
class AppBreakpoints {
  AppBreakpoints._();

  static const double compactPhone = 380;
  static const double mobile = 600;
  static const double wideNavigation = 840;
  static const double desktop = 1040;
  static const double maxContentWidth = 1180;
  static const double maxFormWidth = 520;
}

extension ResponsiveContext on BuildContext {
  Size get viewportSize => MediaQuery.sizeOf(this);
  double get screenWidth => viewportSize.width;
  double get screenHeight => viewportSize.height;
  bool get isLandscape => screenWidth > screenHeight;
  bool get isCompactPhone => screenWidth < AppBreakpoints.compactPhone;
  bool get isMobile => screenWidth < AppBreakpoints.mobile;
  bool get isTablet =>
      screenWidth >= AppBreakpoints.mobile &&
      screenWidth < AppBreakpoints.desktop;
  bool get isDesktop => screenWidth >= AppBreakpoints.desktop;
  bool get useNavigationRail => screenWidth >= AppBreakpoints.wideNavigation;

  double get horizontalPagePadding {
    if (screenWidth >= AppBreakpoints.desktop) return 32;
    if (screenWidth >= AppBreakpoints.mobile) return 24;
    return 16;
  }

  int adaptiveColumns({
    double minItemWidth = 340,
    int maxColumns = 3,
  }) {
    final available = (screenWidth - (horizontalPagePadding * 2))
        .clamp(280.0, AppBreakpoints.maxContentWidth);
    final cols = (available / minItemWidth).floor();
    return cols.clamp(1, maxColumns);
  }
}

/// حاوية مركزية تحدد أقصى عرض للمحتوى وتضيف الهوامش المتجاوبة تلقائياً.
class ResponsiveCenter extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;
  final AlignmentGeometry alignment;

  const ResponsiveCenter({
    super.key,
    required this.child,
    this.maxWidth = AppBreakpoints.maxContentWidth,
    this.padding,
    this.alignment = Alignment.topCenter,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedPadding = padding ??
        EdgeInsets.symmetric(horizontal: context.horizontalPagePadding);
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: resolvedPadding,
          child: child,
        ),
      ),
    );
  }
}

/// شبكة بطاقات متجاوبة تحافظ على الارتفاع الطبيعي للنصوص العربية دون قص أو تجاوز (Overflow).
class ResponsiveCardGrid extends StatelessWidget {
  final List<Widget> children;
  final double minItemWidth;
  final int maxColumns;
  final double crossAxisSpacing;
  final double mainAxisSpacing;

  const ResponsiveCardGrid({
    super.key,
    required this.children,
    this.minItemWidth = 340,
    this.maxColumns = 3,
    this.crossAxisSpacing = 16,
    this.mainAxisSpacing = 14,
  });

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : context.screenWidth;
        final columns = (width / minItemWidth).floor().clamp(1, maxColumns);

        if (columns <= 1) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1) SizedBox(height: mainAxisSpacing),
              ],
            ],
          );
        }

        final rows = <Widget>[];
        for (int i = 0; i < children.length; i += columns) {
          final rowChildren = <Widget>[];
          for (int col = 0; col < columns; col++) {
            final index = i + col;
            if (col > 0) {
              rowChildren.add(SizedBox(width: crossAxisSpacing));
            }
            if (index < children.length) {
              rowChildren.add(Expanded(child: children[index]));
            } else {
              rowChildren.add(const Expanded(child: SizedBox.shrink()));
            }
          }
          if (rows.isNotEmpty) {
            rows.add(SizedBox(height: mainAxisSpacing));
          }
          rows.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: rowChildren,
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows,
        );
      },
    );
  }
}

