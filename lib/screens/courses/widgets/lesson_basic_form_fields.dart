import 'package:flutter/material.dart';

import '../../../../core/utils/app_validators.dart';

/// حقول النموذج الأساسية لإضافة أو تعديل درس أو مهمة تطبيقية (النوع، العنوان، الوصف، المدة).
class LessonBasicFormFields extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final String itemType;
  final ValueChanged<String> onItemTypeChanged;
  final TextEditingController titleController;
  final TextEditingController descController;
  final TextEditingController durationController;

  const LessonBasicFormFields({
    super.key,
    required this.formKey,
    required this.itemType,
    required this.onItemTypeChanged,
    required this.titleController,
    required this.descController,
    required this.durationController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
              value: 'video',
              label: Text('درس فيديو'),
              icon: Icon(Icons.play_circle_outline_rounded),
            ),
            ButtonSegment(
              value: 'assignment',
              label: Text('مهمة / تكليف مستقل'),
              icon: Icon(Icons.assignment_outlined),
            ),
          ],
          selected: {itemType},
          onSelectionChanged: (set) => onItemTypeChanged(set.first),
        ),
        const SizedBox(height: 16),
        Form(
          key: formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: itemType == 'assignment'
                      ? 'عنوان المهمة التطبيقية *'
                      : 'عنوان الدرس *',
                  hintText: itemType == 'assignment'
                      ? 'مثال: تطبيق عملي على مخارج الحروف'
                      : 'مثال: جلسة علاج اللدغات والتأتأة',
                  border: const OutlineInputBorder(),
                  prefixIcon: Icon(
                    itemType == 'assignment'
                        ? Icons.assignment_outlined
                        : Icons.title,
                  ),
                ),
                validator: (val) => AppValidators.validateRequired(
                  val,
                  itemType == 'assignment' ? 'عنوان المهمة' : 'عنوان الدرس',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: descController,
                decoration: InputDecoration(
                  labelText: itemType == 'assignment'
                      ? 'وصف المهمة ومطلوب التنفيذ (اختياري)'
                      : 'وصف الدرس (اختياري)',
                  hintText: itemType == 'assignment'
                      ? 'اشرح للطالب المطلوب إنجازه بدقة'
                      : 'محاور الدرس وما تغطيه الجلسة',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.description_outlined),
                ),
              ),
              if (itemType == 'video') ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: durationController,
                  decoration: const InputDecoration(
                    labelText: 'مدة الفيديو (اختياري)',
                    hintText:
                        'تُحسب تلقائياً من Mux، أو أدخلها يدوياً (مثال: 15:30)',
                    helperText:
                        'إذا تُرك فارغاً، سيتم احتساب وقت الفيديو تلقائياً من خوادم البث',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.timer_outlined),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
