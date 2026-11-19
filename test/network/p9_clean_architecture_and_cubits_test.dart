import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:secure_screen_app/core/widgets/app_button.dart';
import 'package:secure_screen_app/core/widgets/app_confirmation_dialog.dart';
import 'package:secure_screen_app/core/widgets/app_empty_state.dart';
import 'package:secure_screen_app/core/widgets/app_error_view.dart';
import 'package:secure_screen_app/core/widgets/app_loading_indicator.dart';
import 'package:secure_screen_app/core/widgets/app_password_field.dart';
import 'package:secure_screen_app/core/widgets/app_section_header.dart';
import 'package:secure_screen_app/core/widgets/app_status_badge.dart';
import 'package:secure_screen_app/core/widgets/app_text_field.dart';
import 'package:secure_screen_app/logic/assignments/assignments_cubit.dart';
import 'package:secure_screen_app/logic/assignments/assignments_state.dart';
import 'package:secure_screen_app/logic/certificates/certificates_cubit.dart';
import 'package:secure_screen_app/logic/certificates/certificates_state.dart';
import 'package:secure_screen_app/logic/notifications/notifications_cubit.dart';
import 'package:secure_screen_app/logic/notifications/notifications_state.dart';
import 'package:secure_screen_app/logic/support/support_tickets_cubit.dart';
import 'package:secure_screen_app/logic/support/support_tickets_state.dart';
import 'package:secure_screen_app/logic/support/ticket_conversation_cubit.dart';
import 'package:secure_screen_app/logic/support/ticket_conversation_state.dart';
import 'package:secure_screen_app/models/app_notification.dart';
import 'package:secure_screen_app/models/assignment.dart';
import 'package:secure_screen_app/models/assignment_submission.dart';
import 'package:secure_screen_app/models/clinical_task_data.dart';
import 'package:secure_screen_app/models/course_certificate.dart';
import 'package:secure_screen_app/models/support_ticket.dart';
import 'package:secure_screen_app/repositories/student_assignments_repository.dart';
import 'package:secure_screen_app/repositories/student_certificates_repository.dart';
import 'package:secure_screen_app/repositories/student_notifications_repository.dart';
import 'package:secure_screen_app/repositories/student_profile_repository.dart';
import 'package:secure_screen_app/repositories/student_support_repository.dart';
import 'package:secure_screen_app/screens/student/profile/widgets/change_password_sheet.dart';

class MockStudentNotificationsRepository extends Mock
    implements StudentNotificationsRepository {}

class MockStudentSupportRepository extends Mock
    implements StudentSupportRepository {}

class MockStudentCertificatesRepository extends Mock
    implements StudentCertificatesRepository {}

class MockStudentAssignmentsRepository extends Mock
    implements StudentAssignmentsRepository {}

