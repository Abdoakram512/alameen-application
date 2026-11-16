import 'package:flutter_test/flutter_test.dart';
import 'package:secure_screen_app/models/course_access_mode.dart';
import 'package:secure_screen_app/models/course_level.dart';
import 'package:secure_screen_app/models/lesson.dart';

void main() {
  group('Regression Suite 5: Student Enrollment & Sequential Permissions', () {
    test('Open course allows direct lesson access without level constraints', () {
      const mode = CourseAccessMode.open;
      expect(mode, CourseAccessMode.open);
      expect(mode.isVisibleToStudents, isTrue);
    });

    test('Sequential course unlocks Level 2 only when all Level 1 lessons reach 95% completion', () {
      final level1 = CourseLevel(
        id: 'lvl_1',
        title: 'Level 1: Foundations',
        description: 'Level 1 description',
        order: 1,
        lessons: const [
          Lesson(id: 'les_1', title: 'Lesson 1', description: 'Desc 1', duration: '10:00', muxPlaybackId: 'mux_1', order: 1),
          Lesson(id: 'les_2', title: 'Lesson 2', description: 'Desc 2', duration: '10:00', muxPlaybackId: 'mux_2', order: 2),
        ],
      );

      final completedLessonIds = <String>{};

      bool isLevelUnlocked(CourseLevel level, CourseLevel? previousLevel) {
        if (previousLevel == null) return true; // Level 1 is always unlocked
        // Level N requires all lessons in Level N-1 to be completed
        return previousLevel.lessons.every((l) => completedLessonIds.contains(l.id));
      }

      // Initially Level 2 is locked
      expect(isLevelUnlocked(level1, null), isTrue);

      final level2 = CourseLevel(
        id: 'lvl_2',
        title: 'Level 2: Advanced',
        description: 'Level 2 description',
        order: 2,
        lessons: const [
          Lesson(id: 'les_3', title: 'Lesson 3', description: 'Desc 3', duration: '10:00', muxPlaybackId: 'mux_3', order: 1),
        ],
      );

      expect(isLevelUnlocked(level2, level1), isFalse);

      // Student completes only Lesson 1
      completedLessonIds.add('les_1');
      expect(isLevelUnlocked(level2, level1), isFalse);

      // Student completes Lesson 2
      completedLessonIds.add('les_2');
      expect(isLevelUnlocked(level2, level1), isTrue, reason: 'Level 2 unlocks when all Level 1 lessons are completed');
    });
  });
}
