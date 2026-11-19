import 'package:equatable/equatable.dart';
import '../../models/support_ticket.dart';

abstract class TicketConversationState extends Equatable {
  const TicketConversationState();

  @override
  List<Object?> get props => [];
}

class TicketConversationInitial extends TicketConversationState {
  const TicketConversationInitial();
}

class TicketConversationLoading extends TicketConversationState {
  const TicketConversationLoading();
}

class TicketConversationLoaded extends TicketConversationState {
  final SupportTicket ticket;
  final List<SupportMessage> messages;
  final bool isSendingReply;

  const TicketConversationLoaded({
    required this.ticket,
    required this.messages,
    this.isSendingReply = false,
  });

  TicketConversationLoaded copyWith({
    SupportTicket? ticket,
    List<SupportMessage>? messages,
    bool? isSendingReply,
  }) {
    return TicketConversationLoaded(
      ticket: ticket ?? this.ticket,
      messages: messages ?? this.messages,
      isSendingReply: isSendingReply ?? this.isSendingReply,
    );
  }

  @override
  List<Object?> get props => [ticket, messages, isSendingReply];
}

class TicketConversationError extends TicketConversationState {
  final String message;

  const TicketConversationError(this.message);

  @override
  List<Object?> get props => [message];
}
