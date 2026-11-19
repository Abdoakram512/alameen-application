import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import 'api_exceptions.dart';
import 'api_response.dart';
import 'auth_interceptor.dart';
import 'safe_http_logger.dart';

/// Central HTTP networking client wrapping [Dio] with automatic error mapping,
/// timeout configurations, token injection, and typed envelope parsing.
class ApiClient {
  final Dio _dio;

  ApiClient({
    Dio? dio,
    required AuthInterceptor authInterceptor,
    String? baseUrl,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: baseUrl ?? AppConfig.apiBaseUrl,
               connectTimeout: const Duration(seconds: 15),
               receiveTimeout: const Duration(seconds: 15),
               sendTimeout: const Duration(seconds: 15),
               headers: {'Accept': 'application/json'},
             ),
           ) {
    _dio.interceptors.add(authInterceptor);

    if (kDebugMode) {
      _dio.interceptors.add(SafeHttpLogger());
    }
  }

  /// Direct access to underlying [Dio] instance for advanced configurations or testing.
  Dio get dio => _dio;

  /// Perform a standard GET request.
  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.get(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Perform a standard POST request.
  Future<Response<dynamic>> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Perform a standard PUT request.
  Future<Response<dynamic>> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Perform a standard DELETE request.
  Future<Response<dynamic>> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.delete(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Upload files via multipart/form-data POST request.
  Future<Response<dynamic>> postMultipart(
    String path, {
    required FormData formData,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
  }) async {
    try {
      final multipartOptions = (options ?? Options()).copyWith(
        contentType: 'multipart/form-data',
      );

      return await _dio.post(
        path,
        data: formData,
        queryParameters: queryParameters,
        options: multipartOptions,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Convenience helper to execute a GET request and parse into strongly-typed [ApiResponse<T>].
  Future<ApiResponse<T>> getParsed<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    T Function(dynamic data)? fromDataJson,
  }) async {
    final response = await get(
      path,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
    return ApiResponse<T>.fromJson(response.data, fromDataJson: fromDataJson);
  }

  /// Convenience helper to execute a POST request and parse into strongly-typed [ApiResponse<T>].
  Future<ApiResponse<T>> postParsed<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    T Function(dynamic data)? fromDataJson,
  }) async {
    final response = await post(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
    return ApiResponse<T>.fromJson(response.data, fromDataJson: fromDataJson);
  }
}
