import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../models/assignment.dart';
import '../../../../models/assignment_submission.dart';
import '../../../../repositories/student_assignments_repository.dart';
import '../../../../models/clinical_task_data.dart';

/// قسم التكليفات العملية للدورة مع عرض حالة التسليم ودرجة التقييم وملاحظات المحاضر.
class CourseAssignmentsSection extends StatefulWidget {
  final String courseId;
  final String? studentId;
  final bool isEnrolled;
  final Future<void> Function(Assignment) onSubmitTap;
  final StudentAssignmentsRepository? repository;

  const CourseAssignmentsSection({
    super.key,
    required this.courseId,
    required this.studentId,
    required this.isEnrolled,
    required this.onSubmitTap,
    this.repository,
  });

  @override
  State<CourseAssignmentsSection> createState() =>
      _CourseAssignmentsSectionState();
}

class _CourseAssignmentsSectionState extends State<CourseAssignmentsSection> {
  late Future<StudentAssignmentsData> _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(CourseAssignmentsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.courseId != widget.courseId ||
        oldWidget.studentId != widget.studentId ||
        oldWidget.isEnrolled != widget.isEnrolled) {
      _load();
    }
  }

  void _load() {
    _data = widget.studentId == null || !widget.isEnrolled
        ? Future.value(const StudentAssignmentsData())
        : (widget.repository ?? sl<StudentAssignmentsRepository>()).getAssignments();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<StudentAssignmentsData>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return TextButton(
            onPressed: () => setState(_load),
            child: const Text('تعذر تحميل التكليفات. اضغط لإعادة المحاولة'),
          );
        }
        final data = snapshot.data ?? const StudentAssignmentsData();
        final tasks = data.tasks.where((t) => t.courseId == widget.courseId);
        final submissions = {
          for (final s in data.submissions) s.assignmentId: s,
        };
        return Column(
          children: [
            for (final task in tasks)
              _AssignmentItemCard(
                assignment: task,
                submission: submissions[task.id],
                isEnrolled: widget.isEnrolled,
                onSubmitTap: () async {
                  await widget.onSubmitTap(task);
                  if (mounted) setState(_load);
                },
              ),
          ],
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
          if (assignment.hasAttachment) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.picture_as_pdf_rounded,
                    color: Color(0xFFDC2626),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      assignment.pdfAttachmentName ??
                          'ملف ورقة عمل التكليف (PDF)',
                      style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF991B1B),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      alignment: Alignment.center,
                    ),
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: const Text('فتح PDF'),
                    onPressed: () {
                      final uri = Uri.tryParse(assignment.attachmentUrl);
                      if (uri != null) {
                        launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                ],
              ),
            ),
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
                label: Text(hasSubmitted ? 'تحديث التسليم' : 'تسليم التكليف'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
