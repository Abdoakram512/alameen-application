import '../models/support_ticket.dart';

abstract class StudentSupportRepository {
  Future<StudentTicketsData> getTickets({
    String? status,
    String? category,
    String? search,
    int? page,
    int perPage = 12,
  });

  Future<SupportTicket> createTicket({
    required String subject,
    required String category,
    required String message,
    String priority = 'normal',
    int? courseId,
    List<String>? attachmentPaths,
  });

  Future<SupportTicket> getTicketDetails(int ticketId);

  Future<SupportMessage> replyToTicket({
    required int ticketId,
    required String message,
    List<String>? attachmentPaths,
  });

  Future<void> closeTicket(int ticketId);

  Future<void> reopenTicket(int ticketId);

  Future<TicketPollResult> pollTicketUpdates({
    required int ticketId,
    int afterId = 0,
  });

  void clearCache();
}
