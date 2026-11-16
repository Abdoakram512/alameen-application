import 'dart:io';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/student_avatar.dart';
import '../../../../logic/auth/auth_cubit.dart';

/// بطاقة هوية المتدرب المميزة مع زر تعديل البيانات وعرض صادق لنوع الحساب.
class StudentProfileHeaderCard extends StatelessWidget {
  final String displayName;
  final String email;
  final String phone;
  final String avatarUrl;
  final VoidCallback? onEditTap;

  const StudentProfileHeaderCard({
    super.key,
    required this.displayName,
    required this.email,
    required this.phone,
    required this.avatarUrl,
    this.onEditTap,
  });

  bool _isGoogleAccount() {
    try {
      final providers = FirebaseAuth.instance.currentUser?.providerData ?? [];
      return providers.any((p) => p.providerId == 'google.com');
    } catch (_) {
      return false;
    }
  }

  Future<void> _pickAndUploadImage(
    BuildContext context,
    ImageSource source,
  ) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 85,
      );
      if (pickedFile == null || !context.mounted) return;

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 12),
              Text('جارٍ رفع الصورة وتحديث الملف التدريبي...'),
            ],
          ),
          duration: Duration(seconds: 4),
        ),
      );

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_pictures')
          .child('${user.uid}.jpg');

      final uploadTask = await storageRef.putFile(
        File(pickedFile.path),
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      if (context.mounted) {
        await context.read<AuthCubit>().updateProfilePhoto(downloadUrl);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم تحديث صورتك الشخصية بنجاح!'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر رفع الصورة: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showImagePickerSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'تغيير الصورة الشخصية',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(
                  PhosphorIconsRegular.camera,
                  color: AppColors.primary,
                ),
                title: const Text('التقاط صورة بالكاميرا'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _pickAndUploadImage(context, ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(
                  PhosphorIconsRegular.image,
                  color: AppColors.primary,
                ),
                title: const Text('اختيار صورة من المعرض'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _pickAndUploadImage(context, ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isGoogle = _isGoogleAccount();
    final compact = MediaQuery.sizeOf(context).width < 390;

    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppColors.heroShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _HeaderAmbientArcsPainter(),
            child: Padding(
              padding: EdgeInsets.all(compact ? 16 : 22),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(2.5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.35),
                                width: 1.5,
                              ),
                            ),
                            child: StudentAvatar(
                              name: displayName,
                              photoUrl: avatarUrl,
                              radius: compact ? 28 : 34,
                              fontSize: compact ? 19 : 23,
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Material(
                              color: AppColors.primary,
                              shape: const CircleBorder(),
                              elevation: 2,
                              child: InkWell(
                                onTap: () => _showImagePickerSheet(context),
                                customBorder: const CircleBorder(),
                                child: const Padding(
                                  padding: EdgeInsets.all(6),
                                  child: Icon(
                                    PhosphorIconsRegular.camera,
                                    size: 15,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: AppTextStyles.heading2.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (email.trim().isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                email,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                              ),
                            ],
                            if (phone.trim().isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    PhosphorIconsRegular.phone,
                                    size: 13,
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    phone,
                                    textDirection: TextDirection.ltr,
                                    style: AppTextStyles.caption.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.85,
                                      ),
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.22,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        PhosphorIconsFill.sealCheck,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        isGoogle
                                            ? 'profile.google_linked'.tr()
                                            : 'profile.verified_account'.tr(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (onEditTap != null)
                                  InkWell(
                                    onTap: onEditTap,
                                    borderRadius: BorderRadius.circular(999),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 11,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            PhosphorIconsRegular
                                                .pencilSimpleLine,
                                            color: AppColors.primary,
                                            size: 13,
                                          ),
                                          SizedBox(width: 5),
                                          Text(
                                            'تعديل بياناتي',
                                            style: TextStyle(
                                              color: AppColors.primary,
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
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

class _HeaderAmbientArcsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final ringPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final anchor = Offset(24, size.height * 0.15);
    canvas.drawCircle(anchor, 64, ringPaint);
    canvas.drawCircle(anchor, 108, ringPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
