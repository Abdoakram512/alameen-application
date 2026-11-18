import 'dart:async';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/di/injection_container.dart';
import '../../core/utils/network_error_mapper.dart';
import '../../models/access_request.dart';
import '../../models/course.dart';
import '../../models/payment_receipt_model.dart';
import '../../models/user_profile.dart';
import '../../repositories/student_courses_repository.dart';
import '../../repositories/student_payment_repository.dart';
import '../../services/notification_service.dart';
import 'access_state.dart';

class AccessCubit extends Cubit<AccessState> {
  final StudentPaymentRepository _paymentRepository;
  final StudentCoursesRepository? _coursesRepository;
  final Map<String, AccessStatus> _statuses = {};
  final Map<String, CourseAccessRequest> _requestsByCourse = {};
  final Map<String, PaymentReceiptModel> _receiptsByCourse = {};
  final List<CourseAccessRequest> _allRequests = [];
  bool _initialSnapshotHandled = false;

  /// In-memory cache for fast display of student requests across session switches
  static final Map<String, List<CourseAccessRequest>> _cachedRequests = {};

  AccessCubit({
    StudentPaymentRepository? paymentRepository,
    StudentCoursesRepository? coursesRepository,
  })  : _paymentRepository = paymentRepository ?? sl<StudentPaymentRepository>(),
        _coursesRepository = coursesRepository ??
            (sl.isRegistered<StudentCoursesRepository>()
                ? sl<StudentCoursesRepository>()
                : null),
        super(AccessInitial());

  /// Clear all cached requests on sign-out or account deletion
  static void clearCache() => _cachedRequests.clear();

  void clear() {
    _statuses.clear();
    _requestsByCourse.clear();
    _receiptsByCourse.clear();
    _allRequests.clear();
    _initialSnapshotHandled = false;
    _cachedRequests.clear();
    emit(AccessInitial());
  }

  void reset() {
    _statuses.clear();
    _requestsByCourse.clear();
    _receiptsByCourse.clear();
    _allRequests.clear();
    _initialSnapshotHandled = false;
    if (!isClosed) emit(AccessInitial());
  }

  /// Initialize and load student receipts for [studentId].
  void listenToStudentRequests(String studentId) {
    _initialSnapshotHandled = false;

    if (_cachedRequests.containsKey(studentId) &&
        _cachedRequests[studentId]!.isNotEmpty) {
      _statuses.clear();
      _requestsByCourse.clear();
      _allRequests.clear();
      _allRequests.addAll(_cachedRequests[studentId]!);

      for (final req in _allRequests) {
        if (_statuses[req.courseId] != AccessStatus.approved) {
          _statuses[req.courseId] = req.status;
          _requestsByCourse[req.courseId] = req;
        }
      }

      emit(
        AccessLoaded(
          Map.unmodifiable(_statuses),
          requestsByCourse: Map.unmodifiable(_requestsByCourse),
          allRequests: List.unmodifiable(_allRequests),
        ),
      );
    }

    unawaited(loadStudentReceipts(studentId: studentId, silent: true));
  }

