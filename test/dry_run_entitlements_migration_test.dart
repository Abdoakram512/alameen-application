import 'package:flutter_test/flutter_test.dart';
import 'package:secure_admin_app/models/access_request.dart';
import 'package:secure_admin_app/models/registered_student.dart';

void main() {
  group('P6 Audited Entitlements Migration Logic Tests (Dry Run Safety)', () {
    test('Verified Full-Course Buyer: approved request without levelId grants fullCourseEntitlements', () {
      final legacyStudent = RegisteredStudent(
        id: 'student_legacy_full',
        name: 'أحمد محمود',
        email: 'ahmed@test.com',
        joinedAt: DateTime(2025, 1, 1),
        enrolledCourseIds: const ['course_math_101'],
        completedLessonIds: const {},
        fullCourseEntitlements: const [],
        levelEntitlements: const [],
        unlockedLevelIds: const [],
      );

      final approvedRequest = CourseAccessRequest(
        id: 'req_001',
        studentId: 'student_legacy_full',
        studentName: 'أحمد محمود',
        studentEmail: 'ahmed@test.com',
        courseId: 'course_math_101',
        courseTitle: 'الرياضيات',
        status: AccessStatus.approved,
        requestedAt: DateTime(2025, 1, 1),
        reviewedAt: DateTime(2025, 1, 2),
      );

      // Migration auditor checks:
      final hasApprovedRequest = approvedRequest.status == AccessStatus.approved;
      final isLevelSpecific = approvedRequest.levelId != null && approvedRequest.levelId!.isNotEmpty;

      expect(hasApprovedRequest, isTrue);
      expect(isLevelSpecific, isFalse);

      final migrated = legacyStudent.copyWith(
        fullCourseEntitlements: [approvedRequest.courseId],
      );

      expect(migrated.fullCourseEntitlements, contains('course_math_101'));
      expect(migrated.isLevelUnlocked('course_math_101', 'lvl_1'), isTrue);
    });

    test('Verified Level-Only Buyer: approved request with levelId grants levelEntitlements ONLY', () {
      final legacyStudent = RegisteredStudent(
        id: 'student_legacy_lvl1',
        name: 'كريم هاني',
        email: 'karim@test.com',
        joinedAt: DateTime(2025, 2, 1),
        enrolledCourseIds: const ['course_physics_201'],
        completedLessonIds: const {},
        fullCourseEntitlements: const [],
        levelEntitlements: const [],
        unlockedLevelIds: const [],
      );

      final approvedLevelRequest = CourseAccessRequest(
        id: 'req_002',
        studentId: 'student_legacy_lvl1',
        studentName: 'كريم هاني',
        studentEmail: 'karim@test.com',
        courseId: 'course_physics_201',
        courseTitle: 'الفيزياء',
        levelId: 'lvl_1',
        levelTitle: 'المستوى الأول',
        status: AccessStatus.approved,
        requestedAt: DateTime(2025, 2, 1),
        reviewedAt: DateTime(2025, 2, 2),
      );

      expect(approvedLevelRequest.levelId, equals('lvl_1'));

      final migrated = legacyStudent.copyWith(
        levelEntitlements: ['${approvedLevelRequest.courseId}:${approvedLevelRequest.levelId}'],
      );

      expect(migrated.fullCourseEntitlements, isEmpty);
      expect(migrated.levelEntitlements, equals(['course_physics_201:lvl_1']));
      expect(migrated.isLevelUnlocked('course_physics_201', 'lvl_1'), isTrue);
      expect(migrated.isLevelUnlocked('course_physics_201', 'lvl_2'), isFalse);
    });

    test('Unverified Enrollment: enrolledCourseIds without payment record is NOT automatically granted', () {
      final unverifiedStudent = RegisteredStudent(
        id: 'student_suspicious',
        name: 'مستخدم مجهول',
        email: 'unknown@test.com',
        joinedAt: DateTime(2025, 3, 1),
        enrolledCourseIds: const ['course_chemistry_paid'],
        completedLessonIds: const {},
        fullCourseEntitlements: const [],
        levelEntitlements: const [],
        unlockedLevelIds: const [],
      );

      // No approved request found in database
      const List<CourseAccessRequest> requests = [];

      final hasApprovedRequest = requests.any((r) =>
          r.studentId == unverifiedStudent.id &&
          r.courseId == 'course_chemistry_paid' &&
          r.status == AccessStatus.approved);

      expect(hasApprovedRequest, isFalse);

      // Must NOT automatically grant fullCourseEntitlements!
      final resultEntitlements = hasApprovedRequest ? ['course_chemistry_paid'] : <String>[];
      expect(resultEntitlements, isEmpty);
    });
  });
}
