import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/responsive/responsive_layout.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../logic/auth/auth_cubit.dart';
import '../../logic/auth/auth_state.dart';
import '../../logic/courses/courses_cubit.dart';
import '../../logic/courses/courses_state.dart';
import '../../models/course.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/language_switch_button.dart';
import '../onboarding/onboarding_screen.dart';
import 'profile/widgets/edit_student_profile_sheet.dart';
import 'profile/widgets/enrolled_courses_section.dart';
import 'profile/widgets/student_analytics_overview_card.dart';
import 'profile/widgets/student_profile_header_card.dart';
import 'profile/widgets/student_requests_status_section.dart';
import 'profile/widgets/student_stats_grid.dart';
import 'profile/widgets/student_submissions_section.dart';

class StudentProfileScreen extends StatelessWidget {
  final VoidCallback? onBrowseCourses;

  const StudentProfileScreen({super.key, this.onBrowseCourses});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, authState) {
        final currentUser = authState is Authenticated ? authState.user : null;
        final displayName = currentUser?.displayName.trim().isNotEmpty == true
            ? currentUser!.displayName
            : 'متدرب مركز الأمين';
        final displayEmail = currentUser?.email.trim().isNotEmpty == true
            ? currentUser!.email
            : '';
        final displayPhone = currentUser?.phone ?? '';
        final avatarUrl = currentUser?.photoUrl ?? '';

        return BlocBuilder<CoursesCubit, CoursesState>(
          builder: (context, coursesState) {
            final enrolledCourses = <Course>[];
            if (coursesState is CoursesLoaded && currentUser != null) {
              enrolledCourses.addAll(
                coursesState.allCourses.where(
                  (c) => currentUser.isEnrolled(c.id),
                ),
              );
            }

            return Scaffold(
              backgroundColor: AppColors.scaffoldBackground,
              appBar: AppBar(
                title: Text('profile.title'.tr()),
                actions: [
                  const LanguageSwitchButton(compact: true),
                  const SizedBox(width: 4),
                  if (currentUser != null)
                    IconButton(
                      tooltip: 'profile.app_settings'.tr(),
                      icon: const Icon(
                        PhosphorIconsRegular.slidersHorizontal,
                        size: 21,
                      ),
                      onPressed: () {
                        EditStudentProfileSheet.show(
                          context,
                          initialName: displayName,
                          initialPhone: displayPhone,
                          email: displayEmail,
                        );
                      },
                    ),
                  IconButton(
                    tooltip: 'جولة تعريفية بالمنصة',
                    icon: const Icon(PhosphorIconsRegular.question, size: 21),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (pageContext) => OnboardingScreen(
                            onComplete: () async {
                              Navigator.of(pageContext).pop();
                            },
                          ),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    tooltip: 'auth.sign_out'.tr(),
                    icon: const Icon(
                      PhosphorIconsRegular.signOut,
                      color: AppColors.error,
                      size: 21,
                    ),
                    onPressed: () async {
                      final confirm = await AppDialogs.showConfirm(
                        context,
                        title: 'auth.sign_out'.tr(),
                        message: 'auth.sign_out_confirm'.tr(),
                        confirmText: 'auth.sign_out'.tr(),
                        cancelText: 'dialogs.cancel'.tr(),
                        isDestructive: true,
                      );
                      if (confirm && context.mounted) {
                        await context.read<AuthCubit>().signOut();
                      }
                    },
                  ),
                ],
              ),
              body: ListView(
                padding: const EdgeInsets.symmetric(vertical: 20),
                children: [
                  ResponsiveCenter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        StudentProfileHeaderCard(
                          displayName: displayName,
                          email: displayEmail,
                          phone: displayPhone,
                          avatarUrl: avatarUrl,
                          onEditTap: currentUser == null
                              ? null
                              : () {
                                  EditStudentProfileSheet.show(
                                    context,
                                    initialName: displayName,
                                    initialPhone: displayPhone,
                                    email: displayEmail,
                                  );
                                },
                        ),
                        const SizedBox(height: 16),
                        StudentStatsGrid(
                          enrolledCount: enrolledCourses.length,
                          completedLessonsCount:
                              currentUser?.completedLessonIds.length ?? 0,
                          watchTimeFormatted:
                              currentUser?.watchTimeFormatted ?? '0 دقيقة',
                        ),
                        const SizedBox(height: 24),
                        StudentAnalyticsOverviewCard(
                          currentUser: currentUser,
                          enrolledCourses: enrolledCourses,
                        ),
                        const SizedBox(height: 24),
                        EnrolledCoursesSection(
                          enrolledCourses: enrolledCourses,
                          currentUser: currentUser,
                          onBrowseCourses: onBrowseCourses,
                        ),
                        const SizedBox(height: 24),
                        const StudentRequestsStatusSection(),
                        StudentSubmissionsSection(studentId: currentUser?.uid),
                        const SizedBox(height: 28),
                        Center(
                          child: Text(
                            'مركز الأمين للتخاطب وتنمية المهارات',
                            style: AppTextStyles.caption,
                          ),
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
  }
}
