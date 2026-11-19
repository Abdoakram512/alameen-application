import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/errors/app_failure.dart';
import '../../../../../models/course.dart';
import '../../../../../repositories/student_courses_repository.dart';
import '../../../domain/entities/course_entitlement.dart';
import 'course_entitlement_state.dart';

/// مصدر الحقيقة الأوحد في طبقة العرض لأهلية الدورات المؤكدة من خادم Laravel.
/// يعتمد حصرياً على استجابات الخادم الموثقة ولا يشتق الصلاحية من الإيصالات أو الكاش.
class CourseEntitlementCubit extends Cubit<CourseEntitlementState> {
  final StudentCoursesRepository _coursesRepository;

  int _sessionGeneration = 0;
  int _syncGeneration = 0;
  final Map<String, int> _courseRequestSeq = {};

  CourseEntitlementCubit({
    required StudentCoursesRepository coursesRepository,
  })  : _coursesRepository = coursesRepository,
        super(const CourseEntitlementState());

  Future<void> syncStudentEnrollments({required String studentId}) async {
    final normalizedId = studentId.trim();
    if (normalizedId.isEmpty) {
      clear();
      return;
    }

    final isAccountSwitch =
        state.activeStudentId != null && state.activeStudentId != normalizedId;
    final sessionGen = isAccountSwitch ? ++_sessionGeneration : _sessionGeneration;
    final syncGen = ++_syncGeneration;
    if (isAccountSwitch) {
      _courseRequestSeq.clear();
    }

    if (!isClosed) {
      emit(
        CourseEntitlementState(
          entitlements: isAccountSwitch ? const {} : state.entitlements,
          activeStudentId: normalizedId,
          isSyncingAll: true,
        ),
      );
    }

    try {
      final data = await _coursesRepository.getStudentCourses();
      if (isClosed ||
          sessionGen != _sessionGeneration ||
          syncGen != _syncGeneration ||
          state.activeStudentId != normalizedId) {
        return;
      }

      final activeIds = data.activeEnrolledCourseIdStrings.toSet();
      final expiries = data.expiryDatesByCourseId;
      final now = DateTime.now();

      final updated = <String, CourseEntitlement>{};
      for (final existingKey in state.entitlements.keys) {
        if (!activeIds.contains(existingKey)) {
          updated[existingKey] = CourseEntitlement.notEnrolled(
            existingKey,
            checkedAt: now,
          );
        }
      }
      for (final id in activeIds) {
        updated[id] = CourseEntitlement.enrolled(
          id,
          expiresAt: expiries[id],
          checkedAt: now,
        );
      }

      emit(
        CourseEntitlementState(
          entitlements: Map.unmodifiable(updated),
          activeStudentId: normalizedId,
          isSyncingAll: false,
        ),
      );
    } on AppFailure catch (failure) {
      if (isClosed ||
          sessionGen != _sessionGeneration ||
          syncGen != _syncGeneration ||
          state.activeStudentId != normalizedId) {
        return;
      }
      emit(
        state.copyWith(
          isSyncingAll: false,
          syncFailure: failure,
        ),
      );
    } catch (_) {
      if (isClosed ||
          sessionGen != _sessionGeneration ||
          syncGen != _syncGeneration ||
          state.activeStudentId != normalizedId) {
        return;
      }
      emit(
        state.copyWith(
          isSyncingAll: false,
          syncFailure: const UnknownFailure(
            'تعذر مزامنة اشتراكات الدورات من الخادم.',
          ),
        ),
      );
    }
  }

