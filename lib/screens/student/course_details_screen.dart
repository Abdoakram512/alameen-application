import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/injection_container.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/feedback/app_error_state.dart';
import '../../logic/access/access_cubit.dart';
import '../../logic/access/access_state.dart';
import '../../logic/assignments/assignments_cubit.dart';
import '../../logic/assignments/assignments_state.dart';
import '../../logic/auth/auth_cubit.dart';
import '../../logic/auth/auth_state.dart';
import '../../logic/courses/courses_cubit.dart';
import '../../logic/courses/courses_state.dart';
import '../../models/access_request.dart';
import '../../models/assignment.dart';
import '../../models/assignment_submission.dart';
import '../../models/course.dart';
import '../../models/course_access_mode.dart';
import '../../models/course_progress_policy.dart';
import '../../models/learning_history.dart';
import '../../models/lesson.dart';
import '../../models/user_profile.dart';
import '../../repositories/student_assignments_repository.dart';
import 'course_details/widgets/course_assignments_section.dart';
import 'course_details/widgets/course_certificate_card.dart';
import 'course_details/widgets/course_curriculum_section.dart';
import 'course_details/widgets/course_enrollment_status_card.dart';
import 'course_details/widgets/course_header_banner.dart';
import 'video_player_screen.dart';
import 'widgets/request_access_sheet.dart';
import 'widgets/submit_assignment_sheet.dart';

class CourseDetailsScreen extends StatefulWidget {
  final String courseId;
  final AssignmentsCubit? assignmentsCubit;

  const CourseDetailsScreen({
    super.key,
    required this.courseId,
    this.assignmentsCubit,
  });

  @override
  State<CourseDetailsScreen> createState() => _CourseDetailsScreenState();
}

class _CourseDetailsScreenState extends State<CourseDetailsScreen> {
  late final AssignmentsCubit _assignmentsCubit;
  bool _ownsAssignmentsCubit = false;

