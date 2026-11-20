import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../models/course.dart';
import '../../../../models/course_certificate.dart';
import '../../../../models/user_profile.dart';
import '../../../../repositories/student_certificates_repository.dart';
import '../../certificate/course_certificate_screen.dart';

/// بطاقة متابعة واستحقاق شهادة الدورة التدريبية الصادرة رسمياً عبر Laravel REST API
/// تمنع التوليد المحلي المزيف للشهادات وتعتمد حصرياً على الإصدار الرسمي من الخادم
class CourseCertificateCard extends StatefulWidget {
  final Course course;
  final UserModel? user;
  final int completedLessonsCount;
  final int totalLessonsCount;
  final StudentCertificatesRepository? repository;

  const CourseCertificateCard({
    super.key,
    required this.course,
    required this.user,
    required this.completedLessonsCount,
    required this.totalLessonsCount,
    this.repository,
  });

  @override
  State<CourseCertificateCard> createState() => _CourseCertificateCardState();
}

class _CourseCertificateCardState extends State<CourseCertificateCard> {
  CourseCertificate? _officialCertificate;
  bool _isChecking = false;
  bool _hasChecked = false;

  StudentCertificatesRepository get _repository =>
      widget.repository ??
      (sl.isRegistered<StudentCertificatesRepository>()
          ? sl<StudentCertificatesRepository>()
          : StudentCertificatesRepositoryImpl());

  @override
  void initState() {
    super.initState();
    _checkServerCertificate();
  }

  @override
  void didUpdateWidget(covariant CourseCertificateCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.course.id != widget.course.id ||
        oldWidget.user?.uid != widget.user?.uid ||
        oldWidget.completedLessonsCount != widget.completedLessonsCount) {
      _checkServerCertificate();
    }
  }

  Future<void> _checkServerCertificate({bool forceRefresh = false}) async {
    final user = widget.user;
    if (user == null) return;

    if (!forceRefresh && _hasChecked && _officialCertificate != null) return;

    setState(() => _isChecking = true);
    try {
      final certs = await _repository.getStudentCertificates(
        forceRefresh: forceRefresh,
        currentStudentId: user.uid,
      );

      CourseCertificate? matched;
      final courseIdStr = widget.course.id.trim();
      for (final c in certs) {
        if (c.courseId.trim() == courseIdStr ||
            (c.courseTitle.trim().isNotEmpty &&
                c.courseTitle.trim() == widget.course.title.trim())) {
          matched = c;
          break;
        }
      }

      if (mounted) {
        setState(() {
          _officialCertificate = matched;
          _hasChecked = true;
          _isChecking = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _hasChecked = true;
          _isChecking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.totalLessonsCount <= 0 || widget.user == null) {
      return const SizedBox.shrink();
    }

    final isAr = Directionality.of(context) == TextDirection.rtl;
    final progressPct = (widget.completedLessonsCount /
            widget.totalLessonsCount *
            100)
        .clamp(0.0, 100.0);
    final isEligible = progressPct >= 95.0;
    final hasOfficialCert = _officialCertificate != null;
    final remainingPct = (95.0 - progressPct).clamp(0.0, 95.0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: hasOfficialCert ? const Color(0xFF0B192C) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasOfficialCert
              ? const Color(0xFFC5A059)
              : (isEligible
                  ? const Color(0xFF10B981)
                  : AppColors.borderHairline),
          width: hasOfficialCert ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: hasOfficialCert
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
                  color: hasOfficialCert
                      ? const Color(0xFFC5A059).withValues(alpha: 0.2)
                      : (isEligible
                          ? const Color(0xFFD1FAE5)
                          : AppColors.surfaceLevel0),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hasOfficialCert
                      ? PhosphorIconsFill.certificate
                      : (isEligible
                          ? Icons.hourglass_top_rounded
                          : PhosphorIconsRegular.lockSimple),
                  color: hasOfficialCert
                      ? const Color(0xFFC5A059)
                      : (isEligible ? const Color(0xFF059669) : AppColors.textMuted),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasOfficialCert
                          ? (isAr
                              ? 'شهادة إتمام الدورة المعتمدة جاهزة!'
                              : 'Course Certificate Ready!')
                          : (isEligible
                              ? (isAr
                                  ? 'متطلبات الشهادة مكتملة (95%+)'
                                  : 'Certificate Requirements Met')
                              : (isAr
                                  ? 'شهادة إتمام الدورة المعتمدة'
                                  : 'Official Certificate')),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: hasOfficialCert
                            ? Colors.white
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasOfficialCert
                          ? (isAr
                              ? 'رقم الاعتماد الرسمي: ${_officialCertificate!.certificateCode}'
                              : 'Code: ${_officialCertificate!.certificateCode}')
                          : (isEligible
                              ? (isAr
                                  ? 'أتممت المشاهدة بنجاح — بانتظار الاعتماد والإصدار الرسمي من الإدارة'
                                  : 'Requirements completed. Pending official approval & issuance.')
                              : (isAr
                                  ? 'أنجزت ${progressPct.toStringAsFixed(0)}% - متبقي ${remainingPct.toStringAsFixed(0)}% للتأهل للشهادة'
                                  : 'Progress: ${progressPct.toStringAsFixed(0)}% (95% required)')),
                      style: TextStyle(
                        fontSize: 12,
                        color: hasOfficialCert
                            ? const Color(0xFFC5A059)
                            : (isEligible
                                ? const Color(0xFF059669)
                                : AppColors.textSecondary),
                        fontWeight: (hasOfficialCert || isEligible)
                            ? FontWeight.bold
                            : FontWeight.normal,
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
              backgroundColor: hasOfficialCert
                  ? Colors.white12
                  : AppColors.surfaceLevel1,
              valueColor: AlwaysStoppedAnimation<Color>(
                hasOfficialCert
                    ? const Color(0xFFC5A059)
                    : (isEligible ? const Color(0xFF10B981) : AppColors.primary),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Action Buttons
          if (hasOfficialCert)
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
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CourseCertificateScreen(
                        certificate: _officialCertificate!,
                      ),
                    ),
                  );
                },
                icon: const Icon(PhosphorIconsFill.certificate, size: 20),
                label: Text(
                  isAr
                      ? 'عرض وتوثيق الشهادة الرسمية'
                      : 'View & Verify Official Certificate',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                ),
              ),
            )
          else if (isEligible)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF059669),
                      side: const BorderSide(color: Color(0xFF059669)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _isChecking
                        ? null
                        : () => _checkServerCertificate(forceRefresh: true),
                    icon: _isChecking
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF059669),
                            ),
                          )
                        : const Icon(Icons.sync_rounded, size: 18),
                    label: Text(
                      _isChecking
                          ? (isAr ? 'جاري الفحص...' : 'Checking...')
                          : (isAr
                              ? 'التحقق من حالة إصدار الشهادة'
                              : 'Check Issuance Status'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
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
                          ? 'شاهد ما لا يقل عن 95% من فيديوهات المحاضرات لتأهيل حسابك لاستخراج الشهادة المعتمدة من الخادم.'
                          : 'Watch at least 95% of lectures to become eligible for an official certificate.',
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
