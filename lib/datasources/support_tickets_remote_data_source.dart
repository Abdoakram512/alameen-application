import 'dart:io';
import 'package:dio/dio.dart';
import '../core/network/api_client.dart';
import '../core/network/api_exceptions.dart';
import '../models/support_ticket.dart';

abstract class SupportTicketsRemoteDataSource {
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
}

class SupportTicketsRemoteDataSourceImpl implements SupportTicketsRemoteDataSource {
  final ApiClient _apiClient;

  SupportTicketsRemoteDataSourceImpl({required ApiClient apiClient})
      : _apiClient = apiClient;

  @override
  Future<StudentTicketsData> getTickets({
    String? status,
    String? category,
    String? search,
    int? page,
    int perPage = 12,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'per_page': perPage,
      };
      if (status != null && status.isNotEmpty && status != 'all') {
        queryParams['status'] = status;
      }
      if (category != null && category.isNotEmpty && category != 'all') {
        queryParams['category'] = category;
      }
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }
      if (page != null && page > 1) {
        queryParams['page'] = page;
      }

      final response = await _apiClient.get(
        '/student/support-tickets',
        queryParameters: queryParams,
      );

      final rawData = response.data;
      if (rawData is Map<String, dynamic>) {
        final innerData = rawData['data'];
        if (innerData is Map<String, dynamic>) {
          return StudentTicketsData.fromJson(innerData);
        }
      }
      return const StudentTicketsData(tickets: []);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  @override
  Future<SupportTicket> createTicket({
    required String subject,
    required String category,
    required String message,
    String priority = 'normal',
    int? courseId,
    List<String>? attachmentPaths,
  }) async {
    try {
      final formData = FormData();
      formData.fields.add(MapEntry('subject', subject.trim()));
      formData.fields.add(MapEntry('category', category));
      formData.fields.add(MapEntry('message', message.trim()));
      formData.fields.add(MapEntry('priority', priority));
      if (courseId != null) {
        formData.fields.add(MapEntry('course_id', courseId.toString()));
      }

      if (attachmentPaths != null && attachmentPaths.isNotEmpty) {
        for (final path in attachmentPaths) {
          final file = File(path);
          if (await file.exists()) {
            final fileName = file.uri.pathSegments.last;
            formData.files.add(
              MapEntry(
                'attachments[]',
                await MultipartFile.fromFile(path, filename: fileName),
              ),
            );
          }
        }
      }

      final response = await _apiClient.postMultipart(
        '/student/support-tickets',
        formData: formData,
      );

      final rawData = response.data;
      if (rawData is Map<String, dynamic>) {
        final innerData = rawData['data'];
        if (innerData is Map<String, dynamic>) {
          // If the backend returns ticket in 'ticket' key or directly in 'data'
          if (innerData.containsKey('ticket') && innerData['ticket'] is Map<String, dynamic>) {
            return SupportTicket.fromJson(innerData['ticket'] as Map<String, dynamic>);
          }
          return SupportTicket.fromJson(innerData);
        }
      }
      throw const ApiException('فشل استلام بيانات التذكرة بعد إنشائها.');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  @override
  Future<SupportTicket> getTicketDetails(int ticketId) async {
    try {
      final response = await _apiClient.get(
        '/student/support-tickets/$ticketId',
      );

      final rawData = response.data;
      if (rawData is Map<String, dynamic>) {
        final innerData = rawData['data'];
        if (innerData is Map<String, dynamic>) {
          if (innerData.containsKey('ticket') && innerData['ticket'] is Map<String, dynamic>) {
            return SupportTicket.fromJson(innerData['ticket'] as Map<String, dynamic>);
          }
          return SupportTicket.fromJson(innerData);
        }
      }
      throw const ApiException('تعذر تحميل تفاصيل تذكرة الدعم الفني.');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  @override
  Future<SupportMessage> replyToTicket({
    required int ticketId,
    required String message,
    List<String>? attachmentPaths,
  }) async {
    try {
      final formData = FormData();
      formData.fields.add(MapEntry('message', message.trim()));

      if (attachmentPaths != null && attachmentPaths.isNotEmpty) {
        for (final path in attachmentPaths) {
          final file = File(path);
          if (await file.exists()) {
            final fileName = file.uri.pathSegments.last;
            formData.files.add(
              MapEntry(
                'attachments[]',
                await MultipartFile.fromFile(path, filename: fileName),
              ),
            );
          }
        }
      }

      final response = await _apiClient.postMultipart(
        '/student/support-tickets/$ticketId/reply',
        formData: formData,
      );

      final rawData = response.data;
      if (rawData is Map<String, dynamic>) {
        final innerData = rawData['data'];
        if (innerData is Map<String, dynamic>) {
          if (innerData.containsKey('message') && innerData['message'] is Map<String, dynamic>) {
            return SupportMessage.fromJson(innerData['message'] as Map<String, dynamic>);
          }
          return SupportMessage.fromJson(innerData);
        }
      }
      throw const ApiException('فشل إرسال الرد على التذكرة.');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  @override
  Future<void> closeTicket(int ticketId) async {
    try {
      await _apiClient.post('/student/support-tickets/$ticketId/close');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  @override
  Future<void> reopenTicket(int ticketId) async {
    try {
      await _apiClient.post('/student/support-tickets/$ticketId/reopen');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  @override
  Future<TicketPollResult> pollTicketUpdates({
    required int ticketId,
    int afterId = 0,
  }) async {
    try {
      final response = await _apiClient.get(
        '/student/support-tickets/$ticketId/poll',
        queryParameters: {
          'after_id': afterId,
        },
      );

      final rawData = response.data;
      if (rawData is Map<String, dynamic>) {
        final innerData = rawData['data'];
        if (innerData is Map<String, dynamic>) {
          return TicketPollResult.fromJson(innerData);
        }
      }
      return const TicketPollResult();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
