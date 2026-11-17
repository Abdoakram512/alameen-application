import 'dart:async';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/utils/network_error_mapper.dart';
import '../../models/access_request.dart';
import '../../models/course.dart';
import '../../models/user_profile.dart';
import '../../services/firestore_service.dart';
import '../../services/notification_service.dart';
import '../../services/storage_service.dart';
import 'access_state.dart';

class AccessCubit extends Cubit<AccessState> {
  final FirestoreService _firestoreService;
  final StorageService _storageService;
  StreamSubscription? _requestsSubscription;
  final Map<String, AccessStatus> _statuses = {};
  final Map<String, CourseAccessRequest> _requestsByCourse = {};
  bool _initialSnapshotHandled = false;

  /// كاش فوري في الذاكرة لعرض طلبات المتدرب بـ 0ms تأخير
  static final Map<String, List<CourseAccessRequest>> _cachedRequests = {};

  AccessCubit({
    FirestoreService? firestoreService,
    StorageService? storageService,
  })  : _firestoreService = firestoreService ?? FirestoreService(),
        _storageService = storageService ?? StorageService(),
        super(AccessInitial());

  /// تفريغ كاش الطلبات المخزنة في الذاكرة بالكامل عند تسجيل الخروج
  static void clearCache() => _cachedRequests.clear();

  void clear() {
    _requestsSubscription?.cancel();
    _requestsSubscription = null;
    _statuses.clear();
    _requestsByCourse.clear();
    _initialSnapshotHandled = false;
    _cachedRequests.clear();
    emit(AccessInitial());
  }

  void listenToStudentRequests(String studentId) {
    _requestsSubscription?.cancel();
    _initialSnapshotHandled = false;

    // بث فوري فوري للبيانات المحفوظة مسبقاً دون انتظار الشبكة
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

    _requestsSubscription =
        _firestoreService.streamStudentRequests(studentId).listen(
      (requests) {
        _cachedRequests[studentId] = requests;
        final previousStatuses = Map<String, AccessStatus>.from(_statuses);
        _statuses.clear();
        _requestsByCourse.clear();
        for (final req in requests) {
          _statuses[req.courseId] = req.status;
          _requestsByCourse[req.courseId] = req;

          if (_initialSnapshotHandled) {
            final prev = previousStatuses[req.courseId];
            if (prev == AccessStatus.pending &&
                req.status == AccessStatus.approved) {
              unawaited(
                NotificationService().showInstantNotification(
                  id: req.id.hashCode,
                  title: 'تم تفعيل اشتراكك بنجاح',
                  body:
                      'تمت الموافقة على انضمامك إلى دورة "${req.courseTitle}". يمكنك بدء المشاهدة الآن.',
                ),
              );
            } else if (prev == AccessStatus.pending &&
                req.status == AccessStatus.rejected) {
              unawaited(
                NotificationService().showInstantNotification(
                  id: req.id.hashCode,
                  title: 'تحديث بخصوص طلب الانضمام',
                  body: req.adminNotes.trim().isNotEmpty
                      ? 'تعذر اعتماد إيصال "${req.courseTitle}": ${req.adminNotes}'
                      : 'يرجى مراجعة بيانات إيصال السداد لدورة "${req.courseTitle}" وإعادة المحاولة.',
                ),
              );
            }
          }
        }
        _initialSnapshotHandled = true;
        emit(
          AccessLoaded(
            Map.unmodifiable(_statuses),
            requestsByCourse: Map.unmodifiable(_requestsByCourse),
          ),
        );
      },
      onError: (e) {
        if (_requestsSubscription == null) return;
        final msg = e.toString();
        if (msg.contains('permission-denied') ||
            msg.contains('PERMISSION_DENIED')) {
          return;
        }
        emit(
          AccessError(
            'تعذر تحديث حالة طلبات الانضمام حالياً.',
            courseStatuses: Map.unmodifiable(_statuses),
            requestsByCourse: Map.unmodifiable(_requestsByCourse),
          ),
        );
      },
    );
  }

  Future<void> sendRequest({
    required Course course,
    required UserModel user,
    String paymentMethod = 'فودافون كاش',
    String senderNumberOrRef = '',
    String receiptUrl = '',
    File? receiptFile,
  }) async {
    emit(
      AccessLoading(
        courseStatuses: Map.unmodifiable(_statuses),
        requestsByCourse: Map.unmodifiable(_requestsByCourse),
      ),
    );
    try {
      String finalReceiptUrl = receiptUrl;
      if (receiptFile != null) {
        finalReceiptUrl = await _storageService.uploadReceipt(
          studentId: user.uid,
          courseId: course.id,
          file: receiptFile,
        );
      }

      final newReq = CourseAccessRequest(
        id: 'req_${user.uid}_${course.id}',
        studentId: user.uid,
        studentName: user.displayName,
        studentEmail: user.email,
        studentAvatar: user.photoUrl,
        courseId: course.id,
        courseTitle: course.title,
        paymentMethod: paymentMethod,
        senderNumberOrRef: senderNumberOrRef,
        receiptUrl: finalReceiptUrl,
        requestedAt: DateTime.now(),
        status: AccessStatus.pending,
      );

      await _firestoreService.sendAccessRequest(newReq);
      _statuses[course.id] = AccessStatus.pending;
      _requestsByCourse[course.id] = newReq;

      emit(
        AccessActionSuccess(
          finalReceiptUrl.trim().isNotEmpty
              ? 'تم إرسال طلب الانضمام ومرفق الإيصال للمراجعة بنجاح.'
              : 'تم إرسال طلب الانضمام للمراجعة بنجاح.',
          courseStatuses: Map.unmodifiable(_statuses),
          requestsByCourse: Map.unmodifiable(_requestsByCourse),
        ),
      );
    } catch (e) {
      final arabicError = NetworkErrorMapper.toArabicMessage(
        e,
        defaultMessage: 'تعذر إرسال طلب الانضمام، يرجى التحقق من الاتصال والمحاولة مرة أخرى.',
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

  Future<void> enrollInOpenCourse({
    required String uid,
    required Course course,
  }) async {
    try {
      emit(
        AccessLoading(
          courseStatuses: Map.unmodifiable(_statuses),
          requestsByCourse: Map.unmodifiable(_requestsByCourse),
        ),
      );
      await _firestoreService.enrollInOpenCourse(uid, course.id);
      emit(
        AccessActionSuccess(
          'تم تسجيلك في دورة "${course.title}" بنجاح! يمكنك البدء الآن.',
          courseStatuses: Map.unmodifiable(_statuses),
          requestsByCourse: Map.unmodifiable(_requestsByCourse),
        ),
      );
    } catch (e) {
      final arabicError = NetworkErrorMapper.toArabicMessage(
        e,
        defaultMessage:
            'تعذر التسجيل في الدورة، يرجى المحاولة مرة أخرى.',
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

  void reset() {
    _requestsSubscription?.cancel();
    _requestsSubscription = null;
    _statuses.clear();
    _requestsByCourse.clear();
    if (!isClosed) emit(AccessInitial());
  }

  @override
  Future<void> close() {
    _requestsSubscription?.cancel();
    return super.close();
  }
}