  /// Fetch student payment receipts from Laravel REST API (GET /student/receipts).
  Future<void> loadStudentReceipts({
    String? studentId,
    bool silent = false,
    bool emitLoaded = true,
  }) async {
    if (!silent && _statuses.isEmpty) {
      emit(
        AccessLoading(
          courseStatuses: Map.unmodifiable(_statuses),
          requestsByCourse: Map.unmodifiable(_requestsByCourse),
          allRequests: List.unmodifiable(_allRequests),
        ),
      );
    }

    try {
      final receipts = await _paymentRepository.getStudentReceipts();
      final previousStatuses = Map<String, AccessStatus>.from(_statuses);

      _statuses.clear();
      _requestsByCourse.clear();
      _receiptsByCourse.clear();
      _allRequests.clear();

      // Convert all receipts to CourseAccessRequest models
      final allConverted = receipts.map((r) => r.toCourseAccessRequest()).toList();
      allConverted.sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
      _allRequests.addAll(allConverted);

      // Group receipts by courseId to resolve authoritative status
      final receiptsByCourseGroup = <String, List<PaymentReceiptModel>>{};
      for (final receipt in receipts) {
        final courseKey = receipt.courseId.toString();
        receiptsByCourseGroup.putIfAbsent(courseKey, () => []).add(receipt);
      }

      for (final entry in receiptsByCourseGroup.entries) {
        final courseKey = entry.key;
        final courseReceipts = entry.value;

        // Sort course receipts by date (newest first)
        courseReceipts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        // Authoritative status priority: approved > pending > rejected
        final hasApproved = courseReceipts.any((r) => r.status == AccessStatus.approved);
        final hasPending = courseReceipts.any((r) => r.status == AccessStatus.pending);

        final AccessStatus effectiveStatus;
        final PaymentReceiptModel primaryReceipt;

        if (hasApproved) {
          effectiveStatus = AccessStatus.approved;
          primaryReceipt = courseReceipts.firstWhere((r) => r.status == AccessStatus.approved);
        } else if (hasPending) {
          effectiveStatus = AccessStatus.pending;
          primaryReceipt = courseReceipts.firstWhere((r) => r.status == AccessStatus.pending);
        } else {
          effectiveStatus = courseReceipts.first.status;
          primaryReceipt = courseReceipts.first;
        }

        _statuses[courseKey] = effectiveStatus;
        _receiptsByCourse[courseKey] = primaryReceipt;
        _requestsByCourse[courseKey] = primaryReceipt.toCourseAccessRequest();

        // Check for confirmed status transitions
        if (_initialSnapshotHandled) {
          final prev = previousStatuses[courseKey];
          if (prev == AccessStatus.pending && effectiveStatus == AccessStatus.approved) {
            unawaited(
              NotificationService().showInstantNotification(
                id: primaryReceipt.id.hashCode,
                title: 'تم تفعيل اشتراكك بنجاح',
                body: 'تمت الموافقة على إيصال الدورة #${primaryReceipt.courseId}. يمكنك بدء المشاهدة الآن.',
              ),
            );
          } else if (prev == AccessStatus.pending && effectiveStatus == AccessStatus.rejected) {
            final notes = primaryReceipt.adminNotes?.trim() ?? '';
            unawaited(
              NotificationService().showInstantNotification(
                id: primaryReceipt.id.hashCode,
                title: 'تحديث بخصوص طلب الانضمام',
                body: notes.isNotEmpty
                    ? 'تعذر اعتماد إيصال الدورة #${primaryReceipt.courseId}: $notes'
                    : 'يرجى مراجعة بيانات إيصال السداد للدورة #${primaryReceipt.courseId} وإعادة المحاولة.',
              ),
            );
          }
        }
      }

      if (studentId != null && studentId.isNotEmpty) {
        _cachedRequests[studentId] = List.from(_allRequests);
      }

      _initialSnapshotHandled = true;
      if (emitLoaded) {
        emit(
          AccessLoaded(
            Map.unmodifiable(_statuses),
            requestsByCourse: Map.unmodifiable(_requestsByCourse),
            allRequests: List.unmodifiable(_allRequests),
          ),
        );
      }
    } catch (e) {
      if (emitLoaded) {
        final msg = NetworkErrorMapper.toArabicMessage(
          e,
          defaultMessage: 'تعذر تحديث حالة طلبات الانضمام حالياً.',
        );
        emit(
          AccessError(
            msg,
            courseStatuses: Map.unmodifiable(_statuses),
            requestsByCourse: Map.unmodifiable(_requestsByCourse),
            allRequests: List.unmodifiable(_allRequests),
          ),
        );
      } else {
        rethrow;
      }
    }
  }

  /// Submit a payment receipt to the Laravel backend (POST /student/courses/{slug}/receipt).
  Future<void> submitCourseReceipt({
    required String courseSlug,
    required String courseId,
    required String courseTitle,
    required String paymentMethod,
    required String senderName,
    required String senderAccount,
    required double amount,
    required String receiptFilePath,
    String? transactionReference,
  }) async {
    emit(
      AccessLoading(
        courseStatuses: Map.unmodifiable(_statuses),
        requestsByCourse: Map.unmodifiable(_requestsByCourse),
        allRequests: List.unmodifiable(_allRequests),
      ),
    );

    try {
      final receipt = await _paymentRepository.submitCourseReceipt(
        courseSlug: courseSlug,
        paymentMethod: paymentMethod,
        senderName: senderName,
        senderAccount: senderAccount,
        amount: amount,
        receiptFilePath: receiptFilePath,
        transactionReference: transactionReference,
      );

      final key = courseId.isNotEmpty ? courseId : receipt.courseId.toString();

      // If already approved, do NOT downgrade authoritative entitlement
      if (_statuses[key] != AccessStatus.approved) {
        _statuses[key] = receipt.status;
      }

      _receiptsByCourse[key] = receipt;
      final req = receipt.toCourseAccessRequest(fallbackCourseTitle: courseTitle);
      _requestsByCourse[key] = req;
      _allRequests.insert(0, req);

      emit(
        AccessActionSuccess(
          'تم إرسال إيصال السداد للمراجعة بنجاح وسيتم تفعيل الدورة بعد التدقيق.',
          courseStatuses: Map.unmodifiable(_statuses),
          requestsByCourse: Map.unmodifiable(_requestsByCourse),
          allRequests: List.unmodifiable(_allRequests),
        ),
      );
    } catch (e) {
      final arabicError = NetworkErrorMapper.toArabicMessage(
        e,
        defaultMessage: 'تعذر إرسال إيصال السداد، يرجى التحقق من الاتصال والمحاولة مرة أخرى.',
      );
      emit(
        AccessError(
          arabicError,
          courseStatuses: Map.unmodifiable(_statuses),
          requestsByCourse: Map.unmodifiable(_requestsByCourse),
          allRequests: List.unmodifiable(_allRequests),
        ),
      );
    }
  }

