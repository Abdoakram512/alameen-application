import 'package:flutter/foundation.dart';

@immutable
class AppNotification {
  final String id;
  final String type;
  final String title;
  final String message;
  final String icon;
  final String color;
  final String? actionUrl;
  final String? actionLabel;
  final Map<String, dynamic>? meta;
  final bool isRead;
  final DateTime? readAt;
  final DateTime? createdAt;
  final String? timeAgo;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    this.icon = 'bell',
    this.color = 'primary',
    this.actionUrl,
    this.actionLabel,
    this.meta,
    this.isRead = false,
    this.readAt,
    this.createdAt,
    this.timeAgo,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final idStr = rawId?.toString() ?? '';

    final rawTitle = json['title']?.toString() ?? '';
    final rawMessage = json['message']?.toString() ??
        json['body']?.toString() ??
        '';

    final rawType = json['type']?.toString() ?? 'system';
    final rawIcon = json['icon']?.toString() ?? 'bell';
    final rawColor = json['color']?.toString() ?? 'primary';
    final rawActionUrl = json['action_url']?.toString();
    final rawActionLabel = json['action_label']?.toString() ??
        json['action_text']?.toString();

    final dynamic rawMeta = json['meta'] ?? json['data'];
    final Map<String, dynamic>? metaMap =
        rawMeta is Map<String, dynamic> ? rawMeta : null;

    final isReadBool = json['is_read'] == true || json['is_read'] == 1;

    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is DateTime) return val;
      return DateTime.tryParse(val.toString());
    }

    return AppNotification(
      id: idStr,
      type: rawType,
      title: rawTitle,
      message: rawMessage,
      icon: rawIcon,
      color: rawColor,
      actionUrl: rawActionUrl,
      actionLabel: rawActionLabel,
      meta: metaMap,
      isRead: isReadBool,
      readAt: parseDate(json['read_at']),
      createdAt: parseDate(json['created_at']),
      timeAgo: json['time_ago']?.toString() ??
          json['time_formatted']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'message': message,
      'icon': icon,
      'color': color,
      'action_url': actionUrl,
      'action_label': actionLabel,
      'meta': meta,
      'is_read': isRead,
      'read_at': readAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'time_ago': timeAgo,
    };
  }

  AppNotification copyWith({
    String? id,
    String? type,
    String? title,
    String? message,
    String? icon,
    String? color,
    String? actionUrl,
    String? actionLabel,
    Map<String, dynamic>? meta,
    bool? isRead,
    DateTime? readAt,
    DateTime? createdAt,
    String? timeAgo,
  }) {
    return AppNotification(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      actionUrl: actionUrl ?? this.actionUrl,
      actionLabel: actionLabel ?? this.actionLabel,
      meta: meta ?? this.meta,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt ?? this.createdAt,
      timeAgo: timeAgo ?? this.timeAgo,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppNotification &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          isRead == other.isRead;

  @override
  int get hashCode => id.hashCode ^ isRead.hashCode;
}

@immutable
class NotificationPaginationMeta {
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  const NotificationPaginationMeta({
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
  });

  factory NotificationPaginationMeta.fromJson(Map<String, dynamic> json) {
    return NotificationPaginationMeta(
      currentPage: _asInt(json['current_page'], 1),
      lastPage: _asInt(json['last_page'], 1),
      perPage: _asInt(json['per_page'], 15),
      total: _asInt(json['total'], 0),
    );
  }

  static int _asInt(dynamic v, int fallback) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }
}

@immutable
class StudentNotificationsData {
  final int unreadCount;
  final List<AppNotification> notifications;
  final NotificationPaginationMeta? pagination;

  const StudentNotificationsData({
    required this.unreadCount,
    required this.notifications,
    this.pagination,
  });

  factory StudentNotificationsData.fromJson(Map<String, dynamic> json) {
    final rawUnread = json['unread_count'];
    final unread = rawUnread is num ? rawUnread.toInt() : (int.tryParse('$rawUnread') ?? 0);

    final rawList = json['notifications'];
    final List<AppNotification> items = [];
    if (rawList is List) {
      for (final item in rawList) {
        if (item is Map<String, dynamic>) {
          items.add(AppNotification.fromJson(item));
        }
      }
    }

    final rawPagination = json['pagination'];
    final pagination = rawPagination is Map<String, dynamic>
        ? NotificationPaginationMeta.fromJson(rawPagination)
        : null;

    return StudentNotificationsData(
      unreadCount: unread,
      notifications: items,
      pagination: pagination,
    );
  }
}

@immutable
class RecentNotificationsData {
  final int unreadCount;
  final List<AppNotification> notifications;

  const RecentNotificationsData({
    required this.unreadCount,
    required this.notifications,
  });

  factory RecentNotificationsData.fromJson(Map<String, dynamic> json) {
    final rawUnread = json['unread_count'];
    final unread = rawUnread is num ? rawUnread.toInt() : (int.tryParse('$rawUnread') ?? 0);

    final rawList = json['notifications'];
    final List<AppNotification> items = [];
    if (rawList is List) {
      for (final item in rawList) {
        if (item is Map<String, dynamic>) {
          items.add(AppNotification.fromJson(item));
        }
      }
    }

    return RecentNotificationsData(
      unreadCount: unread,
      notifications: items,
    );
  }
}
