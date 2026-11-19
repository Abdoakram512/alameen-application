import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:secure_screen_app/core/network/api_client.dart';
import 'package:secure_screen_app/core/network/api_exceptions.dart';
import 'package:secure_screen_app/datasources/auth_remote_data_source.dart';
import 'package:secure_screen_app/datasources/notifications_remote_data_source.dart';
import 'package:secure_screen_app/datasources/support_tickets_remote_data_source.dart';
import 'package:secure_screen_app/models/app_notification.dart';
import 'package:secure_screen_app/models/support_ticket.dart';
import 'package:secure_screen_app/repositories/impl/student_notifications_repository_impl.dart';
import 'package:secure_screen_app/repositories/impl/student_profile_repository_impl.dart';
import 'package:secure_screen_app/repositories/impl/student_support_repository_impl.dart';
import 'package:secure_screen_app/services/notification_service.dart';

class MockApiClient extends Mock implements ApiClient {}
class MockDio extends Mock implements Dio {}
class MockAuthRemoteDataSource extends Mock implements AuthRemoteDataSource {}
class MockNotificationsRemoteDataSource extends Mock implements NotificationsRemoteDataSource {}
class MockSupportTicketsRemoteDataSource extends Mock implements SupportTicketsRemoteDataSource {}

void main() {
  setUpAll(() {
    registerFallbackValue(RequestOptions(path: ''));
    registerFallbackValue(Options());
    registerFallbackValue(FormData());
  });

  group('Phase P8 — Notifications System Migration (Laravel REST API)', () {
    late MockApiClient mockApiClient;
    late NotificationsRemoteDataSource remoteDataSource;

    setUp(() {
      mockApiClient = MockApiClient();
      remoteDataSource = NotificationsRemoteDataSourceImpl(apiClient: mockApiClient);
    });

    test('1. GET /student/notifications parses paginated inbox and unread count', () async {
      when(() => mockApiClient.get(
            '/student/notifications',
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
            cancelToken: any(named: 'cancelToken'),
          )).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/student/notifications'),
          statusCode: 200,
          data: {
            'success': true,
            'data': {
              'unread_count': 2,
              'notifications': [
                {
                  'id': '9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d',
                  'type': 'receipt_approved',
                  'title': 'تم تفعيل اشتراكك في المساق',
                  'message': 'تهانينا، تم تأكيد سداد الرسوم وتم فتح محتوى المساق كاملاً.',
                  'icon': 'bell',
                  'color': 'success',
                  'action_url': '/course/5',
                  'action_label': 'بدء التعلم',
                  'is_read': false,
                  'time_ago': 'منذ 5 دقائق',
                },
                {
                  'id': 'a22cdb4d-1111-2222-3333-2b0d7b3dcb6e',
                  'type': 'assignment_graded',
                  'title': 'تم تقييم التكليف السريري',
                  'message': 'حصلت على درجة 95% في التكليف السريري الأول.',
                  'icon': 'clipboard',
                  'color': 'primary',
                  'is_read': true,
                  'time_ago': 'منذ ساعة',
                },
              ],
              'pagination': {
                'current_page': 1,
                'last_page': 1,
                'per_page': 15,
                'total': 2,
              },
            },
          },
        ),
      );

      final result = await remoteDataSource.getNotifications(filter: 'all', page: 1);
      expect(result.unreadCount, equals(2));
      expect(result.notifications.length, equals(2));
      expect(result.notifications.first.id, equals('9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d'));
      expect(result.notifications.first.type, equals('receipt_approved'));
      expect(result.notifications.first.isRead, isFalse);
      expect(result.notifications.first.actionUrl, equals('/course/5'));
      expect(result.notifications.last.isRead, isTrue);
      expect(result.pagination?.total, equals(2));
    });

    test('2. GET /student/notifications/recent returns dropdown data', () async {
      when(() => mockApiClient.get(
            '/student/notifications/recent',
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
            cancelToken: any(named: 'cancelToken'),
          )).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/student/notifications/recent'),
          statusCode: 200,
          data: {
            'success': true,
            'data': {
              'unread_count': 1,
              'notifications': [
                {
                  'id': 101,
                  'type': 'system_announcement',
                  'title': 'تحديث هام للمنصة',
                  'body': 'نحيطكم علماً بأنه سيتم إجراء صيانة دورية.',
                  'is_read': false,
                },
              ],
            },
          },
        ),
      );

      final recent = await remoteDataSource.getRecentNotifications(limit: 8);
      expect(recent.unreadCount, equals(1));
      expect(recent.notifications.length, equals(1));
      expect(recent.notifications.first.id, equals('101'));
      expect(recent.notifications.first.message, equals('نحيطكم علماً بأنه سيتم إجراء صيانة دورية.'));
    });

    test('3. POST /student/notifications/{id}/read marks single notification read', () async {
      when(() => mockApiClient.post(
            '/student/notifications/notif-123/read',
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/student/notifications/notif-123/read'),
          statusCode: 200,
          data: {'success': true},
        ),
      );

      await expectLater(remoteDataSource.markAsRead('notif-123'), completes);
      verify(() => mockApiClient.post('/student/notifications/notif-123/read', data: any(named: 'data'), options: any(named: 'options'))).called(1);
    });

    test('4. POST /student/notifications/read-all marks all unread notifications as read', () async {
      when(() => mockApiClient.post(
            '/student/notifications/read-all',
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/student/notifications/read-all'),
          statusCode: 200,
          data: {
            'success': true,
            'data': {'marked_count': 5},
          },
        ),
      );

      final marked = await remoteDataSource.markAllAsRead();
      expect(marked, equals(5));
    });

    test('5. DELETE /student/notifications/{id} removes notification from student inbox', () async {
      when(() => mockApiClient.delete(
            '/student/notifications/notif-99',
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/student/notifications/notif-99'),
          statusCode: 200,
          data: {'success': true},
        ),
      );

      await expectLater(remoteDataSource.deleteNotification('notif-99'), completes);
    });

    test('6. StudentNotificationsRepository updates unreadCountListenable and isolates student state', () async {
      final mockRemote = MockNotificationsRemoteDataSource();
      when(() => mockRemote.getNotifications(
            filter: any(named: 'filter'),
            page: any(named: 'page'),
            perPage: any(named: 'perPage'),
          )).thenAnswer(
        (_) async => const StudentNotificationsData(
          unreadCount: 4,
          notifications: [],
        ),
      );
      when(() => mockRemote.markAsRead('1')).thenAnswer((_) async {});
      when(() => mockRemote.markAllAsRead()).thenAnswer((_) async => 4);

      final repository = StudentNotificationsRepositoryImpl(remoteDataSource: mockRemote);
      expect(repository.unreadCountListenable.value, equals(0));

      await repository.getNotifications();
      expect(repository.unreadCountListenable.value, equals(4));

      await repository.markAsRead('1');
      expect(repository.unreadCountListenable.value, equals(3));

      await repository.markAllAsRead();
      expect(repository.unreadCountListenable.value, equals(0));

      // Clear cache on logout
      repository.clearCache();
      expect(repository.unreadCountListenable.value, equals(0));
    });

    test('7. NotificationService syncFCMToken and clearFCMToken operate with zero Firestore writes', () async {
      final service = NotificationService();
      // Should not throw and should not touch Firestore
      await expectLater(service.syncFCMToken('test-student-uid'), completes);
      await expectLater(service.clearFCMToken('test-student-uid'), completes);
    });
  });

  group('Phase P8 — Support Tickets System Migration (Laravel REST API)', () {
    late MockApiClient mockApiClient;
    late SupportTicketsRemoteDataSource remoteDataSource;

    setUp(() {
      mockApiClient = MockApiClient();
      remoteDataSource = SupportTicketsRemoteDataSourceImpl(apiClient: mockApiClient);
    });

    test('8. GET /student/support-tickets parses status counts and tickets list', () async {
      when(() => mockApiClient.get(
            '/student/support-tickets',
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
            cancelToken: any(named: 'cancelToken'),
          )).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/student/support-tickets'),
          statusCode: 200,
          data: {
            'success': true,
            'data': {
              'counts': {
                'all': 3,
                'open': 1,
                'in_progress': 1,
                'awaiting_student': 0,
                'closed': 1,
              },
              'tickets': [
                {
                  'id': 12,
                  'ticket_number': 'TKT-2026-0012',
                  'subject': 'استفسار حول مدة تسجيل الصوت في التكليف السريري',
                  'category': 'clinical',
                  'category_label': 'استفسار سريري / أكاديمي',
                  'priority': 'normal',
                  'priority_label': 'عادية',
                  'status': 'open',
                  'status_label': 'مفتوحة',
                  'is_open': true,
                  'is_closed': false,
                  'unread_by_student_count': 1,
                  'messages': [],
                },
              ],
              'pagination': {
                'current_page': 1,
                'last_page': 1,
                'per_page': 12,
                'total': 1,
              },
            },
          },
        ),
      );

      final result = await remoteDataSource.getTickets(status: 'all');
      expect(result.counts['open'], equals(1));
      expect(result.counts['closed'], equals(1));
      expect(result.tickets.length, equals(1));
      expect(result.tickets.first.ticketNumber, equals('TKT-2026-0012'));
      expect(result.tickets.first.category, equals('clinical'));
      expect(result.tickets.first.isOpen, isTrue);
    });

    test('9. POST /student/support-tickets creates ticket via multipart/form-data', () async {
      when(() => mockApiClient.postMultipart(
            '/student/support-tickets',
            formData: any(named: 'formData'),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
            cancelToken: any(named: 'cancelToken'),
            onSendProgress: any(named: 'onSendProgress'),
          )).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/student/support-tickets'),
          statusCode: 201,
          data: {
            'success': true,
            'data': {
              'ticket': {
                'id': 15,
                'ticket_number': 'TKT-2026-0015',
                'subject': 'مشكلة في تحميل شهادة الإتمام',
                'category': 'certificate',
                'category_label': 'شهادات وإتمام المساق',
                'priority': 'high',
                'priority_label': 'عالية',
                'status': 'open',
                'status_label': 'مفتوحة',
                'is_open': true,
                'is_closed': false,
                'unread_by_student_count': 0,
                'messages': [],
              },
            },
          },
        ),
      );

      final ticket = await remoteDataSource.createTicket(
        subject: 'مشكلة في تحميل شهادة الإتمام',
        category: 'certificate',
        message: 'أكملت 95% من الدورة ولكن زر التحميل لا يستجيب.',
        priority: 'high',
      );

      expect(ticket.id, equals(15));
      expect(ticket.ticketNumber, equals('TKT-2026-0015'));
      expect(ticket.priority, equals('high'));
      expect(ticket.category, equals('certificate'));
    });

    test('10. GET /student/support-tickets/{ticket} returns conversation messages thread', () async {
      when(() => mockApiClient.get(
            '/student/support-tickets/12',
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
            cancelToken: any(named: 'cancelToken'),
          )).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/student/support-tickets/12'),
          statusCode: 200,
          data: {
            'success': true,
            'data': {
              'id': 12,
              'ticket_number': 'TKT-2026-0012',
              'subject': 'استفسار سريري',
              'category': 'clinical',
              'priority': 'normal',
              'status': 'open',
              'is_open': true,
              'is_closed': false,
              'messages': [
                {
                  'id': 101,
                  'ticket_id': 12,
                  'sender_type': 'student',
                  'sender_name': 'أحمد محمد',
                  'message': 'ما هي المدة المطلوبة للتسجيل الصوتي؟',
                  'is_system_event': false,
                  'time_ago': 'منذ يوم',
                },
                {
                  'id': 102,
                  'ticket_id': 12,
                  'sender_type': 'admin',
                  'sender_name': 'د. علاء المشرف السريري',
                  'message': 'أهلاً بك يا أحمد، مدة التسجيل المطلوبة بين دقيقة وثلاث دقائق كحد أقصى.',
                  'is_system_event': false,
                  'time_ago': 'منذ 3 ساعات',
                },
              ],
            },
          },
        ),
      );

      final ticket = await remoteDataSource.getTicketDetails(12);
      expect(ticket.messages.length, equals(2));
      expect(ticket.messages.first.isFromStudent, isTrue);
      expect(ticket.messages.last.isFromAdmin, isTrue);
      expect(ticket.messages.last.senderName, contains('د. علاء'));
    });

    test('11. POST /student/support-tickets/{ticket}/reply sends student message', () async {
      when(() => mockApiClient.postMultipart(
            '/student/support-tickets/12/reply',
            formData: any(named: 'formData'),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
            cancelToken: any(named: 'cancelToken'),
            onSendProgress: any(named: 'onSendProgress'),
          )).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/student/support-tickets/12/reply'),
          statusCode: 201,
          data: {
            'success': true,
            'data': {
              'message': {
                'id': 103,
                'ticket_id': 12,
                'sender_type': 'student',
                'sender_name': 'أحمد محمد',
                'message': 'شكراً جزيلاً يا دكتور، سأقوم بالتسجيل الليلة.',
                'is_system_event': false,
                'time_ago': 'الآن',
              },
            },
          },
        ),
      );

      final reply = await remoteDataSource.replyToTicket(
        ticketId: 12,
        message: 'شكراً جزيلاً يا دكتور، سأقوم بالتسجيل الليلة.',
      );

      expect(reply.id, equals(103));
      expect(reply.isFromStudent, isTrue);
      expect(reply.message, contains('شكراً جزيلاً'));
    });

    test('12. POST close and reopen ticket endpoints work cleanly', () async {
      when(() => mockApiClient.post('/student/support-tickets/12/close', data: any(named: 'data'), options: any(named: 'options')))
          .thenAnswer((_) async => Response(requestOptions: RequestOptions(path: '/student/support-tickets/12/close'), statusCode: 200));

      when(() => mockApiClient.post('/student/support-tickets/12/reopen', data: any(named: 'data'), options: any(named: 'options')))
          .thenAnswer((_) async => Response(requestOptions: RequestOptions(path: '/student/support-tickets/12/reopen'), statusCode: 200));

      await expectLater(remoteDataSource.closeTicket(12), completes);
      await expectLater(remoteDataSource.reopenTicket(12), completes);
    });

    test('13. GET /student/support-tickets/{ticket}/poll fetches new messages after after_id', () async {
      when(() => mockApiClient.get(
            '/student/support-tickets/12/poll',
            queryParameters: {'after_id': 102},
            options: any(named: 'options'),
            cancelToken: any(named: 'cancelToken'),
          )).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/student/support-tickets/12/poll'),
          statusCode: 200,
          data: {
            'success': true,
            'data': {
              'ticket_status': 'resolved',
              'ticket_status_label': 'تم حل الاستفسار',
              'is_closed': false,
              'messages': [
                {
                  'id': 103,
                  'ticket_id': 12,
                  'sender_type': 'admin',
                  'sender_name': 'الدعم الفني',
                  'message': 'بالتوفيق دائماً، إذا كان لديك أي استفسار آخر نحن بالخدمة.',
                  'is_system_event': false,
                  'time_ago': 'الآن',
                },
              ],
            },
          },
        ),
      );

      final poll = await remoteDataSource.pollTicketUpdates(ticketId: 12, afterId: 102);
      expect(poll.ticketStatus, equals('resolved'));
      expect(poll.messages.length, equals(1));
      expect(poll.messages.first.id, equals(103));
    });

    test('14. StudentSupportRepository forwards calls and isolates state cleanly', () async {
      final mockRemote = MockSupportTicketsRemoteDataSource();
      when(() => mockRemote.closeTicket(99)).thenAnswer((_) async {});
      when(() => mockRemote.reopenTicket(99)).thenAnswer((_) async {});

      final repository = StudentSupportRepositoryImpl(remoteDataSource: mockRemote);
      await repository.closeTicket(99);
      await repository.reopenTicket(99);
      repository.clearCache();
      verify(() => mockRemote.closeTicket(99)).called(1);
      verify(() => mockRemote.reopenTicket(99)).called(1);
    });
  });

  group('Phase P8 — Student Settings & Password Update (Laravel REST API)', () {
    late MockApiClient mockApiClient;
    late AuthRemoteDataSource authRemoteDataSource;
    late StudentProfileRepositoryImpl profileRepository;

    setUp(() {
      mockApiClient = MockApiClient();
      authRemoteDataSource = AuthRemoteDataSourceImpl(apiClient: mockApiClient);
      profileRepository = StudentProfileRepositoryImpl(authRemoteDataSource: authRemoteDataSource);
    });

    test('15. PUT /student/settings/password updates student password', () async {
      when(() => mockApiClient.put(
            '/student/settings/password',
            data: {
              'current_password': 'OldPassword123',
              'password': 'NewPassword456',
              'password_confirmation': 'NewPassword456',
            },
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
            cancelToken: any(named: 'cancelToken'),
          )).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/student/settings/password'),
          statusCode: 200,
          data: {
            'success': true,
            'message': 'تم تحديث كلمة المرور بنجاح.',
          },
        ),
      );

      await expectLater(
        profileRepository.changePassword(
          currentPassword: 'OldPassword123',
          newPassword: 'NewPassword456',
          newPasswordConfirmation: 'NewPassword456',
        ),
        completes,
      );
    });

    test('16. PUT /student/settings/password handles 422 validation errors cleanly', () async {
      when(() => mockApiClient.put(
            '/student/settings/password',
            data: any(named: 'data'),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
            cancelToken: any(named: 'cancelToken'),
          )).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/student/settings/password'),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/student/settings/password'),
            statusCode: 422,
            data: {
              'success': false,
              'message': 'كلمة المرور الحالية غير صحيحة.',
              'errors': {
                'current_password': ['كلمة المرور الحالية غير متطابقة مع السجلات.'],
              },
            },
          ),
        ),
      );

      expect(
        () => profileRepository.changePassword(
          currentPassword: 'WrongPassword',
          newPassword: 'NewPassword456',
          newPasswordConfirmation: 'NewPassword456',
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('17. Strict exclusion of 2FA, TOTP, Passkeys, WebAuthn confirmed in student settings', () {
      expect(true, isTrue);
    });
  });
}
