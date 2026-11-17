import 'dart:async';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/di/injection_container.dart';
import '../../core/utils/network_error_mapper.dart';
import '../../models/access_request.dart';
import '../../models/course.dart';
import '../../models/payment_receipt_model.dart';
import '../../models/user_profile.dart';
import '../../repositories/student_payment_repository.dart';
import '../../services/notification_service.dart';
import 'access_state.dart';

class AccessCubit extends Cubit<AccessState> {
  final StudentPaymentRepository _paymentRepository;
  final Map<String, AccessStatus> _statuses = {};
  final Map<String, CourseAccessRequest> _requestsByCourse = {};
  final Map<String, PaymentReceiptModel> _receiptsByCourse = {};
  bool _initialSnapshotHandled = false;

  /// In-memory cache for 0ms delay display of student requests across sessions
  static final Map<String, List<CourseAccessRequest>> _cachedRequests = {};

  AccessCubit({
    StudentPaymentRepository? paymentRepository,
  })  : _paymentRepository = paymentRepository ?? sl<StudentPaymentRepository>(),
        super(AccessInitial());

  /// Clear all cached requests on sign-out or account deletion
  static void clearCache() => _cachedRequests.clear();

  void clear() {
    _statuses.clear();
    _requestsByCourse.clear();
    _receiptsByCourse.clear();
    _initialSnapshotHandled = false;
    _cachedRequests.clear();
    emit(AccessInitial());
  }

  void reset() {
    _statuses.clear();
    _requestsByCourse.clear();
    _receiptsByCourse.clear();
    _initialSnapshotHandled = false;
    if (!isClosed) emit(AccessInitial());
  }

  /// Initialize and load student receipts for [studentId].
  /// Matches previous API for seamless integration with main.dart and existing call sites.
  void listenToStudentRequests(String studentId) {
    _initialSnapshotHandled = false;

    // Immediate emission of cached data for 0ms perception
    if (_cachedRequests.containsKey(studentId) &&
        _cachedRequests[studentId]!.isNotEmpty) {
      _statuses.clear();
      _requestsByCourse.clear();
      for (final req in _cachedRequests[studentId]!) {
        _statuses[req.courseId] = req.status;
        _requestsByCourse[req.courseId] = req;
      }
      emit(
        AccessLoaded(
          Map.unmodifiable(_statuses),
          requestsByCourse: Map.unmodifiable(_requestsByCourse),
        ),
      );
    }

    unawaited(loadStudentReceipts(studentId: studentId, silent: true));
  }

  /// Fetch student payment receipts from Laravel REST API (GET /student/receipts).
  Future<void> loadStudentReceipts({
    String? studentId,
    bool silent = false,
  }) async {
    if (!silent && _statuses.isEmpty) {
      emit(
        AccessLoading(
          courseStatuses: Map.unmodifiable(_statuses),
          requestsByCourse: Map.unmodifiable(_requestsByCourse),
        ),
      );
    }

    try {
      final receipts = await _paymentRepository.getStudentReceipts();
      final previousStatuses = Map<String, AccessStatus>.from(_statuses);

      _statuses.clear();
      _requestsByCourse.clear();
      _receiptsByCourse.clear();

      final listToCache = <CourseAccessRequest>[];

      for (final receipt in receipts) {
        final courseKey = receipt.courseId.toString();
        _receiptsByCourse[courseKey] = receipt;
        _statuses[courseKey] = receipt.status;

        final req = receipt.toCourseAccessRequest();
        _requestsByCourse[courseKey] = req;
        listToCache.add(req);

        if (_initialSnapshotHandled) {
          final prev = previousStatuses[courseKey];
          if (prev == AccessStatus.pending && receipt.status == AccessStatus.approved) {
            unawaited(
              NotificationService().showInstantNotification(
                id: receipt.id.hashCode,
                title: 'تم تفعيل اشتراكك بنجاح',
                body: 'تمت الموافقة على إيصال الدورة #${receipt.courseId}. يمكنك بدء المشاهدة الآن.',
              ),
            );
          } else if (prev == AccessStatus.pending && receipt.status == AccessStatus.rejected) {
            final notes = receipt.adminNotes?.trim() ?? '';
            unawaited(
              NotificationService().showInstantNotification(
                id: receipt.id.hashCode,
                title: 'تحديث بخصوص طلب الانضمام',
                body: notes.isNotEmpty
                    ? 'تعذر اعتماد إيصال الدورة #${receipt.courseId}: $notes'
                    : 'يرجى مراجعة بيانات إيصال السداد للدورة #${receipt.courseId} وإعادة المحاولة.',
              ),
            );
          }
        }
      }

      if (studentId != null && studentId.isNotEmpty) {
        _cachedRequests[studentId] = listToCache;
      }

      _initialSnapshotHandled = true;
      emit(
        AccessLoaded(
          Map.unmodifiable(_statuses),
          requestsByCourse: Map.unmodifiable(_requestsByCourse),
        ),
      );
    } catch (e) {
      final msg = NetworkErrorMapper.toArabicMessage(
        e,
        defaultMessage: 'تعذر تحديث حالة طلبات الانضمام حالياً.',
      );
      emit(
        AccessError(
          msg,
          courseStatuses: Map.unmodifiable(_statuses),
          requestsByCourse: Map.unmodifiable(_requestsByCourse),
        ),
      );
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
      _statuses[key] = receipt.status;
      _receiptsByCourse[key] = receipt;

      final req = receipt.toCourseAccessRequest(fallbackCourseTitle: courseTitle);
      _requestsByCourse[key] = req;

      emit(
        AccessActionSuccess(
          'تم إرسال إيصال السداد للمراجعة بنجاح وسيتم تفعيل الدورة بعد التدقيق.',
          courseStatuses: Map.unmodifiable(_statuses),
          requestsByCourse: Map.unmodifiable(_requestsByCourse),
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
    String receiptUrl = '',
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

  /// Enrollment for free/open courses.
  Future<void> enrollInOpenCourse({
    required String uid,
    required Course course,
  }) async {
    emit(
      AccessLoading(
        courseStatuses: Map.unmodifiable(_statuses),
        requestsByCourse: Map.unmodifiable(_requestsByCourse),
      ),
    );

    // Free/open course access is immediately permitted locally while backend flags it
    _statuses[course.id] = AccessStatus.approved;

    emit(
      AccessActionSuccess(
        'تم تسجيلك في دورة "${course.title}" بنجاح! يمكنك البدء الآن.',
        courseStatuses: Map.unmodifiable(_statuses),
        requestsByCourse: Map.unmodifiable(_requestsByCourse),
      ),
    );
  }

}
