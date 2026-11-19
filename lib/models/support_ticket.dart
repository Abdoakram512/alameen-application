import 'package:flutter/foundation.dart';
import 'app_notification.dart';

@immutable
class SupportMessage {
  final int id;
  final int ticketId;
  final String senderType; // 'student' | 'admin' | 'system'
  final int? senderId;
  final String senderName;
  final bool isSystemEvent;
  final String message;
  final String? attachmentUrl;
  final String? attachmentName;
  final String? attachmentSize;
  final bool isImage;
  final bool isRead;
  final DateTime? createdAt;
  final String? timeAgo;

  const SupportMessage({
    required this.id,
    required this.ticketId,
    required this.senderType,
    this.senderId,
    required this.senderName,
    this.isSystemEvent = false,
    required this.message,
    this.attachmentUrl,
    this.attachmentName,
    this.attachmentSize,
    this.isImage = false,
    this.isRead = true,
    this.createdAt,
    this.timeAgo,
  });

  bool get isFromStudent => senderType.toLowerCase() == 'student';
  bool get isFromAdmin => senderType.toLowerCase() == 'admin';

  factory SupportMessage.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v, int fallback) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? fallback;
      return fallback;
    }

    int? asNullableInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v);
      return null;
    }

    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is DateTime) return val;
      return DateTime.tryParse(val.toString());
    }

    return SupportMessage(
      id: asInt(json['id'], 0),
      ticketId: asInt(json['ticket_id'], 0),
      senderType: json['sender_type']?.toString() ?? 'student',
      senderId: asNullableInt(json['sender_id']),
      senderName: json['sender_name']?.toString() ?? '',
      isSystemEvent: json['is_system_event'] == true || json['is_system_event'] == 1,
      message: json['message']?.toString() ?? '',
      attachmentUrl: json['attachment_url']?.toString(),
      attachmentName: json['attachment_name']?.toString(),
      attachmentSize: json['attachment_size']?.toString(),
      isImage: json['is_image'] == true || json['is_image'] == 1,
      isRead: json['is_read'] != false && json['is_read'] != 0,
      createdAt: parseDate(json['created_at']),
      timeAgo: json['time_ago']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ticket_id': ticketId,
      'sender_type': senderType,
      'sender_id': senderId,
      'sender_name': senderName,
      'is_system_event': isSystemEvent,
      'message': message,
      'attachment_url': attachmentUrl,
      'attachment_name': attachmentName,
      'attachment_size': attachmentSize,
      'is_image': isImage,
      'is_read': isRead,
      'created_at': createdAt?.toIso8601String(),
      'time_ago': timeAgo,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SupportMessage &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

@immutable
class SupportTicket {
  final int id;
  final String ticketNumber;
  final int? userId;
  final int? courseId;
  final String subject;
  final String category;
  final String categoryLabel;
  final String priority;
  final String priorityLabel;
  final String status;
  final String statusLabel;
  final bool isOpen;
  final bool isClosed;
  final int unreadByStudentCount;
  final DateTime? lastReplyAt;
  final String? lastReplyBy;
  final DateTime? closedAt;
  final DateTime? createdAt;
  final List<SupportMessage> messages;

  const SupportTicket({
    required this.id,
    required this.ticketNumber,
    this.userId,
    this.courseId,
    required this.subject,
    required this.category,
    this.categoryLabel = '',
    required this.priority,
    this.priorityLabel = '',
    required this.status,
    this.statusLabel = '',
    this.isOpen = true,
    this.isClosed = false,
    this.unreadByStudentCount = 0,
    this.lastReplyAt,
    this.lastReplyBy,
    this.closedAt,
    this.createdAt,
    this.messages = const [],
  });

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v, int fallback) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? fallback;
      return fallback;
    }

    int? asNullableInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v);
      return null;
    }

    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is DateTime) return val;
      return DateTime.tryParse(val.toString());
    }

    final rawMessages = json['messages'];
    final List<SupportMessage> parsedMessages = [];
    if (rawMessages is List) {
      for (final m in rawMessages) {
        if (m is Map<String, dynamic>) {
          parsedMessages.add(SupportMessage.fromJson(m));
        }
      }
    }

    final statusStr = json['status']?.toString() ?? 'open';
    final isOpenBool = json['is_open'] == true ||
        (json['is_open'] == null && statusStr != 'closed' && statusStr != 'resolved');
    final isClosedBool = json['is_closed'] == true || statusStr == 'closed';

    return SupportTicket(
      id: asInt(json['id'], 0),
      ticketNumber: json['ticket_number']?.toString() ?? 'TKT-${json['id']}',
      userId: asNullableInt(json['user_id']),
      courseId: asNullableInt(json['course_id']),
      subject: json['subject']?.toString() ?? '',
      category: json['category']?.toString() ?? 'technical',
      categoryLabel: json['category_label']?.toString() ?? '',
      priority: json['priority']?.toString() ?? 'normal',
      priorityLabel: json['priority_label']?.toString() ?? '',
      status: statusStr,
      statusLabel: json['status_label']?.toString() ?? '',
      isOpen: isOpenBool,
      isClosed: isClosedBool,
      unreadByStudentCount: asInt(json['unread_by_student_count'], 0),
      lastReplyAt: parseDate(json['last_reply_at']),
      lastReplyBy: json['last_reply_by']?.toString(),
      closedAt: parseDate(json['closed_at']),
      createdAt: parseDate(json['created_at']),
      messages: parsedMessages,
    );
  }

  SupportTicket copyWith({
    int? id,
    String? ticketNumber,
    int? userId,
    int? courseId,
    String? subject,
    String? category,
    String? categoryLabel,
    String? priority,
    String? priorityLabel,
    String? status,
    String? statusLabel,
    bool? isOpen,
    bool? isClosed,
    int? unreadByStudentCount,
    DateTime? lastReplyAt,
    String? lastReplyBy,
    DateTime? closedAt,
    DateTime? createdAt,
    List<SupportMessage>? messages,
  }) {
    return SupportTicket(
      id: id ?? this.id,
      ticketNumber: ticketNumber ?? this.ticketNumber,
      userId: userId ?? this.userId,
      courseId: courseId ?? this.courseId,
      subject: subject ?? this.subject,
      category: category ?? this.category,
      categoryLabel: categoryLabel ?? this.categoryLabel,
      priority: priority ?? this.priority,
      priorityLabel: priorityLabel ?? this.priorityLabel,
      status: status ?? this.status,
      statusLabel: statusLabel ?? this.statusLabel,
      isOpen: isOpen ?? this.isOpen,
      isClosed: isClosed ?? this.isClosed,
      unreadByStudentCount: unreadByStudentCount ?? this.unreadByStudentCount,
      lastReplyAt: lastReplyAt ?? this.lastReplyAt,
      lastReplyBy: lastReplyBy ?? this.lastReplyBy,
      closedAt: closedAt ?? this.closedAt,
      createdAt: createdAt ?? this.createdAt,
      messages: messages ?? this.messages,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SupportTicket &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          status == other.status &&
          unreadByStudentCount == other.unreadByStudentCount &&
          messages.length == other.messages.length;

  @override
  int get hashCode => id.hashCode ^ status.hashCode;
}

@immutable
class StudentTicketsData {
  final Map<String, int> counts;
  final List<SupportTicket> tickets;
  final NotificationPaginationMeta? pagination;

  const StudentTicketsData({
    this.counts = const {},
    required this.tickets,
    this.pagination,
  });

  factory StudentTicketsData.fromJson(Map<String, dynamic> json) {
    final rawCounts = json['counts'];
    final Map<String, int> countsMap = {};
    if (rawCounts is Map) {
      rawCounts.forEach((k, v) {
        if (v is num) {
          countsMap[k.toString()] = v.toInt();
        } else if (v is String) {
          countsMap[k.toString()] = int.tryParse(v) ?? 0;
        }
      });
    }

    final rawTickets = json['tickets'];
    final List<SupportTicket> list = [];
    if (rawTickets is List) {
      for (final t in rawTickets) {
        if (t is Map<String, dynamic>) {
          list.add(SupportTicket.fromJson(t));
        }
      }
    }

    final rawPagination = json['pagination'];
    final pagination = rawPagination is Map<String, dynamic>
        ? NotificationPaginationMeta.fromJson(rawPagination)
        : null;

    return StudentTicketsData(
      counts: countsMap,
      tickets: list,
      pagination: pagination,
    );
  }
}

@immutable
class TicketPollResult {
  final String? ticketStatus;
  final String? ticketStatusLabel;
  final bool isClosed;
  final List<SupportMessage> messages;

  const TicketPollResult({
    this.ticketStatus,
    this.ticketStatusLabel,
    this.isClosed = false,
    this.messages = const [],
  });

  factory TicketPollResult.fromJson(Map<String, dynamic> json) {
    final rawMessages = json['messages'];
    final List<SupportMessage> list = [];
    if (rawMessages is List) {
      for (final m in rawMessages) {
        if (m is Map<String, dynamic>) {
          list.add(SupportMessage.fromJson(m));
        }
      }
    }

    final statusStr = json['ticket_status']?.toString();
    final isClosedBool = json['is_closed'] == true || statusStr == 'closed';

    return TicketPollResult(
      ticketStatus: statusStr,
      ticketStatusLabel: json['ticket_status_label']?.toString(),
      isClosed: isClosedBool,
      messages: list,
    );
  }
}
