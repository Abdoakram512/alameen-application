import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/responsive/responsive_layout.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_error_view.dart';
import '../../core/widgets/app_loading_indicator.dart';
import '../../core/widgets/app_section_header.dart';
import '../../features/courses/presentation/cubits/course_entitlement/course_entitlement_cubit.dart';
import '../../features/courses/presentation/cubits/course_entitlement/course_entitlement_state.dart';
import '../../logic/auth/auth_cubit.dart';
import '../../logic/auth/auth_state.dart';
import '../../logic/courses/courses_cubit.dart';
import '../../logic/courses/courses_state.dart';
import '../../models/course.dart';
import '../../models/course_access_mode.dart';
import '../../models/user_profile.dart';
import 'home/widgets/course_search_filter_bar.dart';
import 'home/widgets/student_course_card.dart';
import 'home/widgets/student_home_app_bar.dart';
import 'home/widgets/student_welcome_banner.dart';
import 'resume_learning_card.dart';

class StudentHomeScreen extends StatelessWidget {
  const StudentHomeScreen({super.key});

  bool _isCourseVisibleToStudent(
    Course c,
    UserModel? user,
    CourseEntitlementState entitlementState,
  ) {
    if (c.accessMode == CourseAccessMode.closed) return false;
    if (c.accessMode == CourseAccessMode.assignedOnly) {
      if (user == null) return false;
      return entitlementState.isCourseAuthorized(c.id);
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: const StudentHomeAppBar(),
      body: BlocBuilder<CourseEntitlementCubit, CourseEntitlementState>(
        builder: (context, entitlementState) {
          return BlocBuilder<CoursesCubit, CoursesState>(
            builder: (context, coursesState) {
              final currentUser = context.select<AuthCubit, UserModel?>((c) {
                final s = c.state;
                return s is Authenticated ? s.user : null;
              });
              if (coursesState is CoursesLoading) {
                return const Center(
                  child: AppLoadingIndicator(
                    message: 'جاري تحميل البرامج التدريبية المعتمدة...',
                  ),
                );
              }

              if (coursesState is CoursesError) {
                return AppErrorView(
                  message:
                      'تعذر تحميل البرامج التدريبية حالياً، تحقق من اتصالك بالإنترنت.',
                  onRetry: () => context.read<CoursesCubit>().loadCourses(),
                );
              }

              if (coursesState is! CoursesLoaded) {
                return const Center(child: AppLoadingIndicator());
              }

              final allCourses = coursesState.allCourses
                  .where(
                    (c) => _isCourseVisibleToStudent(
                      c,
                      currentUser,
                      entitlementState,
                    ),
                  )
                  .toList();
              final filteredCourses = coursesState.filteredCourses
                  .where(
                    (c) => _isCourseVisibleToStudent(
                      c,
                      currentUser,
                      entitlementState,
                    ),
                  )
                  .toList();
              final categories = <String>{
                'home.all_categories'.tr(),
                ...allCourses
                    .map((c) => c.category.trim())
                    .where((c) => c.isNotEmpty),
              }.toList();
              final enrolledCount = currentUser == null
                  ? 0
                  : allCourses
                        .where((c) => entitlementState.isCourseAuthorized(c.id))
                        .length;

              return RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () => context.read<CoursesCubit>().loadCourses(
                  forceRefresh: true,
                ),
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: ResponsiveCenter(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (currentUser != null)
                                ResumeLearningCard(
                                  user: currentUser,
                                  courses: allCourses,
                                ),
                              StudentWelcomeBanner(
                                totalCourses: allCourses.length,
                                enrolledCount: enrolledCount,
                              ),
                              const SizedBox(height: 18),
                              CourseSearchFilterBar(
                                categories: categories,
                                selectedCategory: coursesState.selectedCategory,
                                onSearchChanged: context
                                    .read<CoursesCubit>()
                                    .search,
                                onCategorySelected: context
                                    .read<CoursesCubit>()
                                    .filterByCategory,
                              ),
                              const SizedBox(height: 20),
                              AppSectionHeader(
                                title: 'home.available_courses'.tr(),
                                subtitle: 'home.courses_count'.tr(
                                  args: ['${filteredCourses.length}'],
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (filteredCourses.isEmpty)
                      SliverToBoxAdapter(
                        child: AppEmptyState(
                          title: 'home.no_matching_courses'.tr(),
                          description: 'home.try_different_search'.tr(),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: EdgeInsets.symmetric(
                          horizontal: context.horizontalPagePadding,
                        ),
                        sliver: SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 440,
                                mainAxisSpacing: 16,
                                crossAxisSpacing: 16,
                                childAspectRatio: 0.94,
                              ),
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final course = filteredCourses[index];
                            return StudentCourseCard(
                              course: course,
                              isEnrolled:
                                  currentUser != null &&
                                  entitlementState.isCourseAuthorized(
                                    course.id,
                                  ),
                              progress: (course.serverProgressPercent != null)
                                  ? (course.serverProgressPercent! / 100.0)
                                        .clamp(0.0, 1.0)
                                  : (currentUser?.calculateCourseProgress(
                                          course.allLessonIds,
                                        ) ??
                                        0.0),
                              onTap: () => context.push('/course/${course.id}'),
                            );
                          }, childCount: filteredCourses.length),
                        ),
                      ),
                    const SliverToBoxAdapter(
                      child: SizedBox(height: kBottomNavigationBarHeight + 24),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
