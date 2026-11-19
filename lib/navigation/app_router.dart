import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../core/di/injection_container.dart';
import '../core/responsive/responsive_layout.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../features/payments/presentation/cubits/receipt_submission/receipt_submission_cubit.dart';
import '../logic/auth/auth_cubit.dart';
import '../logic/auth/auth_state.dart';
import '../screens/auth/student_login_screen.dart';
import '../screens/auth/student_register_screen.dart';
import '../screens/debug/debug_api_test_screen.dart';
import '../screens/info/about_us_screen.dart';
import '../screens/info/faqs_screen.dart';
import '../screens/info/privacy_policy_screen.dart';
import '../screens/security/suspended_account_screen.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/student/course_details_screen.dart';
import '../screens/student/notifications/student_notifications_screen.dart';
import '../screens/student/student_analytics_screen.dart';
import '../screens/student/student_assignments_screen.dart';
import '../screens/student/student_home_screen.dart';
import '../screens/student/student_profile_screen.dart';
import '../screens/student/support/student_support_tickets_screen.dart';
import '../screens/student/support/ticket_conversation_screen.dart';
import 'student_route_policy.dart';

GoRouter createStudentRouter(AuthCubit authCubit) {
  final policy = StudentRoutePolicy();
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: GoRouterRefreshStream(authCubit.stream),
    redirect: (context, state) {
      final authState = authCubit.state;
      final isSuspended = (authState is Authenticated && authState.user.isSuspendedAccount) ||
          (authState is AuthSuspended);

      if (isSuspended) {
        if (state.uri.path == '/suspended') return null;
        return '/suspended';
      }
      if (state.uri.path == '/suspended' && !isSuspended) {
        return '/';
      }

      final isPending = authState is AuthPendingApproval;
      if (isPending) {
        if (state.uri.path == '/login' || state.uri.path == '/register') return null;
        return '/login';
      }

      return policy.redirect(
        state.uri,
        signedIn: authState is Authenticated,
        resolving:
            authState is AuthInitial || authState is AuthLoading,
      );
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const StudentLoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const StudentRegisterScreen(),
      ),
      GoRoute(
        path: '/suspended',
        builder: (context, state) => const SuspendedAccountScreen(),
      ),
      GoRoute(
        path: '/about',
        builder: (context, state) => const AboutUsScreen(),
      ),
      GoRoute(
        path: '/privacy-policy',
        builder: (context, state) => const PrivacyPolicyScreen(),
      ),
      GoRoute(
        path: '/faqs',
        builder: (context, state) => const FaqsScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const StudentNotificationsScreen(),
      ),
      GoRoute(
        path: '/support',
        builder: (context, state) => const StudentSupportTicketsScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (context, state) {
              final idStr = state.pathParameters['id'] ?? '0';
              final id = int.tryParse(idStr) ?? 0;
              return TicketConversationScreen(ticketId: id);
            },
          ),
        ],
      ),
      if (kDebugMode)
        GoRoute(
          path: '/debug-api-test',
          builder: (context, state) => const DebugApiTestScreen(),
        ),
      GoRoute(
        path: '/',
        builder: (context, state) => const StudentMainNavigationScaffold(),
        routes: [
          GoRoute(
            path: 'course/:id',
            builder: (context, state) {
              final courseId = state.pathParameters['id'] ?? '';
              return BlocProvider<ReceiptSubmissionCubit>(
                create: (_) => sl<ReceiptSubmissionCubit>(),
                child: CourseDetailsScreen(courseId: courseId),
              );
            },
          ),
        ],
      ),
    ],
  );
}

class StudentMainNavigationScaffold extends StatefulWidget {
  const StudentMainNavigationScaffold({super.key});

  @override
  State<StudentMainNavigationScaffold> createState() =>
      _StudentMainNavigationScaffoldState();
}

