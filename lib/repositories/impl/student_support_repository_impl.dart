import '../../datasources/support_tickets_remote_data_source.dart';
import '../../models/support_ticket.dart';
import '../student_support_repository.dart';

class StudentSupportRepositoryImpl implements StudentSupportRepository {
  final SupportTicketsRemoteDataSource _remoteDataSource;

  StudentSupportRepositoryImpl({
    required SupportTicketsRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  @override
  Future<StudentTicketsData> getTickets({
    String? status,
    String? category,
    String? search,
    int? page,
    int perPage = 12,
  }) {
    return _remoteDataSource.getTickets(
      status: status,
      category: category,
      search: search,
      page: page,
      perPage: perPage,
    );
  }

  @override
  Future<SupportTicket> createTicket({
    required String subject,
    required String category,
    required String message,
    String priority = 'normal',
    int? courseId,
    List<String>? attachmentPaths,
  }) {
    return _remoteDataSource.createTicket(
      subject: subject,
      category: category,
      message: message,
      priority: priority,
      courseId: courseId,
      attachmentPaths: attachmentPaths,
    );
  }

  @override
  Future<SupportTicket> getTicketDetails(int ticketId) {
    return _remoteDataSource.getTicketDetails(ticketId);
  }

  @override
  Future<SupportMessage> replyToTicket({
    required int ticketId,
    required String message,
    List<String>? attachmentPaths,
  }) {
    return _remoteDataSource.replyToTicket(
      ticketId: ticketId,
      message: message,
      attachmentPaths: attachmentPaths,
    );
  }

  @override
  Future<void> closeTicket(int ticketId) {
    return _remoteDataSource.closeTicket(ticketId);
  }

  @override
  Future<void> reopenTicket(int ticketId) {
    return _remoteDataSource.reopenTicket(ticketId);
  }

  @override
  Future<TicketPollResult> pollTicketUpdates({
    required int ticketId,
    int afterId = 0,
  }) {
    return _remoteDataSource.pollTicketUpdates(
      ticketId: ticketId,
      afterId: afterId,
    );
  }

  @override
  void clearCache() {
    // In-memory state cleared on student logout
  }
}
