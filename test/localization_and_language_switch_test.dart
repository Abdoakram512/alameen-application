import 'dart:convert';
import 'dart:io';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_admin_app/core/config/app_config.dart';
import 'package:secure_admin_app/widgets/language_switch_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  group('1. Localization Dictionary Integrity & Key Symmetry Tests', () {
    test('ar.json and en.json exist, are valid JSON, and have 100% symmetric keys', () {
      final arFile = File('assets/translations/ar.json');
      final enFile = File('assets/translations/en.json');

      expect(arFile.existsSync(), isTrue, reason: 'assets/translations/ar.json must exist');
      expect(enFile.existsSync(), isTrue, reason: 'assets/translations/en.json must exist');

      final Map<String, dynamic> arJson = jsonDecode(arFile.readAsStringSync());
      final Map<String, dynamic> enJson = jsonDecode(enFile.readAsStringSync());

      Set<String> extractKeys(Map<String, dynamic> map, [String prefix = '']) {
        final keys = <String>{};
        map.forEach((key, value) {
          final fullKey = prefix.isEmpty ? key : '$prefix.$key';
          if (value is Map<String, dynamic>) {
            keys.addAll(extractKeys(value, fullKey));
          } else {
            keys.add(fullKey);
          }
        });
        return keys;
      }

      final arKeys = extractKeys(arJson);
      final enKeys = extractKeys(enJson);

      final missingInEn = arKeys.difference(enKeys);
      final missingInAr = enKeys.difference(arKeys);

      expect(missingInEn, isEmpty, reason: 'Keys in ar.json missing in en.json: $missingInEn');
      expect(missingInAr, isEmpty, reason: 'Keys in en.json missing in ar.json: $missingInAr');

      // Verify no empty string values
      for (final k in arKeys) {
        dynamic getVal(Map<String, dynamic> map, String path) {
          final parts = path.split('.');
          dynamic curr = map;
          for (final p in parts) {
            curr = curr[p];
          }
          return curr;
        }

        final arVal = getVal(arJson, k);
        final enVal = getVal(enJson, k);

        expect(arVal, isA<String>());
        expect(enVal, isA<String>());
        expect((arVal as String).trim(), isNotEmpty, reason: 'Key $k in ar.json must not be empty');
        expect((enVal as String).trim(), isNotEmpty, reason: 'Key $k in en.json must not be empty');
      }
    });
  });

  group('2. Interactive Language Switching Widget Test', () {
    testWidgets('Tapping AdminLanguageSwitchButton immediately switches locale and updates UI text', (tester) async {
      await tester.pumpWidget(
        EasyLocalization(
          supportedLocales: AppConfig.supportedLocales,
          path: 'assets/translations',
          fallbackLocale: AppConfig.arabicLocale,
          startLocale: AppConfig.arabicLocale,
          saveLocale: false,
          useOnlyLangCode: true,
          child: Builder(
            builder: (context) {
              return MaterialApp(
                key: ValueKey(context.locale.languageCode),
                locale: context.locale,
                supportedLocales: context.supportedLocales,
                localizationsDelegates: context.localizationDelegates,
                home: Scaffold(
                  appBar: AppBar(
                    title: Builder(
                      builder: (ctx) => Text(ctx.tr('dashboard.quick_actions_title')),
                    ),
                    actions: const [
                      AdminLanguageSwitchButton(compact: true),
                    ],
                  ),
                  body: Center(
                    child: Builder(
                      builder: (ctx) => Text(ctx.tr('courses.create_course')),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Initial State: Arabic (RTL)
      expect(Directionality.of(tester.element(find.byType(Scaffold))), TextDirection.rtl);
      expect(find.text('إجراءات الإدارة السريعة'), findsOneWidget);
      expect(find.text('إضافة كورس جديد'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);

      // 2. Tap to switch to English
      await tester.tap(find.byType(AdminLanguageSwitchButton));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // 3. English State (LTR)
      expect(Directionality.of(tester.element(find.byType(Scaffold))), TextDirection.ltr);
      expect(find.text('Executive Quick Actions'), findsOneWidget);
      expect(find.text('Create New Course'), findsOneWidget);
      expect(find.text('العربية'), findsOneWidget);

      // 4. Tap to switch back to Arabic
      await tester.tap(find.byType(AdminLanguageSwitchButton));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // 5. Back to Arabic State (RTL)
      expect(Directionality.of(tester.element(find.byType(Scaffold))), TextDirection.rtl);
      expect(find.text('إجراءات الإدارة السريعة'), findsOneWidget);
      expect(find.text('إضافة كورس جديد'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
    });
  });
}
