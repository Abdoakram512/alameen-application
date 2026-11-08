import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_screen_app/core/theme/app_theme.dart';
import 'package:secure_screen_app/screens/onboarding/onboarding_screen.dart';
void main() {
 testWidgets('Onboarding visual review', (tester) async {
  tester.view.physicalSize = const Size(390,844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.runAsync(() async {
    for (final entry in {
      'Cairo': 'assets/fonts/Cairo.ttf',
      'Baloo Bhaijaan 2': 'assets/fonts/BalooBhaijaan2.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
      'packages/phosphor_flutter/PhosphorRegular':
          'packages/phosphor_flutter/lib/fonts/Phosphor.ttf',
      'packages/phosphor_flutter/PhosphorFill':
          'packages/phosphor_flutter/lib/fonts/Phosphor-Fill.ttf',
      'packages/phosphor_flutter/PhosphorBold':
          'packages/phosphor_flutter/lib/fonts/Phosphor-Bold.ttf',
    }.entries) {
      final loader = FontLoader(entry.key)..addFont(rootBundle.load(entry.value));
      await loader.load();
    }
  });
  await tester.pumpWidget(MaterialApp(debugShowCheckedModeBanner: false, theme: AppTheme.lightTheme,home:OnboardingScreen(onComplete: () async {})));
  await tester.runAsync(() async {
    final context = tester.element(find.byType(OnboardingScreen));
    await precacheImage(const AssetImage('assets/images/website-logo.png'), context);
    for (final slide in onboardingSlides) { await precacheImage(AssetImage(slide.image), context); }
  });
  await tester.pumpAndSettle();
  await expectLater(find.byType(MaterialApp),matchesGoldenFile('goldens/onboarding.png'));
 });
}
