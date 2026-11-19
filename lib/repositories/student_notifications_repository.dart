import 'package:flutter/foundation.dart';
import '../models/app_notification.dart';

abstract class StudentNotificationsRepository {
  /// Unread notifications count notifier for real-time app bar badge updates
  ValueListenable<int> get unreadCountListenable;

  /// Fetch paginated notifications with optional filter ('all', 'unread', 'read')
  Future<StudentNotificationsData> getNotifications({
    String filter = 'all',
    int page = 1,
    int perPage = 15,
    bool forceRefresh = false,
  });

  /// Refresh and return recent notifications (used by bell dropdown / preview)
  Future<RecentNotificationsData> getRecentNotifications({int limit = 8});

  /// Refresh unread count from server
  Future<int> refreshUnreadCount();

  /// Mark single notification as read
  Future<void> markAsRead(String id);

  /// Mark all notifications as read
  Future<int> markAllAsRead();

  /// Delete notification from inbox
  Future<void> deleteNotification(String id);

  /// Clear all cached data on student logout
  void clearCache();
}
