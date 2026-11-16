import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/constants/app_constants.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../core/theme/app_colors.dart';
import '../../logic/courses/admin_courses_cubit.dart';
import '../../models/course.dart';
import '../../models/course_access_mode.dart';
import '../../models/course_level.dart';
import '../../services/storage_service.dart';
import 'widgets/course_form_fields_card.dart';

class CreateCourseScreen extends StatefulWidget {
  const CreateCourseScreen({super.key});

  @override
  State<CreateCourseScreen> createState() => _CreateCourseScreenState();
}

class _CreateCourseScreenState extends State<CreateCourseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _storageService = StorageService();
  late final String _draftCourseId = 'c_${DateTime.now().millisecondsSinceEpoch}';
  final _titleController = TextEditingController();
  final _priceController = TextEditingController(text: '0');
  final _descriptionController = TextEditingController();
  final _instructorController = TextEditingController(
    text: AppConstants.appNameAr,
  );
  final _categoryController = TextEditingController(
    text: AppConstants.defaultCategory,
  );
  final _thumbnailController = TextEditingController();

  bool _isSaving = false;
  bool _isUploadingThumbnail = false;
  bool _isPickerActive = false;

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _instructorController.dispose();
    _categoryController.dispose();
    _thumbnailController.dispose();
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
        courseId: _draftCourseId,
        file: File(filePath),
      ).timeout(
        const Duration(seconds: 12),
        onTimeout: () => throw TimeoutException(
          'استغرق رفع الصورة وقتاً طويلاً أو تم بلوغ الحد اليومي لكتابة الكوتا المجانية. يمكنك إكمال حفظ الكورس بدون غلاف أو إدخال رابط صورة خارجي.',
        ),
      );
      if (!mounted) return;
      setState(() {
        _isUploadingThumbnail = false;
        _thumbnailController.text = uploadedUri;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم رفع صورة غلاف الكورس بنجاح.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingThumbnail = false);
      final msg = e is TimeoutException
          ? e.message ?? 'استغرق رفع الصورة وقتاً طويلاً.'
          : (e.toString().contains('429') ||
                  e.toString().contains('RESOURCE_EXHAUSTED') ||
                  e.toString().contains('Quota')
              ? 'تم بلوغ الحد الأقصى اليومي للكتابة في خطة فايربيز المجانية. يمكنك حفظ الكورس بدون غلاف وسيعمل بنجاح.'
              : 'تعذر رفع صورة الغلاف: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploadingThumbnail = false);
      }
      _isPickerActive = false;
    }
  }

  Future<void> _saveCourse() async {
    if (_isSaving || _isUploadingThumbnail) return;
    if (_formKey.currentState?.validate() ?? false) {
      final price = double.tryParse(_priceController.text.trim()) ?? 0.0;

      final newCourse = Course(
        id: _draftCourseId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        instructor: _instructorController.text.trim(),
        category: _categoryController.text.trim().isNotEmpty
            ? _categoryController.text.trim()
            : AppConstants.defaultCategory,
        thumbnailUrl: _thumbnailController.text.trim(),
        price: price,
        enrolledCount: 0,
        accessMode: CourseAccessMode.approvalRequired,
        levels: [
          CourseLevel(
            id: 'lvl_1_${DateTime.now().millisecondsSinceEpoch}',
            title: 'المستوى الأول: التأسيس والمقدمة',
            description: 'المفاهيم الأولى والمقدمة لهذا الكورس',
            order: 1,
            lessons: const [],
          ),
        ],
      );

      setState(() => _isSaving = true);
      try {
        final cubit = context.read<AdminCoursesCubit>();
        unawaited(cubit.addCourse(newCourse));

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تم إنشاء الكورس بنجاح في سنتر الأمين مع إضافة المستوى الأول.',
            ),
            backgroundColor: AppColors.success,
          ),
        );

        Navigator.of(context).pop();
      } catch (e) {
        if (!mounted) return;
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ أثناء حفظ الكورس: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Directionality.of(context) == TextDirection.rtl;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: Text(isAr ? 'إضافة كورس جديد' : 'Create New Course'),
        elevation: 0,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 20),
          children: [
            ResponsiveCenter(
              maxWidth: 760,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CourseFormFieldsCard(
                    titleController: _titleController,
                    priceController: _priceController,
                    descriptionController: _descriptionController,
                    instructorController: _instructorController,
                    categoryController: _categoryController,
                    thumbnailController: _thumbnailController,
                    onThumbnailChanged: (_) => setState(() {}),
                    onPickThumbnail: _pickAndUploadThumbnail,
                    isUploadingThumbnail: _isUploadingThumbnail,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _isSaving || _isUploadingThumbnail
                          ? null
                          : _saveCourse,
                      icon: const Icon(Icons.check_circle_outline),
                      label: Text(
                        _isSaving
                            ? (isAr ? 'جاري الحفظ...' : 'Saving...')
                            : (isAr
                                ? 'حفظ الكورس والبدء بإدارة المستويات والدروس'
                                : 'Save Course & Manage Curriculum'),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
