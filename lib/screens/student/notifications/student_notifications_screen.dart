import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../logic/notifications/notifications_cubit.dart';
import '../../../logic/notifications/notifications_state.dart';
import '../../../models/app_notification.dart';
import '../../../repositories/student_notifications_repository.dart';

class StudentNotificationsScreen extends StatefulWidget {
  final NotificationsCubit? cubit;
  final StudentNotificationsRepository? repository;

  const StudentNotificationsScreen({
    super.key,
    this.cubit,
    this.repository,
  });

  @override
  State<StudentNotificationsScreen> createState() => _StudentNotificationsScreenState();
}

class _StudentNotificationsScreenState extends State<StudentNotificationsScreen>
    with SingleTickerProviderStateMixin {
  late final NotificationsCubit _cubit;
  late final TabController _tabController;
  bool _ownsCubit = false;

  static const List<String> _filters = ['all', 'unread', 'read'];

  @override
  void initState() {
    super.initState();
    if (widget.cubit != null) {
      _cubit = widget.cubit!;
    } else if (widget.repository != null) {
      _cubit = NotificationsCubit(repository: widget.repository!);
      _ownsCubit = true;
    } else {
      _cubit = sl<NotificationsCubit>();
      _ownsCubit = true;
    }

    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
    _cubit.loadNotifications(filter: _currentFilter);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    if (_ownsCubit) {
      _cubit.close();
    }
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) return;
    _cubit.changeFilter(_currentFilter);
  }

  String get _currentFilter => _filters[_tabController.index];

  Future<void> _handleNotificationTap(AppNotification notification) async {
    if (!notification.isRead) {
      _cubit.markAsRead(notification.id);
    }

    if (!mounted) return;

    final actionUrl = notification.actionUrl;
    final meta = notification.meta;

    if (actionUrl != null && actionUrl.isNotEmpty) {
      if (actionUrl.startsWith('/')) {
        context.push(actionUrl);
        return;
      }
    }

    if (meta != null) {
      final courseId = meta['course_id'];
      if (courseId != null) {
        context.push('/course/$courseId');
        return;
      }
      final ticketId = meta['ticket_id'];
      if (ticketId != null) {
        context.push('/support/$ticketId');
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: BlocBuilder<NotificationsCubit, NotificationsState>(
        builder: (context, state) {
          final unreadCount = state is NotificationsLoaded ? state.unreadCount : 0;

          return Scaffold(
            backgroundColor: AppColors.scaffoldBackground,
            appBar: AppBar(
              title: const Text('الإشعارات والتنبيهات'),
              centerTitle: false,
              backgroundColor: Colors.white,
              elevation: 0,
              actions: [
                if (unreadCount > 0)
                  TextButton.icon(
                    onPressed: () => _cubit.markAllAsRead(),
                    icon: const Icon(PhosphorIconsRegular.checks, size: 18),
                    label: const Text(
                      'تحديد الكل كمقروء',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                    ),
                  ),
                const SizedBox(width: 8),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  color: Colors.white,
                  child: TabBar(
                    controller: _tabController,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: AppColors.textSecondary,
                    indicatorColor: AppColors.primary,
                    indicatorWeight: 3,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                    unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    tabs: [
                      const Tab(text: 'الكل'),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('غير المقروءة'),
                            if (unreadCount > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$unreadCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const Tab(text: 'المقروءة'),
                    ],
                  ),
                ),
              ),
            ),
            body: _buildBody(state),
          );
        },
      ),
    );
  }

  Widget _buildBody(NotificationsState state) {
    if (state is NotificationsLoading || state is NotificationsInitial) {
      return const AppLoadingIndicator(
        message: 'جاري تحميل الإشعارات...',
      );
    }

    if (state is NotificationsError) {
      return AppErrorView(
        message: state.message,
        onRetry: () => _cubit.loadNotifications(filter: _currentFilter),
      );
    }

    if (state is NotificationsLoaded) {
      final notifications = state.notifications;
      if (notifications.isEmpty) {
        return RefreshIndicator(
          onRefresh: () => _cubit.loadNotifications(filter: _currentFilter),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(height: MediaQuery.of(context).size.height * 0.18),
              AppEmptyState(
                defaultIconData: PhosphorIconsRegular.bellSlash,
                title: _tabController.index == 1
                    ? 'لا توجد إشعارات غير مقروءة'
                    : 'صندوق الإشعارات فارغ حالياً',
                description: 'ستصلك إشعارات وتحديثات الدورات والواجبات فور توفرها.',
                actionText: 'تحديث',
                onAction: () => _cubit.loadNotifications(filter: _currentFilter),
              ),
            ],
          ),
        );
      }

      return RefreshIndicator(
        onRefresh: () => _cubit.loadNotifications(filter: _currentFilter),
        child: NotificationListener<ScrollNotification>(
          onNotification: (ScrollNotification scrollInfo) {
            if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
              _cubit.loadMore();
            }
            return false;
          },
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            itemCount: notifications.length + (state.isLoadingMore ? 1 : 0),
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (index >= notifications.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }

              final notification = notifications[index];
              return _buildNotificationCard(notification);
            },
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildNotificationCard(AppNotification notification) {
    final (iconData, iconBgColor, iconFgColor) = _resolveVisuals(notification);

    return Dismissible(
      key: Key('notif_${notification.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(PhosphorIconsRegular.trash, color: Colors.white, size: 24),
      ),
      onDismissed: (_) {
        _cubit.deleteNotification(notification.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حذف الإشعار من البريد الوارد'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: Material(
        color: notification.isRead ? Colors.white : const Color(0xFFF4F7FC),
        borderRadius: BorderRadius.circular(14),
        elevation: notification.isRead ? 0.5 : 1,
        child: InkWell(
          onTap: () => _handleNotificationTap(notification),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: notification.isRead
                    ? AppColors.borderHairline
                    : AppColors.primary.withValues(alpha: 0.35),
                width: notification.isRead ? 1 : 1.5,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(iconData, color: iconFgColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: AppTextStyles.bodyLarge.copyWith(
                                fontWeight: notification.isRead
                                    ? FontWeight.w600
                                    : FontWeight.w800,
                                color: AppColors.textPrimary,
                                fontSize: 14.5,
                              ),
                            ),
                          ),
                          if (!notification.isRead) ...[
                            const SizedBox(width: 6),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (notification.message.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          notification.message,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (notification.timeAgo != null &&
                              notification.timeAgo!.isNotEmpty) ...[
                            const Icon(
                              PhosphorIconsRegular.clock,
                              size: 13,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              notification.timeAgo!,
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textMuted,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                          const Spacer(),
                          if (notification.actionLabel != null &&
                              notification.actionLabel!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 3.5,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    notification.actionLabel!,
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  const Icon(
                                    PhosphorIconsRegular.arrowLeft,
                                    size: 12,
                                    color: AppColors.primary,
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  (IconData, Color, Color) _resolveVisuals(AppNotification notification) {
    final type = notification.type.toLowerCase();
    final color = notification.color.toLowerCase();

    if (color == 'success' || type.contains('approved') || type.contains('success')) {
      return (
        PhosphorIconsRegular.checkCircle,
        const Color(0xFFE8F5E9),
        AppColors.success,
      );
    }
    if (color == 'danger' || type.contains('rejected') || type.contains('failed')) {
      return (
        PhosphorIconsRegular.xCircle,
        const Color(0xFFFFEBEE),
        AppColors.error,
      );
    }
    if (color == 'warning' || type.contains('reminder') || type.contains('pending')) {
      return (
        PhosphorIconsRegular.bellRinging,
        const Color(0xFFFFF8E1),
        AppColors.warning,
      );
    }
    if (type.contains('assignment') || type.contains('clinical')) {
      return (
        PhosphorIconsRegular.clipboardText,
        const Color(0xFFEDE7F6),
        const Color(0xFF673AB7),
      );
    }
    if (type.contains('certificate')) {
      return (
        PhosphorIconsRegular.certificate,
        const Color(0xFFFFF3E0),
        const Color(0xFFE65100),
      );
    }
    if (type.contains('support')) {
      return (
        PhosphorIconsRegular.chatsCircle,
        const Color(0xFFE0F7FA),
        const Color(0xFF00838F),
      );
    }

    return (
      PhosphorIconsRegular.bell,
      AppColors.primaryLight,
      AppColors.primary,
    );
  }
}
