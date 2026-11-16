import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../models/assignment_submission.dart';
import 'grade_submission_dialog.dart';

/// بطاقة إدارة ومراجعة تكليفات المتدربين العملية داخل لوحة الإحصائيات.
class PendingSubmissionsGradingCard extends StatelessWidget {
  final List<AssignmentSubmission> submissions;

  const PendingSubmissionsGradingCard({
    super.key,
    required this.submissions,
  });

  @override
  Widget build(BuildContext context) {
    final pending = submissions.where((s) => !s.isGraded).toList();
    final recentItems = pending.isNotEmpty
        ? pending.take(6).toList()
        : submissions.take(4).toList();

    return Container(
      padding: const EdgeInsets.all(18),
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
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: pending.isNotEmpty
                      ? AppColors.warningLight
                      : AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  PhosphorIconsRegular.clipboardText,
                  color: pending.isNotEmpty
                      ? AppColors.warningDark
                      : AppColors.primary,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'التكليفات العملية وتقييمات المتدربين',
                      style: AppTextStyles.heading3.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      pending.isNotEmpty
                          ? 'يوجد ${pending.length} تكليف بانتظار المراجعة ورصد الدرجة'
                          : 'جميع التكليفات المرسلة تمت مراجعتها وتقييمها',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              if (pending.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warningLight,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${pending.length} بانتظار التقييم',
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.warningDark,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (recentItems.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.scaffoldBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderHairline),
              ),
              child: const Text(
                'لم يقم المتدربون بإرسال تكليفات عملية بعد. يمكنك إضافة تكليفات لأي دورة من شاشة إدارة مستويات الكورس.',
                style: AppTextStyles.bodyMedium,
              ),
            )
          else
            for (var i = 0; i < recentItems.length; i++) ...[
              _SubmissionReviewRow(submission: recentItems[i]),
              if (i < recentItems.length - 1) const Divider(height: 18),
            ],
        ],
      ),
    );
  }
}

class _SubmissionReviewRow extends StatelessWidget {
  final AssignmentSubmission submission;

  const _SubmissionReviewRow({required this.submission});

  @override
  Widget build(BuildContext context) {
    final graded = submission.isGraded;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                submission.assignmentTitle.isNotEmpty
                    ? submission.assignmentTitle
                    : 'تكليف تدريبي',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'المتدرب: ${submission.studentName} (${submission.studentEmail})',
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: graded ? AppColors.successDark : AppColors.primary,
            side: BorderSide(
              color: graded ? AppColors.successBorder : AppColors.borderHairline,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () => GradeSubmissionDialog.show(
            context,
            submission: submission,
          ),
          icon: Icon(
            graded
                ? PhosphorIconsRegular.pencilSimple
                : PhosphorIconsRegular.sealCheck,
            size: 16,
          ),
          label: Text(
            graded
                ? '${submission.score ?? 0}/${submission.maxScore}'
                : 'تقييم الآن',
          ),
        ),
      ],
    );
  }
}

