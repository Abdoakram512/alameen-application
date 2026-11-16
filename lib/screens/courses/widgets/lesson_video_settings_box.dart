import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// إعدادات الفيديو الإضافية للدرس (معاينة مجانية، نسبة إكمال المشاهدة المطلوبة).
class LessonVideoSettingsBox extends StatelessWidget {
  final bool isFreePreview;
  final ValueChanged<bool> onFreePreviewChanged;
  final int completionThreshold;
  final ValueChanged<int> onCompletionThresholdChanged;

  const LessonVideoSettingsBox({
    super.key,
    required this.isFreePreview,
    required this.onFreePreviewChanged,
    required this.completionThreshold,
    required this.onCompletionThresholdChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          title: const Text('إتاحة معاينة مجانية للدرس'),
          subtitle: const Text(
            'يسمح للمتدرب بمشاهدة هذا الدرس التعريفي قبل الاشتراك',
          ),
          value: isFreePreview,
          activeTrackColor: AppColors.primary,
          contentPadding: EdgeInsets.zero,
          onChanged: onFreePreviewChanged,
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceLevel0,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderHairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'نسبة المشاهدة المطلوبة لاجتياز الدرس:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$completionThreshold%',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'الحد الأدنى لنسبة إتمام مشاهدة الفيديو لاحتساب الدرس ومطابقة استحقاق الشهادة (المعتمد 95%).',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              Slider(
                value: completionThreshold.toDouble(),
                min: 50,
                max: 100,
                divisions: 10,
                label: '$completionThreshold%',
                activeColor: AppColors.primary,
                onChanged: (val) => onCompletionThresholdChanged(val.round()),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
