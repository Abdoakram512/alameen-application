import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/responsive/responsive_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../logic/auth/auth_cubit.dart';
import '../../../logic/auth/auth_state.dart';
import '../../../logic/certificates/certificates_cubit.dart';
import '../../../logic/certificates/certificates_state.dart';
import '../../../models/course_certificate.dart';
import '../../../repositories/student_certificates_repository.dart';
import 'course_certificate_screen.dart';
import 'widgets/certificate_verification_dialog.dart';

/// شاشة قائمة الشهادات المعتمدة التي حصل عليها الطالب عبر Laravel REST API
/// GET /student/certificates
class StudentCertificatesScreen extends StatefulWidget {
  final CertificatesCubit? cubit;
  final StudentCertificatesRepository? repository;

  const StudentCertificatesScreen({
    super.key,
    this.cubit,
    this.repository,
  });

  @override
  State<StudentCertificatesScreen> createState() =>
      _StudentCertificatesScreenState();
}

class _StudentCertificatesScreenState extends State<StudentCertificatesScreen> {
  late final CertificatesCubit _cubit;
  bool _ownsCubit = false;

  @override
  void initState() {
    super.initState();
    if (widget.cubit != null) {
      _cubit = widget.cubit!;
    } else if (widget.repository != null) {
      _cubit = CertificatesCubit(repository: widget.repository!);
      _ownsCubit = true;
    } else {
      _cubit = sl<CertificatesCubit>();
      _ownsCubit = true;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchCertificates();
    });
  }

  @override
  void dispose() {
    if (_ownsCubit) {
      _cubit.close();
    }
    super.dispose();
  }

  void _fetchCertificates({bool forceRefresh = false}) {
    final authState = context.read<AuthCubit>().state;
    final currentUid = authState is Authenticated ? authState.user.uid : null;
    _cubit.loadCertificates(
      forceRefresh: forceRefresh,
      currentStudentId: currentUid,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Directionality.of(context) == TextDirection.rtl;

    return BlocProvider.value(
      value: _cubit,
      child: Scaffold(
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
          onRefresh: () async => _fetchCertificates(forceRefresh: true),
          child: ResponsiveCenter(
            child: BlocBuilder<CertificatesCubit, CertificatesState>(
              builder: (context, state) => _buildBody(context, state, isAr),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, CertificatesState state, bool isAr) {
    if (state is CertificatesLoading || state is CertificatesInitial) {
      return const AppLoadingIndicator(
        message: 'جاري تحميل الشهادات المعتمدة...',
      );
    }

    if (state is CertificatesError) {
      return AppErrorView(
        message: state.message,
        onRetry: () => _fetchCertificates(forceRefresh: true),
      );
    }

    if (state is CertificatesLoaded) {
      final certificates = state.certificates;
      if (certificates.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: AppEmptyState(
              defaultIconData: PhosphorIconsRegular.certificate,
              title: isAr
                  ? 'لم تصدر لك أي شهادات بعد'
                  : 'No certificates issued yet',
              description: isAr
                  ? 'شاهد ما لا يقل عن 95% من فيديوهات الدورات التدريبية المسجل بها لتأهيل حسابك واستخراج شهادتك المعتمدة رسمياً من مركز الأمين.'
                  : 'Complete at least 95% of your enrolled courses to earn official certificates from Al-Ameen Center.',
              actionText: isAr ? 'تحديث' : 'Refresh',
              onAction: () => _fetchCertificates(forceRefresh: true),
            ),
          ),
        );
      }

      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        itemCount: certificates.length,
        itemBuilder: (context, index) {
          final cert = certificates[index];
          return _buildCertificateCard(context, cert, isAr);
        },
      );
    }

    return const SizedBox.shrink();
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
                        builder: (_) => CourseCertificateScreen(
                          certificate: cert,
                          cubit: _cubit,
                        ),
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
