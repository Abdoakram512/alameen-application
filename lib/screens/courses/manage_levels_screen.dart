import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/feedback/app_error_state.dart';
import '../../logic/courses/admin_courses_cubit.dart';
import '../../logic/courses/admin_courses_state.dart';
import 'widgets/add_level_dialog.dart';
import 'widgets/course_assignments_sheet.dart';
import 'widgets/edit_course_dialog.dart';
import 'widgets/level_expansion_card.dart';

class ManageLevelsScreen extends StatelessWidget {
  final String courseId;

  const ManageLevelsScreen({super.key, required this.courseId});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AdminCoursesCubit, AdminCoursesState>(
      listener: (context, state) {
        if (state is AdminCoursesActionSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        } else if (state is AdminCoursesError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      },
      builder: (context, state) {
        final courses = state.courses;
        final courseIndex = courses.indexWhere((c) => c.id == courseId);

        if (state is AdminCoursesError && courses.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: Text('levels.manage_course_title'.tr())),
            body: AppErrorState(
              message: 'courses.courses_error'.tr(),
              onRetry: context.read<AdminCoursesCubit>().loadCourses,
            ),
          );
        }
        if (courseIndex == -1) {
          if (state is AdminCoursesLoading && courses.isEmpty) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return Scaffold(
            appBar: AppBar(title: Text('levels.manage_course_title'.tr())),
            body: Center(
              child: Text('levels.course_not_found'.tr()),
            ),
          );
        }

        final course = courses[courseIndex];

        return Scaffold(
          backgroundColor: AppColors.scaffoldBackground,
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${'levels.price_prefix'.tr()} ${course.priceFormatted}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.success,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            elevation: 0,
            backgroundColor: Colors.white,
            foregroundColor: AppColors.textPrimary,
            actions: [
              TextButton.icon(
                onPressed: () =>
                    CourseAssignmentsSheet.show(context, course: course),
                icon: const Icon(
                  PhosphorIconsRegular.clipboardText,
                  color: AppColors.primary,
                  size: 18,
                ),
                label: Text(
                  'levels.assignments'.tr(),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(
                  PhosphorIconsRegular.pencilSimpleLine,
                  color: AppColors.primary,
                  size: 20,
                ),
                tooltip: 'levels.edit_course_tooltip'.tr(),
                onPressed: () => EditCourseDialog.show(context, course: course),
              ),
            ],
          ),
          body: SafeArea(
            child: course.levels.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.layers_clear_outlined,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'levels.empty_levels'.tr(),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 14),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                            ),
                            onPressed: () => AddLevelDialog.show(
                              context,
                              courseId: course.id,
                              currentLevelsCount: course.levels.length,
                            ),
                            icon: const Icon(Icons.add),
                            label: Text('levels.add_level'.tr()),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 16, bottom: 88),
                    itemCount: course.levels.length,
                    itemBuilder: (context, index) {
                      final level = course.levels[index];
                      return ResponsiveCenter(
                        maxWidth: 920,
                        child: LevelExpansionCard(
                          courseId: courseId,
                          level: level,
                          index: index,
                        ),
                      );
                    },
                  ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            onPressed: () => AddLevelDialog.show(
              context,
              courseId: course.id,
              currentLevelsCount: course.levels.length,
            ),
            icon: const Icon(Icons.add),
            label: Text('levels.add_level'.tr()),
          ),
        );
      },
    );
  }
}
