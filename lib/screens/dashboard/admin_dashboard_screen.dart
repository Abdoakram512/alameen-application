import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/responsive/responsive_layout.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/desktop_keyboard_scroller.dart';
import '../../logic/admins/admin_admins_cubit.dart';
import '../../logic/admins/admin_admins_state.dart';
import '../../logic/courses/admin_courses_cubit.dart';
import '../../logic/courses/admin_courses_state.dart';
import '../../logic/requests/admin_requests_cubit.dart';
import '../../logic/requests/admin_requests_state.dart';
import '../../logic/students/admin_students_cubit.dart';
import '../../logic/students/admin_students_state.dart';
import 'admin_welcome.dart';
import 'tabs/admins_tab.dart';
import 'tabs/analytics_tab.dart';
import 'tabs/assignments_tab.dart';
import 'tabs/courses_tab.dart';
import 'tabs/profile_tab.dart';
import 'tabs/requests_tab.dart';
import 'tabs/students_tab.dart';
import 'widgets/dashboard_app_bar.dart';
import 'widgets/dashboard_bottom_nav_bar.dart';
import 'widgets/dashboard_side_nav_rail.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        showAdminWelcome(context);
        final coursesCubit = context.read<AdminCoursesCubit>();
        if (coursesCubit.state is! AdminCoursesLoaded) {
          coursesCubit.loadCourses();
        }
        final studentsCubit = context.read<AdminStudentsCubit>();
        if (studentsCubit.state is! AdminStudentsLoaded) {
          studentsCubit.loadStudents();
        }
        final requestsCubit = context.read<AdminRequestsCubit>();
        if (requestsCubit.state is! AdminRequestsLoaded) {
          requestsCubit.loadRequests();
        }
        final adminsCubit = context.read<AdminAdminsCubit>();
        if (adminsCubit.state is! AdminAdminsLoaded) {
          adminsCubit.loadAdmins();
        }
      }
    });
  }

  void _onTabChanged(int index) {
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final useSideRail = context.useNavigationRail;

    return MultiBlocListener(
      listeners: [
        BlocListener<AdminCoursesCubit, AdminCoursesState>(
          listener: (context, state) {
            if (state is AdminCoursesActionSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: AppColors.success,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            } else if (state is AdminCoursesError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: AppColors.error,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
        ),
        BlocListener<AdminRequestsCubit, AdminRequestsState>(
          listener: (context, state) {
            if (state is AdminRequestsActionSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: AppColors.success,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            } else if (state is AdminRequestsError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: AppColors.error,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
        ),
      ],
      child: BlocBuilder<AdminRequestsCubit, AdminRequestsState>(
        builder: (context, requestsState) {
          final pendingCount = requestsState is AdminRequestsLoaded
              ? requestsState.pendingCount
              : 0;

          final tabStack = DesktopKeyboardScroller(
            child: IndexedStack(
              index: _currentIndex,
              children: [
                CoursesTab(onSelectTab: _onTabChanged),
                AssignmentsTab(onBackToHome: () => _onTabChanged(0)),
                AnalyticsTab(onSelectTab: _onTabChanged),
                const StudentsTab(),
                const RequestsTab(),
                const ProfileTab(),
                const AdminsTab(),
              ],
            ),
          );

          return Scaffold(
            backgroundColor: AppColors.scaffoldBackground,
            appBar: DashboardAppBar(
              pendingCount: pendingCount,
              onOpenRequests: () => _onTabChanged(4),
            ),
            body: SafeArea(
              top: false,
              bottom: useSideRail,
              child: useSideRail
                  ? Row(
                      children: [
                        DashboardSideNavRail(
                          currentIndex: _currentIndex,
                          onIndexChanged: _onTabChanged,
                          pendingCount: pendingCount,
                        ),
                        Expanded(child: tabStack),
                      ],
                    )
                  : tabStack,
            ),
            bottomNavigationBar: useSideRail
                ? null
                : DashboardBottomNavBar(
                    currentIndex: _currentIndex,
                    onIndexChanged: _onTabChanged,
                    pendingCount: pendingCount,
                  ),
          );
        },
      ),
    );
  }
}
