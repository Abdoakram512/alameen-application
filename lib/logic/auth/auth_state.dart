import 'package:equatable/equatable.dart';
import '../../models/user_profile.dart';

abstract class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}

/// Initial state on app startup before session restoration.
class AuthInitial extends AuthState {}

/// State during an active network authentication or registration request.
class AuthLoading extends AuthState {}

/// Authenticated state with active student profile and valid session.
class Authenticated extends AuthState {
  final UserModel user;
  const Authenticated(this.user);
  @override
  List<Object?> get props => [user];
}

/// Account successfully registered or logged in, but awaiting platform administrator approval.
class AuthPendingApproval extends AuthState {
  final String message;
  final UserModel? user;
  const AuthPendingApproval({
    required this.message,
    this.user,
  });
  @override
  List<Object?> get props => [message, user];
}

/// Account suspended by administration.
class AuthSuspended extends AuthState {
  final String message;
  final UserModel? user;
  const AuthSuspended({
    required this.message,
    this.user,
  });
  @override
  List<Object?> get props => [message, user];
}

/// Unauthenticated state (guest, logged out, or expired token).
class Unauthenticated extends AuthState {}

/// Error state containing human-readable localized message.
class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);
  @override
  List<Object?> get props => [message];
}

/// Password reset OTP dispatched to user's email.
class PasswordResetOtpSent extends AuthState {
  final String email;
  final String message;
  const PasswordResetOtpSent({
    required this.email,
    required this.message,
  });
  @override
  List<Object?> get props => [email, message];
}

/// Password reset OTP validated successfully.
class PasswordResetOtpVerified extends AuthState {
  final String email;
  final String otp;
  const PasswordResetOtpVerified({
    required this.email,
    required this.otp,
  });
  @override
  List<Object?> get props => [email, otp];
}

/// Password reset successfully completed.
class PasswordResetSuccess extends AuthState {
  final String message;
  const PasswordResetSuccess(this.message);
  @override
  List<Object?> get props => [message];
}
