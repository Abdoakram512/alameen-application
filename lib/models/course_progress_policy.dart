import 'course.dart';
import 'course_level.dart';
import 'lesson.dart';

/// سياسة التقدم والفتح المتسلسل للمستويات والدروس:
/// 1. اشتراك الدورة يُفتح المستوى الأول فقط وفق صلاحيات الخادم.
/// 2. فتح المستويات يخضع لقرار Laravel الموثق فقط.
/// 3. المعاينة المجانية (`isFreePreview`) تظل متاحة للمعاينة (ويظل التحقق النهائي بالخادم عند الفتح).
/// 4. لا يُسمح مطلقاً بتجاوز أقفال الخادم عبر تعديل الحالة المحلية.
class CourseProgressPolicy {
  const CourseProgressPolicy._();

  static const double strictLevelThresholdPercent = 95.0;

  /// يحسب نسبة الإكمال المئوية (0.0 إلى 100.0) للمستوى المحدد.
  static double levelCompletionPercentage(
    CourseLevel level, {
    required Set<String> completedLessonIds,
  }) {
    if (level.lessons.isEmpty) return 100.0;

    final videoOrTaskLessons = level.lessons;
    int completedCount = 0;
    for (final lesson in videoOrTaskLessons) {
      if (lesson.isCompleted || completedLessonIds.contains(lesson.id)) {
        completedCount++;
      }
    }
    return ((completedCount / videoOrTaskLessons.length) * 100.0).clamp(
      0.0,
      100.0,
    );
  }

  /// يتحقق مما إذا كان المستوى عند الفهرس [levelIndex] مفتوحاً أم لا.
  static bool isLevelUnlocked({
    required List<CourseLevel> levels,
    required int levelIndex,
    required bool isEnrolled,
    required Set<String> completedLessonIds,
  }) {
    if (levelIndex < 0 || levelIndex >= levels.length) return false;
    final level = levels[levelIndex];

    // الطالب غير المسجل لا يملك صلاحية فتح أي مستوى بالدورة
    if (!isEnrolled) {
      return false;
    }

    // خادم Laravel هو المصدر الحاكم: المستوى لا يفتح مطلقاً إذا كان الخادم يغلقه
    if (!level.isAccessible) {
      return false;
    }

    return true; // Authenticated Laravel access is authoritative.
  }

  /// البحث عن فهرس المستوى الذي يحتوي على [lessonId].
  static int findLevelIndexForLesson(
    List<CourseLevel> levels,
    String lessonId,
  ) {
    for (int i = 0; i < levels.length; i++) {
      if (levels[i].lessons.any((l) => l.id == lessonId)) {
        return i;
      }
    }
    return -1;
  }

  /// يعيد سبب قفل الدرس إن وُجد، أو null إذا كان متاحاً للفتح.
  static String? lessonLockReason({
    required List<CourseLevel> levels,
    required Lesson lesson,
    required bool isEnrolled,
    required Set<String> completedLessonIds,
    List<int> accessibleVideoIds = const [],
    bool enforceServerAccessibleList = false,
    Map<String, String> assignmentLockReasons = const {},
  }) {
    if (!lesson.isAvailableNow) {
      return 'هذه المحاضرة غير متاحة حالياً.';
    }

    if (assignmentLockReasons.containsKey(lesson.id)) {
      return 'يتطلب تسليم تكليف: ${assignmentLockReasons[lesson.id]}';
    }

    // المعاينة المجانية تخضع لقواعد الخادم عند البث، ولا تُقفل بقيود شراء الدورة أو المستويات
    if (lesson.isFreePreview && lesson.isAccessible) {
      return null;
    }

    if (!isEnrolled) {
      return 'يتطلب الاشتراك في الدورة وتفعيل الوصول من الإدارة.';
    }

    // احترام قائمة المعرفات المسموحة من الخادم عند توفرها صراحةً من الخادم
    if (enforceServerAccessibleList) {
      final numericId = int.tryParse(lesson.id);
      if (numericId != null && !accessibleVideoIds.contains(numericId)) {
        return 'هذه المحاضرة مقفلة حالياً على الخادم.';
      }
    }

    // احترام قفل الدرس على الخادم
    if (!lesson.isAccessible) {
      return 'هذه المحاضرة مقفلة حتى اعتماد التقدم من الخادم.';
    }

    final lvlIdx = findLevelIndexForLesson(levels, lesson.id);
    if (lvlIdx >= 0) {
      final levelUnlocked = isLevelUnlocked(
        levels: levels,
        levelIndex: lvlIdx,
        isEnrolled: isEnrolled,
        completedLessonIds: completedLessonIds,
      );
      if (!levelUnlocked) {
        return 'هذا المستوى مغلق حالياً.';
      }
    }

    return null;
  }

  /// حساب مجموعة المعرّفات المكتملة الموحدة بين نموذج الطالب ونموذج الدورة من الخادم.
  static Set<String> effectiveCompletedLessonIds({
    required Course course,
    Set<String> userCompletedLessonIds = const {},
  }) {
    final merged = <String>{...userCompletedLessonIds};
    for (final id in course.completedVideoIds) {
      merged.add(id.toString());
    }
    for (final lvl in course.levels) {
      for (final lesson in lvl.lessons) {
        if (lesson.isCompleted) {
          merged.add(lesson.id);
        }
      }
    }
    return merged;
  }
}
