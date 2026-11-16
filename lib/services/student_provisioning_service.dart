import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class ProvisionStudentDraft {
  final String name;
  final String email;
  final String password;
  final String phone;

  const ProvisionStudentDraft({
    required this.name,
    required this.email,
    required this.password,
    this.phone = '',
  });
}

class ProvisionStudentOutcome {
  final String name;
  final String email;
  final String password;
  final bool createdNewAccount;
  final bool succeeded;
  final String? message;

  const ProvisionStudentOutcome({
    required this.name,
    required this.email,
    required this.password,
    required this.createdNewAccount,
    required this.succeeded,
    this.message,
  });
}

/// خدمة إنشاء حسابات المتدربين (مفرد أو جماعي) عبر نسخة Firebase معزولة
/// لضمان عدم تسجيل خروج المشرف أثناء إنشاء حسابات الطلاب ومنحهم الصلاحيات.
class StudentProvisioningService {
  static const String _secondaryAppName = 'AlameenStudentProvisioner';

  final FirebaseFirestore? _injectedFirestore;

  StudentProvisioningService({FirebaseFirestore? firestore})
      : _injectedFirestore = firestore;

  FirebaseFirestore get _db => _injectedFirestore ?? FirebaseFirestore.instance;

  static String generateStrongPassword({int length = 9}) {
    const upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
    const lower = 'abcdefghijkmnpqrstuvwxyz';
    const digits = '23456789';
    const all = '$upper$lower$digits';
    final rng = Random.secure();
    final chars = <String>[
      upper[rng.nextInt(upper.length)],
      lower[rng.nextInt(lower.length)],
      digits[rng.nextInt(digits.length)],
      digits[rng.nextInt(digits.length)],
    ];
    while (chars.length < length) {
      chars.add(all[rng.nextInt(all.length)]);
    }
    chars.shuffle(rng);
    return chars.join();
  }

  Future<FirebaseAuth> _getIsolatedAuth() async {
    FirebaseApp secondaryApp;
    try {
      secondaryApp = Firebase.app(_secondaryAppName);
    } catch (_) {
      secondaryApp = await Firebase.initializeApp(
        name: _secondaryAppName,
        options: Firebase.app().options,
      );
    }
    return FirebaseAuth.instanceFor(app: secondaryApp);
  }

