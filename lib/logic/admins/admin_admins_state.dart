import 'package:equatable/equatable.dart';
import '../../models/admin_model.dart';

abstract class AdminAdminsState extends Equatable {
  const AdminAdminsState();

  @override
  List<Object?> get props => [];
}

class AdminAdminsInitial extends AdminAdminsState {}

class AdminAdminsLoading extends AdminAdminsState {}

class AdminAdminsLoaded extends AdminAdminsState {
  final List<AdminModel> admins;

  const AdminAdminsLoaded(this.admins);

  int get totalCount => admins.length;
  int get activeCount => admins.where((a) => a.isActive).length;

  @override
  List<Object?> get props => [admins];
}

class AdminAdminsError extends AdminAdminsState {
  final String message;

  const AdminAdminsError(this.message);

  @override
  List<Object?> get props => [message];
}

class AdminAdminsActionSuccess extends AdminAdminsState {
  final String message;

  const AdminAdminsActionSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

