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

/// يدير حالة إيصالات الدفع وطلبات الالتحاق (Payment Receipts & Access Requests).
///
/// قاعدة معمارية صارمة:
/// خادم Laravel هو المصدر الأوحد للحقيقة (Single Source of Truth) لأهلية الاشتراك (Course Entitlement).
/// إيصالات الدفع تمثل سجل المعاملات المالية وحالتها الإدارية (pending / approved / rejected)
/// ولا تمثل بذاتها ترخيصاً ملزماً بالوصول للمحتوى، ولا يجوز لها تجاوز قرارات الخادم أو إلغاء الحظر.
class AccessCubit extends Cubit<AccessState> {
  final StudentPaymentRepository _paymentRepository;
  final StudentCoursesRepository? _coursesRepository;

  final Map<String, AccessStatus> _statuses = {};
  final Map<String, CourseAccessRequest> _requestsByCourse = {};
  final Map<String, PaymentReceiptModel> _receiptsByCourse = {};
  final List<CourseAccessRequest> _allRequests = [];
  bool _initialSnapshotHandled = false;

  /// حارس أجيال الطلبات لمنع تداخل الاستجابات غير المتزامنة بين الجلسات
  int _requestGeneration = 0;
  String? _activeStudentId;

  AccessCubit({
    StudentPaymentRepository? paymentRepository,
    StudentCoursesRepository? coursesRepository,
  })  : _paymentRepository = paymentRepository ?? sl<StudentPaymentRepository>(),
        _coursesRepository = coursesRepository ??
            (sl.isRegistered<StudentCoursesRepository>()
                ? sl<StudentCoursesRepository>()
                : null),
        super(AccessInitial());

  /// تنظيف الذاكرة المؤقتة (توافق خلفي للاختبارات والمصادقة)
  static void clearCache() {
    // لم يعد يتم استخدام كاش ثابت مشترك بين المستخدمين لمنع تسريب البيانات
  }

  void clear() {
    _requestGeneration++;
    _activeStudentId = null;
    _statuses.clear();
    _requestsByCourse.clear();
    _receiptsByCourse.clear();
    _allRequests.clear();
    _initialSnapshotHandled = false;
    emit(AccessInitial());
  }

  void reset() {
    _requestGeneration++;
    _activeStudentId = null;
    _statuses.clear();
    _requestsByCourse.clear();
    _receiptsByCourse.clear();
    _allRequests.clear();
    _initialSnapshotHandled = false;
    if (!isClosed) emit(AccessInitial());
  }

  /// الاستماع لطلبات وإيصالات الطالب بناءً على معرّفه الموثق [studentId].
  void listenToStudentRequests(String studentId) {
    if (_activeStudentId != studentId) {
      _requestGeneration++;
      _activeStudentId = studentId;
      _statuses.clear();
      _requestsByCourse.clear();
      _receiptsByCourse.clear();
      _allRequests.clear();
      _initialSnapshotHandled = false;
      emit(AccessInitial());
    }

    unawaited(loadStudentReceipts(studentId: studentId, silent: true));
  }

  /// جلب إيصالات الدفع الخاصة بالطالب من Laravel REST API (GET /student/receipts).
  Future<void> loadStudentReceipts({
    String? studentId,
    bool silent = false,
    bool emitLoaded = true,
  }) async {
    final generation = ++_requestGeneration;
    await _loadStudentReceiptsInternal(
      generation: generation,
      studentId: studentId,
      silent: silent,
      emitLoaded: emitLoaded,
    );
  }

