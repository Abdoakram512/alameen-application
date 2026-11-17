import 'package:dio/dio.dart';
import '../storage/secure_token_storage.dart';

/// Dio interceptor responsible for injecting Sanctum Bearer tokens and localization headers,
/// as well as handling unauthorized (401) responses.
class AuthInterceptor extends Interceptor {
  final SecureTokenStorage _tokenStorage;
  final void Function()? _onSessionExpired;

  AuthInterceptor({
    required SecureTokenStorage tokenStorage,
    void Function()? onSessionExpired,
  })  : _tokenStorage = tokenStorage,
        _onSessionExpired = onSessionExpired;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Inject standard Laravel API negotiation and locale headers
    options.headers['Accept'] = 'application/json';
    options.headers['X-Locale'] = 'ar';
    options.headers['Accept-Language'] = 'ar';

    // Check if request explicitly opts out of authentication (e.g. public endpoints)
    final bool skipAuth = options.extra['skipAuth'] == true;

    if (!skipAuth) {
      final token = await _tokenStorage.getToken();
      if (token != null && token.trim().isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }

    return handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // If the backend returns 401 Unauthorized, notify session expiration listener
    if (err.response?.statusCode == 401) {
      final bool skipAuth = err.requestOptions.extra['skipAuth'] == true;
      // Do not clear token if the 401 came from the login endpoint itself (invalid credentials)
      final bool isLoginEndpoint = err.requestOptions.path.contains('/auth/login');

      if (!skipAuth && !isLoginEndpoint) {
        await _tokenStorage.deleteToken();
        _onSessionExpired?.call();
      }
    }

    return handler.next(err);
  }
}
