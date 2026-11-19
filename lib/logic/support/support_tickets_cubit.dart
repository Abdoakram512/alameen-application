import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/network/api_exceptions.dart';
import '../../models/support_ticket.dart';
import '../../repositories/student_support_repository.dart';
import 'support_tickets_state.dart';

class SupportTicketsCubit extends Cubit<SupportTicketsState> {
  final StudentSupportRepository _repository;

  SupportTicketsCubit({
    required StudentSupportRepository repository,
  })  : _repository = repository,
        super(const SupportTicketsInitial());

  Future<void> loadTickets({
    String status = 'all',
    String? search,
    bool reset = true,
  }) async {
    if (reset) {
      emit(const SupportTicketsLoading());
    }

    try {
      final data = await _repository.getTickets(
        status: status,
        search: search,
        page: 1,
        perPage: 12,
      );

      emit(SupportTicketsLoaded(
        tickets: data.tickets,
        counts: data.counts,
        statusFilter: status,
        searchQuery: search,
        currentPage: data.pagination?.currentPage ?? 1,
        lastPage: data.pagination?.lastPage ?? 1,
      ));
    } on ApiException catch (e) {
      emit(SupportTicketsError(e.message));
    } catch (e) {
      emit(const SupportTicketsError('تعذر تحميل تذاكر الدعم. يرجى التحقق من اتصالك بالإنترنت.'));
    }
  }

  Future<void> loadMore() async {
    final currentState = state;
    if (currentState is! SupportTicketsLoaded ||
        currentState.isLoadingMore ||
        !currentState.hasMore) {
      return;
    }

    emit(currentState.copyWith(isLoadingMore: true));

    try {
      final nextPage = currentState.currentPage + 1;
      final data = await _repository.getTickets(
        status: currentState.statusFilter,
        search: currentState.searchQuery,
        page: nextPage,
        perPage: 12,
      );

      final combined = List<SupportTicket>.from(currentState.tickets)
        ..addAll(data.tickets);

      emit(currentState.copyWith(
        tickets: combined,
        currentPage: nextPage,
        lastPage: data.pagination?.lastPage ?? nextPage,
        isLoadingMore: false,
      ));
    } catch (_) {
      emit(currentState.copyWith(isLoadingMore: false));
    }
  }

  Future<SupportTicket> createTicket({
    required String subject,
    required String category,
    required String message,
    String priority = 'normal',
    int? courseId,
    List<String>? attachmentPaths,
  }) async {
    try {
      final ticket = await _repository.createTicket(
        subject: subject,
        category: category,
        message: message,
        priority: priority,
        courseId: courseId,
        attachmentPaths: attachmentPaths,
      );

      // Reload tickets to update counts and list
      await loadTickets(reset: false);
      return ticket;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('تعذر إرسال التذكرة: $e');
    }
  }
}
