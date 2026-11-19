import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/network/api_exceptions.dart';
import '../../models/support_ticket.dart';
import '../../repositories/student_support_repository.dart';
import 'ticket_conversation_state.dart';

class TicketConversationCubit extends Cubit<TicketConversationState> {
  final StudentSupportRepository _repository;
  final int ticketId;

  TicketConversationCubit({
    required StudentSupportRepository repository,
    required this.ticketId,
  })  : _repository = repository,
        super(const TicketConversationInitial());

  int get lastMessageId {
    final currentState = state;
    if (currentState is TicketConversationLoaded && currentState.messages.isNotEmpty) {
      return currentState.messages.map((m) => m.id).reduce((a, b) => a > b ? a : b);
    }
    return 0;
  }

  Future<void> loadTicket() async {
    emit(const TicketConversationLoading());

    try {
      final ticket = await _repository.getTicketDetails(ticketId);
      emit(TicketConversationLoaded(
        ticket: ticket,
        messages: List<SupportMessage>.from(ticket.messages),
      ));
    } on ApiException catch (e) {
      emit(TicketConversationError(e.message));
    } catch (e) {
      emit(TicketConversationError('تعذر تحميل بيانات التذكرة: $e'));
    }
  }

  Future<bool> pollUpdates() async {
    final currentState = state;
    if (currentState is! TicketConversationLoaded) return false;

    try {
      final pollResult = await _repository.pollTicketUpdates(
        ticketId: ticketId,
        afterId: lastMessageId,
      );

      var updatedTicket = currentState.ticket;
      if (pollResult.isClosed && updatedTicket.isOpen) {
        updatedTicket = updatedTicket.copyWith(
          status: pollResult.ticketStatus ?? 'closed',
          statusLabel: pollResult.ticketStatusLabel ?? 'مغلقة',
          isClosed: true,
          isOpen: false,
        );
      } else if (pollResult.ticketStatus != null &&
          pollResult.ticketStatus != updatedTicket.status) {
        updatedTicket = updatedTicket.copyWith(
          status: pollResult.ticketStatus!,
          statusLabel: pollResult.ticketStatusLabel ?? updatedTicket.statusLabel,
        );
      }

      bool hasNewMessages = false;
      final updatedMessages = List<SupportMessage>.from(currentState.messages);
      if (pollResult.messages.isNotEmpty) {
        final existingIds = updatedMessages.map((m) => m.id).toSet();
        for (final msg in pollResult.messages) {
          if (!existingIds.contains(msg.id)) {
            updatedMessages.add(msg);
            hasNewMessages = true;
          }
        }
      }

      emit(currentState.copyWith(
        ticket: updatedTicket,
        messages: updatedMessages,
      ));
      return hasNewMessages;
    } catch (_) {
      return false;
    }
  }

  Future<void> sendReply({
    required String message,
    List<String>? attachmentPaths,
  }) async {
    final currentState = state;
    if (currentState is! TicketConversationLoaded) return;

    emit(currentState.copyWith(isSendingReply: true));

    try {
      final newMessage = await _repository.replyToTicket(
        ticketId: ticketId,
        message: message,
        attachmentPaths: attachmentPaths,
      );

      final updatedMessages = List<SupportMessage>.from(currentState.messages)
        ..add(newMessage);

      var updatedTicket = currentState.ticket;
      if (updatedTicket.isClosed) {
        updatedTicket = updatedTicket.copyWith(
          isOpen: true,
          isClosed: false,
          status: 'open',
          statusLabel: 'مفتوحة',
        );
      }

      emit(currentState.copyWith(
        ticket: updatedTicket,
        messages: updatedMessages,
        isSendingReply: false,
      ));
    } on ApiException catch (e) {
      emit(currentState.copyWith(isSendingReply: false));
      throw ApiException(e.message);
    } catch (e) {
      emit(currentState.copyWith(isSendingReply: false));
      throw ApiException('تعذر إرسال الرد: $e');
    }
  }

  Future<void> closeTicket() async {
    final currentState = state;
    try {
      await _repository.closeTicket(ticketId);
      if (currentState is TicketConversationLoaded) {
        emit(currentState.copyWith(
          ticket: currentState.ticket.copyWith(
            isOpen: false,
            isClosed: true,
            status: 'closed',
            statusLabel: 'مغلقة',
          ),
        ));
      }
    } on ApiException catch (e) {
      throw ApiException(e.message);
    } catch (e) {
      throw ApiException('فشل إغلاق التذكرة: $e');
    }
  }

  Future<void> reopenTicket() async {
    final currentState = state;
    try {
      await _repository.reopenTicket(ticketId);
      if (currentState is TicketConversationLoaded) {
        emit(currentState.copyWith(
          ticket: currentState.ticket.copyWith(
            isOpen: true,
            isClosed: false,
            status: 'open',
            statusLabel: 'مفتوحة',
          ),
        ));
      }
    } on ApiException catch (e) {
      throw ApiException(e.message);
    } catch (e) {
      throw ApiException('فشل إعادة فتح التذكرة: $e');
    }
  }

  Future<void> toggleTicketStatus() async {
    final currentState = state;
    if (currentState is! TicketConversationLoaded) return;

    final shouldClose = currentState.ticket.isOpen;
    try {
      if (shouldClose) {
        await _repository.closeTicket(ticketId);
        emit(currentState.copyWith(
          ticket: currentState.ticket.copyWith(
            isOpen: false,
            isClosed: true,
            status: 'closed',
            statusLabel: 'مغلقة',
          ),
        ));
      } else {
        await _repository.reopenTicket(ticketId);
        emit(currentState.copyWith(
          ticket: currentState.ticket.copyWith(
            isOpen: true,
            isClosed: false,
            status: 'open',
            statusLabel: 'مفتوحة',
          ),
        ));
      }
    } on ApiException catch (e) {
      throw ApiException(e.message);
    } catch (e) {
      throw ApiException('فشل تحديث حالة التذكرة: $e');
    }
  }
}
