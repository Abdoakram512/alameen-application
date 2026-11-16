import 'package:go_router/go_router.dart';

import '../../logic/auth/admin_auth_cubit.dart';
import '../../logic/auth/admin_auth_state.dart';
import '../../models/registered_student.dart';
import '../../screens/auth/admin_login_screen.dart';
import '../../screens/courses/create_course_screen.dart';
import '../../screens/courses/manage_levels_screen.dart';
import '../../screens/dashboard/admin_dashboard_screen.dart';
import '../../screens/splash/splash_screen.dart';
import '../../screens/students/student_detail_screen.dart';
import 'app_routes.dart';
import 'router_refresh_stream.dart';

GoRouter createAppRouter(AdminAuthCubit authCubit) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: GoRouterRefreshStream(authCubit.stream),
    redirect: (context, state) {
      final authState = authCubit.state;
      final isAuthenticated = authState is AdminAuthenticated;
      final isResolving =
          authState is AdminAuthInitial || authState is AdminAuthLoading;
      final isGoingToLogin = state.matchedLocation == AppRoutes.login;
      final isSplash = state.matchedLocation == AppRoutes.splash;

      // SplashScreen handles its own timing and initial handoff deterministically
      if (isSplash) {
        return null;
      }

      // If auth is still resolving and somehow outside splash, keep on splash
      if (isResolving) {
        return AppRoutes.splash;
      }

      if (!isAuthenticated && !isGoingToLogin) {
        return AppRoutes.login;
      }
      if (isAuthenticated && isGoingToLogin) {
        return AppRoutes.dashboard;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const AdminLoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.dashboard,
        builder: (context, state) => const AdminDashboardScreen(),
        routes: [
          GoRoute(
            path: 'course/create',
            builder: (context, state) => const CreateCourseScreen(),
          ),
          GoRoute(
            path: 'course/:id/levels',
            builder: (context, state) {
              final courseId = state.pathParameters['id'] ?? '';
              return ManageLevelsScreen(courseId: courseId);
            },
          ),
          GoRoute(
            path: 'students/:id',
            builder: (context, state) {
              final student = state.extra as RegisteredStudent?;
              final studentId = state.pathParameters['id'] ?? '';

              if (student != null) {
                return StudentDetailScreen(student: student);
              }

              // Fallback if accessed via direct deep link without extra
              return StudentDetailScreen(
                student: RegisteredStudent(
                  id: studentId,
                  name: 'طالب',
                  email: '',
                  phone: '',
                  role: 'student',
                  joinedAt: DateTime.now(),
                  enrolledCourseIds: const [],
                  completedLessonIds: const {},
                ),
              );
            },
          ),
        ],
      ),
    ],
  );
}