  Future<void> _loadStudentReceiptsInternal({
    required int generation,
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

      // حماية صارمة من تسريب البيانات: إذا تغير جيل الطلب أثناء الجلب (تسجيل خروج أو تبديل مستخدم)، يتم التخلص من الاستجابة فوراً
      if (generation != _requestGeneration) {
        return;
      }

      final previousStatuses = Map<String, AccessStatus>.from(_statuses);

      _statuses.clear();
      _requestsByCourse.clear();
      _receiptsByCourse.clear();
      _allRequests.clear();

      final allConverted = receipts.map((r) => r.toCourseAccessRequest()).toList();
      allConverted.sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
      _allRequests.addAll(allConverted);

      // تجميع الإيصالات حسب الدورة لتحديد أحدث حالة إدارية للإيصال
      final receiptsByCourseGroup = <String, List<PaymentReceiptModel>>{};
      for (final receipt in receipts) {
        final courseKey = receipt.courseId.toString();
        receiptsByCourseGroup.putIfAbsent(courseKey, () => []).add(receipt);
      }

      for (final entry in receiptsByCourseGroup.entries) {
        final courseKey = entry.key;
        final courseReceipts = entry.value;

        // فرز الإيصالات من الأحدث للأقدم
        courseReceipts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        // حالة الإيصال الإدارية الأحدث:
        // إذا كان هناك إيصال معتمد نأخذه، أو قيد المراجعة، أو الأحدث
        final hasApproved = courseReceipts.any((r) => r.status == AccessStatus.approved);
        final hasPending = courseReceipts.any((r) => r.status == AccessStatus.pending);

        final AccessStatus effectiveReceiptStatus;
        final PaymentReceiptModel primaryReceipt;

        if (hasApproved) {
          effectiveReceiptStatus = AccessStatus.approved;
          primaryReceipt = courseReceipts.firstWhere((r) => r.status == AccessStatus.approved);
        } else if (hasPending) {
          effectiveReceiptStatus = AccessStatus.pending;
          primaryReceipt = courseReceipts.firstWhere((r) => r.status == AccessStatus.pending);
        } else {
          effectiveReceiptStatus = courseReceipts.first.status;
          primaryReceipt = courseReceipts.first;
        }

        _statuses[courseKey] = effectiveReceiptStatus;
        _receiptsByCourse[courseKey] = primaryReceipt;
        _requestsByCourse[courseKey] = primaryReceipt.toCourseAccessRequest();

        // إشعارات تحديث حالة الإيصال
        if (_initialSnapshotHandled) {
          final prev = previousStatuses[courseKey];
          if (prev == AccessStatus.pending && effectiveReceiptStatus == AccessStatus.approved) {
            unawaited(
              NotificationService().showInstantNotification(
                id: primaryReceipt.id.hashCode,
                title: 'تم اعتماد إيصال السداد بنجاح',
                body: 'تمت الموافقة على إيصال الدورة #${primaryReceipt.courseId}. يمكنك بدء المشاهدة بمجرد تفعيل الخادم لاشتراكك.',
              ),
            );
          } else if (prev == AccessStatus.pending && effectiveReceiptStatus == AccessStatus.rejected) {
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

      _initialSnapshotHandled = true;
      if (!isClosed && emitLoaded && generation == _requestGeneration) {
        emit(
          AccessLoaded(
            Map.unmodifiable(_statuses),
            requestsByCourse: Map.unmodifiable(_requestsByCourse),
            allRequests: List.unmodifiable(_allRequests),
          ),
        );
      }
    } catch (e) {
      if (!isClosed && emitLoaded && generation == _requestGeneration) {
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

  /// إرسال إيصال سداد إلى خادم Laravel (POST /student/courses/{slug}/receipt).
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
    // التحقق من صحة المدخلات دون قيم افتراضية مزيفة
    final cleanSlug = courseSlug.trim();
    if (cleanSlug.isEmpty) {
      emit(
        AccessError(
          'معرّف الدورة (Course Slug) غير متوفر لإتمام عملية السداد.',
          courseStatuses: Map.unmodifiable(_statuses),
          requestsByCourse: Map.unmodifiable(_requestsByCourse),
          allRequests: List.unmodifiable(_allRequests),
        ),
      );
      return;
    }

    final cleanName = senderName.trim();
    if (cleanName.isEmpty) {
      emit(
        AccessError(
          'يرجى إدخال اسم صاحب الحساب المحول منه.',
          courseStatuses: Map.unmodifiable(_statuses),
          requestsByCourse: Map.unmodifiable(_requestsByCourse),
          allRequests: List.unmodifiable(_allRequests),
        ),
      );
      return;
    }

    final cleanAccount = senderAccount.trim();
    if (cleanAccount.isEmpty) {
      emit(
        AccessError(
          'يرجى إدخال رقم المحفظة أو الحساب المحول منه.',
          courseStatuses: Map.unmodifiable(_statuses),
          requestsByCourse: Map.unmodifiable(_requestsByCourse),
          allRequests: List.unmodifiable(_allRequests),
        ),
      );
      return;
    }

    if (amount <= 0) {
      emit(
        AccessError(
          'المبلغ المدفوع يجب أن يكون أكبر من صفر.',
          courseStatuses: Map.unmodifiable(_statuses),
          requestsByCourse: Map.unmodifiable(_requestsByCourse),
          allRequests: List.unmodifiable(_allRequests),
        ),
      );
      return;
    }

    final generation = ++_requestGeneration;

    emit(
      AccessLoading(
        courseStatuses: Map.unmodifiable(_statuses),
        requestsByCourse: Map.unmodifiable(_requestsByCourse),
        allRequests: List.unmodifiable(_allRequests),
      ),
    );

    try {
      final receipt = await _paymentRepository.submitCourseReceipt(
        courseSlug: cleanSlug,
        paymentMethod: paymentMethod,
        senderName: cleanName,
        senderAccount: cleanAccount,
        amount: amount,
        receiptFilePath: receiptFilePath,
        transactionReference: transactionReference?.trim().isNotEmpty == true
            ? transactionReference!.trim()
            : null,
      );

      if (generation != _requestGeneration) return;

      final key = courseId.isNotEmpty ? courseId : receipt.courseId.toString();

      // تحديث حالة الإيصال إلى حالة الاستجابة الفعلية من الخادم (عادة pending)
      _statuses[key] = receipt.status;
      _receiptsByCourse[key] = receipt;
      final req = receipt.toCourseAccessRequest(fallbackCourseTitle: courseTitle);
      _requestsByCourse[key] = req;
      _allRequests.insert(0, req);

      emit(
        AccessActionSuccess(
          'تم إرسال إيصال السداد للمراجعة بنجاح وسيتم تفعيل الدورة بعد التدقيق من الإدارة.',
          courseStatuses: Map.unmodifiable(_statuses),
          requestsByCourse: Map.unmodifiable(_requestsByCourse),
          allRequests: List.unmodifiable(_allRequests),
        ),
      );
    } catch (e) {
      if (generation != _requestGeneration) return;

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

  /// إرسال طلب سداد متوافق مع الواجهات، يرفض أي قيم وهمية أو غائبة
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
        ? course.slug!.trim()
        : (course.id.trim().isNotEmpty ? course.id.trim() : null);

    if (effectiveSlug == null) {
      emit(
        AccessError(
          'معرّف الدورة (Course Slug) غير متوفر لإتمام عملية السداد.',
          courseStatuses: Map.unmodifiable(_statuses),
          requestsByCourse: Map.unmodifiable(_requestsByCourse),
          allRequests: List.unmodifiable(_allRequests),
        ),
      );
      return;
    }

    final effectiveSenderName = (senderName ?? user.displayName).trim();
    if (effectiveSenderName.isEmpty) {
      emit(
        AccessError(
          'يرجى إدخال اسم صاحب الحساب أو المحفظة المحول منها.',
          courseStatuses: Map.unmodifiable(_statuses),
          requestsByCourse: Map.unmodifiable(_requestsByCourse),
          allRequests: List.unmodifiable(_allRequests),
        ),
      );
      return;
    }

    final effectiveSenderAccount = (senderAccount ?? (senderNumberOrRef.isNotEmpty ? senderNumberOrRef : user.phone)).trim();
    if (effectiveSenderAccount.isEmpty) {
      emit(
        AccessError(
          'يرجى إدخال رقم المحفظة أو الحساب المحول منه.',
          courseStatuses: Map.unmodifiable(_statuses),
          requestsByCourse: Map.unmodifiable(_requestsByCourse),
          allRequests: List.unmodifiable(_allRequests),
        ),
      );
      return;
    }

    final effectiveAmount = amount ?? (course.price > 0 ? course.price : null);
    if (effectiveAmount == null || effectiveAmount <= 0) {
      emit(
        AccessError(
          'المبلغ المدفوع غير محدد أو غير صالح لدورة "${course.title}".',
          courseStatuses: Map.unmodifiable(_statuses),
          requestsByCourse: Map.unmodifiable(_requestsByCourse),
          allRequests: List.unmodifiable(_allRequests),
        ),
      );
      return;
    }

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

  /// التحقق من صلاحية الاشتراك في الدورات المفتوحة أو المجانية.
  ///
  /// قاعدة أمنية صارمة:
  /// الأهلية تمنح حصرياً وبشكل صريح إذا أكد خادم Laravel اشتراك الطالب (`serverHasEnrolled == true`).
  /// لا يُسمح مطلقاً بمنح الصلاحية بناءً على نتيجة فارغة (null)، أو خطأ شبكة، أو وجود إيصال دفع سابق.
  Future<void> enrollInOpenCourse({
    required String uid,
    required Course course,
  }) async {
    final generation = ++_requestGeneration;

    emit(
      AccessLoading(
        courseStatuses: Map.unmodifiable(_statuses),
        requestsByCourse: Map.unmodifiable(_requestsByCourse),
        allRequests: List.unmodifiable(_allRequests),
      ),
    );

    try {
      bool serverHasEnrolled = false;
      final coursesRepo = _coursesRepository;
      if (coursesRepo != null) {
        try {
          final courseSlug = (course.slug != null && course.slug!.trim().isNotEmpty)
              ? course.slug!.trim()
              : course.id;
          final detailed = await coursesRepo.getCourseDetails(courseSlug);
          if (detailed.hasEnrolled) {
            serverHasEnrolled = true;
          }
        } catch (_) {
          // في حال فشل الاستعلام من الخادم، تظل القيمة false ولا تُمنح الصلاحية افتراضياً
          serverHasEnrolled = false;
        }
      }

      if (generation != _requestGeneration) return;

      // تحقق حاسم: فقط الموافقة الصريحة من خادم Laravel تمنح الوصول
      if (serverHasEnrolled) {
        _statuses[course.id] = AccessStatus.approved;
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

      // إذا لم يمنح الخادم الصلاحية، يتم إغلاق الوصول (Fail Closed) ورفض منح الصلاحية
      // يتم تحديث الإيصالات للعرض للمستخدم فقط دون اعتبار الإيصال ترخيصاً
      await _loadStudentReceiptsInternal(
        generation: generation,
        studentId: uid,
        silent: true,
        emitLoaded: false,
      );

      if (generation != _requestGeneration) return;

      emit(
        AccessError(
          'التسجيل في دورة "${course.title}" يتطلب اعتماداً من إدارة الأكاديمية أو إرسال إيصال السداد.',
          courseStatuses: Map.unmodifiable(_statuses),
          requestsByCourse: Map.unmodifiable(_requestsByCourse),
          allRequests: List.unmodifiable(_allRequests),
        ),
      );
    } catch (e) {
      if (generation != _requestGeneration) return;

      final msg = NetworkErrorMapper.toArabicMessage(
        e,
        defaultMessage: 'تعذر التحقق من حالة التسجيل من الخادم، يرجى المحاولة لاحقاً.',
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
