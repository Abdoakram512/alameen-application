import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:secure_screen_app/models/course.dart';
import 'package:secure_screen_app/models/course_certificate.dart';
import 'package:secure_screen_app/models/user_profile.dart';
import 'package:secure_screen_app/screens/student/course_details/widgets/course_certificate_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testCourse = Course(
    id: 'course-101',
    title: 'دبلومة الذكاء الاصطناعي والأمن السيبراني',
    description: 'دورة تدريبية مكثفة ومتكاملة',
    instructor: 'م. أحمد حسني',
    category: 'Cybersecurity',
    thumbnailUrl: 'https://example.com/thumb.jpg',
    levels: const [],
    price: 1500,
  );

  final testUser = UserModel(
    uid: 'student-999',
    displayName: 'محمد علي حسن',
    email: 'student@example.com',
    photoUrl: '',
    createdAt: DateTime(2026, 1, 1),
  );

  group('CourseCertificateCard Widget Tests', () {
    testWidgets('Renders locked state when progress is below 95%', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Directionality(
              textDirection: TextDirection.rtl,
              child: CourseCertificateCard(
                course: testCourse,
                user: testUser,
                completedLessonsCount: 6, // 6/10 = 60% < 95%
                totalLessonsCount: 10,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show locked certificate title
      expect(find.text('شهادة إتمام الدورة المعتمدة'), findsOneWidget);
      // Should show progress and remaining percentage (60% done, 35% remaining)
      expect(find.textContaining('أنجزت 60%'), findsOneWidget);
      expect(find.textContaining('متبقي 35% للتأهل للشهادة'), findsOneWidget);
      // Should show lock icon
      expect(find.byIcon(PhosphorIconsRegular.lockSimple), findsOneWidget);
      // Should show progress indicator and hint
      expect(find.textContaining('شاهد ما لا يقل عن 95% من فيديوهات المحاضرات'), findsOneWidget);
      // Should NOT show ready button
      expect(find.text('عرض وتحميل الشهادة المعتمدة (PDF)'), findsNothing);
    });

    testWidgets('Renders unlocked eligible state when progress is 95% or higher', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Directionality(
              textDirection: TextDirection.rtl,
              child: CourseCertificateCard(
                course: testCourse,
                user: testUser,
                completedLessonsCount: 10, // 10/10 = 100% >= 95%
                totalLessonsCount: 10,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show unlocked ready certificate title
      expect(find.text('شهادة إتمام الدورة المعتمدة جاهزة!'), findsOneWidget);
      expect(find.textContaining('تهانينا! حققت نسبة الإنجاز المطلوبة (95%+)'), findsOneWidget);
      // Should show certificate icon
      expect(find.byIcon(PhosphorIconsFill.certificate), findsOneWidget);
      // Should show ready CTA button
      expect(find.text('عرض وتحميل الشهادة المعتمدة (PDF)'), findsOneWidget);
    });

    testWidgets('Returns SizedBox.shrink when total lessons is 0 or user is null', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Directionality(
              textDirection: TextDirection.rtl,
              child: CourseCertificateCard(
                course: testCourse,
                user: null,
                completedLessonsCount: 0,
                totalLessonsCount: 0,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('شهادة إتمام الدورة المعتمدة'), findsNothing);
      expect(find.text('شهادة إتمام الدورة المعتمدة جاهزة!'), findsNothing);
    });
  });

  group('CourseCertificate Model Tests', () {
    test('CourseCertificate creates, serializes and deserializes correctly', () {
      final cert = CourseCertificate(
        id: 'cert-12345',
        courseId: 'course-101',
        courseTitle: 'دورة بايثون المتقدمة',
        studentId: 'std-77',
        studentName: 'محمود السيد',
        studentEmail: 'student@example.com',
        issuedAt: DateTime(2026, 11, 9),
        completionPercentage: 98.5,
        serialNumber: 'ALAMEEN-2026-9988',
        instructorName: 'م. أحمد حسني',
      );

      final map = cert.toMap();
      expect(map['id'], equals('cert-12345'));
      expect(map['courseId'], equals('course-101'));
      expect(map['completionPercentage'], equals(98.5));
      expect(map['serialNumber'], equals('ALAMEEN-2026-9988'));

      final fromMap = CourseCertificate.fromMap(map, id: 'cert-12345');
      expect(fromMap.id, equals('cert-12345'));
      expect(fromMap.studentName, equals('محمود السيد'));
      expect(fromMap.courseTitle, equals('دورة بايثون المتقدمة'));
      expect(fromMap.serialNumber, equals('ALAMEEN-2026-9988'));
    });
  });
}
