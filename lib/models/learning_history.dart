import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'course.dart';
import 'lesson.dart';

final learningHistoryRevision = ValueNotifier<int>(0);

List<Lesson> orderedLessons(Course course) {
  final levels = [...course.levels]..sort((a, b) => a.order.compareTo(b.order));
  return levels
      .expand(
        (level) =>
            [...level.lessons]..sort((a, b) => a.order.compareTo(b.order)),
      )
      .toList();
}

class RecentLesson {
  final String courseId, lessonId;
  final int positionMs;
  const RecentLesson({
    required this.courseId,
    required this.lessonId,
    required this.positionMs,
  });
  String encode() => jsonEncode({
    'courseId': courseId,
    'lessonId': lessonId,
    'positionMs': positionMs,
  });
  static RecentLesson? decode(String? value) {
    if (value == null) return null;
    try {
      final data = jsonDecode(value) as Map<String, dynamic>;
      if (data['courseId'] is! String ||
          data['lessonId'] is! String ||
          data['positionMs'] is! int) {
        return null;
      }
      return RecentLesson(
        courseId: data['courseId'],
        lessonId: data['lessonId'],
        positionMs: (data['positionMs'] as int).clamp(0, 2147483647),
      );
    } catch (_) {
      return null;
    }
  }
}
