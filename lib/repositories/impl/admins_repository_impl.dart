import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/admin_model.dart';
import '../admins_repository.dart';

class AdminsRepositoryImpl implements AdminsRepository {
  final FirebaseFirestore? _explicitFirestore;

  AdminsRepositoryImpl({FirebaseFirestore? firestore})
      : _explicitFirestore = firestore;

  bool get isAvailable {
    try {
      final _ = db;
      return true;
    } catch (_) {
      return false;
    }
  }

  FirebaseFirestore get db => _explicitFirestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _adminsRef =>
      db.collection('admins');

  @override
  Stream<List<AdminModel>> streamAdmins() {
    if (!isAvailable) return Stream.value(const <AdminModel>[]);
    return _adminsRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return AdminModel.fromJson(doc.data(), doc.id);
      }).toList();
    });
  }

  @override
  Future<AdminModel?> getAdminByEmail(String email) async {
    final cleanEmail = email.toLowerCase().trim();
    final query = await _adminsRef
        .where('email', isEqualTo: cleanEmail)
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;
    final doc = query.docs.first;
    return AdminModel.fromJson(doc.data(), doc.id);
  }

  @override
  Future<AdminModel?> getAdminByUid(String uid) async {
    final doc = await _adminsRef.doc(uid).get();
    if (doc.exists && doc.data() != null) {
      return AdminModel.fromJson(doc.data()!, doc.id);
    }
    final query = await _adminsRef.where('uid', isEqualTo: uid).limit(1).get();
    if (query.docs.isNotEmpty) {
      return AdminModel.fromJson(query.docs.first.data(), query.docs.first.id);
    }
    return null;
  }

  @override
  Future<void> saveAdmin(AdminModel admin) async {
    final docRef = admin.id.isNotEmpty
        ? _adminsRef.doc(admin.id)
        : (admin.uid.isNotEmpty ? _adminsRef.doc(admin.uid) : _adminsRef.doc());
    await docRef.set(admin.toJson(), SetOptions(merge: true));
  }

  @override
  Future<void> updateAdminPermissions(
    String adminId, {
    required AdminRole role,
    required List<String> permissions,
  }) async {
    await _adminsRef.doc(adminId).update({
      'role': role.code,
      'permissions': permissions,
    });
  }

  @override
  Future<void> toggleAdminStatus(String adminId, bool isActive) async {
    await _adminsRef.doc(adminId).update({
      'isActive': isActive,
    });
  }

  @override
  Future<void> deleteAdmin(String adminId) async {
    await _adminsRef.doc(adminId).delete();
  }

  @override
  Future<AdminModel> ensureRootAdminProvisioned({
    required String rootEmail,
    String? rootUid,
  }) async {
    final cleanEmail = rootEmail.toLowerCase().trim();
    final AdminModel? existing = await getAdminByEmail(cleanEmail);
    if (existing == null) {
      final docRef = rootUid != null && rootUid.isNotEmpty
          ? _adminsRef.doc(rootUid)
          : _adminsRef.doc();
      final rootAdmin = AdminModel(
        id: docRef.id,
        uid: rootUid ?? docRef.id,
        email: cleanEmail,
        name: 'الأمين سنتر (المدير العام)',
        role: AdminRole.superAdmin,
        permissions: AdminPermission.all,
        isActive: true,
        createdAt: DateTime.now(),
        createdBy: 'system',
      );
      await docRef.set(rootAdmin.toJson(), SetOptions(merge: true));
      return rootAdmin;
    }
    return existing;
  }
}
