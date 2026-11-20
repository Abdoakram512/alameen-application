import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/responsive/responsive_layout.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../features/courses/presentation/cubits/course_entitlement/course_entitlement_cubit.dart';
import '../../features/courses/presentation/cubits/course_entitlement/course_entitlement_state.dart';
import '../../logic/auth/auth_cubit.dart';
import '../../logic/auth/auth_state.dart';
import '../../logic/courses/courses_cubit.dart';
import '../../logic/courses/courses_state.dart';
import '../../models/course.dart';
import 'profile/widgets/student_analytics_overview_card.dart';
import 'profile/widgets/student_stats_grid.dart';

class StudentAnalyticsScreen extends StatelessWidget {
  const StudentAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: Text(
          'analytics.title'.tr(),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, authState) {
          final currentUser =
              authState is Authenticated ? authState.user : null;
          if (currentUser == null) {
            return Center(child: Text('analytics.login_required'.tr()));
          }

          return BlocBuilder<CourseEntitlementCubit, CourseEntitlementState>(
            builder: (context, entitlementState) {
              return BlocBuilder<CoursesCubit, CoursesState>(
                builder: (context, coursesState) {
                  final allCourses = coursesState is CoursesLoaded
                      ? coursesState.allCourses
                      : const <Course>[];
                  final authorizedCourses = allCourses
                      .where((c) => entitlementState.isCourseAuthorized(c.id))
                      .toList();
                  final enrolledCount = authorizedCourses.length;

              return RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () async {
                  context.read<CoursesCubit>().loadCourses();
                },
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 20,
                  ),
                  children: [
                    ResponsiveCenter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Introduction banner
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  AppColors.primary,
                                  AppColors.primaryDark,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.25),
                                  blurRadius: 14,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    PhosphorIconsRegular.chartLineUp,
                                    color: Colors.white,
                                    size: 26,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'سجل الإنجاز وساعات التدريب',
                                        style: AppTextStyles.heading3.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'تحليلات فورية لانتظامك وساعات المشاهدة ونسبة التقدم في مسارات التأهيل.',
                                        style: AppTextStyles.caption.copyWith(
                                          color: Colors.white.withValues(alpha: 0.9),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Stats Grid
                          StudentStatsGrid(
                            enrolledCount: enrolledCount,
                            completedLessonsCount:
                                currentUser.completedLessonIds.length,
                            watchTimeFormatted:
                                currentUser.watchTimeFormatted,
                          ),
                          const SizedBox(height: 20),

                          // Analytics Chart Overview Card
                          StudentAnalyticsOverviewCard(
                            currentUser: currentUser,
                            enrolledCourses: authorizedCourses,
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ],
                ),
              );
                },
              );
            },
          );
        },
      ),
    );
  }
}

