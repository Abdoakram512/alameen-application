import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/di/injection_container.dart';
import '../../core/network/api_exceptions.dart';
import '../../core/storage/course_local_cache.dart';
import '../../models/course.dart';
import '../../models/student_courses_data.dart';
import '../../models/student_dashboard_data.dart';
import '../../repositories/student_auth_repository.dart';
import '../../repositories/student_certificates_repository.dart';
import '../../repositories/student_notifications_repository.dart';
import '../../repositories/student_profile_repository.dart';
import '../../repositories/student_support_repository.dart';
import '../../services/watch_queue.dart';
import '../access/access_cubit.dart';
import '../assignments/assignments_cubit.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final StudentAuthRepository _authRepository;
  final StudentProfileRepository? _profileRepository;

  AuthCubit({
    StudentAuthRepository? authRepository,
    StudentProfileRepository? profileRepository,
  })  : _authRepository = authRepository ?? sl<StudentAuthRepository>(),
        _profileRepository = profileRepository,
        super(AuthInitial()) {
    restoreSession();
  }

  /// استعادة جلسة الطالب النشطة عند فتح التطبيق
  Future<void> restoreSession() async {
    try {
      final user = await _authRepository.restoreSession();
      if (state is Unauthenticated) return;
      if (user != null) {
        if (user.isSuspendedAccount) {
          emit(
            AuthSuspended(
              message: user.suspensionReason ?? 'تم تعطيل هذا الحساب من قِبل إدارة المنصة.',
              user: user,
            ),
          );
        } else if (user.isPending) {
          emit(
            AuthPendingApproval(
              message: 'حسابك قيد المراجعة من قِبل إدارة المنصة.',
              user: user,
            ),
          );
        } else {
          emit(Authenticated(user));
        }
      } else {
        if (state is AuthInitial) {
          emit(Unauthenticated());
        }
      }
    } catch (e) {
      debugPrint('restoreSession non-fatal: $e');
      if (state is AuthInitial) {
        emit(Unauthenticated());
      }
    }
  }

  /// تسجيل الدخول بالبريد الإلكتروني وكلمة المرور
  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    emit(AuthLoading());
    try {
      final result = await _authRepository.login(
        email: email,
        password: password,
      );

      if (result.isPending) {
        emit(
          AuthPendingApproval(
            message: result.message ?? 'حسابك قيد المراجعة من قِبل إدارة المنصة.',
            user: result.user,
          ),
        );
      } else if (result.isSuspended) {
        emit(
          AuthSuspended(
            message: result.message ?? 'تم تعطيل هذا الحساب من قِبل إدارة المنصة.',
            user: result.user,
          ),
        );
      } else if (result.isAuthenticated && result.user != null) {
        if (sl.isRegistered<AccessCubit>()) {
          sl<AccessCubit>().clear();
        }
        if (sl.isRegistered<AssignmentsCubit>()) {
          sl<AssignmentsCubit>().clear();
        }
        emit(Authenticated(result.user!));
      } else {
        emit(Unauthenticated());
      }
    } on ValidationException catch (e) {
      emit(AuthError(e.firstErrorMessage));
    } on ForbiddenException catch (e) {
      emit(
        AuthPendingApproval(
          message: e.message,
        ),
      );
    } on ApiException catch (e) {
      emit(AuthError(e.message));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  /// إنشاء حساب طالب جديد — يبدأ دائماً بحالة قيد المراجعة (Pending)
  Future<void> signUpWithEmailAndPassword({
    required String name,
    required String email,
    required String password,
    String phone = '',
    String? country,
    String? city,
    String? address,
  }) async {
    emit(AuthLoading());
    try {
      final result = await _authRepository.register(
        name: name,
        email: email,
        password: password,
        passwordConfirmation: password,
        phone: phone,
        country: country,
        city: city,
        address: address,
      );

      // يعرض دائماً رسالة قيد المراجعة ولا يمنح جلسة موثقة فورية
      emit(
        AuthPendingApproval(
          message: result.message ?? 'تم إنشاء حسابك بنجاح وهو الآن قيد المراجعة من قِبل إدارة المنصة.',
          user: result.user,
        ),
      );
    } on ValidationException catch (e) {
      emit(AuthError(e.firstErrorMessage));
    } on ApiException catch (e) {
      emit(AuthError(e.message));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  /// تسجيل الدخول عبر حساب Google
  Future<void> signInWithGoogle() async {
    emit(AuthLoading());
    try {
      final result = await _authRepository.loginWithGoogle();

      if (result.status == 'cancelled') {
        emit(Unauthenticated());
        return;
      }

      if (result.isPending) {
        emit(
          AuthPendingApproval(
            message: result.message ?? 'حسابك قيد المراجعة من قِبل إدارة المنصة.',
            user: result.user,
          ),
        );
      } else if (result.isSuspended) {
        emit(
          AuthSuspended(
            message: result.message ?? 'تم تعطيل هذا الحساب من قِبل إدارة المنصة.',
            user: result.user,
          ),
        );
      } else if (result.isAuthenticated && result.user != null) {
        if (sl.isRegistered<AccessCubit>()) {
          sl<AccessCubit>().clear();
        }
        if (sl.isRegistered<AssignmentsCubit>()) {
          sl<AssignmentsCubit>().clear();
        }
        emit(Authenticated(result.user!));
      } else {
        emit(Unauthenticated());
      }
    } on ValidationException catch (e) {
      emit(AuthError(e.firstErrorMessage));
    } on ForbiddenException catch (e) {
      emit(
        AuthPendingApproval(
          message: e.message,
        ),
      );
    } on ApiException catch (e) {
      emit(AuthError(e.message));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  /// إرسال رمز OTP لاستعادة كلمة المرور
  Future<String> sendPasswordReset(String email) async {
    try {
      return await _authRepository.forgotPassword(email);
    } on ApiException catch (e) {
      throw e.message;
    } catch (e) {
      throw e.toString();
    }
  }

  /// التحقق من صحة رمز OTP
  Future<bool> verifyPasswordResetOtp({
    required String email,
    required String otp,
  }) async {
    try {
      return await _authRepository.verifyOtp(email, otp);
    } on ApiException catch (e) {
      throw e.message;
    } catch (e) {
      throw e.toString();
    }
  }

  /// تعيين كلمة مرور جديدة بعد التحقق من OTP
  Future<String> resetPasswordWithOtp({
    required String email,
    required String otp,
    required String password,
    required String passwordConfirmation,
  }) async {
    try {
      return await _authRepository.resetPassword(
        email: email,
        otp: otp,
        password: password,
        passwordConfirmation: passwordConfirmation,
      );
    } on ApiException catch (e) {
      throw e.message;
    } catch (e) {
      throw e.toString();
    }
  }

  /// مزامنة اشتراكات وإحصائيات الطالب المعتمدة من Laravel (/student/courses و /student/dashboard).
  void syncStudentEntitlements(
    StudentCoursesData coursesData, {
    StudentDashboardData? dashboard,
  }) {
    final current = state;
    if (current is! Authenticated) return;

    final updatedEnrolledIds = coursesData.activeEnrolledCourseIdStrings;
    final updatedExpiries = coursesData.expiryDatesByCourseId;
    final updatedWatchSeconds = (dashboard != null && dashboard.totalWatchSeconds > 0)
        ? dashboard.totalWatchSeconds
        : current.user.totalWatchSeconds;

    final updatedUser = current.user.copyWith(
      enrolledCourseIds: updatedEnrolledIds,
      courseExpiryDates: updatedExpiries,
      totalWatchSeconds: updatedWatchSeconds,
    );

    if (updatedUser != current.user) {
      emit(Authenticated(updatedUser));
    }
  }

  /// تحديث حالة اشتراك دورة محددة وحصيلة الدروس المكتملة انطلاقاً من GET /student/courses/{slug}.
  void markCourseDetailEntitlement(Course detailedCourse) {
    final current = state;
    if (current is! Authenticated) return;

    final enrolledIds = List<String>.from(current.user.enrolledCourseIds);
    if (detailedCourse.hasEnrolled) {
      if (!enrolledIds.contains(detailedCourse.id)) {
        enrolledIds.add(detailedCourse.id);
      }
    } else if (detailedCourse.isDetailedFromAuthServer) {
      // سحب الصلاحية فوراً إذا أكد الخادم أن الطالب لم يعد مشتركاً
      enrolledIds.remove(detailedCourse.id);
    }

    final completedIds = Set<String>.from(current.user.completedLessonIds);
    for (final id in detailedCourse.completedVideoIds) {
      completedIds.add(id.toString());
    }
    for (final lvl in detailedCourse.levels) {
      for (final lesson in lvl.lessons) {
        if (lesson.isCompleted) {
          completedIds.add(lesson.id);
        }
      }
    }

    final updatedUser = current.user.copyWith(
      enrolledCourseIds: enrolledIds,
      completedLessonIds: completedIds.toList(),
    );
    if (updatedUser != current.user) {
      emit(Authenticated(updatedUser));
    }
  }

  /// تسجيل إكمال درس فوري في حالة المستخدم الحالية بعد تأكيد الخادم أو بلوغ 95%.
  void markLessonCompleted(String lessonId) {
    final current = state;
    if (current is! Authenticated) return;
    if (current.user.completedLessonIds.contains(lessonId)) return;

    final updatedCompleted = List<String>.from(current.user.completedLessonIds)
      ..add(lessonId);
    emit(
      Authenticated(
        current.user.copyWith(completedLessonIds: updatedCompleted),
      ),
    );
  }

  /// تسجيل الخروج الآمن مع مسح طابور المشاهدة والذاكرة المؤقتة للحساب المنتهي.
  Future<void> signOut() async {
    final outgoingUid = state is Authenticated ? (state as Authenticated).user.uid : null;
    emit(Unauthenticated());
    try {
      if (sl.isRegistered<AccessCubit>()) {
        sl<AccessCubit>().clear();
      }
      if (sl.isRegistered<AssignmentsCubit>()) {
        sl<AssignmentsCubit>().clear();
      }
      if (outgoingUid != null && outgoingUid.isNotEmpty) {
        if (sl.isRegistered<WatchQueue>()) {
          await sl<WatchQueue>().clearUser(outgoingUid);
        } else {
          await WatchQueue.clearStorageForUser(outgoingUid);
        }
      }
      if (sl.isRegistered<CourseLocalCache>()) {
        await sl<CourseLocalCache>().clearAllUserCaches();
      }
      if (sl.isRegistered<StudentCertificatesRepository>()) {
        sl<StudentCertificatesRepository>().clearCache();
      }
      if (sl.isRegistered<StudentNotificationsRepository>()) {
        sl<StudentNotificationsRepository>().clearCache();
      }
      if (sl.isRegistered<StudentSupportRepository>()) {
        sl<StudentSupportRepository>().clearCache();
      }
      await _authRepository.logout().timeout(const Duration(seconds: 4));
    } catch (_) {}
  }

  /// تحديث بيانات الملف الشخصي للمتدرب (الاسم ورقم الهاتف)
  Future<void> updateProfileInfo({
    required String displayName,
    required String phone,
    String? email,
    String? bio,
    String? locale,
    String? avatarFilePath,
  }) async {
    final current = state;
    if (current is! Authenticated) return;
    final trimmedName = displayName.trim();
    final trimmedPhone = phone.trim();

    // Primary & Sole Remote Source: REST API update
    final profileRepo = _profileRepository ??
        (sl.isRegistered<StudentProfileRepository>()
            ? sl<StudentProfileRepository>()
            : null);
    if (profileRepo != null) {
      try {
        await profileRepo.updateStudentProfile(
          uid: current.user.uid,
          displayName: trimmedName,
          phone: trimmedPhone,
          email: email,
          bio: bio,
          locale: locale,
          avatarFilePath: avatarFilePath,
        );
      } catch (_) {}
    }

    emit(
      Authenticated(
        current.user.copyWith(
          displayName: trimmedName,
          phone: trimmedPhone,
        ),
      ),
    );
  }

  /// تحديث الصورة الشخصية للطالب
  Future<void> updateProfilePhoto(String photoUrl) async {
    final current = state;
    if (current is! Authenticated) return;
    final trimmedUrl = photoUrl.trim();

    emit(
      Authenticated(
        current.user.copyWith(photoUrl: trimmedUrl),
      ),
    );
  }

  /// حذف حساب الطالب نهائياً
  Future<void> deleteAccount({String? password}) async {
    final current = state;
    if (current is! Authenticated) return;
    emit(AuthLoading());
    try {
      final profileRepo = _profileRepository ??
          (sl.isRegistered<StudentProfileRepository>()
              ? sl<StudentProfileRepository>()
              : null);
      if (profileRepo != null) {
        try {
          await profileRepo.deleteStudentAccount(
            current.user.uid,
            currentPassword: password,
          );
        } catch (_) {}
      }

      if (sl.isRegistered<AccessCubit>()) {
        sl<AccessCubit>().clear();
      }
      if (sl.isRegistered<AssignmentsCubit>()) {
        sl<AssignmentsCubit>().clear();
      }
      if (sl.isRegistered<WatchQueue>()) {
        await sl<WatchQueue>().clearUser(current.user.uid);
      } else {
        await WatchQueue.clearStorageForUser(current.user.uid);
      }
      if (sl.isRegistered<CourseLocalCache>()) {
        await sl<CourseLocalCache>().clearAllUserCaches();
      }
      if (sl.isRegistered<StudentCertificatesRepository>()) {
        sl<StudentCertificatesRepository>().clearCache();
      }
      if (sl.isRegistered<StudentNotificationsRepository>()) {
        sl<StudentNotificationsRepository>().clearCache();
      }
      if (sl.isRegistered<StudentSupportRepository>()) {
        sl<StudentSupportRepository>().clearCache();
      }

      await _authRepository.logout();
      emit(Unauthenticated());
    } catch (e) {
      emit(Authenticated(current.user));
      emit(AuthError('تعذر حذف الحساب في الوقت الحالي: $e'));
    }
  }
}
