import 'package:flutter/foundation.dart';
import '../../datasources/notifications_remote_data_source.dart';
import '../../models/app_notification.dart';
import '../student_notifications_repository.dart';

class StudentNotificationsRepositoryImpl implements StudentNotificationsRepository {
  final NotificationsRemoteDataSource _remoteDataSource;
  final ValueNotifier<int> _unreadCountNotifier = ValueNotifier<int>(0);

  StudentNotificationsRepositoryImpl({
    required NotificationsRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  @override
  ValueListenable<int> get unreadCountListenable => _unreadCountNotifier;

  @override
  Future<StudentNotificationsData> getNotifications({
    String filter = 'all',
    int page = 1,
    int perPage = 15,
    bool forceRefresh = false,
  }) async {
    final data = await _remoteDataSource.getNotifications(
      filter: filter,
      page: page,
      perPage: perPage,
    );
    _unreadCountNotifier.value = data.unreadCount;
    return data;
  }

  @override
  Future<RecentNotificationsData> getRecentNotifications({int limit = 8}) async {
    final data = await _remoteDataSource.getRecentNotifications(limit: limit);
    _unreadCountNotifier.value = data.unreadCount;
    return data;
  }

  @override
  Future<int> refreshUnreadCount() async {
    try {
      final recent = await _remoteDataSource.getRecentNotifications(limit: 1);
      _unreadCountNotifier.value = recent.unreadCount;
      return recent.unreadCount;
    } catch (_) {
      return _unreadCountNotifier.value;
    }
  }

  @override
  Future<void> markAsRead(String id) async {
    await _remoteDataSource.markAsRead(id);
    if (_unreadCountNotifier.value > 0) {
      _unreadCountNotifier.value = _unreadCountNotifier.value - 1;
    }
  }

  @override
  Future<int> markAllAsRead() async {
    final count = await _remoteDataSource.markAllAsRead();
    _unreadCountNotifier.value = 0;
    return count;
  }

  @override
  Future<void> deleteNotification(String id) async {
    await _remoteDataSource.deleteNotification(id);
  }

  @override
  void clearCache() {
    _unreadCountNotifier.value = 0;
  }
}
