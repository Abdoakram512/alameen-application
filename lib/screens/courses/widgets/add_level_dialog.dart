import 'dart:async';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_validators.dart';
import '../../../logic/courses/admin_courses_cubit.dart';
import '../../../models/course_level.dart';

class AddLevelDialog extends StatefulWidget {
  final String courseId;
  final int currentLevelsCount;

  const AddLevelDialog({
    super.key,
    required this.courseId,
    required this.currentLevelsCount,
  });

  static Future<void> show(
    BuildContext context, {
    required String courseId,
    required int currentLevelsCount,
  }) {
    return showDialog(
      context: context,
      builder: (_) => BlocProvider.value(
        value: context.read<AdminCoursesCubit>(),
        child: AddLevelDialog(
          courseId: courseId,
          currentLevelsCount: currentLevelsCount,
        ),
      ),
    );
  }

  @override
  State<AddLevelDialog> createState() => _AddLevelDialogState();
}

class _AddLevelDialogState extends State<AddLevelDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  bool _isSaving = false;

  String _tr(String key, String fallback) {
    try {
      final res = key.tr();
      return (res == key) ? fallback : res;
    } catch (_) {
      return fallback;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    if (_isSaving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final title = _titleController.text.trim();
    final order = widget.currentLevelsCount + 1;
    final newLevel = CourseLevel(
      id: 'lvl_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      description: _descController.text.trim(),
      order: order,
      lessons: [],
    );
    setState(() => _isSaving = true);
    final cubit = context.read<AdminCoursesCubit>();
    // إغلاق النافذة فوراً لتجربة مستخدم سلسة وفورية دون تعليق
    Navigator.of(context).pop();
    unawaited(cubit.addLevel(widget.courseId, newLevel));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 520),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.royalNavy.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.layers_rounded,
                      color: AppColors.royalNavy,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _tr('levels.add_level_title', 'إضافة مستوى جديد للكورس'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    tooltip: _tr('dialogs.cancel', 'إلغاء'),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.divider),
              const SizedBox(height: 16),

              // Fields
              Flexible(
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _titleController,
                          decoration: InputDecoration(
                            labelText: '${_tr('levels.level_title', 'اسم المستوى')} *',
                            hintText: _tr('levels.level_title_hint', 'مثال: المستوى الثاني: إدارة وتأهيل الحالة المتقدمة'),
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.title, size: 20),
                          ),
                          validator: (val) => AppValidators.validateRequired(
                            val,
                            _tr('levels.level_title', 'اسم المستوى'),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _descController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: _tr('levels.level_desc', 'وصف المستوى (اختياري)'),
                            hintText: _tr('levels.level_desc_hint', 'ما الذي سيتعلمه الطالب في هذا المستوى'),
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.notes, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              const Divider(height: 1, color: AppColors.divider),
              const SizedBox(height: 12),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(_tr('dialogs.cancel', 'إلغاء')),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.royalNavy,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _isSaving ? null : _onSave,
                    child: Text(
                      _isSaving
                          ? _tr('levels.saving', 'جاري الحفظ...')
                          : _tr('levels.add_level_btn', 'إضافة المستوى'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
