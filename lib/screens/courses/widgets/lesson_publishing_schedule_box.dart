import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// بطاقة إدارة حالة النشر وموعد جدولة إتاحة المحاضرة للطلاب.
class LessonPublishingScheduleBox extends StatelessWidget {
  final String publishOption;
  final ValueChanged<String> onPublishOptionChanged;
  final DateTime? scheduledDateTime;
  final VoidCallback onPickScheduleDateTime;

  const LessonPublishingScheduleBox({
    super.key,
    required this.publishOption,
    required this.onPublishOptionChanged,
    required this.scheduledDateTime,
    required this.onPickScheduleDateTime,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceLevel0,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.schedule_send_rounded,
                size: 18,
                color: AppColors.primary,
              ),
              SizedBox(width: 8),
              Text(
                'حالة النشر وموعد المحاضرة',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'يمكنك رفع المحاضرة ونشرها فوراً، أو جدولتها لتُتاح للطلاب تلقائياً في موعد الدرس، أو حفظها كمسودة.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: 'immediate',
                label: Text(
                  'نشر فوري',
                  style: TextStyle(fontSize: 12),
                ),
                icon: Icon(Icons.check_circle_outline, size: 16),
              ),
              ButtonSegment(
                value: 'schedule',
                label: Text(
                  'جدولة بموعد',
                  style: TextStyle(fontSize: 12),
                ),
                icon: Icon(Icons.access_time_rounded, size: 16),
              ),
              ButtonSegment(
                value: 'draft',
                label: Text(
                  'مسودة (مغلق)',
                  style: TextStyle(fontSize: 12),
                ),
                icon: Icon(Icons.drafts_outlined, size: 16),
              ),
            ],
            selected: {publishOption},
            onSelectionChanged: (set) => onPublishOptionChanged(set.first),
          ),
          if (publishOption == 'schedule') ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.royalNavy.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.event_available,
                    color: AppColors.royalNavy,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'موعد إتاحة المحاضرة للطلاب:',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          scheduledDateTime != null
                              ? '${scheduledDateTime!.year}/${scheduledDateTime!.month.toString().padLeft(2, '0')}/${scheduledDateTime!.day.toString().padLeft(2, '0')} - ${scheduledDateTime!.hour.toString().padLeft(2, '0')}:${scheduledDateTime!.minute.toString().padLeft(2, '0')}'
                              : 'لم يتم تحديد الموعد بعد',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppColors.royalNavy,
                          ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: onPickScheduleDateTime,
                    icon: const Icon(Icons.edit_calendar, size: 15),
                    label: const Text(
                      'تحديد الموعد',
                      style: TextStyle(fontSize: 11),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
