import 'dart:io';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_validators.dart';
import '../../../core/widgets/app_cached_image.dart';
import '../../../logic/courses/admin_courses_cubit.dart';
import '../../../models/course.dart';
import '../../../models/course_access_mode.dart';
import '../../../services/storage_service.dart';

class EditCourseDialog extends StatefulWidget {
  final Course course;

  const EditCourseDialog({super.key, required this.course});

  static Future<void> show(BuildContext context, {required Course course}) {
    return showDialog(
      context: context,
      builder: (_) => BlocProvider.value(
        value: context.read<AdminCoursesCubit>(),
        child: EditCourseDialog(course: course),
      ),
    );
  }

  @override
  State<EditCourseDialog> createState() => _EditCourseDialogState();
}

class _EditCourseDialogState extends State<EditCourseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _storageService = StorageService();
  late final TextEditingController _titleController;
  late final TextEditingController _priceController;
  late final TextEditingController _descController;
  late final TextEditingController _instructorController;
  late final TextEditingController _categoryController;
  late final TextEditingController _thumbnailController;
  late final TextEditingController _validityDaysController;
  late bool _isEnrollmentClosed;
  late CourseAccessMode _accessMode;

  bool _isSaving = false;
  bool _isUploadingThumbnail = false;
  bool _isPickerActive = false;

  @override
  void initState() {
    super.initState();
    final course = widget.course;
    _accessMode = course.accessMode;
    _isEnrollmentClosed = course.isEnrollmentClosed;
    _titleController = TextEditingController(text: course.title);
    _priceController = TextEditingController(
      text: course.price.truncateToDouble() == course.price
          ? course.price.toInt().toString()
          : course.price.toString(),
    );
    _descController = TextEditingController(text: course.description);
    _instructorController = TextEditingController(text: course.instructor);
    _categoryController = TextEditingController(text: course.category);
    _thumbnailController = TextEditingController(text: course.thumbnailUrl);
    _validityDaysController = TextEditingController(
      text: course.validityDays > 0 ? course.validityDays.toString() : '',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _descController.dispose();
    _instructorController.dispose();
    _categoryController.dispose();
    _thumbnailController.dispose();
    _validityDaysController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadThumbnail() async {
    if (_isPickerActive || _isUploadingThumbnail) return;
    _isPickerActive = true;
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      );
      if (result.isEmpty || result.first.path == null) {
        return;
      }
      if (!mounted) return;

      final filePath = result.first.path!;
      setState(() => _isUploadingThumbnail = true);
      final uploadedUri = await _storageService.uploadCourseThumbnail(
        courseId: widget.course.id,
        file: File(filePath),
      );
      if (!mounted) return;
      setState(() {
        _isUploadingThumbnail = false;
        _thumbnailController.text = uploadedUri;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تحديث صورة الغلاف بنجاح.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingThumbnail = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر رفع صورة الغلاف: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      _isPickerActive = false;
    }
  }

  Future<void> _onSave() async {
    if (_isSaving || _isUploadingThumbnail) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final normPrice = AppValidators.normalizeDigits(_priceController.text.trim());
    final newPrice = double.tryParse(normPrice) ?? widget.course.price;

    final updated = widget.course.copyWith(
      title: _titleController.text.trim(),
      price: newPrice >= 0 ? newPrice : widget.course.price,
      description: _descController.text.trim(),
      instructor: _instructorController.text.trim(),
      category: _categoryController.text.trim(),
      thumbnailUrl: _thumbnailController.text.trim(),
      accessMode: _accessMode,
      validityDays: int.tryParse(_validityDaysController.text.trim()) ?? 0,
      isEnrollmentClosed: _isEnrollmentClosed,
    );
    setState(() => _isSaving = true);
    final saved = await context.read<AdminCoursesCubit>().updateCourse(updated);
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر الحفظ. بياناتك ما زالت موجودة، حاول مرة أخرى.'),
        ),
      );
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final previewUrl = _thumbnailController.text.trim();
    bool isEn = false;
    try {
      isEn = context.locale.languageCode == 'en';
    } catch (_) {
      isEn = false;
    }
    final isAr = !isEn;

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 680),
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
                      Icons.edit_note_rounded,
                      color: AppColors.royalNavy,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isAr ? 'تعديل بيانات وسعر الكورس' : 'Edit Course & Price',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    tooltip: 'dialogs.cancel'.tr(),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.divider),
              const SizedBox(height: 16),

              // Scrollable Form Fields
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
                          decoration: const InputDecoration(
                            labelText: 'عنوان الكورس *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.school_outlined),
                          ),
                          validator: (val) => AppValidators.validateRequired(
                            val,
                            'عنوان الكورس',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _priceController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.left,
                          decoration: const InputDecoration(
                            labelText: 'سعر الكورس (جنيه مصري) *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(
                              Icons.payments_outlined,
                              color: AppColors.primary,
                            ),
                            suffixText: AppConstants.currency,
                          ),
                          validator: AppValidators.validatePrice,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _descController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'وصف الكورس',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.description_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _instructorController,
                          decoration: const InputDecoration(
                            labelText: 'اسم المحاضر / المركز',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _categoryController,
                          decoration: const InputDecoration(
                            labelText: 'التصنيف',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.category_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLevel0,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderHairline),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _accessMode.icon,
                                  size: 18,
                                  color: _accessMode.badgeFg,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isAr ? 'حالة إتاحة الكورس للطلاب' : 'Access Mode',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<CourseAccessMode>(
                              initialValue: _accessMode,
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                fillColor: Colors.white,
                                filled: true,
                              ),
                              items: CourseAccessMode.values.map((mode) {
                                return DropdownMenuItem<CourseAccessMode>(
                                  value: mode,
                                  child: Row(
                                    children: [
                                      Icon(mode.icon, size: 16, color: mode.badgeFg),
                                      const SizedBox(width: 8),
                                      Text(
                                        isAr ? mode.labelAr : mode.labelEn,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: mode.badgeFg,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _accessMode = val);
                                }
                              },
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _accessMode.descriptionAr,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // إعدادات مدة الصلاحية وإغلاق الاشتراك
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLevel0,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderHairline),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.timer_outlined,
                                  size: 18,
                                  color: AppColors.royalNavy,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isAr ? 'صلاحية الاشتراك وإغلاق الدورة' : 'Validity & Enrollment',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _validityDaysController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'مدة الصلاحية بالأيام',
                                hintText: 'مثال: 30 أو 90 يوماً (0 = دائم وغير محدود)',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.calendar_month_outlined),
                                isDense: true,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                'إغلاق الدورة بالكامل (إلغاء اشتراك الجميع)',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.errorDark,
                                ),
                              ),
                              subtitle: const Text(
                                'عند التفعيل، يتم حظر وصول جميع الطلاب للمحتوى تلقائياً لحين فتحها مجدداً.',
                                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                              value: _isEnrollmentClosed,
                              activeThumbColor: AppColors.error,
                              onChanged: (val) => setState(() => _isEnrollmentClosed = val),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _thumbnailController,
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.left,
                        decoration: const InputDecoration(
                          labelText: 'رابط صورة الغلاف',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.image_outlined),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _isUploadingThumbnail
                            ? null
                            : _pickAndUploadThumbnail,
                        icon: _isUploadingThumbnail
                            ? const SizedBox(
                                width: 15,
                                height: 15,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.upload_file_rounded, size: 18),
                        label: Text(
                          _isUploadingThumbnail
                              ? 'جاري رفع صورة الغلاف...'
                              : 'اختيار غلاف جديد من الجهاز',
                        ),
                      ),
                      if (previewUrl.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        AppCachedImage(
                          imageUrl: previewUrl,
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

              const SizedBox(height: 16),
              const Divider(height: 1, color: AppColors.divider),
              const SizedBox(height: 12),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('dialogs.cancel'.tr()),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.royalNavy,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _isSaving || _isUploadingThumbnail ? null : _onSave,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_rounded, size: 18),
                    label: Text(
                      _isSaving
                          ? (isAr ? 'جاري الحفظ...' : 'Saving...')
                          : 'dialogs.save'.tr(),
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
