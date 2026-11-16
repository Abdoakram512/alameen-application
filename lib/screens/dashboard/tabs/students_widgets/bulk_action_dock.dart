import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../models/course.dart';

/// شريط عائم سفلي للإجراءات الجماعية على الطلاب المحددين
class BulkActionDock extends StatelessWidget {
  final int selectedCount;
  final List<Course> availableCourses;
  final VoidCallback onClearSelection;
  final VoidCallback onSelectAll;
  final Function(Course course, int validityDays) onAssignToCourse;
  final Function(Course course) onRemoveFromCourse;
  final Function(Course course, int days) onExtendValidity;
  final Function(bool suspend, String? reason) onToggleSuspension;
  final VoidCallback onDeleteSelected;

  const BulkActionDock({
    super.key,
    required this.selectedCount,
    required this.availableCourses,
    required this.onClearSelection,
    required this.onSelectAll,
    required this.onAssignToCourse,
    required this.onRemoveFromCourse,
    required this.onExtendValidity,
    required this.onToggleSuspension,
    required this.onDeleteSelected,
  });

  void _showAssignModal(BuildContext context) {
    if (availableCourses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد كورسات متاحة حالياً.')),
      );
      return;
    }
    Course selectedCourse = availableCourses.first;
    final validityController = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('إلحاق الطلاب المحددين بدورة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('سيتم تسجيل ($selectedCount) طلاب في الدورة التالية:'),
              const SizedBox(height: 12),
              DropdownButtonFormField<Course>(
                initialValue: selectedCourse,
                decoration: const InputDecoration(
                  labelText: 'اختر الدورة التدريبية',
                  border: OutlineInputBorder(),
                ),
                items: availableCourses.map((c) {
                  return DropdownMenuItem(value: c, child: Text(c.title));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => selectedCourse = val);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: validityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'صلاحية الاشتراك بالأيام (0 = دائم)',
                  suffixText: 'يوم',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () {
                final days = int.tryParse(validityController.text.trim()) ?? 0;
                Navigator.pop(ctx);
                onAssignToCourse(selectedCourse, days);
              },
              child: const Text('تأكيد الإلحاق'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRemoveModal(BuildContext context) {
    if (availableCourses.isEmpty) return;
    Course selectedCourse = availableCourses.first;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('إلغاء اشتراك الطلاب المحددين من دورة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('اختر الدورة لإلغاء تسجيل ($selectedCount) طلاب منها:'),
              const SizedBox(height: 12),
              DropdownButtonFormField<Course>(
                initialValue: selectedCourse,
                decoration: const InputDecoration(
                  labelText: 'الدورة المراد الإلغاء منها',
                  border: OutlineInputBorder(),
                ),
                items: availableCourses.map((c) {
                  return DropdownMenuItem(value: c, child: Text(c.title));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => selectedCourse = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () {
                Navigator.pop(ctx);
                onRemoveFromCourse(selectedCourse);
              },
              child: const Text('تأكيد الإلغاء'),
            ),
          ],
        ),
      ),
    );
  }

  void _showExtendModal(BuildContext context) {
    if (availableCourses.isEmpty) return;
    Course selectedCourse = availableCourses.first;
    final daysController = TextEditingController(text: '30');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('تمديد الصلاحية للطلاب المحددين'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('تمديد صلاحية ($selectedCount) طلاب في دورة:'),
              const SizedBox(height: 12),
              DropdownButtonFormField<Course>(
                initialValue: selectedCourse,
                decoration: const InputDecoration(
                  labelText: 'الدورة المراد التمديد فيها',
                  border: OutlineInputBorder(),
                ),
                items: availableCourses.map((c) {
                  return DropdownMenuItem(value: c, child: Text(c.title));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => selectedCourse = val);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: daysController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'عدد الأيام الإضافية',
                  suffixText: 'يوم',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.royalNavy),
              onPressed: () {
                final days = int.tryParse(daysController.text.trim()) ?? 30;
                Navigator.pop(ctx);
                onExtendValidity(selectedCourse, days);
              },
              child: const Text('تأكيد التمديد'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSuspendModal(BuildContext context) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعليق حسابات الطلاب المحددين'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('هل أنت متأكد من تعليق حسابات ($selectedCount) طلاب دفعة واحدة ومنعهم من الدخول؟'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'سبب التعليق (اختياري)',
                hintText: 'مثال: إجراء إداري أو تدقيق حسابات',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(ctx);
              onToggleSuspension(true, reasonController.text.trim());
            },
            child: const Text('تأكيد التعليق الجماعي'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.royalNavy,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 8,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'تم تحديد $selectedCount طالب',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: onSelectAll,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white.withValues(alpha: 0.9),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text('تحديد الكل', style: TextStyle(fontSize: 12)),
                ),
                IconButton(
                  tooltip: 'إلغاء التحديد',
                  icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
                  onPressed: onClearSelection,
                ),
              ],
            ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.royalNavy,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _showAssignModal(context),
                  icon: const Icon(PhosphorIconsRegular.userPlus, size: 15),
                  label: const Text('+ إضافة لكورس', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white30),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _showRemoveModal(context),
                  icon: const Icon(PhosphorIconsRegular.userMinus, size: 15),
                  label: const Text('- إزالة من كورس', style: TextStyle(fontSize: 12)),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white30),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _showExtendModal(context),
                  icon: const Icon(PhosphorIconsRegular.timer, size: 15),
                  label: const Text('⏱️ تمديد', style: TextStyle(fontSize: 12)),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.amberAccent,
                    side: const BorderSide(color: Colors.amberAccent),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _showSuspendModal(context),
                  icon: const Icon(PhosphorIconsRegular.prohibit, size: 15),
                  label: const Text('تعليق', style: TextStyle(fontSize: 12)),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.greenAccent,
                    side: const BorderSide(color: Colors.greenAccent),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => onToggleSuspension(false, null),
                  icon: const Icon(PhosphorIconsRegular.checkCircle, size: 15),
                  label: const Text('تنشيط', style: TextStyle(fontSize: 12)),
                ),
                IconButton(
                  tooltip: 'حذف جماعي',
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.error.withValues(alpha: 0.25),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(PhosphorIconsRegular.trash, color: Colors.redAccent, size: 16),
                  onPressed: onDeleteSelected,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
