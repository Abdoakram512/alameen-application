import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_validators.dart';
import '../../../core/widgets/app_cached_image.dart';

/// بطاقة حقول بيانات الكورس مع رفع مباشر لصورة الغلاف ومعاينتها.
class CourseFormFieldsCard extends StatelessWidget {
  final TextEditingController titleController;
  final TextEditingController priceController;
  final TextEditingController descriptionController;
  final TextEditingController instructorController;
  final TextEditingController categoryController;
  final TextEditingController thumbnailController;
  final ValueChanged<String> onThumbnailChanged;
  final VoidCallback? onPickThumbnail;
  final bool isUploadingThumbnail;

  const CourseFormFieldsCard({
    super.key,
    required this.titleController,
    required this.priceController,
    required this.descriptionController,
    required this.instructorController,
    required this.categoryController,
    required this.thumbnailController,
    required this.onThumbnailChanged,
    this.onPickThumbnail,
    this.isUploadingThumbnail = false,
  });

  @override
  Widget build(BuildContext context) {
    final previewUrl = thumbnailController.text.trim();
    final isAr = Directionality.of(context) == TextDirection.rtl;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: AppColors.cardShadow,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 560;

          final priceField = TextFormField(
            controller: priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.left,
            decoration: InputDecoration(
              labelText: isAr ? 'سعر الكورس (جنيه مصري) *' : 'Course Price (EGP) *',
              hintText: isAr ? 'مثال: 500 أو 0 إذا كان مجانياً' : 'e.g. 500 or 0 for free',
              prefixIcon: const Icon(
                Icons.payments_outlined,
                color: AppColors.primary,
              ),
              suffixText: isAr ? AppConstants.currency : 'EGP',
              suffixStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            validator: (val) {
              final norm = AppValidators.normalizeDigits(val);
              if (norm.isEmpty) {
                return isAr
                    ? 'يرجى تحديد سعر الكورس (اكتب 0 للمجاني)'
                    : 'Please enter course price (0 for free)';
              }
              final num = double.tryParse(norm);
              if (num == null || !num.isFinite || num < 0) {
                return isAr
                    ? 'يرجى إدخال رقم صحيح أو عشري موجب للسعر'
                    : 'Please enter a valid positive number';
              }
              return null;
            },
          );

          final categoryField = TextFormField(
            controller: categoryController,
            decoration: InputDecoration(
              labelText: isAr ? 'تصنيف الكورس' : 'Course Category',
              hintText: isAr ? 'مثال: تخاطب، تأهيل نطق، تعديل سلوك' : 'e.g. Speech Therapy, Rehabilitation',
              prefixIcon: const Icon(
                Icons.category_outlined,
                color: AppColors.primary,
              ),
            ),
          );

          final instructorField = TextFormField(
            controller: instructorController,
            decoration: InputDecoration(
              labelText: isAr ? 'اسم المحاضر / المركز *' : 'Instructor / Center Name *',
              prefixIcon: const Icon(
                Icons.person_outline,
                color: AppColors.primary,
              ),
            ),
            validator: (val) => val == null || val.trim().isEmpty
                ? (isAr ? 'يرجى إدخال اسم المحاضر' : 'Please enter instructor name')
                : null,
          );

          final thumbnailField = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: thumbnailController,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.left,
                decoration: InputDecoration(
                  labelText: isAr ? 'رابط صورة الغلاف (اختياري)' : 'Cover Image URL (Optional)',
                  hintText: 'https://example.com/cover.jpg',
                  prefixIcon: const Icon(
                    Icons.image_outlined,
                    color: AppColors.primary,
                  ),
                ),
                onChanged: onThumbnailChanged,
              ),
              if (onPickThumbnail != null) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: isUploadingThumbnail ? null : onPickThumbnail,
                  icon: isUploadingThumbnail
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_file_rounded, size: 18),
                  label: Text(
                    isUploadingThumbnail
                        ? (isAr ? 'جاري تجهيز ورفع صورة الغلاف...' : 'Uploading Cover Image...')
                        : (isAr ? 'اختيار صورة الغلاف من الجهاز' : 'Choose Cover from Device'),
                  ),
                ),
              ],
            ],
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: isAr ? 'عنوان الكورس *' : 'Course Title *',
                  hintText: isAr ? 'مثال: دورة تنمية المهارات اللغوية والتخاطب' : 'e.g. Speech & Language Therapy Course',
                  prefixIcon: const Icon(
                    Icons.school_outlined,
                    color: AppColors.primary,
                  ),
                ),
                validator: (val) => val == null || val.trim().isEmpty
                    ? (isAr ? 'يرجى إدخال عنوان الكورس' : 'Please enter course title')
                    : null,
              ),
              const SizedBox(height: 16),
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: priceField),
                    const SizedBox(width: 14),
                    Expanded(child: categoryField),
                  ],
                )
              else ...[
                priceField,
                const SizedBox(height: 16),
                categoryField,
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'وصف الكورس *',
                  hintText:
                      'اكتب نبذة واضحة تشرح أهداف البرنامج وما سيتعلمه المتدرب...',
                  prefixIcon: Icon(
                    Icons.description_outlined,
                    color: AppColors.primary,
                  ),
                ),
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'يرجى إدخال وصف الكورس'
                    : null,
              ),
              const SizedBox(height: 16),
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: instructorField),
                    const SizedBox(width: 14),
                    Expanded(child: thumbnailField),
                  ],
                )
              else ...[
                instructorField,
                const SizedBox(height: 16),
                thumbnailField,
              ],
              if (previewUrl.isNotEmpty) ...[
                const SizedBox(height: 14),
                AppCachedImage(
                  imageUrl: previewUrl,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  borderRadius: BorderRadius.circular(12),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
