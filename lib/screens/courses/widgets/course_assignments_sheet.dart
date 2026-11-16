import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/assignment.dart';
import '../../../models/course.dart';
import '../../../services/firestore_service.dart';

/// نافذة إدارة التكليفات والتطبيقات العملية الخاصة بالدورة التدريبية.
class CourseAssignmentsSheet extends StatefulWidget {
  final Course course;

  const CourseAssignmentsSheet({super.key, required this.course});

  static Future<void> show(BuildContext context, {required Course course}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CourseAssignmentsSheet(course: course),
    );
  }

  @override
  State<CourseAssignmentsSheet> createState() => _CourseAssignmentsSheetState();
}

class _CourseAssignmentsSheetState extends State<CourseAssignmentsSheet> {
  late final Stream<List<Assignment>> _assignmentsStream;
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _instructionsController = TextEditingController();
  final _maxScoreController = TextEditingController(text: '100');
  bool _showCreateForm = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _assignmentsStream = FirestoreService().streamCourseAssignments(
      widget.course.id,
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _instructionsController.dispose();
    _maxScoreController.dispose();
    super.dispose();
  }

  Future<void> _createAssignment() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final maxScore = int.tryParse(_maxScoreController.text.trim()) ?? 100;
      final newAssignment = Assignment(
        id: 'asg_${DateTime.now().millisecondsSinceEpoch}',
        courseId: widget.course.id,
        courseTitle: widget.course.title,
        title: _titleController.text.trim(),
        instructions: _instructionsController.text.trim(),
        maxScore: maxScore.clamp(1, 1000),
        createdAt: DateTime.now(),
      );
      await FirestoreService().saveAssignment(newAssignment);
      if (!mounted) return;
      _titleController.clear();
      _instructionsController.clear();
      _maxScoreController.text = '100';
      setState(() {
        _saving = false;
        _showCreateForm = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم نشر التكليف العملي للمتدربين المشتركين بنجاح.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر حفظ التكليف، يرجى المحاولة مرة أخرى.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620, maxHeight: 720),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.borderHairline,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        width: 38,
                      height: 38,
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
                            'التكليفات العملية للدورة',
                            style: AppTextStyles.heading3.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            widget.course.title,
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => setState(
                        () => _showCreateForm = !_showCreateForm,
                      ),
                      icon: Icon(
                        _showCreateForm
                            ? PhosphorIconsRegular.caretUp
                            : PhosphorIconsRegular.plus,
                        size: 16,
                      ),
                      label: Text(_showCreateForm ? 'إخفاء' : 'تكليف جديد'),
                    ),
                  ],
                ),
                const Divider(height: 22),
                if (_showCreateForm) ...[
                  Form(
                    key: _formKey,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.scaffoldBackground,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.borderHairline),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _titleController,
                            decoration: const InputDecoration(
                              labelText: 'عنوان التكليف العملي',
                              hintText: 'مثال: إعداد خطة تأهيل لحالة تأخر لغوي',
                            ),
                            validator: (v) =>
                                (v == null || v.trim().length < 4)
                                    ? 'أدخل عنواناً واضحاً للتكليف'
                                    : null,
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _instructionsController,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'المطلوب ومعايير التقييم',
                              hintText:
                                  'اشرح للمتدرب الخطوات المطلوبة وطريقة رفع الحل...',
                            ),
                            validator: (v) =>
                                (v == null || v.trim().length < 6)
                                    ? 'أدخل وصف التكليف المطلوب'
                                    : null,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              SizedBox(
                                width: 130,
                                child: TextFormField(
                                  controller: _maxScoreController,
                                  keyboardType: TextInputType.number,
                                  textDirection: TextDirection.ltr,
                                  decoration: const InputDecoration(
                                    labelText: 'الدرجة العظمى',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: SizedBox(
                                  height: 46,
                                  child: FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                    ),
                                    onPressed:
                                        _saving ? null : _createAssignment,
                                    icon: _saving
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(
                                            PhosphorIconsRegular.paperPlaneTilt,
                                            size: 17,
                                          ),
                                    label: const Text('نشر التكليف'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                Flexible(
                  child: StreamBuilder<List<Assignment>>(
                    stream: _assignmentsStream,
                    builder: (context, snapshot) {
                      final items = snapshot.data ?? const <Assignment>[];
                      if (items.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 28),
                          child: Center(
                            child: Text(
                              'لا توجد تكليفات مضافة لهذا الكورس بعد. اضغط "تكليف جديد" لإضافة أول تطبيق عملي.',
                              style: AppTextStyles.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AppColors.borderHairline,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.title,
                                        style: AppTextStyles.bodyLarge.copyWith(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        item.instructions,
                                        style: AppTextStyles.bodyMedium,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'الدرجة العظمى: ${item.maxScore}',
                                        style: AppTextStyles.caption.copyWith(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'حذف التكليف',
                                  onPressed: () async {
                                    await FirestoreService().deleteAssignment(
                                      item.id,
                                    );
                                  },
                                  icon: const Icon(
                                    PhosphorIconsRegular.trash,
                                    color: AppColors.error,
                                    size: 19,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  }
}