  /// Backwards-compatible submission method adapting existing UI calls to the Laravel API.
  Future<void> sendRequest({
    required Course course,
    required UserModel user,
    String paymentMethod = 'فودافون كاش',
    String senderNumberOrRef = '',
    File? receiptFile,
    String? senderName,
    String? senderAccount,
    double? amount,
    String? transactionReference,
  }) async {
    if (receiptFile == null) {
      emit(
        AccessError(
          'يرجى إرفاق صورة واضحة لإيصال السداد لاعتماد الطلب من قبل الإدارة.',
          courseStatuses: Map.unmodifiable(_statuses),
          requestsByCourse: Map.unmodifiable(_requestsByCourse),
          allRequests: List.unmodifiable(_allRequests),
        ),
      );
      return;
    }

    final effectiveSlug = (course.slug != null && course.slug!.trim().isNotEmpty)
        ? course.slug!
        : course.id;

    final effectiveSenderName = (senderName != null && senderName.trim().isNotEmpty)
        ? senderName.trim()
        : (user.displayName.trim().isNotEmpty ? user.displayName.trim() : 'متدرب سنتر الأمين');

    final effectiveSenderAccount = (senderAccount != null && senderAccount.trim().isNotEmpty)
        ? senderAccount.trim()
        : (senderNumberOrRef.trim().isNotEmpty
            ? senderNumberOrRef.trim()
            : (user.phone.trim().isNotEmpty ? user.phone.trim() : '01000000000'));

    final effectiveAmount = amount ?? (course.price > 0 ? course.price : 100.0);

    await submitCourseReceipt(
      courseSlug: effectiveSlug,
      courseId: course.id,
      courseTitle: course.title,
      paymentMethod: paymentMethod,
      senderName: effectiveSenderName,
      senderAccount: effectiveSenderAccount,
      amount: effectiveAmount,
      receiptFilePath: receiptFile.path,
      transactionReference: transactionReference ?? (senderNumberOrRef.isNotEmpty ? senderNumberOrRef : null),
    );
  }

  /// Enrollment check for free/open & auto-enrolled courses.
  /// Relies authoritatively on Laravel course entitlement first, then payment receipts.
  /// Never grants client-side approved access.
  Future<void> enrollInOpenCourse({
    required String uid,
    required Course course,
  }) async {
    emit(
      AccessLoading(
        courseStatuses: Map.unmodifiable(_statuses),
        requestsByCourse: Map.unmodifiable(_requestsByCourse),
        allRequests: List.unmodifiable(_allRequests),
      ),
    );

    try {
      bool? serverHasEnrolled;
      final coursesRepo = _coursesRepository;
      if (coursesRepo != null) {
        try {
          final courseSlug = (course.slug != null && course.slug!.trim().isNotEmpty)
              ? course.slug!.trim()
              : course.id;
          final detailed = await coursesRepo.getCourseDetails(courseSlug);
          if (detailed.isDetailedFromAuthServer) {
            serverHasEnrolled = detailed.hasEnrolled;
          }
        } catch (_) {}
      }

      if (serverHasEnrolled == true) {
        emit(
          AccessActionSuccess(
            'تم تأكيد اشتراكك في دورة "${course.title}" من الخادم بنجاح.',
            courseStatuses: Map.unmodifiable(_statuses),
            requestsByCourse: Map.unmodifiable(_requestsByCourse),
            allRequests: List.unmodifiable(_allRequests),
          ),
        );
        return;
      }

      // Refresh receipts from the backend without intermediate state flickering
      await loadStudentReceipts(studentId: uid, silent: true, emitLoaded: false);

      if (serverHasEnrolled != false && _statuses[course.id] == AccessStatus.approved) {
        emit(
          AccessActionSuccess(
            'تم تأكيد اشتراكك في دورة "${course.title}" من الخادم بنجاح.',
            courseStatuses: Map.unmodifiable(_statuses),
            requestsByCourse: Map.unmodifiable(_requestsByCourse),
            allRequests: List.unmodifiable(_allRequests),
          ),
        );
      } else {
        emit(
          AccessError(
            'التسجيل في دورة "${course.title}" يتطلب اعتماداً من إدارة الأكاديمية أو إرسال إيصال السداد.',
            courseStatuses: Map.unmodifiable(_statuses),
            requestsByCourse: Map.unmodifiable(_requestsByCourse),
            allRequests: List.unmodifiable(_allRequests),
          ),
        );
      }
    } catch (e) {
      final msg = NetworkErrorMapper.toArabicMessage(
        e,
        defaultMessage: 'تعذر التحقق من حالة التسجيل، يرجى المحاولة لاحقاً.',
      );
      emit(
        AccessError(
          msg,
          courseStatuses: Map.unmodifiable(_statuses),
          requestsByCourse: Map.unmodifiable(_requestsByCourse),
          allRequests: List.unmodifiable(_allRequests),
        ),
      );
    }
  }
}
