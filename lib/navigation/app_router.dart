import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../core/responsive/responsive_layout.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../logic/auth/auth_cubit.dart';
import '../logic/auth/auth_state.dart';
import '../screens/auth/student_login_screen.dart';
import '../screens/auth/student_register_screen.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/student/course_details_screen.dart';
import '../screens/student/student_home_screen.dart';
import '../screens/student/student_profile_screen.dart';
import 'student_route_policy.dart';

GoRouter createStudentRouter(AuthCubit authCubit) {
  final policy = StudentRoutePolicy();
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: GoRouterRefreshStream(authCubit.stream),
    redirect: (context, state) => policy.redirect(
      state.uri,
      signedIn: authCubit.state is Authenticated,
      resolving:
          authCubit.state is AuthInitial || authCubit.state is AuthLoading,
    ),
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
        path: '/',
        builder: (context, state) => const StudentMainNavigationScaffold(),
        routes: [
          GoRoute(
            path: 'course/:id',
            builder: (context, state) {
              final courseId = state.pathParameters['id'] ?? '';
              return CourseDetailsScreen(courseId: courseId);
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
                                'assets/images/website-logo.png',
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
                        destinations: const [
                          NavigationRailDestination(
                            icon: Icon(PhosphorIconsRegular.graduationCap),
                            selectedIcon: Icon(PhosphorIconsFill.graduationCap),
                            label: Text('الدورات التدريبية'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(PhosphorIconsRegular.chartPolar),
                            selectedIcon: Icon(PhosphorIconsFill.chartPolar),
                            label: Text('ملفي وتحليلي'),
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
                child: NavigationBar(
                  backgroundColor: Colors.white,
                  elevation: 0,
                  indicatorColor: AppColors.primaryLight,
                  selectedIndex: _selectedTabIndex,
                  onDestinationSelected: (idx) {
                    setState(() => _selectedTabIndex = idx);
                  },
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(PhosphorIconsRegular.graduationCap),
                      selectedIcon: Icon(
                        PhosphorIconsFill.graduationCap,
                        color: AppColors.primary,
                      ),
                      label: 'الدورات',
                    ),
                    NavigationDestination(
                      icon: Icon(PhosphorIconsRegular.chartPolar),
                      selectedIcon: Icon(
                        PhosphorIconsFill.chartPolar,
                        color: AppColors.primary,
                      ),
                      label: 'ملفي وتحليلي',
                    ),
                  ],
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
