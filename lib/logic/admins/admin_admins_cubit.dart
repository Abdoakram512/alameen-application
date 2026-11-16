import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/utils/network_error_mapper.dart';
import '../../models/admin_model.dart';
import '../../repositories/admins_repository.dart';
import '../../repositories/impl/admins_repository_impl.dart';
import '../../services/firestore_service.dart';
import 'admin_admins_state.dart';

class AdminAdminsCubit extends Cubit<AdminAdminsState> {
  final AdminsRepository _adminsRepository;
  StreamSubscription<List<AdminModel>>? _adminsSubscription;

  AdminAdminsCubit({
    AdminsRepository? adminsRepository,
    FirestoreService? firestoreService,
  })  : _adminsRepository = adminsRepository ??
            (firestoreService?.adminsRepository ?? AdminsRepositoryImpl()),
        super(AdminAdminsInitial());

  void loadAdmins() {
    emit(AdminAdminsLoading());
    _adminsSubscription?.cancel();
    _adminsSubscription = _adminsRepository.streamAdmins().listen(
      (admins) {
        emit(AdminAdminsLoaded(admins));
      },
      onError: (error) {
        emit(
          AdminAdminsError(
            NetworkErrorMapper.toArabicMessage(
              error,
              defaultMessage: 'فشل تحميل قائمة المشرفين.',
            ),
          ),
        );
      },
    );
  }

  Future<void> addAdmin({
    required String name,
    required String email,
    required String phone,
    required AdminRole role,
    required List<String> permissions,
    required String createdBy,
  }) async {
    try {
      final cleanEmail = email.toLowerCase().trim();
      final existing = await _adminsRepository.getAdminByEmail(cleanEmail);
      if (existing != null) {
        emit(const AdminAdminsError('هذا البريد الإلكتروني مسجل بالفعل كمشرف.'));
        loadAdmins();
        return;
      }

      final newAdmin = AdminModel(
        id: '',
        uid: '',
        email: cleanEmail,
        name: name.trim(),
        phone: phone.trim(),
        role: role,
        permissions: permissions,
        isActive: true,
        createdAt: DateTime.now(),
        createdBy: createdBy,
      );

      await _adminsRepository.saveAdmin(newAdmin);
      emit(const AdminAdminsActionSuccess('تمت إضافة المشرف بنجاح ومنحه الصلاحيات المحددة.'));
    } catch (e) {
      emit(AdminAdminsError('حدث خطأ أثناء إضافة المشرف: $e'));
    }
  }

  Future<void> updateAdminPermissions({
    required String adminId,
    required AdminRole role,
    required List<String> permissions,
  }) async {
    try {
      await _adminsRepository.updateAdminPermissions(
        adminId,
        role: role,
        permissions: permissions,
      );
      emit(const AdminAdminsActionSuccess('تم تحديث صلاحيات المشرف بنجاح.'));
    } catch (e) {
      emit(AdminAdminsError('حدث خطأ أثناء تحديث الصلاحيات: $e'));
    }
  }

  Future<void> toggleAdminStatus({
    required String adminId,
    required AdminRole role,
    required bool isActive,
  }) async {
    try {
      if (role == AdminRole.superAdmin) {
        emit(const AdminAdminsError('لا يمكن تعطيل حساب المدير العام (Super Admin).'));
        return;
      }

      await _adminsRepository.toggleAdminStatus(adminId, isActive);
      emit(AdminAdminsActionSuccess(
        isActive ? 'تم تنشيط حساب المشرف بنجاح.' : 'تم إيقاف صلاحيات المشرف مؤقتاً.',
      ));
    } catch (e) {
      emit(AdminAdminsError('حدث خطأ أثناء تغيير حالة المشرف: $e'));
    }
  }

  Future<void> deleteAdmin({
    required String adminId,
    required AdminRole role,
  }) async {
    try {
      if (role == AdminRole.superAdmin) {
        emit(const AdminAdminsError('لا يمكن حذف حساب المدير العام (Super Admin).'));
        return;
      }

      await _adminsRepository.deleteAdmin(adminId);
      emit(const AdminAdminsActionSuccess('تم حذف المشرف من النظام نهائياً.'));
    } catch (e) {
      emit(AdminAdminsError('حدث خطأ أثناء حذف المشرف: $e'));
    }
  }

  @override
  Future<void> close() {
    _adminsSubscription?.cancel();
    return super.close();
  }
}

