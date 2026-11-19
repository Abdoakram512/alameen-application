import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/network/api_exceptions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/support_ticket.dart';
import '../../../repositories/student_support_repository.dart';
import 'ticket_conversation_screen.dart';
import 'widgets/create_ticket_sheet.dart';

class StudentSupportTicketsScreen extends StatefulWidget {
  final StudentSupportRepository? repository;

  const StudentSupportTicketsScreen({
    super.key,
    this.repository,
  });

  @override
  State<StudentSupportTicketsScreen> createState() => _StudentSupportTicketsScreenState();
}

class _StudentSupportTicketsScreenState extends State<StudentSupportTicketsScreen>
    with SingleTickerProviderStateMixin {
  late final StudentSupportRepository _repository;
  late final TabController _tabController;

  static const List<String> _statusFilters = [
    'all',
    'open',
    'in_progress',
    'awaiting_student',
    'closed',
  ];

  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String? _errorMessage;
  Map<String, int> _counts = {};
  List<SupportTicket> _tickets = [];
  int _currentPage = 1;
  int _lastPage = 1;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? sl<StudentSupportRepository>();
    _tabController = TabController(length: _statusFilters.length, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadTickets();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) return;
    _loadTickets();
  }

  String get _currentStatus => _statusFilters[_tabController.index];

  Future<void> _loadTickets({bool resetPage = true}) async {
    if (resetPage) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _currentPage = 1;
      });
    }

    try {
      final data = await _repository.getTickets(
        status: _currentStatus,
        search: _searchController.text.trim().isNotEmpty ? _searchController.text.trim() : null,
        page: _currentPage,
        perPage: 12,
      );

      if (!mounted) return;
      setState(() {
        _counts = data.counts;
        _tickets = data.tickets;
        _currentPage = data.pagination?.currentPage ?? 1;
        _lastPage = data.pagination?.lastPage ?? 1;
        _isLoading = false;
        _errorMessage = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'تعذر تحميل تذاكر الدعم. يرجى التحقق من اتصالك بالإنترنت.';
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || _currentPage >= _lastPage) return;

    setState(() => _isLoadingMore = true);
    try {
      final nextPage = _currentPage + 1;
      final data = await _repository.getTickets(
        status: _currentStatus,
        search: _searchController.text.trim().isNotEmpty ? _searchController.text.trim() : null,
        page: nextPage,
        perPage: 12,
      );

      if (!mounted) return;
      setState(() {
        _currentPage = nextPage;
        _lastPage = data.pagination?.lastPage ?? nextPage;
        _tickets.addAll(data.tickets);
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  void _openCreateTicketSheet() {
    CreateTicketSheet.show(
      context,
      repository: _repository,
    ).then((newTicket) {
      if (newTicket != null) {
        _loadTickets(resetPage: true);
      }
    });
  }

  void _openTicketConversation(SupportTicket ticket) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TicketConversationScreen(
          ticketId: ticket.id,
          repository: _repository,
        ),
      ),
    ).then((_) => _loadTickets(resetPage: false));
  }

  @override
  Widget build(BuildContext context) {
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
                Tab(text: 'الكل (${_counts['all'] ?? 0})'),
                Tab(text: 'مفتوحة (${_counts['open'] ?? 0})'),
                Tab(text: 'قيد المعالجة (${_counts['in_progress'] ?? 0})'),
                Tab(text: 'بانتظارك (${_counts['awaiting_student'] ?? 0})'),
                Tab(text: 'مغلقة (${_counts['closed'] ?? 0})'),
              ],
            ),
          ),
        ),
      ),
      body: _buildBody(),
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
  }

  Widget _buildBody() {
    return Column(
      children: [
        // شريط البحث
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _loadTickets(resetPage: true),
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
                        _loadTickets(resetPage: true);
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

        // المحتوى
        Expanded(
          child: _buildTicketList(),
        ),
      ],
    );
  }

  Widget _buildTicketList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(PhosphorIconsRegular.warningCircle, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text(_errorMessage!, textAlign: TextAlign.center, style: AppTextStyles.bodyMedium),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _loadTickets(resetPage: true),
                icon: const Icon(PhosphorIconsRegular.arrowsClockwise, size: 18),
                label: const Text('إعادة المحاولة'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_tickets.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _loadTickets(resetPage: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.18),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      PhosphorIconsRegular.chatsCircle,
                      size: 38,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'لا توجد تذاكر دعم في هذا التصنيف',
                    style: AppTextStyles.heading3.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'يمكنك فتح تذكرة جديدة للاستفسار عن أي موضوع أكاديمي أو تقني.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _openCreateTicketSheet,
                    icon: const Icon(PhosphorIconsRegular.plusCircle, size: 18),
                    label: const Text('إنشاء تذكرة دعم الآن'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadTickets(resetPage: true),
      child: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification scrollInfo) {
          if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
            _loadMore();
          }
          return false;
        },
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          itemCount: _tickets.length + (_isLoadingMore ? 1 : 0),
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            if (index >= _tickets.length) {
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

            final ticket = _tickets[index];
            return _buildTicketCard(ticket);
          },
        ),
      ),
    );
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
                  const Icon(PhosphorIconsRegular.arrowLeft, size: 16, color: AppColors.primary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status, String label) {
    Color bg = const Color(0xFFE5E7EB);
    Color fg = const Color(0xFF374151);

    final s = status.toLowerCase();
    if (s == 'open') {
      bg = const Color(0xFFE0F2FE);
      fg = const Color(0xFF0369A1);
    } else if (s == 'in_progress') {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFFB45309);
    } else if (s == 'awaiting_student') {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFB91C1C);
    } else if (s == 'resolved' || s == 'closed') {
      bg = const Color(0xFFD1FAE5);
      fg = const Color(0xFF047857);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label.isNotEmpty ? label : status,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700),
      ),
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