  @override
  void initState() {
    super.initState();
    if (widget.assignmentsCubit != null) {
      _assignmentsCubit = widget.assignmentsCubit!;
    } else if (sl.isRegistered<AssignmentsCubit>()) {
      _assignmentsCubit = sl<AssignmentsCubit>();
      _ownsAssignmentsCubit = true;
    } else {
      _assignmentsCubit = AssignmentsCubit(
        repository: sl<StudentAssignmentsRepository>(),
      );
      _ownsAssignmentsCubit = true;
    }
    _assignmentsCubit.loadAssignments(reset: false);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final authCubit = context.read<AuthCubit>();
        context.read<CoursesCubit>().loadCourseDetails(
              widget.courseId,
              authCubit: authCubit,
            );
        context.read<AccessCubit>().loadStudentReceipts(silent: true);
      }
    });
  }

  @override
  void dispose() {
    if (_ownsAssignmentsCubit) {
      _assignmentsCubit.close();
    }
    super.dispose();
  }

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
  ) async {
    await showModalBottomSheet(
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
    if (mounted) {
      _assignmentsCubit.loadAssignments(reset: false);
    }
  }

  Future<void> _openLesson(
    BuildContext context,
    Course course,
    Lesson lesson,
    UserModel? currentUser, {
    required bool isEnrolled,
    required Set<String> completedLessonIds,
    Map<String, String> lockedReasons = const {},
  }) async {
    if (!lesson.isAvailableNow) {
      final msg = lesson.isScheduled
          ? 'هذه المحاضرة مجدولة وستتاح تلقائياً للطلاب في موعدها المحدد (${lesson.scheduledPublishAt!.year}/${lesson.scheduledPublishAt!.month.toString().padLeft(2, '0')}/${lesson.scheduledPublishAt!.day.toString().padLeft(2, '0')} - ${lesson.scheduledPublishAt!.hour.toString().padLeft(2, '0')}:${lesson.scheduledPublishAt!.minute.toString().padLeft(2, '0')})'
          : 'هذه المحاضرة غير متاحة حالياً (قيد الإعداد والمراجعة).';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: const Color(0xFF6B21A8),
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    if (lockedReasons.containsKey(lesson.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'course_details.must_submit_assignment_for_lesson'.tr(
              args: [lockedReasons[lesson.id] ?? ''],
            ),
          ),
          backgroundColor: const Color(0xFFB45309),
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    final policyReason = CourseProgressPolicy.lessonLockReason(
      levels: course.levels,
      lesson: lesson,
      isEnrolled: isEnrolled,
      completedLessonIds: completedLessonIds,
      accessibleVideoIds: course.accessibleVideoIds,
      enforceServerAccessibleList: course.isDetailedFromAuthServer,
      assignmentLockReasons: lockedReasons,
    );
    if (policyReason != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(policyReason),
          backgroundColor: const Color(0xFFB45309),
        ),
      );
      return;
    }

    if (lesson.isAssignmentLesson) {
      if (currentUser != null) {
        final taskAssignment = Assignment(
          id: (lesson.assignmentId != null && lesson.assignmentId!.isNotEmpty)
              ? lesson.assignmentId!
              : 'asg_${lesson.id}',
          courseId: course.id,
          courseTitle: course.title,
          lessonId: lesson.id,
          title: lesson.title,
          instructions: lesson.description,
          createdAt: DateTime.now(),
          blocksNextLesson: true,
        );
        _showSubmitAssignmentModal(context, taskAssignment, currentUser);
      }
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VideoPlayerScreen(
          lesson: lesson,
          courseId: course.id,
          courseSlug: course.slug,
          courseTitle: course.title,
          courseAccessMode: course.accessMode,
          currentUser: currentUser,
          playlist: orderedLessons(course),
          levels: course.levels,
        ),
      ),
    );

    // تحديث حالة فتح المستويات والتقدم مباشرة من الخادم بعد العودة من المشغل
    if (context.mounted) {
      final authCubit = context.read<AuthCubit>();
      final coursesCubit = context.read<CoursesCubit>();
      coursesCubit.loadCourseDetails(
        course.slug ?? course.id,
        authCubit: authCubit,
      );
    }
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
          final authCubit = context.read<AuthCubit>();
          context.read<CoursesCubit>().loadCourseDetails(
                widget.courseId,
                authCubit: authCubit,
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
              appBar: AppBar(title: Text('course_details.title'.tr())),
              body: AppErrorState(
                message: 'course_details.load_error'.tr(),
                onRetry: () => context.read<CoursesCubit>().loadCourses(),
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
              .firstWhere(
                (c) => c?.id == widget.courseId || c?.slug == widget.courseId,
                orElse: () => null,
              );

          if (course == null) {
            return Scaffold(
              appBar: AppBar(title: Text('course_details.title'.tr())),
              body: Center(child: Text('course_details.not_found'.tr())),
            );
          }

          return BlocBuilder<AuthCubit, AuthState>(
            builder: (context, authState) {
              final currentUser =
                  authState is Authenticated ? authState.user : null;
              final isExpired =
                  currentUser != null && currentUser.isCourseExpired(course.id);

              // صلاحية الاشتراك تصدر حصرياً من Laravel (has_enrolled عند جلب تفاصيل الطالب)،
              // ولا يُسمح لأي بيانات محلية قديمة بتجاوز رفض الخادم.
              final isEnrolled = !isExpired &&
                  (course.isDetailedFromAuthServer
                      ? course.hasEnrolled
                      : (course.hasEnrolled ||
                          (currentUser?.isEnrolled(course.id) ?? false)));

              final allIds = course.allLessonIds;
              final completedSet = CourseProgressPolicy.effectiveCompletedLessonIds(
                course: course,
                userCompletedLessonIds: {...?currentUser?.completedLessonIds},
              );
              final completedInCourse = course.serverCompletedCount ??
                  allIds.where(completedSet.contains).length;
              final progress = (course.serverProgressPercent != null)
                  ? (course.serverProgressPercent! / 100.0).clamp(0.0, 1.0)
                  : (allIds.isNotEmpty
                      ? (completedInCourse / allIds.length).clamp(0.0, 1.0)
                      : 0.0);

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
                    if (course.accessMode == CourseAccessMode.open ||
                        course.autoEnrollStudents) {
                      context.read<AccessCubit>().enrollInOpenCourse(
                            uid: currentUser.uid,
                            course: course,
                          );
                      return;
                    }
                    if (course.accessMode == CourseAccessMode.assignedOnly) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'course_details.assigned_only_warning'.tr(),
                          ),
                        ),
                      );
                      return;
                    }
                    _showRequestAccessModal(
                      context,
                      course,
                      currentUser,
                      isResubmission: isResubmission,
                    );
                  }

                  void handleLockedLessonTap() {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'course_details.locked_for_subscribers'.tr(),
                        ),
                      ),
                    );
                  }

                  void handleSequentialLockedTap(String reason) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(reason),
                        backgroundColor: const Color(0xFFB45309),
                        duration: const Duration(seconds: 4),
                      ),
                    );
                  }

                  final isDesktopSplit = context.screenWidth >= 980;

                  return BlocBuilder<AssignmentsCubit, AssignmentsState>(
                    bloc: _assignmentsCubit,
                    builder: (context, assignmentsState) {
                      final submissions = assignmentsState is AssignmentsLoaded
                          ? assignmentsState.data.submissions
                          : const <AssignmentSubmission>[];
                      final submittedAssignmentIds =
                          submissions.map((s) => s.assignmentId).toSet();

                      final ordered = orderedLessons(course);
                      final lockedReasons = <String, String>{};
                      String? blockingLessonTitle;

                      for (int i = 0; i < ordered.length; i++) {
                        final item = ordered[i];

                        if (blockingLessonTitle != null) {
                          lockedReasons[item.id] = blockingLessonTitle;
                          continue;
                        }

                        final requiresSubmission = item.isAssignmentLesson ||
                            (item.lockNextUntilSubmitted && item.hasAssignment);
                        final assignmentKey = (item.assignmentId != null &&
                                item.assignmentId!.isNotEmpty)
                            ? item.assignmentId!
                            : 'asg_${item.id}';
                        final isSubmitted =
                            submittedAssignmentIds.contains(assignmentKey) ||
                                submittedAssignmentIds.contains(item.id) ||
                                (item.assignmentId != null &&
                                    submittedAssignmentIds
                                        .contains(item.assignmentId));

                        if (requiresSubmission && !isSubmitted) {
                          blockingLessonTitle = item.title;
                        }
                      }

                      void handleAssignmentLockedLessonTap(String prevTitle) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'course_details.must_submit_assignment_for_lesson'.tr(
                                args: [prevTitle],
                              ),
                            ),
                            backgroundColor: const Color(0xFFB45309),
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      }

                      return Scaffold(
                        backgroundColor: AppColors.scaffoldBackground,
                        appBar: AppBar(
                          title: Text(
                            course.title,
                          ),
                        ),
                        body: RefreshIndicator(
                          color: AppColors.primary,
                          onRefresh: () async {
                            await context.read<CoursesCubit>().loadCourseDetails(
                                  course.slug ?? course.id,
                                  authCubit: context.read<AuthCubit>(),
                                );
                          },
                          child: ListView(
                            padding: EdgeInsets.fromLTRB(
                              0,
                              20,
                              0,
                              MediaQuery.paddingOf(context).bottom + 32,
                            ),
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
                                                  accessibleVideoIds:
                                                      course.accessibleVideoIds,
                                                  enforceServerAccessibleList:
                                                      course.isDetailedFromAuthServer,
                                                  lockedReasons: lockedReasons,
                                                  onPlayLesson: (lesson) =>
                                                      _openLesson(
                                                        context,
                                                        course,
                                                        lesson,
                                                        currentUser,
                                                        isEnrolled: isEnrolled,
                                                        completedLessonIds:
                                                            completedSet,
                                                        lockedReasons:
                                                            lockedReasons,
                                                      ),
                                                  onLockedLessonTap:
                                                      handleLockedLessonTap,
                                                  onAssignmentLockedLessonTap:
                                                      handleAssignmentLockedLessonTap,
                                                  onSequentialLockedLessonTap:
                                                      handleSequentialLockedTap,
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
                                            child: Column(
                                              children: [
                                                CourseEnrollmentStatusCard(
                                                  course: course,
                                                  isEnrolled: isEnrolled,
                                                  isExpired: isExpired,
                                                  progress: progress,
                                                  completedLessonsCount:
                                                      completedInCourse,
                                                  accessRequest: accessRequest,
                                                  isSubmittingRequest: isSubmitting,
                                                  onRequestAccess: handleRequestTap,
                                                ),
                                                if (isEnrolled)
                                                  CourseCertificateCard(
                                                    course: course,
                                                    user: currentUser,
                                                    completedLessonsCount:
                                                        completedInCourse,
                                                    totalLessonsCount:
                                                        course.totalLessonsCount,
                                                  ),
                                              ],
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
                                            isExpired: isExpired,
                                            progress: progress,
                                            completedLessonsCount:
                                                completedInCourse,
                                            accessRequest: accessRequest,
                                            isSubmittingRequest: isSubmitting,
                                            onRequestAccess: handleRequestTap,
                                          ),
                                          if (isEnrolled)
                                            CourseCertificateCard(
                                              course: course,
                                              user: currentUser,
                                              completedLessonsCount:
                                                  completedInCourse,
                                              totalLessonsCount:
                                                  course.totalLessonsCount,
                                            ),
                                          const SizedBox(height: 22),
                                          CourseCurriculumSection(
                                            levels: course.levels,
                                            isEnrolled: isEnrolled,
                                            completedLessonIds: completedSet,
                                            accessibleVideoIds:
                                                course.accessibleVideoIds,
                                            enforceServerAccessibleList:
                                                course.isDetailedFromAuthServer,
                                            lockedReasons: lockedReasons,
                                            onPlayLesson: (lesson) =>
                                                _openLesson(
                                              context,
                                              course,
                                              lesson,
                                              currentUser,
                                              isEnrolled: isEnrolled,
                                              completedLessonIds: completedSet,
                                              lockedReasons: lockedReasons,
                                            ),
                                            onLockedLessonTap:
                                                handleLockedLessonTap,
                                            onAssignmentLockedLessonTap:
                                                handleAssignmentLockedLessonTap,
                                            onSequentialLockedLessonTap:
                                                handleSequentialLockedTap,
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
                        ),
                      );
                    },
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
