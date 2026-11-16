import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/app_validators.dart';
import '../../../../core/widgets/dialogs/receipt_preview_dialog.dart';
import '../../../../models/assignment_submission.dart';
import '../../../../services/firestore_service.dart';

/// نافذة تقييم التكليف العملي للمتدرب وإرسال الدرجة والملاحظات فوراً.
class GradeSubmissionDialog extends StatefulWidget {
  final AssignmentSubmission submission;

  const GradeSubmissionDialog({super.key, required this.submission});

  static Future<void> show(
    BuildContext context, {
    required AssignmentSubmission submission,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => GradeSubmissionDialog(submission: submission),
    );
  }

  @override
  State<GradeSubmissionDialog> createState() => _GradeSubmissionDialogState();
}

class _GradeSubmissionDialogState extends State<GradeSubmissionDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _scoreController;
  late final TextEditingController _feedbackController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final initialScore = widget.submission.score ?? widget.submission.maxScore;
    _scoreController = TextEditingController(text: '$initialScore');
    _feedbackController = TextEditingController(
      text: widget.submission.adminFeedback,
    );
  }

  @override
  void dispose() {
    _scoreController.dispose();
    _feedbackController.dispose();
    super.dispose();
  }

  void _applyPercentage(double ratio) {
    final computed = (widget.submission.maxScore * ratio).round();
    setState(() {
      _scoreController.text = '$computed';
    });
  }

  Future<void> _submitGrade() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final parsedScore = int.parse(_scoreController.text.trim());
    setState(() => _saving = true);
    try {
      await FirestoreService().gradeSubmission(
        submissionId: widget.submission.id,
        score: parsedScore,
        adminFeedback: _feedbackController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم رصد الدرجة ($parsedScore/${widget.submission.maxScore}) للمتدرب ${widget.submission.studentName}',
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر حفظ التقييم، يرجى التحقق من الاتصال والمحاولة.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sub = widget.submission;

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                        PhosphorIconsRegular.sealCheck,
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
                            'تقييم تكليف المتدرب',
                            style: AppTextStyles.heading3.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${sub.studentName} • ${sub.assignmentTitle.isNotEmpty ? sub.assignmentTitle : "تكليف عملي"}',
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(PhosphorIconsRegular.x, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.scaffoldBackground,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.borderHairline),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('إجابة المتدرب المرسلة:', style: AppTextStyles.label),
                      const SizedBox(height: 6),
                      Text(
                        sub.solutionText.trim().isNotEmpty
                            ? sub.solutionText
                            : 'تم إرسال مرفق بدون نص إضافي.',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (sub.attachmentUrl.trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () => ReceiptPreviewDialog.show(
                            context,
                            imageUrl: sub.attachmentUrl,
                          ),
                          icon: const Icon(PhosphorIconsRegular.image, size: 16),
                          label: const Text('فتح ومعاينة المرفق المرسل'),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'الدرجة المستحقة (من ${sub.maxScore})',
                      style: AppTextStyles.label,
                    ),
                    Wrap(
                      spacing: 6,
                      children: [
                        for (final preset in const [1.0, 0.9, 0.8, 0.7])
                          ActionChip(
                            visualDensity: VisualDensity.compact,
                            label: Text('${(preset * 100).round()}%'),
                            onPressed: () => _applyPercentage(preset),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _scoreController,
                  keyboardType: TextInputType.number,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    suffixText: '/ ${sub.maxScore}',
                    prefixIcon: const Icon(PhosphorIconsRegular.exam, size: 19),
                  ),
                  validator: (val) {
                    final norm = AppValidators.normalizeDigits(val);
                    final parsed = int.tryParse(norm);
                    if (parsed == null || parsed < 0 || parsed > sub.maxScore) {
                      return 'أدخل درجة صحيحة بين 0 و ${sub.maxScore}';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                const Text('ملاحظات المحاضر للمتدرب (اختياري)', style: AppTextStyles.label),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _feedbackController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText:
                        'اكتب توجيهات عملية تظهر للمتدرب في ملفه التدريبي...',
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 46,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _saving ? null : _submitGrade,
                    icon: _saving
                        ? const SizedBox(
                            width: 17,
                            height: 17,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(PhosphorIconsRegular.checkCircle, size: 18),
                    label: Text(_saving ? 'جارٍ الحفظ...' : 'اعتماد الدرجة'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

