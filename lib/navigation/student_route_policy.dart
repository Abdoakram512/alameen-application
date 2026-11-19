String safeStudentDestination(String? value) {
  final uri = Uri.tryParse(value ?? '/');
  if (uri == null || uri.hasScheme || uri.hasAuthority) return '/';
  if (uri.path == '/') return '/';
  final segments = uri.pathSegments;
  if (segments.length == 1 &&
      (segments[0] == 'notifications' ||
          segments[0] == 'support' ||
          segments[0] == 'about' ||
          segments[0] == 'privacy-policy' ||
          segments[0] == 'faqs')) {
    return '/${segments[0]}';
  }
  if (segments.length == 2 && segments[0] == 'support') {
    return '/support/${segments[1]}';
  }
  if (segments.length != 2 ||
      segments[0] != 'course' ||
      segments[1].isEmpty ||
      segments[1] == '.' ||
      segments[1] == '..' ||
      segments[1].contains('/')) {
    return '/';
  }
  return Uri(pathSegments: ['', 'course', segments[1]]).toString();
}

String studentAuthLocation(String path, String? destination) => Uri(
  path: path,
  queryParameters: {'from': safeStudentDestination(destination)},
).toString();

class StudentRoutePolicy {
  String? _pending;
  String? redirect(
    Uri location, {
    required bool signedIn,
    required bool resolving,
  }) {
    final isAuth = location.path == '/login' || location.path == '/register';
    final isSplash = location.path == '/splash';
    if (resolving) {
      if (isAuth || isSplash) return null;
      _pending = safeStudentDestination(location.toString());
      return '/splash';
    }
    if (signedIn && (isAuth || isSplash)) {
      final target = safeStudentDestination(
        location.queryParameters['from'] ?? _pending,
      );
      _pending = null;
      return target;
    }
    if (!signedIn && !isAuth) {
      final target =
          _pending ??
          (isSplash ? '/' : safeStudentDestination(location.toString()));
      _pending = null;
      return studentAuthLocation('/login', target);
    }
    return null;
  }
}
