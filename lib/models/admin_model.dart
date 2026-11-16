import 'package:cloud_firestore/cloud_firestore.dart';

enum AdminRole {
  superAdmin('super_admin', 'المدير العام (Super Admin)', 'Super Admin'),
  instructor('instructor', 'محاضر معتمد (Instructor)', 'Instructor'),
  supervisor('supervisor', 'مشرف محتوى (Supervisor)', 'Supervisor'),
  assistant('assistant', 'مساعد إداري (Assistant)', 'Assistant'),
  custom('custom', 'مخصص (Custom)', 'Custom');

  final String code;
  final String labelAr;
  final String labelEn;

  const AdminRole(this.code, this.labelAr, this.labelEn);

  static AdminRole fromCode(String code) {
    return AdminRole.values.firstWhere(
      (r) => r.code == code,
      orElse: () => AdminRole.assistant,
    );
  }
}

class AdminPermission {
  static const String manageCourses = 'manage_courses';
  static const String scheduleLessons = 'schedule_lessons';
  static const String manageStudents = 'manage_students';
  static const String suspendDeleteStudents = 'suspend_delete_students';
  static const String manageRequests = 'manage_requests';
  static const String manageAssignments = 'manage_assignments';
  static const String exportPdfReports = 'export_pdf_reports';
  static const String manageContent = 'manage_content';
  static const String manageSupport = 'manage_support';
  static const String viewAnalytics = 'view_analytics';
  static const String manageAdmins = 'manage_admins';

  static const List<String> all = [
    manageCourses,
    scheduleLessons,
    manageStudents,
    suspendDeleteStudents,
    manageRequests,
    manageAssignments,
    exportPdfReports,
    manageContent,
    manageSupport,
    viewAnalytics,
    manageAdmins,
  ];

  static String getLabelAr(String permission) {
    switch (permission) {
      case manageCourses:
        return 'إدارة الدورات والمحاضرات وبث الفيديو';
      case scheduleLessons:
        return 'جدولة ونشر المحاضرات التلقائي';
      case manageStudents:
        return 'إدارة المتدربين وربط الكورسات';
      case suspendDeleteStudents:
        return 'تعليق وتنشيط وحذف حسابات الطلاب';
      case manageRequests:
        return 'مراجعة طلبات الالتحاق والإيصالات';
      case manageAssignments:
        return 'تصحيح الواجبات واعتماد الدرجات';
      case exportPdfReports:
        return 'تصدير وطباعة تقارير PDF للحضور والدرجات';
      case manageContent:
        return 'إدارة المحتوى التعريفي (من نحن، السياسات، الأسئلة)';
      case manageSupport:
        return 'الدعم الفني ومراسلة الطلاب وحل المشكلات';
      case viewAnalytics:
        return 'عرض التحليلات والتقارير والـ KPIs';
      case manageAdmins:
        return 'إدارة المشرفين وصلاحيات الفريق (Super Admin)';
      default:
        return permission;
    }
  }

  static String getLabelEn(String permission) {
    switch (permission) {
      case manageCourses:
        return 'Manage Courses, Lectures & Streams';
      case scheduleLessons:
        return 'Schedule & Publish Lectures';
      case manageStudents:
        return 'Manage Students & Enrollments';
      case suspendDeleteStudents:
        return 'Suspend, Activate & Delete Students';
      case manageRequests:
        return 'Review Access Requests & Receipts';
      case manageAssignments:
        return 'Grade Assignments & Issue Scores';
      case exportPdfReports:
        return 'Export & Print PDF Audit Reports';
      case manageContent:
        return 'Manage Center Content (About, Policy, FAQs)';
      case manageSupport:
        return 'Customer Support & Helpdesk';
      case viewAnalytics:
        return 'View Analytics & KPI Reports';
      case manageAdmins:
        return 'Manage Team Admins & Roles';
      default:
        return permission;
    }
  }

  static List<String> defaultForRole(AdminRole role) {
    switch (role) {
      case AdminRole.superAdmin:
        return List.from(all);
      case AdminRole.instructor:
        return [
          manageCourses,
          scheduleLessons,
          manageAssignments,
          exportPdfReports,
          viewAnalytics,
        ];
      case AdminRole.supervisor:
        return [
          manageRequests,
          manageStudents,
          suspendDeleteStudents,
          manageAssignments,
          exportPdfReports,
          viewAnalytics,
        ];
      case AdminRole.assistant:
        return [
          manageRequests,
          manageStudents,
          manageSupport,
        ];
      case AdminRole.custom:
        return [];
    }
  }
}

class AdminModel {
  final String id;
  final String uid;
  final String email;
  final String name;
  final String phone;
  final AdminRole role;
  final List<String> permissions;
  final bool isActive;
  final DateTime createdAt;
  final String createdBy;

  const AdminModel({
    required this.id,
    required this.uid,
    required this.email,
    required this.name,
    this.phone = '',
    this.role = AdminRole.assistant,
    this.permissions = const [],
    this.isActive = true,
    required this.createdAt,
    this.createdBy = '',
  });

  bool hasPermission(String permission) {
    if (role == AdminRole.superAdmin) return true;
    return permissions.contains(permission);
  }

  bool get isSuperAdmin => role == AdminRole.superAdmin;

  factory AdminModel.fromJson(Map<String, dynamic> json, String docId) {
    final roleStr = json['role'] as String? ?? 'assistant';
    final role = AdminRole.fromCode(roleStr);

    final permsRaw = json['permissions'];
    final perms = permsRaw is List
        ? permsRaw.map((e) => e.toString()).toList()
        : AdminPermission.defaultForRole(role);

    DateTime created;
    final createdRaw = json['createdAt'];
    if (createdRaw is Timestamp) {
      created = createdRaw.toDate();
    } else if (createdRaw is String) {
      created = DateTime.tryParse(createdRaw) ?? DateTime.now();
    } else {
      created = DateTime.now();
    }

    return AdminModel(
      id: docId,
      uid: json['uid'] as String? ?? docId,
      email: (json['email'] as String? ?? '').toLowerCase().trim(),
      name: json['name'] as String? ?? 'مشرف إداري',
      phone: json['phone'] as String? ?? '',
      role: role,
      permissions: perms,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: created,
      createdBy: json['createdBy'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email.toLowerCase().trim(),
      'name': name,
      'phone': phone,
      'role': role.code,
      'permissions': permissions,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
    };
  }

  AdminModel copyWith({
    String? id,
    String? uid,
    String? email,
    String? name,
    String? phone,
    AdminRole? role,
    List<String>? permissions,
    bool? isActive,
    DateTime? createdAt,
    String? createdBy,
  }) {
    return AdminModel(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      permissions: permissions ?? this.permissions,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}

