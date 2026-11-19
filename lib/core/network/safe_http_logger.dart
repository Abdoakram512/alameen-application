import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Metadata-only logging: never inspects headers, payloads, filenames or errors.
/// Unknown URL segments are hidden because they may contain personal data.
class SafeHttpLogger extends Interceptor {
  SafeHttpLogger({void Function(String)? output})
    : _output = output ?? debugPrint;
  final void Function(String) _output;
  static const _clockKey = 'safeHttpStopwatch';
  static const _routes = {
    'api',
    'v1',
    'student',
    'public',
    'auth',
    'login',
    'logout',
    'register',
    'courses',
    'videos',
    'lessons',
    'receipt',
    'receipts',
    'assignments',
    'submit',
    'submissions',
    'grades',
    'progress',
    'playback',
    'dashboard',
    'profile',
    'me',
    'bootstrap',
    'home',
    'contact',
    'notifications',
  };

  String _path(RequestOptions options) {
    final path = Uri.tryParse(options.path)?.path ?? '';
    return path
        .split('/')
        .map((s) => s.isEmpty || _routes.contains(s) ? s : '[redacted]')
        .join('/');
  }

  void _log(
    String color,
    String event,
    RequestOptions options, {
    int? status,
    String? kind,
  }) {
    if (!kDebugMode) return;
    final clock = options.extra[_clockKey];
    final elapsed = clock is Stopwatch ? clock.elapsedMilliseconds : 0;
    _output(
      '\x1B[${color}mHTTP $event ${options.method} ${_path(options)} '
      'status=${status ?? "-"} ${elapsed}ms '
      '${kind ?? ""} headers/body/query/files=[redacted]\x1B[0m',
    );
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      options.extra[_clockKey] = Stopwatch()..start();
      _log('36', 'REQUEST', options);
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _log(
      '32',
      'RESPONSE',
      response.requestOptions,
      status: response.statusCode,
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _log(
      '31',
      'ERROR',
      err.requestOptions,
      status: err.response?.statusCode,
      kind: err.type.name,
    );
    handler.next(err);
  }
}