class _StudentMainNavigationScaffoldState
    extends State<StudentMainNavigationScaffold> {
  int _selectedTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final useRail = context.useNavigationRail;
    final pages = [
      const StudentHomeScreen(),
      const StudentAssignmentsScreen(),
      const StudentAnalyticsScreen(),
      StudentProfileScreen(
        onBrowseCourses: () => setState(() => _selectedTabIndex = 0),
      ),
    ];

    return Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
        body: useRail
            ? Row(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        left: BorderSide(
                          color: AppColors.borderHairline,
                          width: 1,
                        ),
                      ),
                    ),
                    child: SafeArea(
                      child: NavigationRail(
                        backgroundColor: Colors.white,
                        extended: context.isDesktop,
                        selectedIndex: _selectedTabIndex,
                        onDestinationSelected: (idx) {
                          setState(() => _selectedTabIndex = idx);
                        },
                        indicatorColor: AppColors.primaryLight,
                        selectedIconTheme: const IconThemeData(
                          color: AppColors.primary,
                        ),
                        selectedLabelTextStyle: AppTextStyles.bodyMedium
                            .copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                            ),
                        unselectedLabelTextStyle: AppTextStyles.bodyMedium,
                        leading: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                'assets/images/logo.png',
                                width: 38,
                                height: 38,
                              ),
                              if (context.isDesktop) ...[
                                const SizedBox(width: 10),
                                Text(
                                  'مركز الأمين',
                                  style: AppTextStyles.heading3.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        destinations: [
                          NavigationRailDestination(
                            icon: const Icon(PhosphorIconsRegular.graduationCap),
                            selectedIcon: const Icon(PhosphorIconsFill.graduationCap),
                            label: Text('nav.courses'.tr()),
                          ),
                          NavigationRailDestination(
                            icon: const Icon(PhosphorIconsRegular.clipboardText),
                            selectedIcon: const Icon(PhosphorIconsFill.clipboardText),
                            label: Text('nav.assignments'.tr()),
                          ),
                          NavigationRailDestination(
                            icon: const Icon(PhosphorIconsRegular.chartLineUp),
                            selectedIcon: const Icon(PhosphorIconsFill.chartLineUp),
                            label: Text('nav.analytics'.tr()),
                          ),
                          NavigationRailDestination(
                            icon: const Icon(PhosphorIconsRegular.user),
                            selectedIcon: const Icon(PhosphorIconsFill.user),
                            label: Text('nav.profile'.tr()),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: IndexedStack(
                      index: _selectedTabIndex,
                      children: pages,
                    ),
                  ),
                ],
              )
            : IndexedStack(
                index: _selectedTabIndex,
                children: pages,
              ),
        bottomNavigationBar: useRail
            ? null
            : Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: AppColors.borderHairline, width: 1),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: NavigationBar(
                    backgroundColor: Colors.white,
                    elevation: 0,
                    indicatorColor: AppColors.primaryLight,
                    selectedIndex: _selectedTabIndex,
                    onDestinationSelected: (idx) {
                      setState(() => _selectedTabIndex = idx);
                    },
                    destinations: [
                      NavigationDestination(
                        icon: const Icon(PhosphorIconsRegular.graduationCap),
                        selectedIcon: const Icon(
                          PhosphorIconsFill.graduationCap,
                          color: AppColors.primary,
                        ),
                        label: 'nav.courses'.tr(),
                      ),
                      NavigationDestination(
                        icon: const Icon(PhosphorIconsRegular.clipboardText),
                        selectedIcon: const Icon(
                          PhosphorIconsFill.clipboardText,
                          color: AppColors.primary,
                        ),
                        label: 'nav.assignments'.tr(),
                      ),
                      NavigationDestination(
                        icon: const Icon(PhosphorIconsRegular.chartLineUp),
                        selectedIcon: const Icon(
                          PhosphorIconsFill.chartLineUp,
                          color: AppColors.primary,
                        ),
                        label: 'nav.analytics'.tr(),
                      ),
                      NavigationDestination(
                        icon: const Icon(PhosphorIconsRegular.user),
                        selectedIcon: const Icon(
                          PhosphorIconsFill.user,
                          color: AppColors.primary,
                        ),
                        label: 'nav.profile'.tr(),
                      ),
                    ],
                  ),
                ),
              ),
      );
  }
}

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
      (dynamic _) => notifyListeners(),
    );
  }

  late final dynamic _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
