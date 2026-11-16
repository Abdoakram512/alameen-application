import 'package:flutter_test/flutter_test.dart';
import 'package:secure_admin_app/models/registered_student.dart';

void main() {
  group('P6 Entitlements Migration Logic Tests (Dry Run Safety)', () {
    test('Identifies legacy student with enrolledCourseIds but empty fullCourseEntitlements', () {
      final legacyStudent = RegisteredStudent(
        id: 'student_legacy_001',
        name: 'أحمد محمود',
        email: 'ahmed@test.com',
        joinedAt: DateTime(2025, 1, 1),
        enrolledCourseIds: const ['course_math_101', 'course_physics_201'],
        completedLessonIds: const {},
        fullCourseEntitlements: const [],
        levelEntitlements: const [],
        unlockedLevelIds: const [],
      );

      final isCandidate = legacyStudent.enrolledCourseIds.isNotEmpty &&
          legacyStudent.fullCourseEntitlements.isEmpty &&
          legacyStudent.levelEntitlements.isEmpty;

      expect(isCandidate, isTrue);

      // Proposed dry-run patch
      final migrated = legacyStudent.copyWith(
        fullCourseEntitlements: legacyStudent.enrolledCourseIds,
      );

      expect(migrated.fullCourseEntitlements, equals(['course_math_101', 'course_physics_201']));
      expect(migrated.isLevelUnlocked('course_math_101', 'lvl_any'), isTrue);
    });

    test('Ignores already-migrated or new students with existing entitlements', () {
      final modernStudent = RegisteredStudent(
        id: 'student_modern_002',
        name: 'سارة علي',
        email: 'sara@test.com',
        joinedAt: DateTime(2026, 2, 1),
        enrolledCourseIds: const ['course_math_101'],
        completedLessonIds: const {},
        fullCourseEntitlements: const ['course_math_101'],
        levelEntitlements: const [],
        unlockedLevelIds: const [],
      );

      final isCandidate = modernStudent.enrolledCourseIds.isNotEmpty &&
          modernStudent.fullCourseEntitlements.isEmpty &&
          modernStudent.levelEntitlements.isEmpty;

      expect(isCandidate, isFalse);
    });

    test('Correctly distinguishes level-specific entitlement from full course entitlement', () {
      final levelStudent = RegisteredStudent(
        id: 'student_level_003',
        name: 'كريم هاني',
        email: 'karim@test.com',
        joinedAt: DateTime(2026, 3, 1),
        enrolledCourseIds: const ['course_physics_201'],
        completedLessonIds: const {},
        fullCourseEntitlements: const [],
        levelEntitlements: const ['course_physics_201:lvl_1'],
        unlockedLevelIds: const [],
      );

      expect(levelStudent.isLevelUnlocked('course_physics_201', 'lvl_1'), isTrue);
      expect(levelStudent.isLevelUnlocked('course_physics_201', 'lvl_2'), isFalse);
    });
  });
}
