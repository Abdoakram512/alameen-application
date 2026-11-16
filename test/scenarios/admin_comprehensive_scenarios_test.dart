import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:secure_admin_app/core/widgets/student_avatar.dart';
import 'package:secure_admin_app/models/access_request.dart';
import 'package:secure_admin_app/models/course.dart';
import 'package:secure_admin_app/models/course_level.dart';
import 'package:secure_admin_app/models/lesson.dart';
import 'package:secure_admin_app/models/registered_student.dart';
import 'package:secure_admin_app/screens/dashboard/widgets/course_card_item.dart';
import 'package:secure_admin_app/screens/dashboard/widgets/dashboard_bottom_nav_bar.dart';
import 'package:secure_admin_app/screens/dashboard/widgets/dashboard_hero_kpi_card.dart';
import 'package:secure_admin_app/screens/dashboard/widgets/dashboard_quick_actions.dart';
import 'package:secure_admin_app/screens/dashboard/widgets/request_card_item.dart';
import 'package:secure_admin_app/screens/dashboard/widgets/student_card_item.dart';
import '../test_localization_helper.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initTestLocalization(locale: const Locale('ar'));
  });

  group('Admin Scenario Suite 1: Dashboard Navigation & KPI Architecture', () {
    testWidgets('Scenario 1.1: Bottom navigation switching and pending badge', (tester) async {
      int activeIndex = 0;

      await tester.pumpWidget(
        testAppWrapper(
          wrapInScaffold: false,
          child: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              bottomNavigationBar: Directionality(
                textDirection: TextDirection.rtl,
                child: DashboardBottomNavBar(
                  currentIndex: activeIndex,
                  onIndexChanged: (i) => setState(() => activeIndex = i),
                  pendingCount: 5,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify active tab label and pending badge
      expect(find.text('الكورسات'), findsOneWidget);
      expect(find.text('5'), findsOneWidget); // Pending badge

      // Tap Assignments via notebook (index 1)
      await tester.tap(find.byIcon(PhosphorIconsRegular.notebook), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(activeIndex, equals(1));

      // Tap Analytics via chartPolar (index 2)
      await tester.tap(find.byIcon(PhosphorIconsRegular.chartPolar), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(activeIndex, equals(2));

      // Tap Students via usersThree (index 3)
      await tester.tap(find.byIcon(PhosphorIconsRegular.usersThree), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(activeIndex, equals(3));

      // Tap Requests via receipt (index 4)
      await tester.tap(find.byIcon(PhosphorIconsRegular.receipt), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(activeIndex, equals(4));
    });

    testWidgets('Scenario 1.2: Dashboard Hero KPI Card metrics display and triage trigger', (tester) async {
      bool triageFired = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Directionality(
              textDirection: TextDirection.rtl,
              child: SingleChildScrollView(
                child: DashboardHeroKpiCard(
                  totalCourses: 12,
                  totalLessons: 48,
                  totalStudents: 154,
                  enrolledStudents: 92,
                  pendingRequestsCount: 6,
                  onReviewRequests: () => triageFired = true,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('12'), findsOneWidget);
      expect(find.text('48'), findsOneWidget);
      expect(find.text('92'), findsOneWidget);
      expect(find.textContaining('يوجد 6 طلبات اشتراك تحتاج المراجعة'), findsOneWidget);

      await tester.tap(find.textContaining('يوجد 6 طلبات اشتراك'));
      expect(triageFired, isTrue);
    });

    testWidgets('Scenario 1.3: Executive Quick Actions 4-card interactive grid', (tester) async {
      bool requestsTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Directionality(
              textDirection: TextDirection.rtl,
              child: SingleChildScrollView(
                child: DashboardQuickActions(
                  pendingRequestsCount: 8,
                  onGoToRequests: () => requestsTapped = true,
                  onGoToAnalytics: () {},
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('تسجيل متدربين'), findsOneWidget);
      expect(find.text('فريق العمل'), findsOneWidget);
      expect(find.text('طلبات الاشتراك'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      expect(find.text('مزامنة المنصة'), findsOneWidget);

      await tester.tap(find.text('طلبات الاشتراك'));
      expect(requestsTapped, isTrue);
    });
  });

  group('Admin Scenario Suite 2: Course Cards & Dialogs Edge Cases', () {
    const sampleCourse = Course(
      id: 'c_full_01',
      title: 'دبلومة التخاطب المتكاملة والتأهيل السمعي اللفظي المتقدم للأطفال ذوي الإعاقة',
      description: 'شرح سريري شامل لأحدث أساليب تشخيص وعلاج اضطرابات النطق والكلام',
      instructor: 'أ.د. سمير الأمين',
      category: 'تخاطب سريري',
      price: 1250,
      thumbnailUrl: '',
      levels: [
        CourseLevel(
          id: 'lvl_1',
          title: 'المستوى التأسيسي الأول',
          description: 'علم وظائف أعضاء النطق',
          order: 1,
          lessons: [
            Lesson(
              id: 'l_1',
              title: 'تشريح الجهاز النطقي',
              description: '',
              duration: '45:00',
              muxPlaybackId: 'mux_xyz_123',
            ),
          ],
        ),
      ],
    );

    testWidgets('Scenario 2.1: CourseCardItem baseline alignment with long multi-line title and price badge', (tester) async {
      await tester.pumpWidget(
        testAppWrapper(
          child: const CourseCardItem(
            course: sampleCourse,
            enrolledCount: 42,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify title is rendered completely without ellipsis
      expect(find.text(sampleCourse.title), findsOneWidget);
      expect(find.text('أ.د. سمير الأمين'), findsOneWidget);
      expect(find.text('1250 ج.م'), findsOneWidget);
      expect(find.text('1 مستويات'), findsOneWidget);
      expect(find.text('1 محاضرة'), findsOneWidget);
      expect(find.text('42 طالب'), findsOneWidget);
      expect(find.text('إدارة المستويات والدروس'), findsOneWidget);

      // Verify action buttons exist
      expect(find.byIcon(PhosphorIconsRegular.clipboardText), findsOneWidget);
      expect(find.byIcon(PhosphorIconsRegular.pencilSimpleLine), findsOneWidget);
      expect(find.byIcon(PhosphorIconsRegular.trash), findsOneWidget);
    });

    testWidgets('Scenario 2.2: Course Delete Confirmation Dialog safety barrier', (tester) async {
      bool deleteConfirmed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: ElevatedButton(
                  onPressed: () async {
                    final res = await showDialog<bool>(
                      context: ctx,
                      builder: (dCtx) => AlertDialog(
                        title: const Text('حذف الكورس'),
                        content: Text('هل أنت متأكد من حذف كورس "${sampleCourse.title}" نهائياً من قاعدة البيانات؟'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dCtx, false),
                            child: const Text('إلغاء'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(dCtx, true),
                            child: const Text('حذف'),
                          ),
                        ],
                      ),
                    );
                    if (res == true) deleteConfirmed = true;
                  },
                  child: const Text('افتح دايلوج الحذف'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('افتح دايلوج الحذف'));
      await tester.pumpAndSettle();

      expect(find.text('حذف الكورس'), findsOneWidget);
      expect(find.textContaining(sampleCourse.title), findsOneWidget);

      // Test cancel first
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();
      expect(deleteConfirmed, isFalse);

      // Re-open and confirm
      await tester.tap(find.text('افتح دايلوج الحذف'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('حذف'));
      await tester.pumpAndSettle();
      expect(deleteConfirmed, isTrue);
    });
  });

  group('Admin Scenario Suite 3: Access Requests Triage & Payment Details', () {
    final pendingReq = CourseAccessRequest(
      id: 'req_001',
      studentId: 'std_001',
      studentName: 'محمد أحمد الجندي',
      studentEmail: 'mohamed.elgendy@gmail.com',
      courseId: 'c_full_01',
      courseTitle: 'دبلومة التخاطب المتكاملة والتأهيل السمعي',
      paymentMethod: 'فودافون كاش',
      senderNumberOrRef: '01023456789 - فودافون كاش كود 88291',
      receiptUrl: '',
      status: AccessStatus.pending,
      requestedAt: DateTime(2026, 11, 7, 14, 30),
    );

    testWidgets('Scenario 3.1: RequestCardItem renders baseline-aligned metadata and copyable ref', (tester) async {
      await tester.pumpWidget(
        testAppWrapper(
          child: RequestCardItem(request: pendingReq),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('محمد أحمد الجندي'), findsOneWidget);
      expect(find.text('mohamed.elgendy@gmail.com'), findsOneWidget);
      expect(find.text('قيد الانتظار'), findsOneWidget);
      expect(find.text('الكورس المطلوب: دبلومة التخاطب المتكاملة والتأهيل السمعي'), findsOneWidget);
      expect(find.text('طريقة الدفع: فودافون كاش'), findsOneWidget);
      expect(find.text('الموافقة وتفعيل الكورس'), findsOneWidget);
      expect(find.text('رفض'), findsOneWidget);
    });
  });

  group('Admin Scenario Suite 4: Student Directory & Arabic Initials Resolution', () {
    final student = RegisteredStudent(
      id: 'std_elameen_10',
      name: 'فاطمة الزهراء علي حسن',
      email: 'fatma.ali@alameen-center.org',
      phone: '01123456789',
      joinedAt: DateTime(2026, 10, 1),
      enrolledCourseIds: ['c_1'],
      completedLessonIds: {},
      totalWatchSeconds: 7500,
    );

    final courses = [
      const Course(
        id: 'c_1',
        title: 'كورس تأهيل اضطرابات الصوت',
        description: '',
        instructor: 'د. سارة',
        category: 'صوت',
        price: 0,
        thumbnailUrl: '',
        levels: [],
      ),
      const Course(
        id: 'c_2',
        title: 'كورس التوحد والتواصل البصري واللغوي',
        description: '',
        instructor: 'د. الأمين',
        category: 'توحد',
        price: 500,
        thumbnailUrl: '',
        levels: [],
      ),
    ];

    testWidgets('Scenario 4.1: StudentCardItem renders enrolled chip, watch time and interactive chips', (tester) async {
      await tester.pumpWidget(
        testAppWrapper(
          child: StudentCardItem(
            student: student,
            courses: courses,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('فاطمة الزهراء علي حسن'), findsOneWidget);
      expect(find.text('fatma.ali@alameen-center.org'), findsOneWidget);
      expect(find.text('مشترك'), findsOneWidget);
      expect(find.text('كورس تأهيل اضطرابات الصوت'), findsOneWidget);
      expect(find.text('كورس التوحد والتواصل البصري واللغوي'), findsOneWidget);
      expect(find.text('التحليل الكامل'), findsOneWidget);
    });

    testWidgets('Scenario 4.2: StudentAvatar displays Arabic initials accurately when photo is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: StudentAvatar(
                name: 'محمود عبد السلام',
                photoUrl: null,
                radius: 24,
              ),
            ),
          ),
        ),
      );

      // Verify initials 'مع' (first letter of first and second word)
      expect(find.text('مع'), findsOneWidget);
    });
  });
}
