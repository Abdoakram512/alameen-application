import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_admin_app/models/access_request.dart';
import 'package:secure_admin_app/models/course.dart';
import 'package:secure_admin_app/models/course_level.dart';
import 'package:secure_admin_app/models/lesson.dart';
import 'package:secure_admin_app/models/registered_student.dart';
import 'package:secure_admin_app/screens/dashboard/widgets/course_card_item.dart';
import 'package:secure_admin_app/screens/dashboard/widgets/request_card_item.dart';
import 'package:secure_admin_app/screens/dashboard/widgets/student_card_item.dart';
import 'test_localization_helper.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initTestLocalization(locale: const Locale('ar'));
  });

  group('LMS Elevated Cards UI & Design Tests', () {
    testWidgets('CourseCardItem renders modern badges and price properly', (tester) async {
      const testCourse = Course(
        id: 'c1',
        title: 'دورة تأهيل النطق والتخاطب المتقدمة',
        description: 'شرح متكامل لتمارين التخاطب للأطفال',
        instructor: 'د. أحمد الأمين',
        category: 'تخاطب',
        price: 450,
        thumbnailUrl: '',
        levels: [
          CourseLevel(
            id: 'lvl1',
            title: 'المستوى الأول',
            description: 'المستوى التأسيسي',
            order: 1,
            lessons: [
              Lesson(
                id: 'ls1',
                title: 'مقدمة المخارج',
                description: '',
                duration: '10:00',
                muxPlaybackId: 'mux123',
              ),
              Lesson(
                id: 'ls2',
                title: 'تمارين اللسان',
                description: '',
                duration: '15:00',
                muxPlaybackId: 'mux456',
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        testAppWrapper(
          child: const CourseCardItem(
            course: testCourse,
            enrolledCount: 15,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('دورة تأهيل النطق والتخاطب المتقدمة'), findsOneWidget);
      expect(find.text('د. أحمد الأمين'), findsOneWidget);
      expect(find.text('450 ج.م'), findsOneWidget);
      expect(find.text('1 مستويات'), findsOneWidget);
      expect(find.text('2 محاضرة'), findsOneWidget);
      expect(find.text('15 طالب'), findsOneWidget);
      expect(find.text('إدارة المستويات والدروس'), findsOneWidget);
    });

    testWidgets('RequestCardItem displays payment triage details and copyable ref', (tester) async {
      final testRequest = CourseAccessRequest(
        id: 'req1',
        studentId: 's1',
        studentName: 'محمود عبد الرحمن',
        studentEmail: 'mahmoud@example.com',
        courseId: 'c1',
        courseTitle: 'كورس علاج التلعثم للأطفال',
        paymentMethod: 'فودافون كاش',
        senderNumberOrRef: '01012345678',
        receiptUrl: '',
        status: AccessStatus.pending,
        requestedAt: DateTime(2026, 11, 5),
      );

      await tester.pumpWidget(
        testAppWrapper(
          child: RequestCardItem(request: testRequest),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('محمود عبد الرحمن'), findsOneWidget);
      expect(find.text('mahmoud@example.com'), findsOneWidget);
      expect(find.text('الكورس المطلوب: كورس علاج التلعثم للأطفال'), findsOneWidget);
      expect(find.text('طريقة الدفع: فودافون كاش'), findsOneWidget);
      expect(find.text('قيد الانتظار'), findsOneWidget);
      expect(find.text('الموافقة وتفعيل الكورس'), findsOneWidget);
      expect(find.text('رفض'), findsOneWidget);
    });

    testWidgets('StudentCardItem renders directory chips and enrollment badge', (tester) async {
      final student = RegisteredStudent(
        id: 'std1',
        name: 'سارة خالد',
        email: 'sara@example.com',
        joinedAt: DateTime(2026, 10, 15),
        enrolledCourseIds: ['c1'],
        completedLessonIds: {},
      );

      final List<Course> courses = [
        const Course(
          id: 'c1',
          title: 'كورس التأهيل السمعي',
          description: 'تأهيل الأطفال ضعاف السمع',
          instructor: 'د. سارة',
          category: 'سمعيات',
          thumbnailUrl: '',
          levels: [],
          price: 0,
        ),
      ];

      await tester.pumpWidget(
        testAppWrapper(
          child: StudentCardItem(
            student: student,
            courses: courses,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('سارة خالد'), findsOneWidget);
      expect(find.text('sara@example.com'), findsOneWidget);
      expect(find.text('مشترك'), findsOneWidget);
      expect(find.text('كورس التأهيل السمعي'), findsOneWidget);
      expect(find.text('التحليل الكامل'), findsOneWidget);
    });
  });
}
