import 'package:equatable/equatable.dart';
import '../../services/auth_service.dart';

abstract class AdminAuthState extends Equatable {
  const AdminAuthState();
  @override
  List<Object?> get props => [];
}

class AdminAuthInitial extends AdminAuthState {}

class AdminAuthLoading extends AdminAuthState {}

class AdminAuthenticated extends AdminAuthState {
  final AdminUser user;
  const AdminAuthenticated(this.user);
  @override
  List<Object?> get props => [user];
}

class AdminUnauthenticated extends AdminAuthState {}

class AdminAuthError extends AdminAuthState {
  final String message;
  const AdminAuthError(this.message);
  @override
  List<Object?> get props => [message];
}