  Future<List<ProvisionStudentOutcome>> provisionStudents({
    required List<ProvisionStudentDraft> drafts,
    required List<String> courseIds,
    void Function(int completed, int total)? onProgress,
  }) async {
    final outcomes = <ProvisionStudentOutcome>[];
    final secondaryAuth = await _getIsolatedAuth();
    final uniqueCourseIds = courseIds.toSet().toList();

    for (var i = 0; i < drafts.length; i++) {
      final draft = drafts[i];
      final cleanName = draft.name.trim();
      final cleanEmail = draft.email.trim().toLowerCase();
      final cleanPassword = draft.password.trim();
      final cleanPhone = draft.phone.trim();

      if (cleanName.isEmpty || !cleanEmail.contains('@')) {
        outcomes.add(
          ProvisionStudentOutcome(
            name: cleanName.isEmpty ? 'بدون اسم' : cleanName,
            email: cleanEmail,
            password: cleanPassword,
            createdNewAccount: false,
            succeeded: false,
            message: 'يرجى التحقق من الاسم وصيغة البريد الإلكتروني.',
          ),
        );
        onProgress?.call(i + 1, drafts.length);
        continue;
      }

      if (cleanPassword.length < 6) {
        outcomes.add(
          ProvisionStudentOutcome(
            name: cleanName,
            email: cleanEmail,
            password: cleanPassword,
            createdNewAccount: false,
            succeeded: false,
            message: 'كلمة المرور يجب ألا تقل عن 6 أحرف.',
          ),
        );
        onProgress?.call(i + 1, drafts.length);
        continue;
      }

      try {
        final credential = await secondaryAuth.createUserWithEmailAndPassword(
          email: cleanEmail,
          password: cleanPassword,
        );
        final uid = credential.user?.uid;
        if (uid == null || uid.isEmpty) {
          throw StateError('تعذر استخراج معرف الحساب الجديد.');
        }

        try {
          await credential.user?.updateDisplayName(cleanName);
        } catch (_) {}

        await secondaryAuth.signOut();

        await _db.collection('users').doc(uid).set({
          'uid': uid,
          'id': uid,
          'displayName': cleanName,
          'name': cleanName,
          'email': cleanEmail,
          'phone': cleanPhone,
          'photoUrl': '',
          'role': 'student',
          'provisionedByAdmin': true,
          'enrolledCourseIds': uniqueCourseIds,
          'completedLessonIds': const <String>[],
          'totalWatchSeconds': 0,
          'createdAt': FieldValue.serverTimestamp(),
          'lastActiveAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        await _incrementCoursesEnrollment(uniqueCourseIds);

        outcomes.add(
          ProvisionStudentOutcome(
            name: cleanName,
            email: cleanEmail,
            password: cleanPassword,
            createdNewAccount: true,
            succeeded: true,
            message: 'تم إنشاء الحساب وتفعيل الدورات المختارة.',
          ),
        );
      } on FirebaseAuthException catch (e) {
        try {
          await secondaryAuth.signOut();
        } catch (_) {}

        if (e.code == 'email-already-in-use') {
          final updatedExisting = await _grantCoursesToExistingEmail(
            email: cleanEmail,
            name: cleanName,
            phone: cleanPhone,
            courseIds: uniqueCourseIds,
          );
          outcomes.add(
            ProvisionStudentOutcome(
              name: cleanName,
              email: cleanEmail,
              password: cleanPassword,
              createdNewAccount: false,
              succeeded: updatedExisting,
              message: updatedExisting
                  ? 'البريد مسجل مسبقاً — تم تحديث صلاحيات الدورات له مباشرة.'
                  : 'البريد مستخدم مسبقاً بحساب آخر ولم يُعثر على ملفه.',
            ),
          );
        } else {
          outcomes.add(
            ProvisionStudentOutcome(
              name: cleanName,
              email: cleanEmail,
              password: cleanPassword,
              createdNewAccount: false,
              succeeded: false,
              message: _mapAuthError(e.code),
            ),
          );
        }
      } catch (e) {
        try {
          await secondaryAuth.signOut();
        } catch (_) {}
        outcomes.add(
          ProvisionStudentOutcome(
            name: cleanName,
            email: cleanEmail,
            password: cleanPassword,
            createdNewAccount: false,
            succeeded: false,
            message: 'خطأ غير متوقع أثناء التجهيز: $e',
          ),
        );
      }

      onProgress?.call(i + 1, drafts.length);
    }

    return outcomes;
  }

  Future<bool> _grantCoursesToExistingEmail({
    required String email,
    required String name,
    required String phone,
    required List<String> courseIds,
  }) async {
    final snap = await _db
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return false;

    final doc = snap.docs.first;
    final existingCourses = List<String>.from(
      doc.data()['enrolledCourseIds'] ?? const <String>[],
    );
    final newlyAdded = courseIds
        .where((c) => !existingCourses.contains(c))
        .toList();

    final updates = <String, dynamic>{
      if (courseIds.isNotEmpty)
        'enrolledCourseIds': FieldValue.arrayUnion(courseIds),
      if (name.isNotEmpty) 'displayName': name,
      if (phone.isNotEmpty) 'phone': phone,
    };
    if (updates.isNotEmpty) {
      await doc.reference.set(updates, SetOptions(merge: true));
    }
    if (newlyAdded.isNotEmpty) {
      await _incrementCoursesEnrollment(newlyAdded);
    }
    return true;
  }

  Future<void> _incrementCoursesEnrollment(List<String> courseIds) async {
    if (courseIds.isEmpty) return;
    final batch = _db.batch();
    for (final courseId in courseIds) {
      batch.set(
        _db.collection('courses').doc(courseId),
        {'enrolledCount': FieldValue.increment(1)},
        SetOptions(merge: true),
      );
    }
    try {
      await batch.commit();
    } catch (_) {}
  }

  String _mapAuthError(String code) {
    switch (code) {
      case 'invalid-email':
        return 'صيغة البريد الإلكتروني غير صحيحة.';
      case 'weak-password':
        return 'كلمة المرور ضعيفة جداً (6 أحرف على الأقل).';
      case 'network-request-failed':
        return 'تحقق من اتصال الإنترنت ثم أعد المحاولة.';
      default:
        return 'تعذر إنشاء الحساب ($code).';
    }
  }
}