class MockStudentProfileRepository extends Mock
    implements StudentProfileRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase P9 — Clean Architecture & Feature Cubits Verification', () {
    late MockStudentNotificationsRepository mockNotifRepo;
    late MockStudentSupportRepository mockSupportRepo;
    late MockStudentCertificatesRepository mockCertRepo;
    late MockStudentAssignmentsRepository mockAsgRepo;

    setUp(() {
      mockNotifRepo = MockStudentNotificationsRepository();
      mockSupportRepo = MockStudentSupportRepository();
      mockCertRepo = MockStudentCertificatesRepository();
      mockAsgRepo = MockStudentAssignmentsRepository();
    });

    test('1. NotificationsCubit: loads notifications, handles filter and pagination', () async {
      when(() => mockNotifRepo.getNotifications(
            filter: any(named: 'filter'),
            page: any(named: 'page'),
            perPage: any(named: 'perPage'),
          )).thenAnswer(
        (_) async => const StudentNotificationsData(
          unreadCount: 3,
          notifications: [
            AppNotification(
              id: 'notif-1',
              type: 'system',
              title: 'إشعار تجريبي',
              message: 'محتوى الإشعار',
              isRead: false,
            ),
          ],
          pagination: NotificationPaginationMeta(
            currentPage: 1,
            lastPage: 2,
            perPage: 15,
            total: 20,
          ),
        ),
      );

      final cubit = NotificationsCubit(repository: mockNotifRepo);
      expect(cubit.state, isA<NotificationsInitial>());

      await cubit.loadNotifications(filter: 'all');
      expect(cubit.state, isA<NotificationsLoaded>());

      final loadedState = cubit.state as NotificationsLoaded;
      expect(loadedState.unreadCount, 3);
      expect(loadedState.notifications.length, 1);
      expect(loadedState.hasMore, isTrue);

      // Change filter
      await cubit.changeFilter('unread');
      expect(cubit.state, isA<NotificationsLoaded>());
      expect((cubit.state as NotificationsLoaded).filter, 'unread');

      await cubit.close();
    });

    test('2. NotificationsCubit: markAsRead and markAllAsRead update state synchronously', () async {
      when(() => mockNotifRepo.getNotifications(
            filter: any(named: 'filter'),
            page: any(named: 'page'),
            perPage: any(named: 'perPage'),
          )).thenAnswer(
        (_) async => const StudentNotificationsData(
          unreadCount: 1,
          notifications: [
            AppNotification(
              id: 'notif-1',
              type: 'system',
              title: 'إشعار غير مقروء',
              message: 'محتوى الإشعار',
              isRead: false,
            ),
          ],
        ),
      );

      when(() => mockNotifRepo.markAsRead('notif-1'))
          .thenAnswer((_) async {});
      when(() => mockNotifRepo.markAllAsRead())
          .thenAnswer((_) async => 1);

      final cubit = NotificationsCubit(repository: mockNotifRepo);
      await cubit.loadNotifications();

      await cubit.markAsRead('notif-1');
      var state = cubit.state as NotificationsLoaded;
      expect(state.unreadCount, 0);
      expect(state.notifications.first.isRead, isTrue);

      await cubit.markAllAsRead();
      state = cubit.state as NotificationsLoaded;
      expect(state.unreadCount, 0);

      await cubit.close();
    });

    test('3. SupportTicketsCubit: loads tickets and pagination', () async {
      when(() => mockSupportRepo.getTickets(
            status: any(named: 'status'),
            search: any(named: 'search'),
            page: any(named: 'page'),
            perPage: any(named: 'perPage'),
          )).thenAnswer(
        (_) async => StudentTicketsData(
          counts: const {'all': 5, 'open': 2},
          tickets: [
            SupportTicket(
              id: 101,
              ticketNumber: 'TKT-101',
              subject: 'استفسار عن المحاضرة',
              category: 'academic',
              categoryLabel: 'أكاديمي',
              priority: 'normal',
              priorityLabel: 'عادي',
              status: 'open',
              statusLabel: 'مفتوحة',
              createdAt: DateTime.now(),
            ),
          ],
          pagination: const NotificationPaginationMeta(
            currentPage: 1,
            lastPage: 1,
            perPage: 12,
            total: 1,
          ),
        ),
      );

      final cubit = SupportTicketsCubit(repository: mockSupportRepo);
      expect(cubit.state, isA<SupportTicketsInitial>());

      await cubit.loadTickets(status: 'open');
      expect(cubit.state, isA<SupportTicketsLoaded>());

      final loadedState = cubit.state as SupportTicketsLoaded;
      expect(loadedState.tickets.length, 1);
      expect(loadedState.counts['open'], 2);

      await cubit.close();
    });

    test('4. TicketConversationCubit: conversation flow and live polling', () async {
      final ticket = SupportTicket(
        id: 101,
        ticketNumber: 'TKT-101',
        subject: 'استفسار عن المحاضرة',
        category: 'academic',
        categoryLabel: 'أكاديمي',
        priority: 'normal',
        priorityLabel: 'عادي',
        status: 'open',
        statusLabel: 'مفتوحة',
        createdAt: DateTime.now(),
        messages: [
          SupportMessage(
            id: 1,
            ticketId: 101,
            senderType: 'student',
            senderName: 'الطالب',
            message: 'مرحبا، لدي استفسار',
            createdAt: DateTime.now(),
          ),
        ],
      );

      when(() => mockSupportRepo.getTicketDetails(101))
          .thenAnswer((_) async => ticket);
      when(() => mockSupportRepo.pollTicketUpdates(
            ticketId: 101,
            afterId: any(named: 'afterId'),
          )).thenAnswer(
        (_) async => TicketPollResult(
          ticketStatus: 'open',
          isClosed: false,
          messages: [
            SupportMessage(
              id: 2,
              ticketId: 101,
              senderType: 'support',
              senderName: 'الدعم الفني',
              message: 'أهلاً بك، تفضل بالسؤال',
              createdAt: DateTime.now(),
            ),
          ],
        ),
      );

      final cubit = TicketConversationCubit(repository: mockSupportRepo, ticketId: 101);
      await cubit.loadTicket();

      expect(cubit.state, isA<TicketConversationLoaded>());
      var state = cubit.state as TicketConversationLoaded;
      expect(state.messages.length, 1);
      expect(cubit.lastMessageId, 1);

      final hasNew = await cubit.pollUpdates();
      expect(hasNew, isTrue);

      state = cubit.state as TicketConversationLoaded;
      expect(state.messages.length, 2);
      expect(cubit.lastMessageId, 2);

      await cubit.close();
    });

    test('5. CertificatesCubit: loads student certificates and downloads PDF', () async {
      final cert = CourseCertificate(
        id: '5',
        courseId: '2',
        courseTitle: 'كورس التخاطب الشامل',
        studentId: 'student-99',
        studentName: 'أحمد محمود',
        certificateCode: 'CERT-2026-005',
        fileUrl: 'https://cdn.alameen-center.online/certs/cert_5.pdf',
        issuedAt: DateTime.now(),
      );

      when(() => mockCertRepo.getStudentCertificates(
            forceRefresh: any(named: 'forceRefresh'),
            currentStudentId: any(named: 'currentStudentId'),
          )).thenAnswer((_) async => [cert]);

      when(() => mockCertRepo.downloadOfficialCertificatePdf(cert.fileUrl!))
          .thenAnswer((_) async => Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2D])); // %PDF-

      final cubit = CertificatesCubit(repository: mockCertRepo);
      await cubit.loadCertificates();

      expect(cubit.state, isA<CertificatesLoaded>());
      final loaded = cubit.state as CertificatesLoaded;
      expect(loaded.certificates.length, 1);
      expect(loaded.certificates.first.certificateCode, 'CERT-2026-005');

      final pdfBytes = await cubit.downloadCertificatePdf(cert.fileUrl!);
      expect(pdfBytes.length, 5);
      expect(pdfBytes[0], 0x25); // '%'

      await cubit.close();
    });

    test('6. AssignmentsCubit: loads clinical tasks and submits audio submission', () async {
      final assignment = Assignment(
        id: '1',
        courseId: '2',
        courseTitle: 'كورس التخاطب',
        lessonId: '10',
        title: 'مهمة فحص النطق',
        instructions: 'سجل صوت الحالة',
        createdAt: DateTime.now(),
      );

      when(() => mockAsgRepo.getAssignments()).thenAnswer(
        (_) async => StudentAssignmentsData(
          tasks: [assignment],
          submissions: const [],
        ),
      );

      when(() => mockAsgRepo.submitClinicalTask(
            taskId: any(named: 'taskId'),
            audioFile: any(named: 'audioFile'),
            audioBase64: any(named: 'audioBase64'),
            durationSeconds: any(named: 'durationSeconds'),
            studentNotes: any(named: 'studentNotes'),
          )).thenAnswer(
        (_) async => AssignmentSubmission(
          id: 'sub-1',
          assignmentId: '1',
          courseId: '2',
          studentId: 'student-99',
          studentName: 'أحمد محمود',
          studentEmail: 'ahmed@example.com',
          solutionText: 'ملاحظات سريرية للتسجيل',
          audioRecordingUrl: 'https://alameen-center.online/submissions/1.m4a',
          status: 'pending',
          submittedAt: DateTime.now(),
        ),
      );

      final cubit = AssignmentsCubit(repository: mockAsgRepo);
      await cubit.loadAssignments();

      expect(cubit.state, isA<AssignmentsLoaded>());
      expect((cubit.state as AssignmentsLoaded).data.tasks.length, 1);

      final submission = await cubit.submitClinicalTask(
        taskId: 1,
        studentNotes: 'ملاحظات سريرية للتسجيل',
      );
      expect(submission.id, 'sub-1');
      expect(submission.status, 'pending');

      await cubit.close();
    });
  });

  group('Phase P9 — Core Reusable UI Widgets Verification', () {
    testWidgets('7. AppButton: renders variants, labels and handles callbacks', (tester) async {
      bool pressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton(
              text: 'زر تجريبي',
              onPressed: () => pressed = true,
              variant: AppButtonVariant.primary,
            ),
          ),
        ),
      );

      expect(find.text('زر تجريبي'), findsOneWidget);
      await tester.tap(find.text('زر تجريبي'));
      expect(pressed, isTrue);

      // Loading state
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppButton(
              text: 'جاري الحفظ...',
              isLoading: true,
              onPressed: null,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('8. AppTextField & AppPasswordField: renders labels and toggles obscureText', (tester) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const AppTextField(
                  label: 'الاسم الكامل',
                  hintText: 'أدخل اسمك الثلاثي',
                ),
                AppPasswordField(
                  label: 'كلمة المرور',
                  controller: controller,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('الاسم الكامل'), findsOneWidget);
      expect(find.text('أدخل اسمك الثلاثي'), findsOneWidget);
      expect(find.text('كلمة المرور'), findsOneWidget);

      // Eye toggle icon for password field
      final eyeIcon = find.byIcon(PhosphorIconsRegular.eyeSlash);
      expect(eyeIcon, findsOneWidget);

      // Tap eye icon to toggle visibility
      await tester.tap(eyeIcon);
      await tester.pumpAndSettle();
      expect(find.byIcon(PhosphorIconsRegular.eye), findsOneWidget);
    });

    testWidgets('9. AppLoadingIndicator: displays spinner and status message', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppLoadingIndicator(
              message: 'جاري جلب البيانات من الخادم...',
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('جاري جلب البيانات من الخادم...'), findsOneWidget);
    });

    testWidgets('10. AppErrorView: displays error and triggers retry', (tester) async {
      bool retried = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppErrorView(
              message: 'انقطع الاتصال بالخادم',
              onRetry: () => retried = true,
            ),
          ),
        ),
      );

      expect(find.text('انقطع الاتصال بالخادم'), findsOneWidget);
      expect(find.text('إعادة المحاولة'), findsOneWidget);

      await tester.tap(find.text('إعادة المحاولة'));
      expect(retried, isTrue);
    });

    testWidgets('11. AppEmptyState: displays icon, title and action button', (tester) async {
      bool actionClicked = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppEmptyState(
              title: 'لا توجد عناصر',
              description: 'لم يتم العثور على أي بيانات مطابقة',
              actionText: 'إضافة جديد',
              onAction: () => actionClicked = true,
            ),
          ),
        ),
      );

      expect(find.text('لا توجد عناصر'), findsOneWidget);
      expect(find.text('لم يتم العثور على أي بيانات مطابقة'), findsOneWidget);
      expect(find.text('إضافة جديد'), findsOneWidget);

      await tester.tap(find.text('إضافة جديد'));
      expect(actionClicked, isTrue);
    });

    testWidgets('12. AppConfirmationDialog: confirms and cancels action', (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await AppConfirmationDialog.show(
                    context,
                    title: 'تأكيد الحذف',
                    message: 'هل أنت متأكد من الحذف؟',
                    confirmText: 'نعم، احذف',
                    isDestructive: true,
                  );
                },
                child: const Text('افتح الحوار'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('افتح الحوار'));
      await tester.pumpAndSettle();

      expect(find.text('تأكيد الحذف'), findsOneWidget);
      expect(find.text('هل أنت متأكد من الحذف؟'), findsOneWidget);
      expect(find.text('نعم، احذف'), findsOneWidget);

      await tester.tap(find.text('نعم، احذف'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });

    testWidgets('13. AppStatusBadge: renders status text and badge styling', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                AppStatusBadge(label: 'ناجح', statusType: AppStatusType.success),
                AppStatusBadge(label: 'معلق', statusType: AppStatusType.warning),
                AppStatusBadge(label: 'مرفوض', statusType: AppStatusType.error),
                AppStatusBadge(label: 'قيد المعالجة', statusType: AppStatusType.info),
              ],
            ),
          ),
        ),
      );

      expect(find.text('ناجح'), findsOneWidget);
      expect(find.text('معلق'), findsOneWidget);
      expect(find.text('مرفوض'), findsOneWidget);
      expect(find.text('قيد المعالجة'), findsOneWidget);
    });

    testWidgets('14. AppSectionHeader: renders title and action label', (tester) async {
      bool seeAll = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppSectionHeader(
              title: 'الدورات الموصى بها',
              subtitle: 'أحدث المساقات السريرية المعتمدة',
              actionText: 'عرض الكل',
              onAction: () => seeAll = true,
            ),
          ),
        ),
      );

      expect(find.text('الدورات الموصى بها'), findsOneWidget);
      expect(find.text('أحدث المساقات السريرية المعتمدة'), findsOneWidget);
      expect(find.text('عرض الكل'), findsOneWidget);

      await tester.tap(find.text('عرض الكل'));
      expect(seeAll, isTrue);
    });

    testWidgets('15. ChangePasswordSheet: informs Google-only accounts and prevents password changes', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChangePasswordSheet(
              isGoogleAccount: true,
            ),
          ),
        ),
      );

      expect(find.text('حسابك موثق عبر Google'), findsOneWidget);
      expect(
        find.textContaining('حسابك مسجل عبر تسجيل دخول Google الموحد ولا يتطلب كلمة مرور محلية'),
        findsOneWidget,
      );
      expect(find.text('فهمت ذلك'), findsOneWidget);

      // Password input fields MUST NOT be present for Google accounts
      expect(find.byType(AppPasswordField), findsNothing);
    });
  });
}
