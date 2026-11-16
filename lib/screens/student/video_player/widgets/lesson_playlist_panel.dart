import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../logic/auth/auth_cubit.dart';
import '../../../../logic/auth/auth_state.dart';
import '../../../../models/course_access_mode.dart';
import '../../../../models/lesson.dart';
import '../../lesson_playlist.dart';

/// لوحة قائمة دروس الدورة التدريبية مع إدارة قيود الفتح المتسلسل واشتراطات تسليم الواجبات.
class LessonPlaylistPanel extends StatelessWidget {
  final List<Lesson> playlist;
  final String currentLessonId;
  final String courseId;
  final CourseAccessMode courseAccessMode;
  final Set<String> submittedAssignmentIds;
  final ValueChanged<Lesson> onSelectLesson;

  const LessonPlaylistPanel({
    super.key,
    required this.playlist,
    required this.currentLessonId,
    required this.courseId,
    required this.courseAccessMode,
    required this.submittedAssignmentIds,
    required this.onSelectLesson,
  });

  /// حساب أسباب حجب الدروس اللاحقة عند اشتراط تسليم واجب الدرس الحالي
  Map<String, String> get lockedReasons {
    final reasons = <String, String>{};
    String? blockingLessonTitle;

    for (int i = 0; i < playlist.length; i++) {
      final item = playlist[i];

      if (blockingLessonTitle != null) {
        reasons[item.id] = blockingLessonTitle;
        continue;
      }

      final requiresSubmission = item.isAssignmentLesson ||
          (item.lockNextUntilSubmitted && item.hasAssignment);
      final assignmentKey = (item.assignmentId != null &&
              item.assignmentId!.isNotEmpty)
          ? item.assignmentId!
          : 'asg_${item.id}';
      final isSubmitted = submittedAssignmentIds.contains(assignmentKey) ||
          submittedAssignmentIds.contains(item.id) ||
          (item.assignmentId != null &&
              submittedAssignmentIds.contains(item.assignmentId));

      if (requiresSubmission && !isSubmitted) {
        blockingLessonTitle = item.title;
      }
    }
    return reasons;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        final user = state is Authenticated ? state.user : null;
        final isEnrolled = (user?.isEnrolled(courseId) ?? false) ||
            courseAccessMode == CourseAccessMode.open;

        return LessonPlaylist(
          lessons: playlist,
          selectedId: currentLessonId,
          enrolled: isEnrolled,
          completedIds: {
            ...?user?.completedLessonIds,
          },
          lockedReasons: lockedReasons,
          onSelected: onSelectLesson,
        );
      },
    );
  }
}
