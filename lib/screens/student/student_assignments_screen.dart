import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/injection_container.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_error_view.dart';
import '../../core/widgets/app_loading_indicator.dart';
import '../../logic/assignments/assignments_cubit.dart';
import '../../logic/assignments/assignments_state.dart';
import '../../logic/auth/auth_cubit.dart';
import '../../logic/auth/auth_state.dart';
import '../../models/assignment.dart';
import '../../models/clinical_task_data.dart';
import '../../models/user_profile.dart';
import '../../repositories/student_assignments_repository.dart';
import 'assignments_widgets/pending_assignments_tab_view.dart';
import 'assignments_widgets/student_assignments_kpi_header.dart';
import 'assignments_widgets/submissions_history_tab_view.dart';
import 'widgets/submit_assignment_sheet.dart';

/// شاشة التكليفات والتقييمات السريرية للطالب.
///
/// قاعدة معمارية:
/// خادم Laravel هو المصدر الأوحد للمهام والتسليمات والدرجات.
/// الواجهة لا تُصنّع أي تكليفات محلية ولا تستدعي المستودعات مباشرة،
/// بل تعتمد كلياً على [AssignmentsCubit] وتستعرض حالة العرض غير القابلة للتعديل.
class StudentAssignmentsScreen extends StatefulWidget {
  final AssignmentsCubit? cubit;

  const StudentAssignmentsScreen({
    super.key,
    this.cubit,
  });

  @override
  State<StudentAssignmentsScreen> createState() =>
      _StudentAssignmentsScreenState();
}

class _StudentAssignmentsScreenState extends State<StudentAssignmentsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final AssignmentsCubit _cubit;
  bool _ownsCubit = false;
  String? _lastStudentId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    if (widget.cubit != null) {
      _cubit = widget.cubit!;
    } else if (sl.isRegistered<AssignmentsCubit>()) {
      _cubit = sl<AssignmentsCubit>();
      _ownsCubit = true;
    } else {
      _cubit = AssignmentsCubit(
        repository: sl<StudentAssignmentsRepository>(),
      );
      _ownsCubit = true;
    }

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
      child: BlocListener<AuthCubit, AuthState>(
        listener: (context, authState) {
          if (authState is Authenticated) {
            final uid = authState.user.uid;
            if (_lastStudentId != uid) {
              _lastStudentId = uid;
              _cubit.loadAssignments(reset: false);
            }
          }
        },
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

              return BlocBuilder<AssignmentsCubit, AssignmentsState>(
                builder: (context, asgState) {
                  if (asgState is AssignmentsLoading) {
                    return const Center(
                      child: AppLoadingIndicator(
                        message: 'جاري تحميل التكليفات والتقييمات المعتمدة...',
                      ),
                    );
                  }

                  if (asgState is AssignmentsError) {
                    return AppErrorView(
                      message: asgState.message,
                      onRetry: () => _cubit.loadAssignments(),
                    );
                  }

                  final data = asgState is AssignmentsLoaded
                      ? asgState.data
                      : const StudentAssignmentsData();

                  final pendingAssignments = data.pendingTasks;
                  final submissions = data.submissions;
                  final avgScore = data.averageScore;
                  final submittedCount = data.submittedCount;
                  final pendingCount = data.pendingCount;

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
                              // Tab 1: الواجبات والتطبيقات المطلوبة من الخادم
                              PendingAssignmentsTabView(
                                assignments: pendingAssignments,
                                onOpenSubmit: (asg) => _openSubmitSheet(
                                  context,
                                  asg,
                                  currentUser,
                                ),
                              ),

                              // Tab 2: المسلّمة والتقييمات المعتمدة من الخادم
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
          ),
        ),
      ),
    );
  }
}
