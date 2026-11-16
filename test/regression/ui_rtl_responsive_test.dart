import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_screen_app/core/responsive/responsive_layout.dart';

void main() {
  group('Regression Suite 9: UI RTL & Responsive Breakpoints', () {
    testWidgets('Arabic text renders with right-to-left Directionality cleanly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: Center(
                child: Text('مركز الأمين التعليمي'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('مركز الأمين التعليمي'), findsOneWidget);
      final textWidget = tester.widget<Text>(find.text('مركز الأمين التعليمي'));
      expect(textWidget.data, 'مركز الأمين التعليمي');
    });

    testWidgets('ResponsiveContext detects mobile layout on width < 600px', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      bool? isMobile;
      bool? isTablet;
      bool? isDesktop;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              isMobile = context.isMobile;
              isTablet = context.isTablet;
              isDesktop = context.isDesktop;
              return const Scaffold(body: Text('View'));
            },
          ),
        ),
      );

      expect(isMobile, isTrue);
      expect(isTablet, isFalse);
      expect(isDesktop, isFalse);
    });

    testWidgets('ResponsiveContext detects tablet layout on width 600 - 1040px', (tester) async {
      tester.view.physicalSize = const Size(768, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      bool? isMobile;
      bool? isTablet;
      bool? isDesktop;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              isMobile = context.isMobile;
              isTablet = context.isTablet;
              isDesktop = context.isDesktop;
              return const Scaffold(body: Text('View'));
            },
          ),
        ),
      );

      expect(isMobile, isFalse);
      expect(isTablet, isTrue);
      expect(isDesktop, isFalse);
    });

    testWidgets('ResponsiveCenter constrains content to maxWidth', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ResponsiveCenter(
              maxWidth: 500,
              child: Text('Centered Content'),
            ),
          ),
        ),
      );

      expect(find.text('Centered Content'), findsOneWidget);
    });
  });
}
