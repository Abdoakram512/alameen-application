import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/injection_container.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/feedback/app_error_state.dart';
import '../../features/courses/domain/entities/course_entitlement.dart';
import '../../features/courses/presentation/cubits/course_entitlement/course_entitlement_cubit.dart';
import '../../features/courses/presentation/cubits/course_entitlement/course_entitlement_state.dart';
import '../../features/payments/domain/entities/receipt_status.dart';
import '../../features/payments/presentation/cubits/receipt_submission/receipt_submission_cubit.dart';
import '../../features/payments/presentation/cubits/receipts/receipts_cubit.dart';
import '../../features/payments/presentation/cubits/receipts/receipts_state.dart';
import '../../logic/assignments/assignments_cubit.dart';
import '../../logic/assignments/assignments_state.dart';
import '../../logic/auth/auth_cubit.dart';
import '../../logic/auth/auth_state.dart';
import '../../logic/courses/courses_cubit.dart';
import '../../logic/courses/courses_state.dart';
import '../../models/assignment.dart';
import '../../models/course.dart';
import '../../models/course_access_mode.dart';
import '../../models/course_progress_policy.dart';
import '../../models/learning_history.dart';
import '../../models/lesson.dart';
import '../../models/user_profile.dart';
import '../../repositories/student_assignments_repository.dart';
// import 'course_details/widgets/course_assignments_section.dart';
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
  bool _loadingDetails = true;
  bool _detailsFailed = false;

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

    unawaited(_refreshCourseDetailsAndReceipts());
  }

  Future<void> _refreshCourseDetailsAndReceipts() async {
    final authCubit = context.read<AuthCubit>();
    final coursesCubit = context.read<CoursesCubit>();
    final entitlementCubit = context.read<CourseEntitlementCubit>();
    if (!_loadingDetails && mounted) setState(() => _loadingDetails = true);
    try {
      final detailed = await coursesCubit.loadCourseDetails(
        widget.courseId,
        authCubit: authCubit,
      );
      if (mounted) _detailsFailed = detailed == null;
      if (mounted && detailed != null && detailed.isDetailedFromAuthServer) {
        entitlementCubit.applyServerCourseDetails(detailed);
      }
    } finally {
      if (mounted) setState(() => _loadingDetails = false);
    }
  }

  @override
  void dispose() {
    if (_ownsAssignmentsCubit) {
      _assignmentsCubit.close();
    }
    super.dispose();
  }

  Future<void> _showRequestAccessModal(
    BuildContext context,
    Course course,
    UserModel user, {
    bool isResubmission = false,
  }) async {
    final submissionCubit = context.read<ReceiptSubmissionCubit>();
    submissionCubit.reset();

    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => BlocProvider<ReceiptSubmissionCubit>.value(
        value: submissionCubit,
        child: RequestAccessSheet(
          course: course,
          user: user,
          isResubmission: isResubmission,
        ),
      ),
    );

    if (submitted == true && context.mounted) {
      unawaited(context.read<ReceiptsCubit>().refresh(silent: true));
      unawaited(_refreshCourseDetailsAndReceipts());
    }
  }

  Future<void> _showSubmitAssignmentModal(
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
      builder: (_) => SubmitAssignmentSheet(assignment: assignment, user: user),
    );
    if (mounted) {
      // _assignmentsCubit.loadAssignments(reset: false);
    }
  }

  Future<void> _openLesson(
    BuildContext context,
    Course course,
    Lesson lesson,
    UserModel? currentUser, {
    required bool isEnrolled,
    required Set<String> completedLessonIds,
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

    final policyReason = CourseProgressPolicy.lessonLockReason(
      levels: course.levels,
      lesson: lesson,
      isEnrolled: isEnrolled,
      completedLessonIds: completedLessonIds,
      accessibleVideoIds: course.accessibleVideoIds,
      enforceServerAccessibleList: course.isDetailedFromAuthServer,
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
        await _assignmentsCubit.loadAssignments(reset: false);
        if (!context.mounted) return;
        final loadedAssignments = _assignmentsCubit.state is AssignmentsLoaded
            ? (_assignmentsCubit.state as AssignmentsLoaded).data.tasks
            : const <Assignment>[];
        Assignment? matched;
        for (final a in loadedAssignments) {
          if ((lesson.assignmentId != null &&
                  lesson.assignmentId!.isNotEmpty &&
                  a.id == lesson.assignmentId) ||
              a.lessonId == lesson.id) {
            matched = a;
            break;
          }
        }
        if (matched != null) {
          _showSubmitAssignmentModal(context, matched, currentUser);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'لا يوجد تكليف معتمد من الخادم مرتبط بهذه المحاضرة حالياً.',
              ),
              backgroundColor: Color(0xFFB45309),
            ),
          );
        }
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

    if (context.mounted) {
      await _refreshCourseDetailsAndReceipts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CoursesCubit, CoursesState>(
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
            final currentUser = authState is Authenticated
                ? authState.user
                : null;
            final isExpired =
                currentUser != null && currentUser.isCourseExpired(course.id);

            final allIds = course.allLessonIds;
            final completedSet =
                CourseProgressPolicy.effectiveCompletedLessonIds(
                  course: course,
                  userCompletedLessonIds: {...?currentUser?.completedLessonIds},
                );
            final completedInCourse =
                course.serverCompletedCount ??
                allIds.where(completedSet.contains).length;
            final progress = (course.serverProgressPercent != null)
                ? (course.serverProgressPercent! / 100.0).clamp(0.0, 1.0)
                : (allIds.isNotEmpty
                      ? (completedInCourse / allIds.length).clamp(0.0, 1.0)
                      : 0.0);

            return BlocBuilder<CourseEntitlementCubit, CourseEntitlementState>(
              builder: (context, entitlementState) {
                final entitlement = entitlementState.entitlementFor(course.id);
                final isEnrolled =
                    !isExpired && entitlement.canAccessProtectedContent;
                final isVerifying =
                    entitlement.status == CourseAccessState.loading;

                return BlocBuilder<ReceiptsCubit, ReceiptsState>(
                  builder: (context, receiptsState) {
                    final latestReceipt = receiptsState.historyOrNull
                        ?.latestForCourse(course.id);
                    final isResubmission =
                        latestReceipt?.status == ReceiptStatus.rejected;

                    Future<void> verifyEntitlement() async {
                      if (currentUser == null) return;
                      final result = await context
                          .read<CourseEntitlementCubit>()
                          .verifyCourseEntitlement(
                            courseId: course.id,
                            courseSlug: course.slug ?? course.id,
                            studentId: currentUser.uid,
                          );
                      if (!context.mounted) return;
                      if (result.canAccessProtectedContent) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              result.message ??
                                  'تم تأكيد اشتراكك في دورة "${course.title}" من الخادم بنجاح.',
                            ),
                            backgroundColor: AppColors.success,
                          ),
                        );
                        await _refreshCourseDetailsAndReceipts();
                      } else if (result.message != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(result.message!),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                    }

                    void handleRequestTap() {
                      if (currentUser == null) return;
                      if (course.accessMode == CourseAccessMode.open ||
                          course.autoEnrollStudents) {
                        unawaited(verifyEntitlement());
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
                      unawaited(
                        _showRequestAccessModal(
                          context,
                          course,
                          currentUser,
                          isResubmission: isResubmission,
                        ),
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

                    return Scaffold(
                      backgroundColor: AppColors.scaffoldBackground,
                      appBar: AppBar(title: Text(course.title)),
                      body: RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: _refreshCourseDetailsAndReceipts,
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                              if (_loadingDetails &&
                                                  course.levels.isEmpty)
                                                const Padding(
                                                  padding: EdgeInsets.all(24),
                                                  child: Center(
                                                    child:
                                                        CircularProgressIndicator(),
                                                  ),
                                                )
                                              else if (_detailsFailed &&
                                                  course.levels.isEmpty)
                                                TextButton(
                                                  onPressed:
                                                      _refreshCourseDetailsAndReceipts,
                                                  child: const Text(
                                                    'تعذر تحميل المستويات. اضغط لإعادة المحاولة.',
                                                  ),
                                                )
                                              else
                                                CourseCurriculumSection(
                                                  levels: course.levels,
                                                  isEnrolled: isEnrolled,
                                                  completedLessonIds:
                                                      completedSet,
                                                  accessibleVideoIds:
                                                      course.accessibleVideoIds,
                                                  enforceServerAccessibleList:
                                                      course
                                                          .isDetailedFromAuthServer,
                                                  onPlayLesson: (lesson) =>
                                                      _openLesson(
                                                        context,
                                                        course,
                                                        lesson,
                                                        currentUser,
                                                        isEnrolled: isEnrolled,
                                                        completedLessonIds:
                                                            completedSet,
                                                      ),
                                                  onLockedLessonTap:
                                                      handleLockedLessonTap,
                                                  onSequentialLockedLessonTap:
                                                      handleSequentialLockedTap,
                                                ),
                                              // CourseAssignmentsSection(
                                              //   courseId: course.id,
                                              //   studentId: currentUser?.uid,
                                              //   isEnrolled: isEnrolled,
                                              //   onSubmitTap: (assignment) async {
                                              //     if (currentUser != null) {
                                              //       await _showSubmitAssignmentModal(
                                              //         context,
                                              //         assignment,
                                              //         currentUser,
                                              //       );
                                              //     }
                                              //   },
                                              // ),
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
                                                entitlement: entitlement,
                                                latestReceipt: latestReceipt,
                                                isVerifyingEntitlement:
                                                    isVerifying,
                                                onRequestAccess:
                                                    handleRequestTap,
                                                onRetryVerification:
                                                    verifyEntitlement,
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
                                          entitlement: entitlement,
                                          latestReceipt: latestReceipt,
                                          isVerifyingEntitlement: isVerifying,
                                          onRequestAccess: handleRequestTap,
                                          onRetryVerification:
                                              verifyEntitlement,
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
                                        if (_loadingDetails &&
                                            course.levels.isEmpty)
                                          const Padding(
                                            padding: EdgeInsets.all(24),
                                            child: Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            ),
                                          )
                                        else if (_detailsFailed &&
                                            course.levels.isEmpty)
                                          TextButton(
                                            onPressed:
                                                _refreshCourseDetailsAndReceipts,
                                            child: const Text(
                                              'تعذر تحميل المستويات. اضغط لإعادة المحاولة.',
                                            ),
                                          )
                                        else
                                          CourseCurriculumSection(
                                            levels: course.levels,
                                            isEnrolled: isEnrolled,
                                            completedLessonIds: completedSet,
                                            accessibleVideoIds:
                                                course.accessibleVideoIds,
                                            enforceServerAccessibleList:
                                                course.isDetailedFromAuthServer,
                                            onPlayLesson: (lesson) =>
                                                _openLesson(
                                                  context,
                                                  course,
                                                  lesson,
                                                  currentUser,
                                                  isEnrolled: isEnrolled,
                                                  completedLessonIds:
                                                      completedSet,
                                                ),
                                            onLockedLessonTap:
                                                handleLockedLessonTap,
                                            onSequentialLockedLessonTap:
                                                handleSequentialLockedTap,
                                          ),
                                        // CourseAssignmentsSection(
                                        //   courseId: course.id,
                                        //   studentId: currentUser?.uid,
                                        //   isEnrolled: isEnrolled,
                                        //   onSubmitTap: (assignment) async {
                                        //     if (currentUser != null) {
                                        //       await _showSubmitAssignmentModal(
                                        //         context,
                                        //         assignment,
                                        //         currentUser,
                                        //       );
                                        //     }
                                        //   },
                                        // ),
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
    );
  }
}
