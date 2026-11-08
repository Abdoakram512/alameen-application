import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/responsive/responsive_layout.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/feedback/app_error_state.dart';
import '../../logic/access/access_cubit.dart';
import '../../logic/access/access_state.dart';
import '../../logic/auth/auth_cubit.dart';
import '../../logic/auth/auth_state.dart';
import '../../logic/courses/courses_cubit.dart';
import '../../logic/courses/courses_state.dart';
import '../../models/access_request.dart';
import '../../models/assignment.dart';
import '../../models/course.dart';
import '../../models/learning_history.dart';
import '../../models/lesson.dart';
import '../../models/user_profile.dart';
import 'course_details/widgets/course_assignments_section.dart';
import 'course_details/widgets/course_curriculum_section.dart';
import 'course_details/widgets/course_enrollment_status_card.dart';
import 'course_details/widgets/course_header_banner.dart';
import 'video_player_screen.dart';
import 'widgets/request_access_sheet.dart';
import 'widgets/submit_assignment_sheet.dart';

class CourseDetailsScreen extends StatelessWidget {
  final String courseId;

  const CourseDetailsScreen({super.key, required this.courseId});

  void _showRequestAccessModal(
    BuildContext context,
    Course course,
    UserModel user, {
    bool isResubmission = false,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => RequestAccessSheet(
        course: course,
        user: user,
        isResubmission: isResubmission,
      ),
    );
  }

  void _showSubmitAssignmentModal(
    BuildContext context,
    Assignment assignment,
    UserModel user,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => SubmitAssignmentSheet(
        assignment: assignment,
        user: user,
      ),
    );
  }

  void _openLesson(
    BuildContext context,
    Course course,
    Lesson lesson,
    UserModel? currentUser,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VideoPlayerScreen(
          lesson: lesson,
          courseId: course.id,
          courseTitle: course.title,
          currentUser: currentUser,
          playlist: orderedLessons(course),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AccessCubit, AccessState>(
      listener: (context, accessState) {
        if (accessState is AccessActionSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(accessState.message),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 4),
            ),
          );
        } else if (accessState is AccessError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(accessState.message),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      child: BlocBuilder<CoursesCubit, CoursesState>(
        builder: (context, coursesState) {
          if (coursesState is CoursesError) {
            return Scaffold(
              appBar: AppBar(title: const Text('تفاصيل الدورة')),
              body: AppErrorState(
                message: 'تحقق من اتصالك بالإنترنت ثم حاول مرة أخرى.',
                onRetry: context.read<CoursesCubit>().loadCourses,
              ),
            );
          }

          if (coursesState is! CoursesLoaded) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final Course? course = coursesState.allCourses
              .cast<Course?>()
              .firstWhere((c) => c?.id == courseId, orElse: () => null);

          if (course == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('تفاصيل الدورة')),
              body: const Center(child: Text('الدورة المطلوبة غير متوفرة حالياً.')),
            );
          }

          return BlocBuilder<AuthCubit, AuthState>(
            builder: (context, authState) {
              final currentUser =
                  authState is Authenticated ? authState.user : null;
              final isEnrolled = currentUser?.isEnrolled(course.id) ?? false;
              final allIds = course.allLessonIds;
              final completedSet = {...?currentUser?.completedLessonIds};
              final completedInCourse =
                  allIds.where(completedSet.contains).length;
              final progress =
                  currentUser?.calculateCourseProgress(allIds) ?? 0.0;

              return BlocBuilder<AccessCubit, AccessState>(
                builder: (context, accessState) {
                  CourseAccessRequest? accessRequest;
                  if (accessState is AccessLoaded) {
                    accessRequest = accessState.getRequest(course.id);
                  } else if (accessState is AccessLoading) {
                    accessRequest = accessState.requestsByCourse[course.id];
                  }
                  final isSubmitting = accessState is AccessLoading;
                  final isResubmission =
                      accessRequest?.status == AccessStatus.rejected;

                  void handleRequestTap() {
                    if (currentUser == null) return;
                    _showRequestAccessModal(
                      context,
                      course,
                      currentUser,
                      isResubmission: isResubmission,
                    );
                  }

                  void handleLockedLessonTap() {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'هذه المحاضرة متاحة للمشتركين في الدورة. يمكنك إرسال طلب الالتحاق لتفعيلها.',
                        ),
                      ),
                    );
                  }

                  final isDesktopSplit = context.screenWidth >= 980;

                  return Scaffold(
                    backgroundColor: AppColors.scaffoldBackground,
                    appBar: AppBar(
                      title: Text(
                        course.title,
                      ),
                    ),
                    body: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      children: [
                        ResponsiveCenter(
                          child: isDesktopSplit
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 7,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          CourseHeaderBanner(
                                            course: course,
                                            isEnrolled: isEnrolled,
                                          ),
                                          const SizedBox(height: 24),
                                          CourseCurriculumSection(
                                            levels: course.levels,
                                            isEnrolled: isEnrolled,
                                            completedLessonIds: completedSet,
                                            onPlayLesson: (lesson) =>
                                                _openLesson(
                                                  context,
                                                  course,
                                                  lesson,
                                                  currentUser,
                                                ),
                                            onLockedLessonTap:
                                                handleLockedLessonTap,
                                          ),
                                          CourseAssignmentsSection(
                                            courseId: course.id,
                                            studentId: currentUser?.uid,
                                            isEnrolled: isEnrolled,
                                            onSubmitTap: (assignment) {
                                              if (currentUser != null) {
                                                _showSubmitAssignmentModal(
                                                  context,
                                                  assignment,
                                                  currentUser,
                                                );
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 24),
                                    SizedBox(
                                      width: 360,
                                      child: CourseEnrollmentStatusCard(
                                        course: course,
                                        isEnrolled: isEnrolled,
                                        progress: progress,
                                        completedLessonsCount:
                                            completedInCourse,
                                        accessRequest: accessRequest,
                                        isSubmittingRequest: isSubmitting,
                                        onRequestAccess: handleRequestTap,
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    CourseHeaderBanner(
                                      course: course,
                                      isEnrolled: isEnrolled,
                                    ),
                                    const SizedBox(height: 16),
                                    CourseEnrollmentStatusCard(
                                      course: course,
                                      isEnrolled: isEnrolled,
                                      progress: progress,
                                      completedLessonsCount: completedInCourse,
                                      accessRequest: accessRequest,
                                      isSubmittingRequest: isSubmitting,
                                      onRequestAccess: handleRequestTap,
                                    ),
                                    const SizedBox(height: 22),
                                    CourseCurriculumSection(
                                      levels: course.levels,
                                      isEnrolled: isEnrolled,
                                      completedLessonIds: completedSet,
                                      onPlayLesson: (lesson) => _openLesson(
                                        context,
                                        course,
                                        lesson,
                                        currentUser,
                                      ),
                                      onLockedLessonTap: handleLockedLessonTap,
                                    ),
                                    CourseAssignmentsSection(
                                      courseId: course.id,
                                      studentId: currentUser?.uid,
                                      isEnrolled: isEnrolled,
                                      onSubmitTap: (assignment) {
                                        if (currentUser != null) {
                                          _showSubmitAssignmentModal(
                                            context,
                                            assignment,
                                            currentUser,
                                          );
                                        }
                                      },
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
      ),
    );
  }
}
