import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_cached_image.dart';
import '../../../../models/assignment_submission.dart';
import '../../../../repositories/student_learning_repository.dart';

/// سجل التكليفات المسلّمة ودرجاتها وملاحظات المحاضرين (يدير الـ Stream بأمان خارج build).
class StudentSubmissionsSection extends StatefulWidget {
  final String? studentId;

  const StudentSubmissionsSection({super.key, required this.studentId});

  @override
  State<StudentSubmissionsSection> createState() =>
      _StudentSubmissionsSectionState();
}

class _StudentSubmissionsSectionState extends State<StudentSubmissionsSection> {
  Stream<List<AssignmentSubmission>>? _submissionsStream;

  StudentLearningRepository get _repository =>
      sl.isRegistered<StudentLearningRepository>()
          ? sl<StudentLearningRepository>()
          : StudentLearningRepositoryImpl();

  @override
  void initState() {
    super.initState();
    _bindStream();
  }

  @override
  void didUpdateWidget(StudentSubmissionsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.studentId != widget.studentId) {
      _bindStream();
    }
  }

  void _bindStream() {
    final id = widget.studentId;
    _submissionsStream = id != null && id.isNotEmpty
        ? _repository.streamStudentSubmissions(id)
        : null;
  }

  @override
  Widget build(BuildContext context) {
    if (_submissionsStream == null) return const SizedBox.shrink();

    return StreamBuilder<List<AssignmentSubmission>>(
      stream: _submissionsStream,
      builder: (context, snapshot) {
        final submissions = snapshot.data ?? const <AssignmentSubmission>[];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  PhosphorIconsRegular.clipboardText,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text('التكليفات والتقييمات', style: AppTextStyles.heading2),
              ],
            ),
            const SizedBox(height: 12),
            if (submissions.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.borderHairline),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLevel2,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(
                        PhosphorIconsRegular.fileText,
                        color: AppColors.textMuted,
                        size: 19,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'لم تقم بتسليم أي تكليفات عملية بعد. ستظهر تقييمات المحاضرين وملاحظاتهم هنا فور التسليم.',
                        style: AppTextStyles.bodyMedium,
                      ),
                    ),
                  ],
                ),
              )
            else
              for (int i = 0; i < submissions.length; i++) ...[
                _SubmissionTile(submission: submissions[i]),
                if (i < submissions.length - 1) const SizedBox(height: 10),
              ],
          ],
        );
      },
    );
  }
}

class _SubmissionTile extends StatelessWidget {
  final AssignmentSubmission submission;

  const _SubmissionTile({required this.submission});

  @override
  Widget build(BuildContext context) {
    final graded = submission.isGraded;
    final ratio = graded && submission.maxScore > 0
        ? ((submission.score ?? 0) / submission.maxScore).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderHairline),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  submission.assignmentTitle.isNotEmpty
                      ? submission.assignmentTitle
                      : 'تكليف تدريبي',
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
                  color: graded
                      ? AppColors.successLight
                      : AppColors.warningLight,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      graded
                          ? PhosphorIconsFill.sealCheck
                          : PhosphorIconsFill.hourglassMedium,
                      size: 13,
                      color: graded
                          ? AppColors.successDark
                          : AppColors.warningDark,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      graded
                          ? '${submission.score ?? 0} / ${submission.maxScore}'
                          : 'قيد المراجعة',
                      style: AppTextStyles.label.copyWith(
                        color: graded
                            ? AppColors.successDark
                            : AppColors.warningDark,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (graded && submission.maxScore > 0) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 5,
                backgroundColor: AppColors.surfaceLevel2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  ratio >= 0.7 ? AppColors.success : AppColors.primary,
                ),
              ),
            ),
          ],
          if (submission.adminFeedback.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: AppColors.scaffoldBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderHairline),
              ),
              child: Text(
                'تعليق المحاضر: ${submission.adminFeedback}',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
          if (submission.attachmentUrl.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                ),
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (ctx) => Dialog(
                      backgroundColor: Colors.white,
                      surfaceTintColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: 540,
                          maxHeight: 680,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                              child: Row(
                                children: [
                                  const Icon(
                                    PhosphorIconsRegular.paperclip,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'مرفق التكليف المرسل',
                                      style: AppTextStyles.heading3,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(PhosphorIconsRegular.x),
                                    onPressed: () => Navigator.pop(ctx),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            Flexible(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: InteractiveViewer(
                                  child: AppCachedImage(
                                    imageUrl: submission.attachmentUrl,
                                    fit: BoxFit.contain,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                icon: const Icon(PhosphorIconsRegular.image, size: 17),
                label: const Text('معاينة المرفق المرسل'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
