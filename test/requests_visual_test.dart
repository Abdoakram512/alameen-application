import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_admin_app/core/theme/app_theme.dart';
import 'package:secure_admin_app/logic/requests/admin_requests_cubit.dart';
import 'package:secure_admin_app/screens/dashboard/tabs/requests_tab.dart';
import 'package:secure_admin_app/models/access_request.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'requests_state_test.dart' show TestRequests;

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('Request triage renders Arabic filters and keeps search usable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      final loader = FontLoader('Cairo')
        ..addFont(rootBundle.load('assets/fonts/Cairo.ttf'));
      await loader.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
    });
    final repo = TestRequests();
    final cubit = AdminRequestsCubit(requestsRepository: repo);
    cubit.loadRequests();
    addTearDown(cubit.close);
    addTearDown(repo.controller.close);
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
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            home: BlocProvider.value(
              value: cubit,
              child: const Directionality(
                textDirection: TextDirection.rtl,
                child: Scaffold(body: RequestsTab()),
              ),
            ),
          ),
        ),
      ),
    );
    repo.controller.add([
      CourseAccessRequest(
        id: 'r1',
        studentId: 's1',
        studentName: 'أحمد محمد',
        studentEmail: 'student@example.test',
        courseId: 'c1',
        courseTitle: 'أساسيات التخاطب وتنمية التواصل',
        requestedAt: DateTime(2026, 11, 6),
        senderNumberOrRef: 'TEST-1042',
      ),
    ]);
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/requests.png'),
    );
    await tester.enterText(find.byType(TextField), 'غير موجود');
    await tester.pumpAndSettle();
    expect(find.text('لا توجد نتائج مطابقة'), findsOneWidget);
    await tester.tap(find.byTooltip('مسح البحث'));
    await tester.pumpAndSettle();
    expect(find.text('أحمد محمد'), findsOneWidget);
  });
}
