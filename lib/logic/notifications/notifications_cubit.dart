import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/network/api_exceptions.dart';
import '../../models/app_notification.dart';
import '../../repositories/student_notifications_repository.dart';
import 'notifications_state.dart';

class NotificationsCubit extends Cubit<NotificationsState> {
  final StudentNotificationsRepository _repository;

  NotificationsCubit({
    required StudentNotificationsRepository repository,
  })  : _repository = repository,
        super(const NotificationsInitial());

  Future<void> loadNotifications({
    String filter = 'all',
    bool reset = true,
  }) async {
    if (reset) {
      emit(const NotificationsLoading());
    }

    try {
      final data = await _repository.getNotifications(
        filter: filter,
        page: 1,
        perPage: 15,
      );

      emit(NotificationsLoaded(
        notifications: data.notifications,
        unreadCount: data.unreadCount,
        filter: filter,
        currentPage: data.pagination?.currentPage ?? 1,
        lastPage: data.pagination?.lastPage ?? 1,
      ));
    } on ApiException catch (e) {
      emit(NotificationsError(e.message));
    } catch (e) {
      emit(const NotificationsError('تعذر تحميل الإشعارات. يرجى التحقق من اتصالك بالإنترنت.'));
    }
  }

  Future<void> changeFilter(String filter) async {
    await loadNotifications(filter: filter, reset: true);
  }

  Future<void> loadMore() async {
    final currentState = state;
    if (currentState is! NotificationsLoaded ||
        currentState.isLoadingMore ||
        !currentState.hasMore) {
      return;
    }

    emit(currentState.copyWith(isLoadingMore: true));

    try {
      final nextPage = currentState.currentPage + 1;
      final data = await _repository.getNotifications(
        filter: currentState.filter,
        page: nextPage,
        perPage: 15,
      );

      final combined = List<AppNotification>.from(currentState.notifications)
        ..addAll(data.notifications);

      emit(currentState.copyWith(
        notifications: combined,
        unreadCount: data.unreadCount,
        currentPage: nextPage,
        lastPage: data.pagination?.lastPage ?? nextPage,
        isLoadingMore: false,
      ));
    } catch (_) {
      emit(currentState.copyWith(isLoadingMore: false));
    }
  }

  Future<void> markAsRead(String id) async {
    final currentState = state;
    try {
      await _repository.markAsRead(id);
      if (currentState is NotificationsLoaded) {
        final updated = currentState.notifications.map((n) {
          if (n.id == id) {
            return n.copyWith(isRead: true);
          }
          return n;
        }).toList();

        final newUnread = currentState.unreadCount > 0
            ? currentState.unreadCount - 1
            : 0;

        emit(currentState.copyWith(
          notifications: updated,
          unreadCount: newUnread,
        ));
      }
    } catch (_) {}
  }

  Future<void> markAllAsRead() async {
    final currentState = state;
    try {
      await _repository.markAllAsRead();
      if (currentState is NotificationsLoaded) {
        final updated = currentState.notifications
            .map((n) => n.copyWith(isRead: true))
            .toList();

        emit(currentState.copyWith(
          notifications: updated,
          unreadCount: 0,
        ));
      }
    } catch (e) {
      if (e is ApiException) {
        emit(NotificationsError(e.message));
      } else {
        emit(const NotificationsError('تعذر تحديد جميع الإشعارات كمقروءة.'));
      }
    }
  }

  Future<void> deleteNotification(String id) async {
    final currentState = state;
    try {
      await _repository.deleteNotification(id);
      if (currentState is NotificationsLoaded) {
        final target = currentState.notifications.firstWhere(
          (n) => n.id == id,
          orElse: () => const AppNotification(id: '', type: '', title: '', message: ''),
        );
        final wasUnread = !target.isRead && target.id.isNotEmpty;

        final updated = currentState.notifications
            .where((n) => n.id != id)
            .toList();

        final newUnread = wasUnread && currentState.unreadCount > 0
            ? currentState.unreadCount - 1
            : currentState.unreadCount;

        emit(currentState.copyWith(
          notifications: updated,
          unreadCount: newUnread,
        ));
      }
    } catch (e) {
      if (e is ApiException) {
        emit(NotificationsError(e.message));
      }
    }
  }
}
