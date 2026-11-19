import 'package:equatable/equatable.dart';
import '../../models/support_ticket.dart';

abstract class SupportTicketsState extends Equatable {
  const SupportTicketsState();

  @override
  List<Object?> get props => [];
}

class SupportTicketsInitial extends SupportTicketsState {
  const SupportTicketsInitial();
}

class SupportTicketsLoading extends SupportTicketsState {
  const SupportTicketsLoading();
}

class SupportTicketsLoaded extends SupportTicketsState {
  final List<SupportTicket> tickets;
  final Map<String, int> counts;
  final String statusFilter;
  final String? searchQuery;
  final int currentPage;
  final int lastPage;
  final bool isLoadingMore;

  const SupportTicketsLoaded({
    required this.tickets,
    required this.counts,
    this.statusFilter = 'all',
    this.searchQuery,
    this.currentPage = 1,
    this.lastPage = 1,
    this.isLoadingMore = false,
  });

  bool get hasMore => currentPage < lastPage;

  SupportTicketsLoaded copyWith({
    List<SupportTicket>? tickets,
    Map<String, int>? counts,
    String? statusFilter,
    String? searchQuery,
    int? currentPage,
    int? lastPage,
    bool? isLoadingMore,
  }) {
    return SupportTicketsLoaded(
      tickets: tickets ?? this.tickets,
      counts: counts ?? this.counts,
      statusFilter: statusFilter ?? this.statusFilter,
      searchQuery: searchQuery ?? this.searchQuery,
      currentPage: currentPage ?? this.currentPage,
      lastPage: lastPage ?? this.lastPage,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  List<Object?> get props => [
        tickets,
        counts,
        statusFilter,
        searchQuery,
        currentPage,
        lastPage,
        isLoadingMore,
      ];
}

class SupportTicketsError extends SupportTicketsState {
  final String message;

  const SupportTicketsError(this.message);

  @override
  List<Object?> get props => [message];
}
