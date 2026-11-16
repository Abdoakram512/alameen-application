import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:secure_admin_app/screens/dashboard/widgets/dashboard_bottom_nav_bar.dart';
import 'package:secure_admin_app/screens/dashboard/widgets/dashboard_hero_kpi_card.dart';
import 'package:secure_admin_app/screens/dashboard/widgets/dashboard_quick_actions.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  group('Home Screen Design & Executive Widgets Tests', () {
    testWidgets(
      'DashboardBottomNavBar displays 6 ergonomic tabs and badge correctly',
      (tester) async {
        int selected = 0;

        await tester.pumpWidget(
          EasyLocalization(
            supportedLocales: const [Locale('ar'), Locale('en')],
            path: 'assets/translations',
            fallbackLocale: const Locale('ar'),
            startLocale: const Locale('ar'),
            child: Builder(
              builder: (context) => MaterialApp(
                locale: context.locale,
                supportedLocales: context.supportedLocales,
                localizationsDelegates: context.localizationDelegates,
                home: Scaffold(
                  bottomNavigationBar: Directionality(
                    textDirection: TextDirection.rtl,
                    child: DashboardBottomNavBar(
                      currentIndex: selected,
                      onIndexChanged: (i) => selected = i,
                      pendingCount: 4,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('الكورسات'), findsOneWidget);
        expect(find.text('الواجبات'), findsNothing);
        expect(find.text('الإحصائيات'), findsNothing);
        expect(find.text('حسابي'), findsNothing);
        expect(find.text('4'), findsOneWidget);

        // Tap on Assignments tab (index 1)
        await tester.tap(find.byIcon(PhosphorIconsRegular.notebook));
        await tester.pump();
        expect(selected, equals(1));

        // Tap on Analytics tab (index 2)
        await tester.tap(find.byIcon(PhosphorIconsRegular.chartPolar));
        await tester.pump();
        expect(selected, equals(2));

        // Tap on Students tab (index 3)
        await tester.tap(find.byIcon(PhosphorIconsRegular.usersThree));
        await tester.pump();
        expect(selected, equals(3));

        // Tap on Profile tab (index 5)
        await tester.tap(find.byIcon(PhosphorIconsRegular.userGear));
        await tester.pump();
        expect(selected, equals(5));
      },
    );

    testWidgets(
      'DashboardHeroKpiCard renders metrics and handles triage click',
      (tester) async {
        bool triageClicked = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Directionality(
                textDirection: TextDirection.rtl,
                child: DashboardHeroKpiCard(
                  totalCourses: 5,
                  totalLessons: 42,
                  totalStudents: 120,
                  enrolledStudents: 85,
                  pendingRequestsCount: 3,
                  onReviewRequests: () => triageClicked = true,
                ),
              ),
            ),
          ),
        );

        expect(find.text('5'), findsOneWidget);
        expect(find.text('42'), findsOneWidget);
        expect(find.text('85'), findsOneWidget);
        expect(find.text('يوجد 3 طلبات اشتراك تحتاج المراجعة'), findsOneWidget);

        await tester.tap(find.text('يوجد 3 طلبات اشتراك تحتاج المراجعة'));
        await tester.pump();
        expect(triageClicked, isTrue);
      },
    );

    testWidgets('DashboardQuickActions displays action buttons properly', (
      tester,
    ) async {
      bool wentToRequests = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Directionality(
              textDirection: TextDirection.rtl,
              child: DashboardQuickActions(
                onGoToRequests: () => wentToRequests = true,
                onGoToAnalytics: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('إجراءات الإدارة السريعة'), findsOneWidget);
      expect(find.text('تسجيل متدربين'), findsOneWidget);
      expect(find.text('فريق العمل'), findsOneWidget);
      expect(find.text('طلبات الاشتراك'), findsOneWidget);
      expect(find.text('مزامنة المنصة'), findsOneWidget);

      await tester.tap(find.text('طلبات الاشتراك'));
      expect(wentToRequests, isTrue);
    });
  });
}
