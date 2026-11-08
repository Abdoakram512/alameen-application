import 'package:flutter/material.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../models/assignment.dart';
import '../../../../models/assignment_submission.dart';
import '../../../../repositories/student_learning_repository.dart';

/// قسم التكليفات العملية للدورة مع عرض حالة التسليم ودرجة التقييم وملاحظات المحاضر.
class CourseAssignmentsSection extends StatefulWidget {
  final String courseId;
  final String? studentId;
  final bool isEnrolled;
  final ValueChanged<Assignment> onSubmitTap;

  const CourseAssignmentsSection({
    super.key,
    required this.courseId,
    required this.studentId,
    required this.isEnrolled,
    required this.onSubmitTap,
  });

  @override
  State<CourseAssignmentsSection> createState() =>
      _CourseAssignmentsSectionState();
}

class _CourseAssignmentsSectionState extends State<CourseAssignmentsSection> {
  late Stream<List<Assignment>> _assignmentsStream;
  Stream<List<AssignmentSubmission>>? _submissionsStream;

  StudentLearningRepository get _repository =>
      sl.isRegistered<StudentLearningRepository>()
          ? sl<StudentLearningRepository>()
          : StudentLearningRepositoryImpl();

  @override
  void initState() {
    super.initState();
    _bindStreams();
  }

  @override
  void didUpdateWidget(CourseAssignmentsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.courseId != widget.courseId ||
        oldWidget.studentId != widget.studentId) {
      _bindStreams();
    }
  }

  void _bindStreams() {
    _assignmentsStream = _repository.streamCourseAssignments(widget.courseId);
    _submissionsStream = widget.studentId != null
        ? _repository.streamStudentSubmissions(widget.studentId!)
        : null;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Assignment>>(
      stream: _assignmentsStream,
      builder: (context, snapshot) {
        final assignments = snapshot.data ?? const <Assignment>[];
        if (assignments.isEmpty) return const SizedBox.shrink();

        return StreamBuilder<List<AssignmentSubmission>>(
          stream: _submissionsStream,
          builder: (context, subSnap) {
            final submissions = subSnap.data ?? const <AssignmentSubmission>[];
            final byAssignment = <String, AssignmentSubmission>{
              for (final s in submissions) s.assignmentId: s,
            };

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                Text(
                  'التكليفات والتطبيقات العملية',
                  style: AppTextStyles.heading2,
                ),
                const SizedBox(height: 12),
                for (int i = 0; i < assignments.length; i++) ...[
                  _AssignmentItemCard(
                    assignment: assignments[i],
                    submission: byAssignment[assignments[i].id],
                    isEnrolled: widget.isEnrolled,
                    onSubmitTap: () => widget.onSubmitTap(assignments[i]),
                  ),
                  if (i < assignments.length - 1) const SizedBox(height: 12),
                ],
              ],
            );
          },
        );
      },
    );
  }
}

class _AssignmentItemCard extends StatelessWidget {
  final Assignment assignment;
  final AssignmentSubmission? submission;
  final bool isEnrolled;
  final VoidCallback onSubmitTap;

  const _AssignmentItemCard({
    required this.assignment,
    required this.submission,
    required this.isEnrolled,
    required this.onSubmitTap,
  });

  @override
  Widget build(BuildContext context) {
    final isGraded = submission?.isGraded ?? false;
    final hasSubmitted = submission != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.assignment_outlined,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  assignment.title,
                  style: AppTextStyles.heading3.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isGraded
                      ? AppColors.successLight
                      : hasSubmitted
                          ? AppColors.warningLight
                          : AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isGraded
                      ? '${submission!.score ?? 0} / ${assignment.maxScore}'
                      : hasSubmitted
                          ? 'قيد التقييم'
                          : '${assignment.maxScore} درجة',
                  style: AppTextStyles.label.copyWith(
                    color: isGraded
                        ? AppColors.successDark
                        : hasSubmitted
                            ? AppColors.warningDark
                            : AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          if (assignment.instructions.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(assignment.instructions, style: AppTextStyles.bodyMedium),
          ],
          if (submission != null &&
              submission!.adminFeedback.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'ملاحظات المحاضر: ${submission!.adminFeedback}',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.successDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          if (isEnrolled && !isGraded) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: onSubmitTap,
                icon: const Icon(Icons.upload_outlined, size: 18),
                label: Text(
                  hasSubmitted ? 'تحديث التسليم' : 'تسليم التكليف',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

