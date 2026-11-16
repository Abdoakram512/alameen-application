import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_validators.dart';
import '../../../models/assignment.dart';
import '../../../services/storage_service.dart';

/// حالة نموذج التكليف المرفق بالدرس (قابلة للاستماع لتحديث الواجهة).
class LessonAssignmentFormController extends ChangeNotifier {
  final titleController = TextEditingController();
  final instructionsController = TextEditingController();
  final maxScoreController = TextEditingController(text: '100');
  final attachmentUrlController = TextEditingController();
  String? pdfAttachmentName;
  bool isUploadingPdf = false;

  void setPdfAttachment({required String? name, required String? url}) {
    pdfAttachmentName = name;
    if (url != null) {
      attachmentUrlController.text = url;
    } else {
      attachmentUrlController.clear();
    }
    notifyListeners();
  }

  void setUploadingPdf(bool value) {
    isUploadingPdf = value;
    notifyListeners();
  }

  bool _enabled = false;
  AssignmentTiming _timing = AssignmentTiming.afterLesson;
  bool _blocksNextLesson = true;
  DateTime? _deadline;

  bool get enabled => _enabled;
  AssignmentTiming get timing => _timing;
  bool get blocksNextLesson => _blocksNextLesson;
  DateTime? get deadline => _deadline;

  set enabled(bool v) {
    _enabled = v;
    notifyListeners();
  }

  set timing(AssignmentTiming v) {
    _timing = v;
    notifyListeners();
  }

  set blocksNextLesson(bool v) {
    _blocksNextLesson = v;
    notifyListeners();
  }

  set deadline(DateTime? v) {
    _deadline = v;
    notifyListeners();
  }

  /// يعيد رسالة خطأ أو `null` إن كانت البيانات صحيحة.
  String? validate() {
    if (!_enabled) return null;
    if (titleController.text.trim().isEmpty) return 'يرجى إدخال عنوان التكليف';
    final score = int.tryParse(maxScoreController.text.trim());
    if (score == null || score <= 0) return 'الدرجة العظمى يجب أن تكون رقماً أكبر من صفر';
    return null;
  }

  /// يبني التكليف (بدون معرفات الدرس/الكورس؛ تُملأ عند الحفظ الذرّي).
  Assignment? build() {
    if (!_enabled) return null;
    return Assignment(
      id: '',
      courseId: '',
      courseTitle: '',
      title: titleController.text.trim(),
      instructions: instructionsController.text.trim(),
      maxScore: int.tryParse(maxScoreController.text.trim()) ?? 100,
      deadline: _deadline,
      createdAt: DateTime.now(),
      timing: _timing,
      attachmentUrl: attachmentUrlController.text.trim(),
      pdfAttachmentName: pdfAttachmentName,
      blocksNextLesson: _blocksNextLesson,
    );
  }

  @override
  void dispose() {
    titleController.dispose();
    instructionsController.dispose();
    maxScoreController.dispose();
    attachmentUrlController.dispose();
    super.dispose();
  }
}

/// قسم "إرفاق تكليف بهذا الدرس" داخل شاشة إضافة الدرس.
class LessonAssignmentForm extends StatelessWidget {
  final LessonAssignmentFormController controller;
  final bool enabled;
  final bool isStandalone;

  const LessonAssignmentForm({
    super.key,
    required this.controller,
    this.enabled = true,
    this.isStandalone = false,
  });

