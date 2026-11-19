import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
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

  /// سجل الحالات المالية للإيصالات مجمعة حسب الدورة
  final Map<String, AccessStatus> _receiptStatuses = {};

  /// حالات الاستحقاق والأهلية الفعلية المؤكدة من خادم Laravel
  final Map<String, CourseEntitlementStatus> _entitlements = {};

  /// أحدث إيصال سداد لكل دورة
  final Map<String, CourseAccessRequest> _requestsByCourse = {};
  final Map<String, PaymentReceiptModel> _receiptsByCourse = {};

  /// قائمة جميع الإيصالات المالية للطالب
  final List<CourseAccessRequest> _allRequests = [];

  bool _initialSnapshotHandled = false;

  /// حارس أجيال الطلبات لمنع تداخل الاستجابات غير المتزامنة بين الجلسات أو بعد تسجيل الخروج
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

  /// تنظيف الحالة الحالية وعزل الجلسة عند تسجيل الخروج أو تبديل الحساب
  void clear() {
    _requestGeneration++;
    _activeStudentId = null;
    _receiptStatuses.clear();
    _entitlements.clear();
    _requestsByCourse.clear();
    _receiptsByCourse.clear();
    _allRequests.clear();
    _initialSnapshotHandled = false;
    if (!isClosed) {
      emit(AccessInitial());
    }
  }

  void reset() => clear();

  @override
  Future<void> close() {
    _requestGeneration++;
    _activeStudentId = null;
    _receiptStatuses.clear();
    _entitlements.clear();
    _requestsByCourse.clear();
    _receiptsByCourse.clear();
    _allRequests.clear();
    return super.close();
  }

  /// الاستماع لطلبات وإيصالات الطالب بناءً على معرّفه الموثق [studentId]
  void listenToStudentRequests(String studentId) {
    if (_activeStudentId != studentId) {
      clear();
      _activeStudentId = studentId;
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
    if (!silent && _receiptStatuses.isEmpty && !isClosed) {
      emit(
        AccessLoading(
          receiptStatuses: Map.unmodifiable(_receiptStatuses),
          courseEntitlements: Map.unmodifiable(_entitlements),
          requestsByCourse: Map.unmodifiable(_requestsByCourse),
          allRequests: List.unmodifiable(_allRequests),
        ),
      );
    }

    try {
      final receipts = await _paymentRepository.getStudentReceipts();

      // حماية صارمة من تسريب البيانات: إذا تغير جيل الطلب أثناء الجلب يتم التخلص من الاستجابة فوراً
      if (generation != _requestGeneration || isClosed) {
        return;
      }

      final previousStatuses = Map<String, AccessStatus>.from(_receiptStatuses);

      _receiptStatuses.clear();
      _requestsByCourse.clear();
      _receiptsByCourse.clear();
      _allRequests.clear();

      final allConverted = receipts.map((r) => r.toCourseAccessRequest()).toList();
      allConverted.sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
      _allRequests.addAll(allConverted);

      // تجميع الإيصالات حسب الدورة لتحديد أحدث حالة تدقيق مالي للإيصال
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

        _receiptStatuses[courseKey] = effectiveReceiptStatus;
        _receiptsByCourse[courseKey] = primaryReceipt;
        _requestsByCourse[courseKey] = primaryReceipt.toCourseAccessRequest();

        // إشعارات تحديث حالة الإيصال المالي
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
            Map.unmodifiable(_receiptStatuses),
            courseEntitlements: Map.unmodifiable(_entitlements),
            requestsByCourse: Map.unmodifiable(_requestsByCourse),
            allRequests: List.unmodifiable(_allRequests),
          ),
        );
      }
    } catch (e) {
      if (generation != _requestGeneration || isClosed) {
        // يتم إهمال الأخطاء المتأخرة بعد إلغاء الطلب دون إطلاق استثناء غير معالج
        return;
      }
      if (emitLoaded) {
        final msg = NetworkErrorMapper.toArabicMessage(
          e,
          defaultMessage: 'تعذر تحديث حالة طلبات الانضمام حالياً.',
        );
        emit(
          AccessError(
            msg,
            receiptStatuses: Map.unmodifiable(_receiptStatuses),
            courseEntitlements: Map.unmodifiable(_entitlements),
            requestsByCourse: Map.unmodifiable(_requestsByCourse),
            allRequests: List.unmodifiable(_allRequests),
          ),
        );
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
    final cleanSlug = (courseSlug.trim().isNotEmpty ? courseSlug : courseId).trim();
    if (cleanSlug.isEmpty) {
      emit(
        AccessError(
          'معرّف الدورة (Course Slug) غير متوفر لإتمام عملية السداد.',
          receiptStatuses: Map.unmodifiable(_receiptStatuses),
          courseEntitlements: Map.unmodifiable(_entitlements),
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
          receiptStatuses: Map.unmodifiable(_receiptStatuses),
          courseEntitlements: Map.unmodifiable(_entitlements),
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
          receiptStatuses: Map.unmodifiable(_receiptStatuses),
          courseEntitlements: Map.unmodifiable(_entitlements),
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
          receiptStatuses: Map.unmodifiable(_receiptStatuses),
          courseEntitlements: Map.unmodifiable(_entitlements),
          requestsByCourse: Map.unmodifiable(_requestsByCourse),
          allRequests: List.unmodifiable(_allRequests),
        ),
      );
      return;
    }

    // مطابقة وتدقيق طريقة الدفع وفق توثيق OpenAPI (vodafone_cash / instapay)
    final String normalizedPaymentMethod;
    final cleanMethod = paymentMethod.trim().toLowerCase();
    if (cleanMethod == 'vodafone_cash' || cleanMethod.contains('فودافون') || cleanMethod.contains('vodafone')) {
      normalizedPaymentMethod = 'vodafone_cash';
    } else if (cleanMethod == 'instapay' || cleanMethod.contains('انستا') || cleanMethod.contains('إنستا') || cleanMethod.contains('insta')) {
      normalizedPaymentMethod = 'instapay';
    } else {
      emit(
        AccessError(
          'طريقة الدفع غير معتمدة. يرجى اختيار إما فودافون كاش (vodafone_cash) أو إنستاباي (instapay).',
          receiptStatuses: Map.unmodifiable(_receiptStatuses),
          courseEntitlements: Map.unmodifiable(_entitlements),
          requestsByCourse: Map.unmodifiable(_requestsByCourse),
          allRequests: List.unmodifiable(_allRequests),
        ),
      );
      return;
    }

    final generation = ++_requestGeneration;

    emit(
      AccessLoading(
        receiptStatuses: Map.unmodifiable(_receiptStatuses),
        courseEntitlements: Map.unmodifiable(_entitlements),
        requestsByCourse: Map.unmodifiable(_requestsByCourse),
        allRequests: List.unmodifiable(_allRequests),
      ),
    );

    try {
      final receipt = await _paymentRepository.submitCourseReceipt(
        courseSlug: cleanSlug,
        paymentMethod: normalizedPaymentMethod,
        senderName: cleanName,
        senderAccount: cleanAccount,
        amount: amount,
        receiptFilePath: receiptFilePath,
        transactionReference: transactionReference?.trim().isNotEmpty == true
            ? transactionReference!.trim()
            : null,
      );

      if (generation != _requestGeneration || isClosed) return;

      final key = courseId.isNotEmpty ? courseId : receipt.courseId.toString();

      // تحديث حالة الإيصال المالي فقط (pending) دون اعتبار ذلك تصريحاً بالدخول
      _receiptStatuses[key] = receipt.status;
      _receiptsByCourse[key] = receipt;
      final req = receipt.toCourseAccessRequest(fallbackCourseTitle: courseTitle);
      _requestsByCourse[key] = req;
      _allRequests.insert(0, req);

      emit(
        AccessActionSuccess(
          'تم إرسال إيصال السداد للمراجعة بنجاح وسيتم تفعيل الدورة بعد التدقيق من الإدارة.',
          receiptStatuses: Map.unmodifiable(_receiptStatuses),
          courseEntitlements: Map.unmodifiable(_entitlements),
          requestsByCourse: Map.unmodifiable(_requestsByCourse),
          allRequests: List.unmodifiable(_allRequests),
        ),
      );
    } catch (e) {
      if (generation != _requestGeneration || isClosed) return;

      final arabicError = NetworkErrorMapper.toArabicMessage(
        e,
        defaultMessage: 'تعذر إرسال إيصال السداد، يرجى التحقق من الاتصال والمحاولة مرة أخرى.',
      );
      emit(
        AccessError(
          arabicError,
          receiptStatuses: Map.unmodifiable(_receiptStatuses),
          courseEntitlements: Map.unmodifiable(_entitlements),
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
    String paymentMethod = 'vodafone_cash',
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
          receiptStatuses: Map.unmodifiable(_receiptStatuses),
          courseEntitlements: Map.unmodifiable(_entitlements),
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
          receiptStatuses: Map.unmodifiable(_receiptStatuses),
          courseEntitlements: Map.unmodifiable(_entitlements),
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
          receiptStatuses: Map.unmodifiable(_receiptStatuses),
          courseEntitlements: Map.unmodifiable(_entitlements),
          requestsByCourse: Map.unmodifiable(_requestsByCourse),
          allRequests: List.unmodifiable(_allRequests),
        ),
      );
      return;
    }

    // إزالة أي افتراض ضمني لحساب المرسل أو الارتداد لرقم هاتف الطالب (user.phone)
    final effectiveSenderAccount = (senderAccount ?? (senderNumberOrRef.trim().isNotEmpty ? senderNumberOrRef.trim() : null))?.trim();
    if (effectiveSenderAccount == null || effectiveSenderAccount.isEmpty) {
      emit(
        AccessError(
          'يرجى إدخال رقم المحفظة أو الحساب المحول منه.',
          receiptStatuses: Map.unmodifiable(_receiptStatuses),
          courseEntitlements: Map.unmodifiable(_entitlements),
          requestsByCourse: Map.unmodifiable(_requestsByCourse),
          allRequests: List.unmodifiable(_allRequests),
        ),
      );
      return;
    }

    // إزالة الافتراض الضمني بأن المبلغ المحول يساوي سعر الدورة المعروض
    if (amount == null || amount <= 0) {
      emit(
        AccessError(
          'المبلغ المدفوع غير محدد أو غير صالح لدورة "${course.title}".',
          receiptStatuses: Map.unmodifiable(_receiptStatuses),
          courseEntitlements: Map.unmodifiable(_entitlements),
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
      amount: amount,
      receiptFilePath: receiptFile.path,
      transactionReference: transactionReference ?? (senderNumberOrRef.isNotEmpty ? senderNumberOrRef : null),
    );
  }

  /// التحقق الصارم من أهلية واستحقاق الطالب بالدورة من واقع خادم Laravel الموثق.
  ///
  /// قاعدة أمنية قطعية:
  /// الأهلية تمنح حصرياً وبشكل صريح إذا أكد خادم Laravel اشتراك الطالب (`has_enrolled == true`).
  /// لا يُسمح مطلقاً بمنح الصلاحية بناءً على وجود إيصال دفع، أو حالة شبكة منقطعة، أو نتيجة غير مؤكدة.
  Future<CourseEntitlementStatus> verifyCourseEntitlement({
    required String uid,
    required Course course,
  }) async {
    final generation = ++_requestGeneration;

    emit(
      AccessLoading(
        receiptStatuses: Map.unmodifiable(_receiptStatuses),
        courseEntitlements: Map.unmodifiable(_entitlements),
        requestsByCourse: Map.unmodifiable(_requestsByCourse),
        allRequests: List.unmodifiable(_allRequests),
      ),
    );

    CourseEntitlementStatus status = CourseEntitlementStatus.unknown;
    String? errorMessage;
    String? successMessage;

    try {
      final coursesRepo = _coursesRepository;
      if (coursesRepo == null) {
        status = CourseEntitlementStatus.unknown;
        errorMessage = 'تعذر الاتصال بمستودع الدورات للتحقق من الأهلية.';
      } else {
        final courseSlug = (course.slug != null && course.slug!.trim().isNotEmpty)
            ? course.slug!.trim()
            : course.id;

        final detailed = await coursesRepo.getCourseDetails(courseSlug);

        if (detailed.hasEnrolled) {
          status = CourseEntitlementStatus.enrolled;
          successMessage = 'تم تأكيد اشتراكك في دورة "${course.title}" من الخادم بنجاح.';
        } else {
          status = CourseEntitlementStatus.notEnrolled;
          errorMessage = 'التسجيل في دورة "${course.title}" يتطلب اعتماداً من إدارة الأكاديمية أو إرسال إيصال السداد.';
        }
      }
    } on DioException catch (dioErr) {
      final statusCode = dioErr.response?.statusCode;
      if (statusCode == 403) {
        status = CourseEntitlementStatus.revoked;
        errorMessage = 'تم سحب أو إلغاء صلاحية الوصول لدورة "${course.title}" من قبل الإدارة.';
      } else if (statusCode == 401) {
        status = CourseEntitlementStatus.unauthorized;
        errorMessage = 'انتهت صلاحية الجلسة، يرجى تسجيل الدخول مجدداً للتحقق من الاشتراك.';
      } else if (dioErr.type == DioExceptionType.connectionTimeout ||
          dioErr.type == DioExceptionType.sendTimeout ||
          dioErr.type == DioExceptionType.receiveTimeout ||
          dioErr.type == DioExceptionType.connectionError ||
          dioErr.error is SocketException) {
        status = CourseEntitlementStatus.networkError;
        errorMessage = 'تعذر التحقق من حالة الاشتراك نظراً لعدم توفر اتصال بالشبكة.';
      } else {
        status = CourseEntitlementStatus.unknown;
        errorMessage = NetworkErrorMapper.toArabicMessage(
          dioErr,
          defaultMessage: 'تعذر التحقق من حالة التسجيل من الخادم، يرجى المحاولة لاحقاً.',
        );
      }
    } catch (e) {
      status = CourseEntitlementStatus.unknown;
      errorMessage = NetworkErrorMapper.toArabicMessage(
        e,
        defaultMessage: 'تعذر التحقق من حالة التسجيل من الخادم، يرجى المحاولة لاحقاً.',
      );
    }

    if (generation != _requestGeneration || isClosed) {
      return status;
    }

    // تسجيل حالة الأهلية الحقيقية (لا يتم لمس سجل الإيصالات المالية إطلاقاً)
    _entitlements[course.id] = status;

    if (status == CourseEntitlementStatus.enrolled) {
      emit(
        AccessActionSuccess(
          successMessage ?? 'تم تأكيد اشتراكك في دورة "${course.title}" من الخادم بنجاح.',
          receiptStatuses: Map.unmodifiable(_receiptStatuses),
          courseEntitlements: Map.unmodifiable(_entitlements),
          requestsByCourse: Map.unmodifiable(_requestsByCourse),
          allRequests: List.unmodifiable(_allRequests),
        ),
      );
    } else {
      emit(
        AccessError(
          errorMessage ?? 'التسجيل في دورة "${course.title}" يتطلب اعتماداً من إدارة الأكاديمية أو إرسال إيصال السداد.',
          receiptStatuses: Map.unmodifiable(_receiptStatuses),
          courseEntitlements: Map.unmodifiable(_entitlements),
          requestsByCourse: Map.unmodifiable(_requestsByCourse),
          allRequests: List.unmodifiable(_allRequests),
          entitlementStatus: status,
        ),
      );
    }

    return status;
  }

  /// توافق عكسي: تم إعادة توجيهه إلى التحقق من الأهلية [verifyCourseEntitlement].
  @Deprecated('Use verifyCourseEntitlement instead. This method only verifies enrollment and does not enroll client-side.')
  Future<void> enrollInOpenCourse({
    required String uid,
    required Course course,
  }) async {
    await verifyCourseEntitlement(uid: uid, course: course);
  }
}
