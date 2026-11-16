import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/responsive/responsive_layout.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/feedback/app_empty_state.dart';
import '../../../core/widgets/feedback/app_error_state.dart';
import '../../../core/widgets/feedback/app_loading_indicator.dart';
import '../../../logic/courses/admin_courses_cubit.dart';
import '../../../logic/courses/admin_courses_state.dart';
import '../../../logic/requests/admin_requests_cubit.dart';
import '../../../logic/requests/admin_requests_state.dart';
import '../../../logic/students/admin_students_cubit.dart';
import '../../../logic/students/admin_students_state.dart';
import '../../../models/registered_student.dart';
import '../widgets/course_card_item.dart';
import '../widgets/dashboard_hero_kpi_card.dart';
import '../widgets/dashboard_quick_actions.dart';

class CoursesTab extends StatelessWidget {
  final ValueChanged<int>? onSelectTab;

  const CoursesTab({super.key, this.onSelectTab});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AdminCoursesCubit, AdminCoursesState>(
      builder: (context, coursesState) {
        return BlocBuilder<AdminStudentsCubit, AdminStudentsState>(
          builder: (context, studentsState) {
            return BlocBuilder<AdminRequestsCubit, AdminRequestsState>(
              builder: (context, requestsState) {
                final courses = coursesState.courses;
                final totalLessons = courses.fold<int>(
                  0,
                  (sum, c) => sum + c.totalLessonsCount,
                );
                final students = studentsState is AdminStudentsLoaded
                    ? studentsState.students
                    : <RegisteredStudent>[];

                final enrolledStudentsCount = students
                    .where((s) => s.enrolledCourseIds.isNotEmpty)
                    .length;
                final pendingCount = requestsState is AdminRequestsLoaded
                    ? requestsState.pendingCount
                    : 0;

                if (coursesState is AdminCoursesLoading && courses.isEmpty) {
                  return AppLoadingIndicator(
                    message: 'courses.loading_courses'.tr(),
                  );
                }

                if (coursesState is AdminCoursesError && courses.isEmpty) {
                  return AppErrorState(
                    message: 'courses.courses_error'.tr(),
                    onRetry: context.read<AdminCoursesCubit>().loadCourses,
                  );
                }

                return RefreshIndicator(
                  color: AppColors.royalNavy,
                  onRefresh: () async {
                    context.read<AdminCoursesCubit>().loadCourses();
                    context.read<AdminRequestsCubit>().loadRequests();
                    await context.read<AdminStudentsCubit>().loadStudents();
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(top: 16, bottom: 88),
                    children: [
                      ResponsiveCenter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            DashboardHeroKpiCard(
                              totalCourses: courses.length,
                              totalLessons: totalLessons,
                              totalStudents: students.length,
                              enrolledStudents: enrolledStudentsCount,
                              pendingRequestsCount: pendingCount,
                              onReviewRequests: () => onSelectTab?.call(4),
                            ),
                            const SizedBox(height: 18),
                            DashboardQuickActions(
                              onGoToRequests: () => onSelectTab?.call(4),
                              onGoToAssignments: () => onSelectTab?.call(1),
                              onGoToAnalytics: () => onSelectTab?.call(2),
                              pendingRequestsCount: pendingCount,
                            ),
                            const SizedBox(height: 24),
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 12,
                              runSpacing: 10,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 4,
                                      height: 18,
                                      decoration: BoxDecoration(
                                        color: AppColors.royalNavy,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'courses.title'.tr(),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.royalNavy,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 9,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                  ),
                                  onPressed: () {
                                    context.push(AppRoutes.createCourse);
                                  },
                                  icon: const Icon(Icons.add_rounded, size: 18),
                                  label: Text(
                                    'courses.create_course'.tr(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            if (courses.isEmpty)
                              AppEmptyState(
                                icon: Icons.school_outlined,
                                title: 'courses.no_courses'.tr(),
                                subtitle: 'courses.no_courses_desc'.tr(),
                                actionButtonText: 'courses.create_course'.tr(),
                                onActionButtonPressed: () =>
                                    context.push(AppRoutes.createCourse),
                              )
                            else
                              ResponsiveCardGrid(
                                minItemWidth: 380,
                                maxColumns: 2,
                                mainAxisSpacing: 4,
                                children: courses.map((course) {
                                  final realEnrolledForThisCourse = students
                                      .where((s) => s.isEnrolled(course.id))
                                      .length;
                                  return CourseCardItem(
                                    course: course,
                                    enrolledCount: realEnrolledForThisCourse,
                                  );
                                }).toList(),
                              ),
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
    );
  }
}
