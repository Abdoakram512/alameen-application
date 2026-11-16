import '../models/admin_model.dart';

abstract class AdminsRepository {
  Stream<List<AdminModel>> streamAdmins();
  Future<AdminModel?> getAdminByEmail(String email);
  Future<AdminModel?> getAdminByUid(String uid);
  Future<void> saveAdmin(AdminModel admin);
  Future<void> updateAdminPermissions(
    String adminId, {
    required AdminRole role,
    required List<String> permissions,
  });
  Future<void> toggleAdminStatus(String adminId, bool isActive);
  Future<void> deleteAdmin(String adminId);
  Future<AdminModel> ensureRootAdminProvisioned({
    required String rootEmail,
    String? rootUid,
  });
}
