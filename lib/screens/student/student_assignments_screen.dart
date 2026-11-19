import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/injection_container.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../logic/assignments/assignments_cubit.dart';
import '../../logic/assignments/assignments_state.dart';
import '../../logic/auth/auth_cubit.dart';
import '../../logic/auth/auth_state.dart';
import '../../logic/courses/courses_cubit.dart';
import '../../logic/courses/courses_state.dart';
import '../../models/assignment.dart';
import '../../models/assignment_submission.dart';
import '../../models/course.dart';
import '../../models/user_profile.dart';
import '../../repositories/student_assignments_repository.dart';
import '../../repositories/student_learning_repository.dart';
import 'assignments_widgets/pending_assignments_tab_view.dart';
import 'assignments_widgets/student_assignments_kpi_header.dart';
import 'assignments_widgets/submissions_history_tab_view.dart';
import 'widgets/submit_assignment_sheet.dart';

class StudentAssignmentsScreen extends StatefulWidget {
  final AssignmentsCubit? cubit;
  final StudentAssignmentsRepository? assignmentsRepository;
  final StudentLearningRepository? learningRepository;

  const StudentAssignmentsScreen({
    super.key,
    this.cubit,
    this.assignmentsRepository,
    this.learningRepository,
  });

  @override
  State<StudentAssignmentsScreen> createState() =>
      _StudentAssignmentsScreenState();
}

class _StudentAssignmentsScreenState extends State<StudentAssignmentsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final AssignmentsCubit _cubit;
  StudentLearningRepository? _learningRepo;
  bool _ownsCubit = false;

  Stream<List<AssignmentSubmission>>? _submissionsStream;
  String? _lastStudentId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    if (widget.cubit != null) {
      _cubit = widget.cubit!;
    } else if (widget.assignmentsRepository != null) {
      _cubit = AssignmentsCubit(repository: widget.assignmentsRepository!);
      _ownsCubit = true;
    } else if (sl.isRegistered<AssignmentsCubit>()) {
      _cubit = sl<AssignmentsCubit>();
      _ownsCubit = true;
    } else {
      _cubit = AssignmentsCubit(
        repository: sl<StudentAssignmentsRepository>(),
      );
      _ownsCubit = true;
    }

    _learningRepo = widget.learningRepository;

    _cubit.loadAssignments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    if (_ownsCubit) {
      _cubit.close();
    }
    super.dispose();
  }

  void _checkStream(String? uid) {
    if (uid != _lastStudentId && uid != null && uid.isNotEmpty) {
      _lastStudentId = uid;
      if (_learningRepo != null) {
        _submissionsStream = _learningRepo!.streamStudentSubmissions(uid);
      }
      _cubit.loadAssignments(reset: false);
    }
  }

  void _openSubmitSheet(
    BuildContext context,
    Assignment assignment,
    UserModel user,
  ) async {
    await showModalBottomSheet(
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
    _cubit.loadAssignments(reset: false);
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: Scaffold(
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

                return BlocBuilder<AssignmentsCubit, AssignmentsState>(
                  builder: (context, asgState) {
                    final serverTasks = asgState is AssignmentsLoaded
                        ? asgState.data.tasks
                        : const <Assignment>[];

                    return StreamBuilder<List<AssignmentSubmission>>(
                      stream: _submissionsStream,
                      builder: (context, subSnap) {
                        final serverSubs = asgState is AssignmentsLoaded
                            ? asgState.data.submissions
                            : const <AssignmentSubmission>[];
                        final submissions = serverSubs.isNotEmpty
                            ? serverSubs
                            : (subSnap.data ?? const <AssignmentSubmission>[]);
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

                        // تجمع كافة تكليفات الكورسات المشترك بها الطالب من خادم Laravel والمنهج
                        final Map<String, Assignment> combinedTasks = {};
                        for (final t in serverTasks) {
                          combinedTasks[t.id] = t;
                        }
                        for (final c in enrolledCourses) {
                          for (final lvl in c.levels) {
                            for (final lsn in lvl.lessons) {
                              if (lsn.hasAssignment) {
                                final asgId = lsn.assignmentId ?? 'asg_${lsn.id}';
                                combinedTasks.putIfAbsent(
                                  asgId,
                                  () => Assignment(
                                    id: asgId,
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
                        final allCourseAssignments = combinedTasks.values.toList();

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
            );
          },
        ),
      ),
    );
  }
}
