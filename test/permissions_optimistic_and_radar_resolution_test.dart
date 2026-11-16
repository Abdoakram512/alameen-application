import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_admin_app/core/painters/executive_quick_action_painter.dart';
import 'package:secure_admin_app/models/registered_student.dart';
import 'package:secure_admin_app/screens/dashboard/widgets/dashboard_quick_actions.dart';
import 'test_localization_helper.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initTestLocalization(locale: const Locale('ar'));
  });

  group('Executive Quick Actions Painter & Widget Tests', () {
    testWidgets('ExecutiveQuickActionPainter paints canvas layers smoothly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 160,
                height: 104,
                child: CustomPaint(
                  painter: ExecutiveQuickActionPainter(
                    baseColor: Color(0xFF0B192C),
                    isPressed: false,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('DashboardQuickActions renders modern cards and pending badge', (tester) async {
      bool requestsClicked = false;

      await tester.pumpWidget(
        testAppWrapper(
          child: DashboardQuickActions(
            pendingRequestsCount: 7,
            onGoToRequests: () {
              requestsClicked = true;
            },
            onGoToAnalytics: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('تسجيل متدربين'), findsOneWidget);
      expect(find.text('فريق العمل'), findsOneWidget);
      expect(find.text('طلبات الاشتراك'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      expect(find.text('مزامنة المنصة'), findsOneWidget);

      await tester.tap(find.text('طلبات الاشتراك'));
      expect(requestsClicked, isTrue);
    });
  });

  group('Student Model & Optimistic Permissions Tests', () {
    test('Optimistic course permission grant updates in-memory copy instantly', () {
      final student = RegisteredStudent(
        id: 'std_42',
        name: 'كريم محمود',
        email: 'karim@alameen.org',
        joinedAt: DateTime(2026, 11, 1),
        enrolledCourseIds: ['course_a'],
        completedLessonIds: {},
      );

      expect(student.enrolledCourseIds.contains('course_a'), isTrue);
      expect(student.enrolledCourseIds.contains('course_b'), isFalse);

      // Grant
      student.grantAccess('course_b');
      expect(student.enrolledCourseIds.contains('course_b'), isTrue);
      expect(student.enrolledCourseIds, containsAll(['course_a', 'course_b']));

      // Revoke
      student.revokeAccess('course_a');
      expect(student.enrolledCourseIds.contains('course_a'), isFalse);
      expect(student.enrolledCourseIds.contains('course_b'), isTrue);
    });

    test('RegisteredStudent localized watch time formats Arabic and English ergonomically', () {
      final student = RegisteredStudent(
        id: 'std_1',
        name: 'علي حسن',
        email: 'ali@example.com',
        joinedAt: DateTime(2026, 11, 1),
        enrolledCourseIds: [],
        completedLessonIds: {},
        totalWatchSeconds: 3720, // 1h 2m
      );

      expect(student.localizedWatchTime(isAr: true), equals('1 س و 2 د'));
      expect(student.localizedWatchTime(isAr: false), equals('1h 2m'));

      final studentShort = student.copyWith(totalWatchSeconds: 1500); // 25 min
      expect(studentShort.localizedWatchTime(isAr: true), equals('25 دقيقة'));
      expect(studentShort.localizedWatchTime(isAr: false), equals('25 min'));
    });
  });
}
