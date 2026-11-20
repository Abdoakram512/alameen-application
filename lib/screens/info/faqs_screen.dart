import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../../core/di/injection_container.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_error_view.dart';
import '../../core/widgets/app_loading_indicator.dart';
import '../../logic/content/content_cubit.dart';
import '../../logic/content/content_state.dart';
import '../../repositories/student_content_repository.dart';

class FaqsScreen extends StatefulWidget {
  final ContentCubit? cubit;

  const FaqsScreen({super.key, this.cubit});

  @override
  State<FaqsScreen> createState() => _FaqsScreenState();
}

class _FaqsScreenState extends State<FaqsScreen> {
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
      _cubit = ContentCubit(
        repository: sl<StudentContentRepository>(),
      );
      _ownsCubit = true;
    }
    _cubit.loadFaqs();
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
          title: Text('faqs.title'.tr()),
          centerTitle: true,
        ),
        body: BlocBuilder<ContentCubit, ContentState>(
          builder: (context, state) {
            if (state is ContentLoading || state is ContentInitial) {
              return const Center(
                child: AppLoadingIndicator(
                  message: 'جاري تحميل الأسئلة الشائعة...',
                ),
              );
            }

            if (state is ContentError) {
              return AppErrorView(
                message: state.message,
                onRetry: () => _cubit.loadFaqs(),
              );
            }

            final items = (state is ContentFaqsLoaded)
                ? state.faqs
                : const <Map<String, String>>[];

            if (items.isEmpty) {
              return const Center(
                child: AppEmptyState(
                  title: 'لا توجد أسئلة شائعة حالياً',
                  description:
                      'يمكنك التواصل مع فريق الدعم الفني للإجابة على استفساراتك.',
                  defaultIconData: PhosphorIconsRegular.chatsCircle,
                ),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.borderHairline),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              PhosphorIconsRegular.chatsCircle,
                              size: 28,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'إجابات على أكثر الاستفسارات شيوعاً',
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'لم تجد إجابة لسؤالك؟ فريق الدعم متاح دائماً لمساعدتك.',
                                    style: AppTextStyles.caption,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: items.length,
                        separatorBuilder: (_, index) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border:
                                  Border.all(color: AppColors.borderHairline),
                              boxShadow: AppColors.cardShadow,
                            ),
                            child: Theme(
                              data: Theme.of(context).copyWith(
                                dividerColor: Colors.transparent,
                              ),
                              child: ExpansionTile(
                                iconColor: AppColors.primary,
                                collapsedIconColor: AppColors.textSecondary,
                                title: Text(
                                  item['question'] ?? '',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 0, 16, 16),
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        item['answer'] ?? '',
                                        style: AppTextStyles.bodySmall.copyWith(
                                          color: AppColors.textSecondary,
                                          height: 1.6,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(
                              PhosphorIconsRegular.whatsappLogo,
                              size: 20),
                          label: const Text(
                            'تحدث مع الدعم الفني عبر واتساب',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onPressed: () => AppConstants.launchWhatsApp(),
                        ),
                      ),
                    ],
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
