import 'package:firebase_auth/firebase_auth.dart';
import '../models/admin_model.dart';
import 'firestore_service.dart';
import 'notification_service.dart';

class AdminUser {
  final String uid;
  final String displayName;
  final String email;
  final String photoUrl;
  final AdminRole role;
  final List<String> permissions;

  AdminUser({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.photoUrl,
    this.role = AdminRole.superAdmin,
    this.permissions = const [],
  });

  bool hasPermission(String permission) {
    if (role == AdminRole.superAdmin) return true;
    return permissions.contains(permission);
  }

  bool get isSuperAdmin => role == AdminRole.superAdmin;
}

class AdminAuthService {
  static final AdminAuthService _instance = AdminAuthService._internal();
  factory AdminAuthService() => _instance;
  AdminAuthService._internal();

  FirebaseAuth get _auth => FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentFirebaseUser => _auth.currentUser;

  /// فحص صلاحية المشرف بالتحقق من قاعدة بيانات المشرفين في Firestore
  Future<bool> isAuthorizedAdmin(String? email) async {
    if (email == null || email.trim().isEmpty) return false;
    final admin = await FirestoreService().getAdminByEmail(email.trim().toLowerCase());
    return admin != null && admin.isActive;
  }

  /// جلب الملف الإداري والصلاحيات للحساب المسجل من Firestore
  Future<AdminUser?> getAdminProfile(User user) async {
    final cleanEmail = (user.email ?? '').toLowerCase().trim();

    // التحقق المباشر من قاعدة بيانات المشرفين في Firestore بالمعرف أولاً (O(1) cache hit) ثم بالبريد
    final adminModel = await FirestoreService().getAdminByUid(user.uid) ??
        (cleanEmail.isNotEmpty ? await FirestoreService().getAdminByEmail(cleanEmail) : null);

    if (adminModel == null || !adminModel.isActive) {
      return null;
    }

    return AdminUser(
      uid: user.uid,
      displayName: (user.displayName != null && user.displayName!.isNotEmpty)
          ? user.displayName!
          : adminModel.name,
      email: cleanEmail,
      photoUrl: user.photoURL ?? '',
      role: adminModel.role,
      permissions: adminModel.permissions,
    );
  }

  /// تسجيل الدخول بالبريد الإلكتروني وكلمة المرور
  Future<AdminUser> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();

    final credential = await _auth.signInWithEmailAndPassword(
      email: cleanEmail,
      password: password,
    );

    final user = credential.user;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'unauthorized-admin',
        message: 'تعذر التحقق من بيانات الحساب.',
      );
    }

    final adminUser = await getAdminProfile(user);
    if (adminUser == null) {
      await _auth.signOut();
      throw FirebaseAuthException(
        code: 'unauthorized-admin',
        message: 'غير مصرح: هذا الحساب غير مسجل كأدمن مصرح به أو تم تعطيل صلاحياته.',
      );
    }

    return adminUser;
  }

  /// تسجيل الخروج وتنظيف اشتراكات الإشعارات الإدارية
  Future<void> signOut() async {
    try {
      final uid = _auth.currentUser?.uid;
      await AdminNotificationService().clearAdminSession(uid);
    } catch (_) {}
    try {
      await _auth.signOut();
    } catch (_) {}
  }
}
