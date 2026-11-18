import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/responsive/responsive_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../logic/auth/auth_cubit.dart';
import '../../../logic/auth/auth_state.dart';
import '../../../models/course_certificate.dart';
import '../../../repositories/student_certificates_repository.dart';
import 'course_certificate_screen.dart';
import 'widgets/certificate_verification_dialog.dart';

/// شاشة قائمة الشهادات المعتمدة التي حصل عليها الطالب عبر Laravel REST API
/// GET /student/certificates
class StudentCertificatesScreen extends StatefulWidget {
  const StudentCertificatesScreen({super.key});

  @override
  State<StudentCertificatesScreen> createState() =>
      _StudentCertificatesScreenState();
}

class _StudentCertificatesScreenState extends State<StudentCertificatesScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<CourseCertificate> _certificates = const [];

  StudentCertificatesRepository get _repository =>
      sl.isRegistered<StudentCertificatesRepository>()
          ? sl<StudentCertificatesRepository>()
          : StudentCertificatesRepositoryImpl();

  @override
  void initState() {
    super.initState();
    _loadCertificates();
  }

  Future<void> _loadCertificates({bool forceRefresh = false}) async {
    final authState = context.read<AuthCubit>().state;
    final currentUid = authState is Authenticated ? authState.user.uid : null;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await _repository.getStudentCertificates(
        forceRefresh: forceRefresh,
        currentStudentId: currentUid,
      );
      if (mounted) {
        setState(() {
          _certificates = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'تعذر تحميل قائمة الشهادات حالياً، تحقق من اتصالك بالإنترنت.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Directionality.of(context) == TextDirection.rtl;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: Text(
          isAr ? 'شهاداتي المعتمدة' : 'My Certificates',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => _loadCertificates(forceRefresh: true),
        child: ResponsiveCenter(
          child: _buildBody(context, isAr),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, bool isAr) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.wifi_off_rounded,
                size: 54,
                color: AppColors.textMuted,
              ),
              const SizedBox(height: 14),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: () => _loadCertificates(forceRefresh: true),
                icon: const Icon(Icons.refresh_rounded),
                label: Text(isAr ? 'إعادة المحاولة' : 'Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_certificates.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B192C).withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  PhosphorIconsRegular.certificate,
                  size: 56,
                  color: Color(0xFFC5A059),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                isAr
                    ? 'لم تصدر لك أي شهادات بعد'
                    : 'No certificates issued yet',
                style: AppTextStyles.heading3.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isAr
                    ? 'شاهد ما لا يقل عن 95% من فيديوهات الدورات التدريبية المسجل بها لتأهيل حسابك واستخراج شهادتك المعتمدة رسمياً من مركز الأمين.'
                    : 'Complete at least 95% of your enrolled courses to earn official certificates from Al-Ameen Center.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: _certificates.length,
      itemBuilder: (context, index) {
        final cert = _certificates[index];
        return _buildCertificateCard(context, cert, isAr);
      },
    );
  }

  Widget _buildCertificateCard(
    BuildContext context,
    CourseCertificate cert,
    bool isAr,
  ) {
    final formattedDate = DateFormat('yyyy/MM/dd', 'ar').format(cert.issuedAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC5A059), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
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
                  color: const Color(0xFF0B192C),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  PhosphorIconsFill.certificate,
                  color: Color(0xFFC5A059),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cert.courseTitle,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0B192C),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Text(
                          'رقم الاعتماد: ',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        Text(
                          cert.certificateCode,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFC5A059),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_rounded,
                    size: 14,
                    color: Color(0xFF9CA3AF),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'تاريخ الإصدار: $formattedDate',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF4B5563),
                    ),
                  ),
                ],
              ),
              if (cert.signatoryName != null && cert.signatoryName!.isNotEmpty)
                Text(
                  cert.signatoryName!,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0B192C),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0B192C),
                    foregroundColor: const Color(0xFFC5A059),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CourseCertificateScreen(certificate: cert),
                      ),
                    );
                  },
                  icon: const Icon(PhosphorIconsFill.certificate, size: 16),
                  label: const Text(
                    'عرض الشهادة',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0B192C),
                  side: const BorderSide(color: Color(0xFF0B192C)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => CertificateVerificationDialog.show(
                  context,
                  cert.certificateCode,
                ),
                icon: const Icon(Icons.verified_outlined, size: 16),
                label: const Text(
                  'توثيق',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
