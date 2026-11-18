import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/responsive/responsive_layout.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_lottie_box.dart';
import '../../core/widgets/app_lottie_loading.dart';
import '../../core/widgets/feedback/app_error_state.dart';
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

  bool _isCourseVisibleToStudent(Course c, UserModel? user) {
    if (c.accessMode == CourseAccessMode.closed) return false;
    if (c.accessMode == CourseAccessMode.assignedOnly) {
      if (user == null) return false;
      return c.hasEnrolled || user.isEnrolled(c.id);
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: const StudentHomeAppBar(),
      body: BlocBuilder<CoursesCubit, CoursesState>(
        builder: (context, coursesState) {
          final currentUser = context.select<AuthCubit, UserModel?>((c) {
            final s = c.state;
            return s is Authenticated ? s.user : null;
          });
          if (coursesState is CoursesLoading) {
            return const AppLottieLoading(
              message: 'جاري تحميل البرامج التدريبية المعتمدة...',
            );
          }

          if (coursesState is CoursesError) {
            return AppErrorState(
              message:
                  'تعذر تحميل البرامج التدريبية حالياً، تحقق من اتصالك بالإنترنت.',
              onRetry: () => context.read<CoursesCubit>().loadCourses(),
            );
          }

          if (coursesState is! CoursesLoaded) {
            return const AppLottieLoading();
          }

              final allCourses = coursesState.allCourses
                  .where((c) => _isCourseVisibleToStudent(c, currentUser))
                  .toList();
              final filteredCourses = coursesState.filteredCourses
                  .where((c) => _isCourseVisibleToStudent(c, currentUser))
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
                        .where(
                          (c) => c.isDetailedFromAuthServer
                              ? c.hasEnrolled
                              : (c.hasEnrolled || currentUser.isEnrolled(c.id)),
                        )
                        .length;

              return RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () async {
                  context.read<CoursesCubit>().loadCourses();
                },
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  children: [
                    ResponsiveCenter(
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
                            onSearchChanged:
                                context.read<CoursesCubit>().search,
                            onCategorySelected:
                                context.read<CoursesCubit>().filterByCategory,
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'home.available_courses'.tr(),
                                style: AppTextStyles.heading2,
                              ),
                              Text(
                                'home.courses_count'.tr(args: [
                                  '${filteredCourses.length}',
                                ]),
                                style: AppTextStyles.caption.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          if (filteredCourses.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(28),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: AppColors.borderHairline,
                                ),
                              ),
                              child: Column(
                                children: [
                                  const AppLottieBox(
                                    assetPath: 'assets/lottie/empty_state.json',
                                    width: 84,
                                    height: 84,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'home.no_matching_courses'.tr(),
                                    style: AppTextStyles.heading3.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'home.try_different_search'.tr(),
                                    style: AppTextStyles.bodyMedium,
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          else
                            ResponsiveCardGrid(
                              minItemWidth: 320,
                              maxColumns: 3,
                              children: [
                                for (final course in filteredCourses)
                                  StudentCourseCard(
                                    course: course,
                                    isEnrolled:
                                        currentUser?.isEnrolled(course.id) ??
                                            false,
                                    progress: currentUser
                                            ?.calculateCourseProgress(
                                              course.allLessonIds,
                                            ) ??
                                        0.0,
                                    onTap: () =>
                                        context.go('/course/${course.id}'),
                                  ),
                              ],
                            ),
                            const SizedBox(
                              height: kBottomNavigationBarHeight + 24,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
  }
}
