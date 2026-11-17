import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/di/injection_container.dart';
import '../../core/network/api_exceptions.dart';
import '../../repositories/student_auth_repository.dart';
import '../../repositories/student_profile_repository.dart';
import '../../services/firestore_service.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final StudentAuthRepository _authRepository;
  final StudentProfileRepository? _profileRepository;
  final FirestoreService? _firestoreService;

  AuthCubit({
    StudentAuthRepository? authRepository,
    StudentProfileRepository? profileRepository,
    FirestoreService? firestoreService,
  })  : _authRepository = authRepository ?? sl<StudentAuthRepository>(),
        _profileRepository = profileRepository,
        _firestoreService = firestoreService,
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

  /// تسجيل الخروج الآمن
  Future<void> signOut() async {
    emit(Unauthenticated());
    try {
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

    // 1. Primary: REST API update
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

    if (_firestoreService != null) {
      try {
        await _firestoreService.updateStudentProfile(
          uid: current.user.uid,
          displayName: trimmedName,
          phone: trimmedPhone,
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

    if (_firestoreService != null) {
      try {
        await _firestoreService.updateStudentPhoto(
          uid: current.user.uid,
          photoUrl: trimmedUrl,
        );
      } catch (_) {}
    }

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

      await _authRepository.logout();
      emit(Unauthenticated());
    } catch (e) {
      emit(Authenticated(current.user));
      emit(AuthError('تعذر حذف الحساب في الوقت الحالي: $e'));
    }
  }
}
