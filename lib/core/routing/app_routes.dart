abstract class AppRoutes {
  AppRoutes._();

  static const String splash = '/splash';
  static const String login = '/login';
  static const String dashboard = '/';
  static const String createCourse = '/course/create';
  static const String manageLevels = '/course/:id/levels';
  static const String studentDetail = '/students/:id';

  // Helper methods to generate parameterized URLs
  static String manageLevelsPath(String courseId) => '/course/$courseId/levels';
  static String studentDetailPath(String studentId) => '/students/$studentId';
}
