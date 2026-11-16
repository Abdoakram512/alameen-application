import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_directional_icons.dart';
import '../../../models/assignment.dart';

/// تبويب عرض المهام والتكليفات المعلقة المطلوب تسليمها من الطالب.
class PendingAssignmentsTabView extends StatelessWidget {
  final List<Assignment> assignments;
  final ValueChanged<Assignment> onOpenSubmit;

  const PendingAssignmentsTabView({
    super.key,
    required this.assignments,
    required this.onOpenSubmit,
  });

  @override
  Widget build(BuildContext context) {
    if (assignments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppDirectionalIcons.checkCircle(
                color: AppColors.success,
                size: 54,
              ),
              const SizedBox(height: 12),
              Text(
                'رائع! لا توجد تكليفات معلقة حالياً',
                style: AppTextStyles.heading3.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'لقد سلمت جميع التطبيقات العملية الخاصة بمحاضراتك حتى الآن.',
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
      itemCount: assignments.length,
      separatorBuilder: (ctx, idx) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final asg = assignments[i];
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
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      PhosphorIconsRegular.clipboardText,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          asg.title,
                          style: AppTextStyles.heading3.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          asg.courseTitle,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (asg.instructions.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(asg.instructions, style: AppTextStyles.bodyMedium),
              ],
              if (asg.hasAttachment) ...[
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                          asg.pdfAttachmentName ??
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
                          alignment: Alignment.center,
                        ),
                        icon: const Icon(Icons.download_rounded, size: 16),
                        label: const Text('فتح PDF'),
                        onPressed: () {
                          final uri = Uri.tryParse(asg.attachmentUrl);
                          if (uri != null) {
                            launchUrl(uri,
                                mode: LaunchMode.externalApplication);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    alignment: Alignment.center,
                    backgroundColor: AppColors.primary,
                  ),
                  onPressed: () => onOpenSubmit(asg),
                  icon: const Icon(Icons.upload_file_rounded, size: 18),
                  label: const Text('تسليم إجابة المهمة الآن'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
