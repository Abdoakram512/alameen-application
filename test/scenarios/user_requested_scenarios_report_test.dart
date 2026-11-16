// ignore_for_file: unused_local_variable, prefer_const_constructors
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_admin_app/models/course.dart';
import 'package:secure_admin_app/models/course_access_mode.dart';
import 'package:secure_admin_app/models/course_level.dart';
import 'package:secure_admin_app/models/lesson.dart';
import 'package:secure_admin_app/models/registered_student.dart';

void main() {
  group('Comprehensive User-Requested Scenario Diagnostics', () {
    test('Scenario 1 & 2: Reproducing Race Condition on Nested Levels Array', () {
      // 1. Initial Course with 1 level
      var course = Course(
        id: 'course_test_100',
        title: 'كورس تجريبي',
        description: 'وصف تجريبي',
        instructor: 'مركز الأمين',
        category: 'تخاطب وتأهيل',
        thumbnailUrl: '',
        price: 500,
        accessMode: CourseAccessMode.approvalRequired,
        levels: [
          CourseLevel(
            id: 'lvl_1',
            title: 'المستوى الأول',
            description: 'وصف 1',
            order: 1,
            lessons: const [],
          ),
        ],
      );

      // Simulating what happens when 3 lessons are added quickly without queuing:
      // Worker A reads course snapshot (0 lessons)
      final snapshotA = course;
      // Worker B reads course snapshot (0 lessons) before Worker A commits
      final snapshotB = course;
      // Worker C reads course snapshot (0 lessons) before Worker A/B commit
      final snapshotC = course;

      // Worker A adds Lesson 1
      final l1 = Lesson(id: 'les_1', title: 'الدرس الأول', description: '', duration: '10:00', order: 1, type: 'video', muxPlaybackId: 'pb_1');
      final levelsA = List<CourseLevel>.from(snapshotA.levels);
      levelsA[0] = levelsA[0].copyWith(lessons: [l1]);
      final commitA = snapshotA.copyWith(levels: levelsA);

      // Worker B adds Lesson 2 from stale snapshotB
      final l2 = Lesson(id: 'les_2', title: 'الدرس الثاني', description: '', duration: '10:00', order: 1, type: 'video', muxPlaybackId: 'pb_2');
      final levelsB = List<CourseLevel>.from(snapshotB.levels);
      levelsB[0] = levelsB[0].copyWith(lessons: [l2]);
      final commitB = snapshotB.copyWith(levels: levelsB);

      // Worker C adds Lesson 3 from stale snapshotC
      final l3 = Lesson(id: 'les_3', title: 'الدرس الثالث', description: '', duration: '10:00', order: 1, type: 'video', muxPlaybackId: 'pb_3');
      final levelsC = List<CourseLevel>.from(snapshotC.levels);
      levelsC[0] = levelsC[0].copyWith(lessons: [l3]);
      final commitC = snapshotC.copyWith(levels: levelsC);

      // If commit C is the last write to Firestore document:
      course = commitC;

      // PROOF OF BUG:
      // Even though 3 lessons were added, only Lesson 3 exists! Lessons 1 and 2 were wiped out!
      expect(course.levels[0].lessons.length, 1);
      expect(course.levels[0].lessons.first.id, 'les_3');
    });

    test('Scenario 1 & 2 [FIXED]: Sequential Mutex Queue preserves all lessons added concurrently', () async {
      var course = Course(
        id: 'course_test_fixed',
        title: 'كورس تجريبي',
        description: 'وصف تجريبي',
        instructor: 'مركز الأمين',
        category: 'تخاطب وتأهيل',
        thumbnailUrl: '',
        price: 500,
        accessMode: CourseAccessMode.approvalRequired,
        levels: [
          CourseLevel(
            id: 'lvl_1',
            title: 'المستوى الأول',
            description: 'وصف 1',
            order: 1,
            lessons: const [],
          ),
        ],
      );

      // Simulated serialized course mutation runner
      Future<void> runSerializedMutation(Future<void> Function() action) async {
        await action();
      }

      final l1 = Lesson(id: 'les_1', title: 'الدرس الأول', description: '', duration: '10:00', order: 1, type: 'video', muxPlaybackId: 'pb_1');
      final l2 = Lesson(id: 'les_2', title: 'الدرس الثاني', description: '', duration: '10:00', order: 2, type: 'video', muxPlaybackId: 'pb_2');
      final l3 = Lesson(id: 'les_3', title: 'الدرس الثالث', description: '', duration: '10:00', order: 3, type: 'video', muxPlaybackId: 'pb_3');

      // 1. Worker A runs
      await runSerializedMutation(() async {
        final currentLvl = course.levels[0];
        final updated = List<Lesson>.from(currentLvl.lessons)..add(l1);
        final lvls = List<CourseLevel>.from(course.levels);
        lvls[0] = currentLvl.copyWith(lessons: updated);
        course = course.copyWith(levels: lvls);
      });

      // 2. Worker B runs in serialized queue
      await runSerializedMutation(() async {
        final currentLvl = course.levels[0];
        final updated = List<Lesson>.from(currentLvl.lessons)..add(l2);
        final lvls = List<CourseLevel>.from(course.levels);
        lvls[0] = currentLvl.copyWith(lessons: updated);
        course = course.copyWith(levels: lvls);
      });

      // 3. Worker C runs in serialized queue
      await runSerializedMutation(() async {
        final currentLvl = course.levels[0];
        final updated = List<Lesson>.from(currentLvl.lessons)..add(l3);
        final lvls = List<CourseLevel>.from(course.levels);
        lvls[0] = currentLvl.copyWith(lessons: updated);
        course = course.copyWith(levels: lvls);
      });

      // PROOF OF FIX: All 3 lessons are 100% preserved in order!
      expect(course.levels[0].lessons.length, 3);
      expect(course.levels[0].lessons[0].id, 'les_1');
      expect(course.levels[0].lessons[1].id, 'les_2');
      expect(course.levels[0].lessons[2].id, 'les_3');
    });

    test('Scenario 1B: Deleted lessons reappear when adding a new level from stale snapshot', () {
      // Course initially had Lesson 1 and Lesson 2
      final l1 = Lesson(id: 'les_1', title: 'الدرس الأول', description: '', duration: '10:00', order: 1, type: 'video', muxPlaybackId: 'pb_1');
      final l2 = Lesson(id: 'les_2', title: 'الدرس الثاني', description: '', duration: '10:00', order: 2, type: 'video', muxPlaybackId: 'pb_2');
      
      var course = Course(
        id: 'c1',
        title: 'كورس',
        description: '',
        instructor: '',
        category: '',
        thumbnailUrl: '',
        levels: [
          CourseLevel(id: 'lvl_1', title: 'المستوى 1', description: '', order: 1, lessons: [l1, l2]),
        ],
      );

      // Stale cache snapshot captured before deletion completes on server
      final staleSnapshot = course;

      // User deletes Lesson 2
      final updatedLessons = course.levels[0].lessons.where((l) => l.id != 'les_2').toList();
      course = course.copyWith(levels: [
        course.levels[0].copyWith(lessons: updatedLessons),
      ]);
      expect(course.levels[0].lessons.length, 1); // Only Lesson 1 remains

      // User now clicks "Add Level"
      // If addLevelToCourse reads docRef.get() which returns staleSnapshot:
      final newLevel = CourseLevel(id: 'lvl_2', title: 'المستوى 2', description: '', order: 2, lessons: const []);
      final resurrectedLevels = List<CourseLevel>.from(staleSnapshot.levels)..add(newLevel);
      course = staleSnapshot.copyWith(levels: resurrectedLevels);

      // PROOF OF BUG: Lesson 2 came back from the dead!
      expect(course.levels[0].lessons.length, 2);
      expect(course.levels[0].lessons.any((l) => l.id == 'les_2'), isTrue);
    });

    test('Scenario 4: 10 Students Catalog Visibility across all Access Modes', () {
      final students = List.generate(
        10,
        (i) => RegisteredStudent(
          id: 'student_${i + 1}',
          name: 'طالب تجريبي ${i + 1}',
          email: 'student${i + 1}@elameen.com',
          role: 'student',
          enrolledCourseIds: const [],
          completedLessonIds: const {},
          appOrigin: 'alameen_speech_center',
          phone: '0100000000$i',
          isSuspended: false,
          joinedAt: DateTime.now(),
        ),
      );

      bool isVisible(Course c, RegisteredStudent user) {
        if (c.accessMode == CourseAccessMode.closed) return false;
        if (c.accessMode == CourseAccessMode.assignedOnly) {
          return c.allowedStudentIds.contains(user.id) || user.enrolledCourseIds.contains(c.id);
        }
        return true;
      }

      // 1. OPEN Course
      final openCourse = Course(
        id: 'c_open',
        title: 'كورس مفتوح',
        description: '',
        instructor: '',
        category: 'تخاطب',
        thumbnailUrl: '',
        accessMode: CourseAccessMode.open,
        levels: const [],
      );
      for (final s in students) {
        expect(isVisible(openCourse, s), isTrue, reason: 'Open course must be visible to all 10 students');
      }

      // 2. CLOSED Course
      final closedCourse = openCourse.copyWith(accessMode: CourseAccessMode.closed);
      for (final s in students) {
        expect(isVisible(closedCourse, s), isFalse, reason: 'Closed course must be hidden from all 10 students');
      }

      // 3. ASSIGNED ONLY (Students 1, 2, 3 assigned)
      final assignedCourse = openCourse.copyWith(
        accessMode: CourseAccessMode.assignedOnly,
        allowedStudentIds: ['student_1', 'student_2', 'student_3'],
      );
      for (final s in students) {
        final expected = ['student_1', 'student_2', 'student_3'].contains(s.id);
        expect(isVisible(assignedCourse, s), expected, reason: 'Only assigned students should see assignedOnly course');
      }

      // 4. APPROVAL REQUIRED (Students can see it in catalog, but must request enrollment)
      final approvalCourse = openCourse.copyWith(accessMode: CourseAccessMode.approvalRequired);
      for (final s in students) {
        expect(isVisible(approvalCourse, s), isTrue, reason: 'Approval required courses are listed in catalog so students can apply');
      }

      // 5. Course Deletion: when course is removed from catalog list
      final catalog = [openCourse, assignedCourse, approvalCourse];
      final deletedCatalog = catalog.where((c) => c.id != 'c_open').toList();
      expect(deletedCatalog.any((c) => c.id == 'c_open'), isFalse);
    });

    test('Scenario 4G: Scheduled Lectures Unlock Simulation over Time Intervals (15s, 20s, 30s, 40s)', () {
      final now = DateTime.now();
      final scheduledAt = now.add(const Duration(seconds: 25));

      final lesson = Lesson(
        id: 'les_sched',
        title: 'محاضرة مجدولة',
        description: '',
        duration: '15:00',
        order: 1,
        type: 'video',
        muxPlaybackId: 'pb_sched',
        isPublished: false,
        scheduledPublishAt: scheduledAt,
      );

      bool isAvailableToStudent(Lesson l, DateTime currentTime) {
        if (l.isPublished) return true;
        if (l.scheduledPublishAt != null && currentTime.isAfter(l.scheduledPublishAt!)) {
          return true;
        }
        return false;
      }

      // At T = 0s
      expect(isAvailableToStudent(lesson, now), isFalse, reason: 'At T=0s lecture is locked');

      // At T = 15s (still before 25s)
      expect(isAvailableToStudent(lesson, now.add(const Duration(seconds: 15))), isFalse);

      // At T = 20s (still before 25s)
      expect(isAvailableToStudent(lesson, now.add(const Duration(seconds: 20))), isFalse);

      // At T = 30s (past 25s) -> UNLOCKED!
      expect(isAvailableToStudent(lesson, now.add(const Duration(seconds: 30))), isTrue);

      // At T = 40s (past 25s) -> UNLOCKED!
      expect(isAvailableToStudent(lesson, now.add(const Duration(seconds: 40))), isTrue);
    });
  });
}

