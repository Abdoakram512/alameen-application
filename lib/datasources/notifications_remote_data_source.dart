import 'package:dio/dio.dart';
import '../core/network/api_client.dart';
import '../core/network/api_exceptions.dart';
import '../models/app_notification.dart';

abstract class NotificationsRemoteDataSource {
  Future<StudentNotificationsData> getNotifications({
    String filter = 'all',
    int page = 1,
    int perPage = 15,
  });

  Future<RecentNotificationsData> getRecentNotifications({int limit = 8});

  Future<void> markAsRead(String id);

  Future<int> markAllAsRead();

  Future<void> deleteNotification(String id);
}

class NotificationsRemoteDataSourceImpl implements NotificationsRemoteDataSource {
  final ApiClient _apiClient;

  NotificationsRemoteDataSourceImpl({required ApiClient apiClient})
      : _apiClient = apiClient;

  @override
  Future<StudentNotificationsData> getNotifications({
    String filter = 'all',
    int page = 1,
    int perPage = 15,
  }) async {
    try {
      final response = await _apiClient.get(
        '/student/notifications',
        queryParameters: {
          'filter': filter,
          'page': page,
          'per_page': perPage,
        },
      );

      final rawData = response.data;
      if (rawData is Map<String, dynamic>) {
        final innerData = rawData['data'];
        if (innerData is Map<String, dynamic>) {
          return StudentNotificationsData.fromJson(innerData);
        }
      }
      return const StudentNotificationsData(
        unreadCount: 0,
        notifications: [],
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  @override
  Future<RecentNotificationsData> getRecentNotifications({int limit = 8}) async {
    try {
      final response = await _apiClient.get(
        '/student/notifications/recent',
        queryParameters: {
          'limit': limit,
        },
      );

      final rawData = response.data;
      if (rawData is Map<String, dynamic>) {
        final innerData = rawData['data'];
        if (innerData is Map<String, dynamic>) {
          return RecentNotificationsData.fromJson(innerData);
        }
      }
      return const RecentNotificationsData(
        unreadCount: 0,
        notifications: [],
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  @override
  Future<void> markAsRead(String id) async {
    try {
      await _apiClient.post(
        '/student/notifications/$id/read',
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  @override
  Future<int> markAllAsRead() async {
    try {
      final response = await _apiClient.post(
        '/student/notifications/read-all',
      );
      final rawData = response.data;
      if (rawData is Map<String, dynamic>) {
        final innerData = rawData['data'];
        if (innerData is Map<String, dynamic> && innerData['marked_count'] is num) {
          return (innerData['marked_count'] as num).toInt();
        }
      }
      return 0;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  @override
  Future<void> deleteNotification(String id) async {
    try {
      await _apiClient.delete(
        '/student/notifications/$id',
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
