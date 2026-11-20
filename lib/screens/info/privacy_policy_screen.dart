import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/di/injection_container.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_error_view.dart';
import '../../core/widgets/app_loading_indicator.dart';
import '../../logic/content/content_cubit.dart';
import '../../logic/content/content_state.dart';
import '../../repositories/student_content_repository.dart';

class PrivacyPolicyScreen extends StatefulWidget {
  final ContentCubit? cubit;

  const PrivacyPolicyScreen({super.key, this.cubit});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  late final ContentCubit _cubit;
  bool _ownsCubit = false;

  @override
  void initState() {
    super.initState();
    if (widget.cubit != null) {
      _cubit = widget.cubit!;
    } else if (sl.isRegistered<ContentCubit>()) {
      _cubit = sl<ContentCubit>();
      _ownsCubit = true;
    } else {
      _cubit = ContentCubit(repository: sl<StudentContentRepository>());
      _ownsCubit = true;
    }
    _cubit.loadPrivacyPolicy();
  }

  @override
  void dispose() {
    if (_ownsCubit) {
      _cubit.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
        appBar: AppBar(
          title: Text('privacy_policy.title'.tr()),
          centerTitle: true,
        ),
        body: BlocBuilder<ContentCubit, ContentState>(
          builder: (context, state) {
            if (state is ContentLoading || state is ContentInitial) {
              return const Center(
                child: AppLoadingIndicator(
                  message: 'جاري تحميل سياسة الخصوصية...',
                ),
              );
            }

            if (state is ContentError) {
              return AppErrorView(
                message: state.message,
                onRetry: () => _cubit.loadPrivacyPolicy(),
              );
            }

            final content = state is ContentPrivacyLoaded
                ? state.content
                : 'نولي في مركز الأمين للتخاطب والتأهيل أولوية قصوى لحماية خصوصيتك وسرية بياناتك الشخصية.\n\n١. جمع البيانات:\nنقوم بجمع بيانات الاسم ورقم الهاتف والبريد الإلكتروني فقط لأغراض التوثيق الأكاديمي، إصدار الشهادات المعتمدة، وتوفير الدعم الفني اللازم.\n\n٢. سرية المحتوى والأمان:\nجميع الدروس والمحاضرات الرقمية والتسجيلات محمية بحقوق ملكية فكرية بموجب القانون. يُمنع تصوير الشاشة أو تسجيل المحاضرات أو مشاركة الحسابات مع أطراف أخرى.\n\n٣. مشاركة البيانات:\nنلتزم التزاماً كاملاً بعدم بيع أو مشاركة بياناتك الشخصية مع أي أطراف ثالثة أو شركات تسويقية إطلاقاً.\n\n٤. حذف الحساب والبيانات:\nيحق للمتدرب في أي وقت طلب حذف حسابه بالكامل من التطبيق عبر الذهاب للملف الشخصي واختيار "حذف الحساب نهائياً"، وسيتم مسح جميع بياناته فوراً وبشكل دائم.';
            final title = state is ContentPrivacyLoaded
                ? state.title
                : 'سياسة الخصوصية والأمان';

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.borderHairline),
                      boxShadow: AppColors.cardShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: const BoxDecoration(
                            color: AppColors.primaryLight,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            PhosphorIconsRegular.shieldCheck,
                            size: 36,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          title,
                          style: AppTextStyles.titleMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        const Divider(color: AppColors.divider),
                        const SizedBox(height: 16),
                        Text(
                          content,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textPrimary,
                            height: 1.8,
                          ),
                          textAlign: TextAlign.justify,
                        ),
                        const SizedBox(height: 28),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                PhosphorIconsRegular.lockKey,
                                color: AppColors.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'بياناتك مشفرة ومحمية وفق أعلى معايير الأمان والخصوصية الرقمية.',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
