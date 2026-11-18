import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/injection_container.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../logic/auth/auth_cubit.dart';
import '../../logic/auth/auth_state.dart';
import '../../logic/courses/courses_cubit.dart';
import '../../logic/courses/courses_state.dart';
import '../../models/assignment.dart';
import '../../models/assignment_submission.dart';
import '../../models/course.dart';
import '../../models/user_profile.dart';
import '../../repositories/student_learning_repository.dart';
import 'assignments_widgets/pending_assignments_tab_view.dart';
import 'assignments_widgets/student_assignments_kpi_header.dart';
import 'assignments_widgets/submissions_history_tab_view.dart';
import 'widgets/submit_assignment_sheet.dart';

class StudentAssignmentsScreen extends StatefulWidget {
  const StudentAssignmentsScreen({super.key});

  @override
  State<StudentAssignmentsScreen> createState() =>
      _StudentAssignmentsScreenState();
}

class _StudentAssignmentsScreenState extends State<StudentAssignmentsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  Stream<List<AssignmentSubmission>>? _submissionsStream;
  String? _lastStudentId;

  StudentLearningRepository get _repository =>
      sl.isRegistered<StudentLearningRepository>()
          ? sl<StudentLearningRepository>()
          : StudentLearningRepositoryImpl();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _checkStream(String? uid) {
    if (uid != _lastStudentId && uid != null && uid.isNotEmpty) {
      _lastStudentId = uid;
      _submissionsStream = _repository.streamStudentSubmissions(uid);
    }
  }

  void _openSubmitSheet(
    BuildContext context,
    Assignment assignment,
    UserModel user,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SubmitAssignmentSheet(
        assignment: assignment,
        user: user,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text(
          'التكليفات والتقييمات',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w800,
          ),
          unselectedLabelStyle: AppTextStyles.bodyMedium,
          tabs: const [
            Tab(text: 'الواجبات والتطبيقات'),
            Tab(text: 'المسلّمة والتقييمات'),
          ],
        ),
      ),
      body: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, authState) {
          final currentUser =
              authState is Authenticated ? authState.user : null;
          if (currentUser == null) {
            return const Center(child: Text('يرجى تسجيل الدخول أولاً'));
          }

          _checkStream(currentUser.uid);

          return BlocBuilder<CoursesCubit, CoursesState>(
            builder: (context, coursesState) {
              final allCourses = coursesState is CoursesLoaded
                  ? coursesState.allCourses
                  : const <Course>[];
              final enrolledCourses = allCourses
                  .where((c) => currentUser.isEnrolled(c.id) || c.hasEnrolled)
                  .toList();

              return StreamBuilder<List<AssignmentSubmission>>(
                stream: _submissionsStream,
                builder: (context, subSnap) {
                  final submissions =
                      subSnap.data ?? const <AssignmentSubmission>[];
                  final gradedSubs = submissions
                      .where((s) => s.isGraded && s.score != null)
                      .toList();
                  final avgScore = gradedSubs.isEmpty
                      ? null
                      : (gradedSubs
                                  .map((s) => s.score!)
                                  .reduce((a, b) => a + b) /
                              gradedSubs.length)
                          .round();

                  // تجمع كافة تكليفات الكورسات المشترك بها الطالب
                  final allCourseAssignments = <Assignment>[];
                  for (final c in enrolledCourses) {
                    for (final lvl in c.levels) {
                      for (final lsn in lvl.lessons) {
                        if (lsn.hasAssignment) {
                          allCourseAssignments.add(
                            Assignment(
                              id: lsn.assignmentId ?? 'asg_${lsn.id}',
                              courseId: c.id,
                              courseTitle: c.title,
                              lessonId: lsn.id,
                              title: 'تكليف: ${lsn.title}',
                              instructions: lsn.description,
                              createdAt: DateTime.now(),
                            ),
                          );
                        }
                      }
                    }
                  }

                  final submittedIds =
                      submissions.map((s) => s.assignmentId).toSet();
                  final pendingAssignments = allCourseAssignments
                      .where((a) => !submittedIds.contains(a.id))
                      .toList();

                  final submittedCount = submissions.length;
                  final pendingCount = pendingAssignments.length;

                  return ResponsiveCenter(
                    child: Column(
                      children: [
                        // KPI Summary Header
                        StudentAssignmentsKpiHeader(
                          submittedCount: submittedCount,
                          pendingCount: pendingCount,
                          avgScore: avgScore,
                        ),

                        // Tab Views
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              // Tab 1: الواجبات والتطبيقات المطلوبة
                              PendingAssignmentsTabView(
                                assignments: pendingAssignments,
                                onOpenSubmit: (asg) => _openSubmitSheet(
                                  context,
                                  asg,
                                  currentUser,
                                ),
                              ),

                              // Tab 2: المسلّمة والتقييمات
                              SubmissionsHistoryTabView(
                                submissions: submissions,
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
