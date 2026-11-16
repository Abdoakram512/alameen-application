import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/responsive/responsive_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../../../logic/courses/admin_courses_cubit.dart';
import '../../../logic/courses/admin_courses_state.dart';
import '../../../logic/students/admin_students_cubit.dart';
import '../../../models/registered_student.dart';

class StudentCoursesTabView extends StatelessWidget {
  final RegisteredStudent student;

  const StudentCoursesTabView({super.key, required this.student});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AdminCoursesCubit, AdminCoursesState>(
      builder: (context, coursesState) {
        final courses = coursesState.courses;

        if (coursesState is AdminCoursesLoading && courses.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (courses.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('لا توجد كورسات متاحة حالياً لمنح الصلاحيات.'),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            ResponsiveCenter(
              maxWidth: 920,
              child: ResponsiveCardGrid(
                minItemWidth: 380,
                maxColumns: 2,
                mainAxisSpacing: 12,
                children: courses.map((course) {
                  final isEnrolled = student.isEnrolled(course.id);

                  return Card(
                    margin: EdgeInsets.zero,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: isEnrolled
                            ? AppColors.success.withValues(alpha: 0.4)
                            : Colors.grey.shade200,
                        width: isEnrolled ? 1.5 : 1,
                      ),
                    ),
                    color: isEnrolled ? AppColors.successLight : Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isEnrolled
                                    ? AppColors.success.withValues(alpha: 0.15)
                                    : Colors.grey.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isEnrolled
                                    ? Icons.check_circle
                                    : Icons.lock_outline,
                                color: isEnrolled
                                    ? AppColors.success
                                    : Colors.grey,
                                size: 22,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  course.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      '${course.levels.length} مستويات • ${course.totalLessonsCount} درس',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 1.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: course.price > 0
                                            ? AppColors.warningLight
                                            : AppColors.successLight,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        course.priceFormatted,
                                        style: TextStyle(
                                          color: course.price > 0
                                              ? AppColors.warningDark
                                              : AppColors.successDark,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 1.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: course.accessMode.badgeBg,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: course.accessMode.badgeBorder,
                                          width: 0.6,
                                        ),
                                      ),
                                      child: Text(
                                        course.accessMode.labelAr,
                                        style: TextStyle(
                                          color: course.accessMode.badgeFg,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: isEnrolled
                                    ? AppColors.errorLight
                                    : AppColors.primary,
                                foregroundColor: isEnrolled
                                    ? AppColors.error
                                    : Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: isEnrolled
                                      ? const BorderSide(
                                          color: AppColors.errorBorder,
                                        )
                                      : BorderSide.none,
                                ),
                              ),
                              onPressed: () async {
                                final cubit = context.read<AdminStudentsCubit>();
                                await HapticFeedback.lightImpact();
                                await cubit.toggleStudentCourse(
                                  student.id,
                                  course.id,
                                  isEnrolled,
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        isEnrolled
                                            ? 'تم إغلاق الوصول لكورس "${course.title}" عن المتدرب'
                                            : 'تم تفعيل كورس "${course.title}" للمتدرب بنجاح',
                                      ),
                                      backgroundColor: isEnrolled
                                          ? AppColors.warning
                                          : AppColors.success,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              },
                              child: Text(
                                isEnrolled ? 'إلغاء الوصول' : 'منح الصلاحية',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }
}