  Future<void> _pickDeadline(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: controller.deadline ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (picked != null) controller.deadline = picked;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceLevel0,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderHairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.assignment_outlined, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isStandalone
                          ? 'تفاصيل المهمة التطبيقية / التكليف'
                          : 'إرفاق تكليف بهذا الدرس',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ),
                  if (!isStandalone)
                    Switch(
                      value: controller.enabled,
                      activeTrackColor: AppColors.primary,
                      onChanged: enabled ? (v) => controller.enabled = v : null,
                    ),
                ],
              ),
              if (isStandalone || controller.enabled) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: controller.titleController,
                  enabled: enabled,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  decoration: const InputDecoration(
                    labelText: 'عنوان التكليف *',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.title),
                  ),
                  validator: (v) => controller.enabled
                      ? AppValidators.validateRequired(v, 'عنوان التكليف')
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: controller.instructionsController,
                  enabled: enabled,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'تعليمات التكليف (اختياري)',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.notes_rounded),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: controller.attachmentUrlController,
                  enabled: enabled,
                  decoration: const InputDecoration(
                    labelText: 'رابط ملف التكليف أو ورقة العمل (Drive / Dropbox) (اختياري)',
                    hintText: 'https://...',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.attachment_rounded),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.borderHairline),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.picture_as_pdf_rounded,
                        color: Color(0xFFDC2626),
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          controller.pdfAttachmentName != null
                              ? 'ملف PDF مرفق: ${controller.pdfAttachmentName}'
                              : 'إرفاق ملف ورقة عمل للتكليف (PDF)',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: controller.pdfAttachmentName != null
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: controller.pdfAttachmentName != null
                                ? const Color(0xFFDC2626)
                                : AppColors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (controller.pdfAttachmentName != null)
                        IconButton(
                          tooltip: 'إزالة الملف',
                          icon: const Icon(Icons.close_rounded,
                              size: 18, color: AppColors.error),
                          onPressed: enabled
                              ? () {
                                  controller.setPdfAttachment(
                                    name: null,
                                    url: null,
                                  );
                                }
                              : null,
                        )
                      else
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFDC2626),
                            side: const BorderSide(color: Color(0xFFDC2626)),
                            visualDensity: VisualDensity.compact,
                            alignment: Alignment.center,
                          ),
                          onPressed: enabled && !controller.isUploadingPdf
                              ? () async {
                                  final files = await FilePicker.pickFiles(
                                    type: FileType.custom,
                                    allowedExtensions: ['pdf'],
                                  );
                                  if (files.isNotEmpty &&
                                      files.first.path != null) {
                                    final file = File(files.first.path!);
                                    final name = files.first.name;
                                    controller.setUploadingPdf(true);
                                    try {
                                      final url = await StorageService()
                                          .uploadAssignmentAttachment(
                                        assignmentId:
                                            'asg_${DateTime.now().millisecondsSinceEpoch}',
                                        file: file,
                                        filename: name,
                                      );
                                      controller.setPdfAttachment(
                                        name: name,
                                        url: url,
                                      );
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                              content: Text(
                                                  'فشل رفع ملف الـ PDF: $e')),
                                        );
                                      }
                                    } finally {
                                      controller.setUploadingPdf(false);
                                    }
                                  }
                                }
                              : null,
                          icon: controller.isUploadingPdf
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2))
                              : const Icon(Icons.upload_file_rounded, size: 16),
                          label: Text(controller.isUploadingPdf
                              ? 'جاري الرفع...'
                              : 'رفع PDF'),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: controller.maxScoreController,
                  enabled: enabled,
                  keyboardType: TextInputType.number,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  decoration: const InputDecoration(
                    labelText: 'الدرجة العظمى',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.scoreboard_outlined),
                  ),
                  validator: (v) {
                    if (!controller.enabled) return null;
                    final n = int.tryParse(AppValidators.normalizeDigits(v));
                    if (n == null || n <= 0) {
                      return 'أدخل درجة عظمى صحيحة أكبر من صفر';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                const Text(
                  'توقيت ظهور التكليف',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                ),
                const SizedBox(height: 6),
                SegmentedButton<AssignmentTiming>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: AssignmentTiming.duringLesson,
                      label: Text('مع الدرس'),
                    ),
                    ButtonSegment(
                      value: AssignmentTiming.afterLesson,
                      label: Text('بعد الدرس'),
                    ),
                  ],
                  selected: {controller.timing},
                  onSelectionChanged:
                      enabled ? (s) => controller.timing = s.first : null,
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: enabled ? () => _pickDeadline(context) : null,
                  icon: const Icon(Icons.event_outlined),
                  label: Text(
                    controller.deadline == null
                        ? 'تحديد موعد نهائي (اختياري)'
                        : 'الموعد النهائي: ${controller.deadline!.year}/${controller.deadline!.month}/${controller.deadline!.day}',
                  ),
                ),
                if (controller.deadline != null)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton(
                      onPressed: enabled ? () => controller.deadline = null : null,
                      child: const Text('إزالة الموعد'),
                    ),
                  ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeTrackColor: AppColors.primary,
                  title: const Text('إلزامي لفتح الدرس التالي'),
                  subtitle: const Text(
                    'لا يُفتح الدرس التالي للطالب قبل تسليم هذا التكليف',
                  ),
                  value: controller.blocksNextLesson,
                  onChanged:
                      enabled ? (v) => controller.blocksNextLesson = v : null,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

