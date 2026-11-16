import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../models/course.dart';
import '../../../../models/course_certificate.dart';
import '../../../../models/user_profile.dart';
import '../../certificate/course_certificate_screen.dart';

/// بطاقة متابعة واستحقاق شهادة الدورة التدريبية (تفتح فقط عند إتمام 95%+)
class CourseCertificateCard extends StatelessWidget {
  final Course course;
  final UserModel? user;
  final int completedLessonsCount;
  final int totalLessonsCount;

  const CourseCertificateCard({
    super.key,
    required this.course,
    required this.user,
    required this.completedLessonsCount,
    required this.totalLessonsCount,
  });

  @override
  Widget build(BuildContext context) {
    if (totalLessonsCount <= 0 || user == null) {
      return const SizedBox.shrink();
    }

    final isAr = Directionality.of(context) == TextDirection.rtl;
    final progressPct = (completedLessonsCount / totalLessonsCount * 100).clamp(0.0, 100.0);
    final isEligible = progressPct >= 95.0;
    final remainingPct = (95.0 - progressPct).clamp(0.0, 95.0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isEligible ? const Color(0xFF0B192C) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isEligible
              ? const Color(0xFFC5A059)
              : AppColors.borderHairline,
          width: isEligible ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isEligible
                ? const Color(0x33C5A059)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isEligible
                      ? const Color(0xFFC5A059).withValues(alpha: 0.2)
                      : AppColors.surfaceLevel0,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isEligible
                      ? PhosphorIconsFill.certificate
                      : PhosphorIconsRegular.lockSimple,
                  color: isEligible
                      ? const Color(0xFFC5A059)
                      : AppColors.textMuted,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEligible
                          ? (isAr
                              ? 'شهادة إتمام الدورة المعتمدة جاهزة!'
                              : 'Course Certificate Ready!')
                          : (isAr
                              ? 'شهادة إتمام الدورة المعتمدة'
                              : 'Official Certificate'),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isEligible ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isEligible
                          ? (isAr
                              ? 'تهانينا! حققت نسبة الإنجاز المطلوبة (95%+)'
                              : 'Congrats! You completed 95%+ of the course')
                          : (isAr
                              ? 'أنجزت ${progressPct.toStringAsFixed(0)}% - متبقي ${remainingPct.toStringAsFixed(0)}% للتأهل للشهادة'
                              : 'Progress: ${progressPct.toStringAsFixed(0)}% (95% required)'),
                      style: TextStyle(
                        fontSize: 12,
                        color: isEligible
                            ? const Color(0xFFC5A059)
                            : AppColors.textSecondary,
                        fontWeight: isEligible ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (progressPct / 100.0).clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: isEligible
                  ? Colors.white12
                  : AppColors.surfaceLevel1,
              valueColor: AlwaysStoppedAnimation<Color>(
                isEligible ? const Color(0xFFC5A059) : AppColors.primary,
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Action Button
          if (isEligible)
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFC5A059),
                  foregroundColor: const Color(0xFF0B192C),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  final serial =
                      'ALM-2026-${course.id.hashCode.abs().toString().padLeft(4, '0').substring(0, 4)}-${user!.uid.hashCode.abs().toString().padLeft(4, '0').substring(0, 4)}';
                  final cert = CourseCertificate(
                    id: 'cert_${user!.uid}_${course.id}',
                    courseId: course.id,
                    courseTitle: course.title,
                    studentId: user!.uid,
                    studentName: user!.displayName.isNotEmpty
                        ? user!.displayName
                        : 'متدرب مركز الأمين',
                    studentEmail: user!.email,
                    serialNumber: serial,
                    issuedAt: DateTime.now(),
                    completionPercentage: progressPct,
                  );
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CourseCertificateScreen(certificate: cert),
                    ),
                  );
                },
                icon: const Icon(PhosphorIconsFill.filePdf, size: 20),
                label: Text(
                  isAr
                      ? 'عرض وتحميل الشهادة المعتمدة (PDF)'
                      : 'View & Download Certificate (PDF)',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceLevel0,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isAr
                          ? 'شاهد ما لا يقل عن 95% من فيديوهات المحاضرات لتفعيل واستخراج شهادتك المعتمدة تلقائياً.'
                          : 'Watch at least 95% of lectures to automatically unlock your certificate.',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
