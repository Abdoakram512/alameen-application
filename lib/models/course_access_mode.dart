import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

/// طريقة إتاحة الكورس للطلاب.
enum CourseAccessMode {
  /// متاح لكل الطلاب فوراً (تسجيل تلقائي عند الضغط على "ابدأ").
  open,

  /// الطالب يطلب الاشتراك والأدمن يوافق (السلوك الافتراضي/القديم).
  approvalRequired,

  /// لا يوجد طلب اشتراك؛ الأدمن فقط يعيّن طلاباً محددين.
  assignedOnly,

  /// مغلق ومخفي عن الطلاب (مسودة).
  closed;

  static CourseAccessMode fromName(String? name) {
    for (final mode in CourseAccessMode.values) {
      if (mode.name == name) return mode;
    }
    return CourseAccessMode.approvalRequired;
  }

  /// هل يظهر الكورس في قائمة الطالب؟
  bool get isVisibleToStudents => this != CourseAccessMode.closed;

  String get labelAr {
    switch (this) {
      case CourseAccessMode.open:
        return 'مفتوح للجميع';
      case CourseAccessMode.approvalRequired:
        return 'يتطلب موافقة';
      case CourseAccessMode.assignedOnly:
        return 'تعيين محدد';
      case CourseAccessMode.closed:
        return 'مغلق (مسودة)';
    }
  }

  String get labelEn {
    switch (this) {
      case CourseAccessMode.open:
        return 'Open';
      case CourseAccessMode.approvalRequired:
        return 'Approval Required';
      case CourseAccessMode.assignedOnly:
        return 'Assigned Only';
      case CourseAccessMode.closed:
        return 'Closed (Draft)';
    }
  }

  String get descriptionAr {
    switch (this) {
      case CourseAccessMode.open:
        return 'يمكن لأي طالب بدء الكورس فوراً دون انتظار موافقة';
      case CourseAccessMode.approvalRequired:
        return 'يرسل الطالب طلب اشتراك وينتظر موافقة الأدمن';
      case CourseAccessMode.assignedOnly:
        return 'يظهر فقط للطلاب المعينين يدوياً من لوحة الأدمن';
      case CourseAccessMode.closed:
        return 'مخفي تماماً عن الطلاب ولا يمكن لأحد فتحه';
    }
  }

  IconData get icon {
    switch (this) {
      case CourseAccessMode.open:
        return Icons.public_rounded;
      case CourseAccessMode.approvalRequired:
        return Icons.verified_user_outlined;
      case CourseAccessMode.assignedOnly:
        return Icons.group_add_outlined;
      case CourseAccessMode.closed:
        return Icons.lock_outline_rounded;
    }
  }

  Color get badgeBg {
    switch (this) {
      case CourseAccessMode.open:
        return AppColors.successLight;
      case CourseAccessMode.approvalRequired:
        return AppColors.primaryLight;
      case CourseAccessMode.assignedOnly:
        return const Color(0xFFEDE9FE);
      case CourseAccessMode.closed:
        return const Color(0xFFF1F5F9);
    }
  }

  Color get badgeFg {
    switch (this) {
      case CourseAccessMode.open:
        return AppColors.successDark;
      case CourseAccessMode.approvalRequired:
        return AppColors.royalNavy;
      case CourseAccessMode.assignedOnly:
        return const Color(0xFF6D28D9);
      case CourseAccessMode.closed:
        return const Color(0xFF475569);
    }
  }

  Color get badgeBorder {
    switch (this) {
      case CourseAccessMode.open:
        return AppColors.successBorder;
      case CourseAccessMode.approvalRequired:
        return AppColors.royalNavy.withValues(alpha: 0.2);
      case CourseAccessMode.assignedOnly:
        return const Color(0xFFDDD6FE);
      case CourseAccessMode.closed:
        return const Color(0xFFCBD5E1);
    }
  }
}

