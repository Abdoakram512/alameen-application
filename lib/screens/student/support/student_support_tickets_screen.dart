import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_directional_icons.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/app_status_badge.dart';
import '../../../logic/support/support_tickets_cubit.dart';
import '../../../logic/support/support_tickets_state.dart';
import '../../../models/support_ticket.dart';
import '../../../repositories/student_support_repository.dart';
import 'ticket_conversation_screen.dart';
import 'widgets/create_ticket_sheet.dart';

class StudentSupportTicketsScreen extends StatefulWidget {
  final SupportTicketsCubit? cubit;
  final StudentSupportRepository? repository;

  const StudentSupportTicketsScreen({
    super.key,
    this.cubit,
    this.repository,
  });

  @override
  State<StudentSupportTicketsScreen> createState() => _StudentSupportTicketsScreenState();
}

class _StudentSupportTicketsScreenState extends State<StudentSupportTicketsScreen>
    with SingleTickerProviderStateMixin {
  late final SupportTicketsCubit _cubit;
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  bool _ownsCubit = false;

  static const List<String> _statusFilters = [
    'all',
    'open',
    'in_progress',
    'awaiting_student',
    'closed',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.cubit != null) {
      _cubit = widget.cubit!;
    } else if (widget.repository != null) {
      _cubit = SupportTicketsCubit(repository: widget.repository!);
      _ownsCubit = true;
    } else {
      _cubit = sl<SupportTicketsCubit>();
      _ownsCubit = true;
    }

    _tabController = TabController(length: _statusFilters.length, vsync: this);
    _tabController.addListener(_handleTabChange);
    _cubit.loadTickets(status: _currentStatus);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _searchController.dispose();
    if (_ownsCubit) {
      _cubit.close();
    }
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) return;
    _cubit.loadTickets(
      status: _currentStatus,
      search: _searchController.text.trim().isNotEmpty ? _searchController.text.trim() : null,
      reset: true,
    );
  }

  String get _currentStatus => _statusFilters[_tabController.index];

  void _openCreateTicketSheet() {
    CreateTicketSheet.show(
      context,
      repository: widget.repository ?? sl<StudentSupportRepository>(),
    ).then((createdTicket) {
      if (createdTicket != null) {
        _cubit.loadTickets(status: _currentStatus, reset: false);
      }
    });
  }

  void _openTicketConversation(SupportTicket ticket) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TicketConversationScreen(
          ticketId: ticket.id,
          repository: widget.repository ?? sl<StudentSupportRepository>(),
        ),
      ),
    ).then((_) => _cubit.loadTickets(status: _currentStatus, reset: false));
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: BlocBuilder<SupportTicketsCubit, SupportTicketsState>(
        builder: (context, state) {
          final counts = state is SupportTicketsLoaded ? state.counts : <String, int>{};

          return Scaffold(
            backgroundColor: AppColors.scaffoldBackground,
            appBar: AppBar(
              title: const Text('تذاكر الدعم والاستفسارات'),
              centerTitle: false,
              backgroundColor: Colors.white,
              elevation: 0,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  color: Colors.white,
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: AppColors.textSecondary,
                    indicatorColor: AppColors.primary,
                    indicatorWeight: 3,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                    unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                    tabs: [
                      Tab(text: 'الكل (${counts['all'] ?? 0})'),
                      Tab(text: 'مفتوحة (${counts['open'] ?? 0})'),
                      Tab(text: 'قيد المعالجة (${counts['in_progress'] ?? 0})'),
                      Tab(text: 'بانتظارك (${counts['awaiting_student'] ?? 0})'),
                      Tab(text: 'مغلقة (${counts['closed'] ?? 0})'),
                    ],
                  ),
                ),
              ),
            ),
            body: Column(
              children: [
                // Search bar
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _cubit.loadTickets(
                      status: _currentStatus,
                      search: _searchController.text.trim().isNotEmpty ? _searchController.text.trim() : null,
                      reset: true,
                    ),
                    decoration: InputDecoration(
                      hintText: 'البحث في تذاكر الدعم برقم التذكرة أو الموضوع...',
                      hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted, fontSize: 13),
                      filled: true,
                      fillColor: const Color(0xFFF3F4F6),
                      prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass, color: AppColors.textMuted, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(PhosphorIconsRegular.xCircle, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _cubit.loadTickets(status: _currentStatus, reset: true);
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),

                // Content
                Expanded(
                  child: _buildTicketContent(state),
                ),
              ],
            ),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: _openCreateTicketSheet,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(PhosphorIconsRegular.plusCircle, size: 20),
              label: const Text(
                'تذكرة جديدة',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTicketContent(SupportTicketsState state) {
    if (state is SupportTicketsLoading || state is SupportTicketsInitial) {
      return const AppLoadingIndicator(message: 'جاري تحميل تذاكر الدعم...');
    }

    if (state is SupportTicketsError) {
      return AppErrorView(
        message: state.message,
        onRetry: () => _cubit.loadTickets(status: _currentStatus, reset: true),
      );
    }

    if (state is SupportTicketsLoaded) {
      final tickets = state.tickets;
      if (tickets.isEmpty) {
        return RefreshIndicator(
          onRefresh: () => _cubit.loadTickets(status: _currentStatus, reset: true),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(height: MediaQuery.of(context).size.height * 0.16),
              AppEmptyState(
                defaultIconData: PhosphorIconsRegular.chatsCircle,
                title: 'لا توجد تذاكر دعم في هذا التصنيف',
                description: 'يمكنك فتح تذكرة جديدة للاستفسار عن أي موضوع أكاديمي أو تقني.',
                actionText: 'إنشاء تذكرة دعم الآن',
                onAction: _openCreateTicketSheet,
              ),
            ],
          ),
        );
      }

      return RefreshIndicator(
        onRefresh: () => _cubit.loadTickets(status: _currentStatus, reset: true),
        child: NotificationListener<ScrollNotification>(
          onNotification: (ScrollNotification scrollInfo) {
            if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
              _cubit.loadMore();
            }
            return false;
          },
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            itemCount: tickets.length + (state.isLoadingMore ? 1 : 0),
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (index >= tickets.length) {
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

              final ticket = tickets[index];
              return _buildTicketCard(ticket);
            },
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildTicketCard(SupportTicket ticket) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 0.5,
      child: InkWell(
        onTap: () => _openTicketConversation(ticket),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: ticket.unreadByStudentCount > 0
                  ? AppColors.primary.withValues(alpha: 0.4)
                  : AppColors.borderHairline,
              width: ticket.unreadByStudentCount > 0 ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      ticket.ticketNumber,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildStatusBadge(ticket.status, ticket.statusLabel),
                  const Spacer(),
                  if (ticket.unreadByStudentCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${ticket.unreadByStudentCount} جديد',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                ticket.subject,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (ticket.categoryLabel.isNotEmpty) ...[
                    const Icon(PhosphorIconsRegular.tag, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      ticket.categoryLabel,
                      style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(width: 14),
                  ],
                  if (ticket.priorityLabel.isNotEmpty) ...[
                    _buildPriorityIndicator(ticket.priority, ticket.priorityLabel),
                  ],
                  const Spacer(),
                  Icon(AppDirectionalIcons.forwardIcon(context), size: 16, color: AppColors.primary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status, String label) {
    AppStatusType type = AppStatusType.neutral;
    final s = status.toLowerCase();
    if (s == 'open') {
      type = AppStatusType.info;
    } else if (s == 'in_progress') {
      type = AppStatusType.warning;
    } else if (s == 'awaiting_student') {
      type = AppStatusType.error;
    } else if (s == 'resolved' || s == 'closed') {
      type = AppStatusType.success;
    }

    return AppStatusBadge(
      label: label.isNotEmpty ? label : status,
      statusType: type,
    );
  }

  Widget _buildPriorityIndicator(String priority, String label) {
    Color fg = AppColors.textSecondary;
    final p = priority.toLowerCase();
    if (p == 'urgent' || p == 'high') {
      fg = AppColors.error;
    } else if (p == 'normal') {
      fg = AppColors.primary;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(PhosphorIconsRegular.flag, size: 13, color: fg),
        const SizedBox(width: 3),
        Text(
          label.isNotEmpty ? label : priority,
          style: TextStyle(color: fg, fontSize: 11.5, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
