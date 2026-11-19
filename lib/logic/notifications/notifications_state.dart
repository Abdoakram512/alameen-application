import 'package:equatable/equatable.dart';
import '../../models/app_notification.dart';

abstract class NotificationsState extends Equatable {
  const NotificationsState();

  @override
  List<Object?> get props => [];
}

class NotificationsInitial extends NotificationsState {
  const NotificationsInitial();
}

class NotificationsLoading extends NotificationsState {
  const NotificationsLoading();
}

class NotificationsLoaded extends NotificationsState {
  final List<AppNotification> notifications;
  final int unreadCount;
  final String filter;
  final int currentPage;
  final int lastPage;
  final bool isLoadingMore;

  const NotificationsLoaded({
    required this.notifications,
    required this.unreadCount,
    this.filter = 'all',
    this.currentPage = 1,
    this.lastPage = 1,
    this.isLoadingMore = false,
  });

  bool get hasMore => currentPage < lastPage;

  NotificationsLoaded copyWith({
    List<AppNotification>? notifications,
    int? unreadCount,
    String? filter,
    int? currentPage,
    int? lastPage,
    bool? isLoadingMore,
  }) {
    return NotificationsLoaded(
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      filter: filter ?? this.filter,
      currentPage: currentPage ?? this.currentPage,
      lastPage: lastPage ?? this.lastPage,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  List<Object?> get props => [
        notifications,
        unreadCount,
        filter,
        currentPage,
        lastPage,
        isLoadingMore,
      ];
}

class NotificationsError extends NotificationsState {
  final String message;

  const NotificationsError(this.message);

  @override
  List<Object?> get props => [message];
}
