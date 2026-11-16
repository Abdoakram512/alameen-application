import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/student_avatar.dart';
import '../../../../models/assignment_submission.dart';

/// بطاقة عرض تسليم الواجب أو التكليف العملي للمتدرب مع تفاصيل الحل وزر التقييم.
class AssignmentSubmissionCard extends StatelessWidget {
  final AssignmentSubmission submission;
  final String courseTitle;
  final bool isAr;
  final VoidCallback onGrade;

  const AssignmentSubmissionCard({
    super.key,
    required this.submission,
    required this.courseTitle,
    required this.isAr,
    required this.onGrade,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy/MM/dd - hh:mm a');
    final formattedDate = dateFormat.format(submission.submittedAt);
    final hasAttachment = submission.attachmentUrl.trim().isNotEmpty;
    final isGraded = submission.isGraded;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGraded ? AppColors.borderHairline : AppColors.warningBorder,
          width: isGraded ? 1 : 1.5,
        ),
        boxShadow: AppColors.cardShadow,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Student Info Row & Status Badge
          Row(
            children: [
              StudentAvatar(
                name: submission.studentName,
                radius: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      submission.studentName.isNotEmpty
                          ? submission.studentName
                          : (isAr ? 'متدرب' : 'Student'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (submission.studentEmail.isNotEmpty)
                      Text(
                        submission.studentEmail,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              // Status Badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isGraded
                      ? AppColors.successLight
                      : AppColors.warningLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isGraded
                        ? AppColors.successBorder
                        : AppColors.warningBorder,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isGraded
                          ? PhosphorIconsFill.sealCheck
                          : PhosphorIconsFill.hourglassMedium,
                      color: isGraded
                          ? AppColors.successDark
                          : AppColors.warningDark,
                      size: 14,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isGraded
                          ? '${submission.score ?? 0} / ${submission.maxScore}'
                          : (isAr ? 'قيد المراجعة' : 'Pending'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isGraded
                            ? AppColors.successDark
                            : AppColors.warningDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 20, color: AppColors.borderHairline),

          // Course and Task Info
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceLevel0,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderHairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      PhosphorIconsRegular.graduationCap,
                      size: 15,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        courseTitle,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    Text(
                      formattedDate,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      PhosphorIconsRegular.bookmarkSimple,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${isAr ? "التكليف: " : "Task: "}${submission.assignmentTitle.isNotEmpty ? submission.assignmentTitle : (isAr ? "مهمة تدريبية" : "Assignment")}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Student Solution Text
          if (submission.solutionText.trim().isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderHairline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isAr
                            ? 'إجابة وحل المتدرب:'
                            : 'Student Submission Text:',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        tooltip: isAr ? 'نسخ النص' : 'Copy',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: submission.solutionText),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(isAr ? 'تم نسخ نص الإجابة' : 'Copied'),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    submission.solutionText,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Attachment Button
          if (hasAttachment) ...[
            SizedBox(
              height: 38,
              child: OutlinedButton.icon(
                icon: const Icon(PhosphorIconsRegular.paperclip, size: 16),
                label: Text(
                  isAr ? 'معاينة المرفق أو الملف' : 'View Attachment',
                  style: const TextStyle(fontSize: 12.5),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () async {
                  final uri = Uri.tryParse(submission.attachmentUrl);
                  if (uri != null) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Admin Evaluation & Feedback Box (if already graded)
          if (isGraded || submission.adminFeedback.trim().isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        PhosphorIconsFill.star,
                        size: 16,
                        color: Color(0xFF15803D),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${isAr ? "الدرجة المرصودة: " : "Score: "}${submission.score ?? 0} / ${submission.maxScore}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF15803D),
                        ),
                      ),
                    ],
                  ),
                  if (submission.adminFeedback.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      '${isAr ? "ملاحظة التوجيه: " : "Feedback: "}${submission.adminFeedback}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF166534),
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Grade / Evaluate Action Button
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor:
                    isGraded ? AppColors.secondary : AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: Icon(
                isGraded
                    ? PhosphorIconsRegular.pencilSimple
                    : PhosphorIconsRegular.checkCircle,
                size: 16,
              ),
              label: Text(
                isGraded
                    ? (isAr ? 'تعديل الدرجة والتقييم' : 'Update Grade')
                    : (isAr ? 'تصحيح ورصد الدرجة' : 'Grade Submission'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: onGrade,
            ),
          ),
        ],
      ),
    );
  }
}
