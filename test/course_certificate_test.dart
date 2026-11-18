import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:secure_screen_app/core/di/injection_container.dart';
import 'package:secure_screen_app/models/course.dart';
import 'package:secure_screen_app/models/course_certificate.dart';
import 'package:secure_screen_app/models/user_profile.dart';
import 'package:secure_screen_app/repositories/student_certificates_repository.dart';
import 'package:secure_screen_app/screens/student/course_details/widgets/course_certificate_card.dart';

class MockCertificatesRepository extends Mock
    implements StudentCertificatesRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockCertificatesRepository mockRepo;

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

  setUp(() {
    mockRepo = MockCertificatesRepository();
    if (sl.isRegistered<StudentCertificatesRepository>()) {
      sl.unregister<StudentCertificatesRepository>();
    }
    sl.registerSingleton<StudentCertificatesRepository>(mockRepo);
  });

  tearDown(() {
    if (sl.isRegistered<StudentCertificatesRepository>()) {
      sl.unregister<StudentCertificatesRepository>();
    }
  });

  group('CourseCertificateCard Widget Tests', () {
    testWidgets('Renders locked state when progress is below 95%', (tester) async {
      when(() => mockRepo.getStudentCertificates(
            forceRefresh: any(named: 'forceRefresh'),
            currentStudentId: any(named: 'currentStudentId'),
          )).thenAnswer((_) async => []);

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
      expect(find.text('عرض وتوثيق الشهادة الرسمية'), findsNothing);
    });

    testWidgets('Renders pending approval state when progress >= 95% but no server certificate issued yet', (tester) async {
      when(() => mockRepo.getStudentCertificates(
            forceRefresh: any(named: 'forceRefresh'),
            currentStudentId: any(named: 'currentStudentId'),
          )).thenAnswer((_) async => []);

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

      // Should show pending state without fabricating a fake certificate
      expect(find.text('متطلبات الشهادة مكتملة (95%+)'), findsOneWidget);
      expect(find.textContaining('بانتظار الاعتماد والإصدار الرسمي'), findsOneWidget);
      expect(find.text('التحقق من حالة إصدار الشهادة'), findsOneWidget);
      expect(find.text('عرض وتوثيق الشهادة الرسمية'), findsNothing);
    });

    testWidgets('Renders official ready state when backend confirms issued certificate', (tester) async {
      final officialCert = CourseCertificate(
        id: 'cert-7',
        courseId: 'course-101',
        courseTitle: testCourse.title,
        studentId: testUser.uid,
        studentName: testUser.displayName,
        certificateCode: 'ALAMEEN-2026-CERT7',
        issuedAt: DateTime.now(),
        verificationUrl: 'https://alameen-center.online/verify/ALAMEEN-2026-CERT7',
        fileUrl: 'https://alameen-center.online/storage/ALAMEEN-2026-CERT7.pdf',
      );

      when(() => mockRepo.getStudentCertificates(
            forceRefresh: any(named: 'forceRefresh'),
            currentStudentId: any(named: 'currentStudentId'),
          )).thenAnswer((_) async => [officialCert]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Directionality(
              textDirection: TextDirection.rtl,
              child: CourseCertificateCard(
                course: testCourse,
                user: testUser,
                completedLessonsCount: 10,
                totalLessonsCount: 10,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show unlocked ready certificate title
      expect(find.text('شهادة إتمام الدورة المعتمدة جاهزة!'), findsOneWidget);
      expect(find.textContaining('ALAMEEN-2026-CERT7'), findsOneWidget);
      // Should show certificate icons (header badge + action button)
      expect(find.byIcon(PhosphorIconsFill.certificate), findsNWidgets(2));
      // Should show ready CTA button
      expect(find.text('عرض وتوثيق الشهادة الرسمية'), findsOneWidget);
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