  /// التحقق الصريح والمباشر من أهلية دورة عبر خادم Laravel الموثق.
  /// كل دورة تحتفظ برقم تسلسل مستقل حتى لا يلغي طلب دورة طلب دورة أخرى أو طلبات الإيصالات.
  Future<CourseEntitlement> verifyCourseEntitlement({
    required String courseId,
    required String courseSlug,
    String? studentId,
  }) async {
    final normalizedStudentId = studentId?.trim();
    if (normalizedStudentId != null && normalizedStudentId.isNotEmpty) {
      if (state.activeStudentId != null &&
          state.activeStudentId != normalizedStudentId) {
        _sessionGeneration++;
        _courseRequestSeq.clear();
        if (!isClosed) {
          emit(CourseEntitlementState(activeStudentId: normalizedStudentId));
        }
      } else if (state.activeStudentId == null && !isClosed) {
        emit(state.copyWith(activeStudentId: normalizedStudentId));
      }
    }

    final sessionGen = _sessionGeneration;
    final nextSeq = (_courseRequestSeq[courseId] ?? 0) + 1;
    _courseRequestSeq[courseId] = nextSeq;

    final targetSlug =
        courseSlug.trim().isNotEmpty ? courseSlug.trim() : courseId.trim();

    if (!isClosed) {
      final loadingMap = Map<String, CourseEntitlement>.from(state.entitlements);
      loadingMap[courseId] = CourseEntitlement.loading(courseId);
      emit(state.copyWith(entitlements: Map.unmodifiable(loadingMap)));
    }

    CourseEntitlement resolved;
    final now = DateTime.now();

    try {
      final detailed =
          await _coursesRepository.verifyStudentCourseDetails(targetSlug);

      if (isClosed ||
          sessionGen != _sessionGeneration ||
          _courseRequestSeq[courseId] != nextSeq) {
        return state.entitlementFor(courseId);
      }

      if (!detailed.isDetailedFromAuthServer) {
        // الإغلاق عند الشك: لا يمنح استنتاج صلاحية من بيانات عامة أو غير موثقة
        resolved = CourseEntitlement(
          courseId: courseId,
          status: CourseAccessState.unknown,
          message: 'تعذر تأكيد صلاحية الاشتراك من الخادم الموثق.',
          checkedAt: now,
        );
      } else if (detailed.hasEnrolled) {
        resolved = CourseEntitlement.enrolled(
          courseId,
          message: 'تم تأكيد اشتراكك في دورة "${detailed.title}" من الخادم بنجاح.',
          expiresAt: state.entitlements[courseId]?.expiresAt,
          checkedAt: now,
        );
      } else {
        resolved = CourseEntitlement.notEnrolled(
          courseId,
          message:
              'التسجيل في دورة "${detailed.title}" يتطلب اعتماداً من إدارة الأكاديمية أو إرسال إيصال السداد.',
          checkedAt: now,
        );
      }
    } on AppFailure catch (failure) {
      if (isClosed ||
          sessionGen != _sessionGeneration ||
          _courseRequestSeq[courseId] != nextSeq) {
        return state.entitlementFor(courseId);
      }

      resolved = _mapFailureToEntitlement(courseId, failure, now);
    } catch (_) {
      if (isClosed ||
          sessionGen != _sessionGeneration ||
          _courseRequestSeq[courseId] != nextSeq) {
        return state.entitlementFor(courseId);
      }

      resolved = _mapFailureToEntitlement(
        courseId,
        const UnknownFailure('تعذر التحقق من حالة التسجيل من الخادم.'),
        now,
      );
    }

    final updated = Map<String, CourseEntitlement>.from(state.entitlements);
    updated[courseId] = resolved;
    emit(state.copyWith(entitlements: Map.unmodifiable(updated)));
    return resolved;
  }

  /// تحديث حالة الأهلية عند استرجاع تفاصيل الدورة المصادق عليها من الخادم.
  void applyServerCourseDetails(Course detailedCourse) {
    if (!detailedCourse.isDetailedFromAuthServer || isClosed) return;

    final now = DateTime.now();
    final updated = Map<String, CourseEntitlement>.from(state.entitlements);
    updated[detailedCourse.id] = detailedCourse.hasEnrolled
        ? CourseEntitlement.enrolled(
            detailedCourse.id,
            expiresAt: updated[detailedCourse.id]?.expiresAt,
            checkedAt: now,
          )
        : CourseEntitlement.notEnrolled(
            detailedCourse.id,
            checkedAt: now,
          );
    emit(state.copyWith(entitlements: Map.unmodifiable(updated)));
  }

  /// تسجيل خطأ تحقق وارد من تحميل تفاصيل الدورة مع التمييز الصارم بين انقطاع الشبكة والمنع المؤكد.
  void recordVerificationFailure(String courseId, AppFailure failure) {
    if (isClosed) return;
    final updated = Map<String, CourseEntitlement>.from(state.entitlements);
    updated[courseId] =
        _mapFailureToEntitlement(courseId, failure, DateTime.now());
    emit(state.copyWith(entitlements: Map.unmodifiable(updated)));
  }

  CourseEntitlement _mapFailureToEntitlement(
    String courseId,
    AppFailure failure,
    DateTime checkedAt,
  ) {
    return switch (failure) {
      NetworkFailure() => CourseEntitlement(
          courseId: courseId,
          status: CourseAccessState.networkUnavailable,
          message: failure.message,
          checkedAt: checkedAt,
        ),
      UnauthorizedFailure() => CourseEntitlement(
          courseId: courseId,
          status: CourseAccessState.unauthorized,
          message: failure.message,
          checkedAt: checkedAt,
        ),
      ForbiddenFailure(reasonCode: final code) => CourseEntitlement(
          courseId: courseId,
          status: CourseAccessState.forbidden,
          message: failure.message,
          forbiddenReasonCode: code,
          checkedAt: checkedAt,
        ),
      _ => CourseEntitlement(
          courseId: courseId,
          status: CourseAccessState.failure,
          message: failure.message,
          checkedAt: checkedAt,
        ),
    };
  }

  void clear() {
    _sessionGeneration++;
    _syncGeneration++;
    _courseRequestSeq.clear();
    if (!isClosed) {
      emit(const CourseEntitlementState());
    }
  }

  @override
  Future<void> close() {
    _sessionGeneration++;
    _syncGeneration++;
    _courseRequestSeq.clear();
    return super.close();
  }
}
