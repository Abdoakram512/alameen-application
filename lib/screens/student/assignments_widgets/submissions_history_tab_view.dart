import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/assignment_submission.dart';

/// تبويب سجل تسليمات المتدرب مع نتائج التقييم وملاحظات المحاضر.
class SubmissionsHistoryTabView extends StatelessWidget {
  final List<AssignmentSubmission> submissions;

  const SubmissionsHistoryTabView({super.key, required this.submissions});

  @override
  Widget build(BuildContext context) {
    if (submissions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                PhosphorIconsRegular.fileText,
                color: AppColors.textMuted,
                size: 54,
              ),
              const SizedBox(height: 12),
              Text(
                'لم تسلم أي تكليفات بعد',
                style: AppTextStyles.heading3.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'عند تسليم المهام العملية، ستظهر هنا درجات التقييم وملاحظات المحاضر بالتفصيل.',
                style: AppTextStyles.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: submissions.length,
      separatorBuilder: (ctx, idx) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final sub = submissions[i];
        final isGraded = sub.isGraded;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderHairline),
            boxShadow: AppColors.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isGraded
                          ? AppColors.successLight
                          : AppColors.warningLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isGraded
                          ? PhosphorIconsFill.checkCircle
                          : PhosphorIconsRegular.clock,
                      color: isGraded
                          ? AppColors.successDark
                          : AppColors.warningDark,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sub.assignmentTitle,
                          style: AppTextStyles.heading3.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'تاريخ التسليم: ${sub.submittedAt.year}/${sub.submittedAt.month.toString().padLeft(2, '0')}/${sub.submittedAt.day.toString().padLeft(2, '0')}',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: isGraded
                          ? AppColors.successLight
                          : AppColors.warningLight,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      isGraded
                          ? '${sub.score ?? 0} / ${sub.maxScore}'
                          : 'قيد المراجعة',
                      style: AppTextStyles.label.copyWith(
                        color: isGraded
                            ? AppColors.successDark
                            : AppColors.warningDark,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              if (sub.solutionText.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLevel2,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'إجابتك المسلّمة:',
                        style: AppTextStyles.caption.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        sub.solutionText,
                        style: AppTextStyles.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
              if (sub.attachmentUrl.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      PhosphorIconsRegular.paperclip,
                      size: 16,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'مرفق الحل:',
                      style: AppTextStyles.caption,
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () {
                        final uri = Uri.tryParse(sub.attachmentUrl);
                        if (uri != null) {
                          launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                      child: Text(
                        'عرض المرفق',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (sub.adminFeedback.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.successLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.successBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            PhosphorIconsRegular.chatCircleText,
                            color: AppColors.successDark,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'تقييم وملاحظات المحاضر:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.successDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        sub.adminFeedback,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.successDark,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
