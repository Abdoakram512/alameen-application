import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> showAdminWelcome(BuildContext context, {bool force = false}) async {
  final preferences = SharedPreferencesAsync();
  try {
    if (!force && await preferences.getBool('admin.introduction.v1') == true) return;
    if (!context.mounted) return;
    final done = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('أهلًا بك في إدارة الأمين'),
      content: const SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: Icon(Icons.school_outlined), title: Text('جهّز رحلة التعلّم'), subtitle: Text('أضف الكورسات والمستويات والدروس وتابع جاهزية الفيديوهات.')),
        ListTile(leading: Icon(Icons.fact_check_outlined), title: Text('راجع طلبات الانضمام'), subtitle: Text('راجع الإيصالات، ثم اقبل الطلب أو وضّح سبب الرفض.')),
        ListTile(leading: Icon(Icons.people_outline), title: Text('تابع طلابك'), subtitle: Text('راجع الاشتراكات والتقدم من ملف كل طالب.')),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('تخطي')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('ابدأ الإدارة'))],
    ));
    if (done == true) await preferences.setBool('admin.introduction.v1', true);
  } catch (_) {
    // An optional introduction must not block operational access.
  }
}
