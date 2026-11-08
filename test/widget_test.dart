import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_screen_app/screens/onboarding/onboarding_screen.dart';
void main() {
  testWidgets('Four slides complete the introduction', (tester) async {
    var completed = 0;
    await tester.pumpWidget(MaterialApp(home: OnboardingScreen(onComplete: () async { completed++; })));
    expect(find.text('التعلّم يبدأ بخطوة'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('التالي'));
      await tester.pumpAndSettle();
    }
    expect(find.text('ابدأ رحلتك مع الأمين'), findsOneWidget);
    await tester.tap(find.text('ابدأ الآن'));
    await tester.pumpAndSettle();
    expect(completed, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Failure keeps skip retryable', (tester) async {
    await tester.pumpWidget(MaterialApp(home: OnboardingScreen(onComplete: () async { throw Exception('disk'); })));
    await tester.tap(find.text('تخطي'));
    await tester.pumpAndSettle();
    expect(find.text('تعذر حفظ اختيارك. حاول مرة أخرى.'), findsOneWidget);
    expect(tester.widget<TextButton>(find.widgetWithText(TextButton, 'تخطي')).onPressed, isNotNull);
  });
  testWidgets('Small screen with large Arabic text does not overflow', (tester) async {
    tester.view.physicalSize = const Size(320,568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.6)), child: child!), home: OnboardingScreen(onComplete: () async {})));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
