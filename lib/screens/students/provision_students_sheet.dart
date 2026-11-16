import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/app_validators.dart';
import '../../logic/courses/admin_courses_cubit.dart';
import '../../logic/students/admin_students_cubit.dart';
import '../../models/course.dart';
import '../../services/student_provisioning_service.dart';
import 'provision_widgets/bulk_students_provision_editor.dart';
import 'provision_widgets/course_access_selector_box.dart';
import 'provision_widgets/provision_progress_indicator.dart';
import 'provision_widgets/provisioned_credentials_dialog.dart';
import 'provision_widgets/single_student_provision_form.dart';

/// نافذة إضافة متدرب واحد أو عدة متدربين دفعة واحدة مع تفعيل فوري للكورسات.
class ProvisionStudentsSheet extends StatefulWidget {
  final List<Course> availableCourses;

  const ProvisionStudentsSheet({
    super.key,
    required this.availableCourses,
  });

  static Future<void> show(
    BuildContext context, {
    required List<Course> availableCourses,
  }) {
    final coursesCubit = context.read<AdminCoursesCubit>();
    final studentsCubit = context.read<AdminStudentsCubit>();

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 680),
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: coursesCubit),
          BlocProvider.value(value: studentsCubit),
        ],
        child: ProvisionStudentsSheet(availableCourses: availableCourses),
      ),
    );
  }

  @override
  State<ProvisionStudentsSheet> createState() => _ProvisionStudentsSheetState();
}

class _ProvisionStudentsSheetState extends State<ProvisionStudentsSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _singleFormKey = GlobalKey<FormState>();
  final _provisioningService = StudentProvisioningService();

  // Single Student controllers
  final _singleNameCtrl = TextEditingController();
  final _singleEmailCtrl = TextEditingController();
  final _singlePhoneCtrl = TextEditingController();
  late final TextEditingController _singlePasswordCtrl = TextEditingController(
    text: StudentProvisioningService.generateStrongPassword(),
  );

  // Bulk Students rows
  final List<BulkRowControllers> _bulkRows = [
    BulkRowControllers(),
    BulkRowControllers(),
  ];

  // Selected Courses shared across tabs
  final Set<String> _selectedCourseIds = <String>{};

  bool _isSubmitting = false;
  int _completedCount = 0;
  int _totalCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _singleNameCtrl.dispose();
    _singleEmailCtrl.dispose();
    _singlePhoneCtrl.dispose();
    _singlePasswordCtrl.dispose();
    for (final row in _bulkRows) {
      row.dispose();
    }
    super.dispose();
  }

  void _toggleCourse(String courseId) {
    setState(() {
      if (!_selectedCourseIds.remove(courseId)) {
        _selectedCourseIds.add(courseId);
      }
    });
  }

  void _toggleAllCourses() {
    setState(() {
      if (_selectedCourseIds.length == widget.availableCourses.length) {
        _selectedCourseIds.clear();
      } else {
        _selectedCourseIds
          ..clear()
          ..addAll(widget.availableCourses.map((c) => c.id));
      }
    });
  }

  Future<void> _openQuickPasteDialog() async {
    final pasteCtrl = TextEditingController();
    final pasted = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('لصق قائمة متدربين سريعة'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ضع كل متدرب في سطر مستقل بالصيغة التالية (كلمة المرور اختيارية ويتم توليدها تلقائياً إن تُركت):',
                style:
                    TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLevel0,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'أحمد محمد, ahmed@mail.com, Pass1234\nسارة علي, sara@mail.com',
                  textDirection: TextDirection.ltr,
                  style: TextStyle(fontSize: 11.5, fontFamily: 'monospace'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pasteCtrl,
                maxLines: 6,
                decoration: const InputDecoration(
                  hintText: 'الصق القائمة هنا...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, pasteCtrl.text),
            child: const Text('استيراد القائمة'),
          ),
        ],
      ),
    );
    pasteCtrl.dispose();
    if (pasted == null || pasted.trim().isEmpty || !mounted) return;

    final lines = pasted
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) return;

    setState(() {
      for (final r in _bulkRows) {
        r.dispose();
      }
      _bulkRows.clear();
      for (final line in lines) {
        final parts = line
            .split(RegExp(r'[,،;\t|]+'))
            .map((p) => p.trim())
            .toList();
        if (parts.length >= 2) {
          _bulkRows.add(
            BulkRowControllers(
              initialName: parts[0],
              initialEmail: parts[1],
              initialPassword: parts.length >= 3 && parts[2].length >= 6
                  ? parts[2]
                  : null,
            ),
          );
        }
      }
      if (_bulkRows.isEmpty) {
        _bulkRows.add(BulkRowControllers());
      }
    });
  }

  Future<void> _submitProvisioning() async {
    if (_isSubmitting) return;

    final drafts = <ProvisionStudentDraft>[];
    if (_tabController.index == 0) {
      if (!(_singleFormKey.currentState?.validate() ?? false)) return;
      final nameErr =
          AppValidators.validateRequired(_singleNameCtrl.text, 'اسم المتدرب');
      if (nameErr != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(nameErr)));
        return;
      }
      final emailErr = AppValidators.validateEmail(_singleEmailCtrl.text);
      if (emailErr != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(emailErr)));
        return;
      }
      final passErr = AppValidators.validatePassword(_singlePasswordCtrl.text);
      if (passErr != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(passErr)));
        return;
      }
      if (_singlePhoneCtrl.text.trim().isNotEmpty) {
        final phoneErr =
            AppValidators.validateEgyptianPhone(_singlePhoneCtrl.text);
        if (phoneErr != null) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(phoneErr)));
          return;
        }
      }

      drafts.add(
        ProvisionStudentDraft(
          name: _singleNameCtrl.text.trim(),
          email: _singleEmailCtrl.text.trim(),
          password: _singlePasswordCtrl.text.trim(),
          phone: AppValidators.cleanEgyptianPhone(_singlePhoneCtrl.text),
        ),
      );
    } else {
      for (final row in _bulkRows) {
        if (row.name.text.trim().isEmpty && row.email.text.trim().isEmpty) {
          continue;
        }
        final emailErr = AppValidators.validateEmail(row.email.text);
        if (emailErr != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ في سطر "${row.name.text}": $emailErr')),
          );
          return;
        }
        drafts.add(
          ProvisionStudentDraft(
            name: row.name.text.trim(),
            email: row.email.text.trim(),
            password: row.password.text.trim(),
          ),
        );
      }
    }

    if (drafts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال بيانات متدرب واحد على الأقل.'),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _completedCount = 0;
      _totalCount = drafts.length;
    });

    final outcomes = await _provisioningService.provisionStudents(
      drafts: drafts,
      courseIds: _selectedCourseIds.toList(),
      onProgress: (done, total) {
        if (mounted) {
          setState(() {
            _completedCount = done;
            _totalCount = total;
          });
        }
      },
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    final unlockedCourses = widget.availableCourses
        .where((c) => _selectedCourseIds.contains(c.id))
        .toList();

    context.read<AdminStudentsCubit>().loadStudents();
    context.read<AdminCoursesCubit>().loadCourses();

    final nav = Navigator.of(context);
    final rootCtx = nav.context;
    nav.pop();
    if (!rootCtx.mounted) return;
    await ProvisionedCredentialsDialog.show(
      rootCtx,
      outcomes: outcomes,
      unlockedCourses: unlockedCourses,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 14, 20, bottomInset + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.accentCobaltLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  PhosphorIconsRegular.userPlus,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'إضافة متدربين وتفعيل الكورسات',
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'إنشاء بريد وكلمة مرور ومنح صلاحية الدورات مباشرة',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(PhosphorIconsRegular.x, size: 20),
                onPressed: _isSubmitting ? null : () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surfaceLevel0,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderHairline),
            ),
            child: TabBar(
              controller: _tabController,
              dividerColor: Colors.transparent,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(9),
                boxShadow: AppColors.cardShadow,
              ),
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                fontFamily: 'Cairo',
              ),
              onTap: (_) => setState(() {}),
              tabs: const [
                Tab(height: 38, text: 'متدرب واحد'),
                Tab(height: 38, text: 'مجموعة متدربين دفعة واحدة'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_tabController.index == 0)
                    SingleStudentProvisionForm(
                      formKey: _singleFormKey,
                      nameController: _singleNameCtrl,
                      emailController: _singleEmailCtrl,
                      passwordController: _singlePasswordCtrl,
                      phoneController: _singlePhoneCtrl,
                    )
                  else
                    BulkStudentsProvisionEditor(
                      bulkRows: _bulkRows,
                      isSubmitting: _isSubmitting,
                      onAddRow: () =>
                          setState(() => _bulkRows.add(BulkRowControllers())),
                      onRemoveRow: (index) {
                        setState(() {
                          final removed = _bulkRows.removeAt(index);
                          removed.dispose();
                        });
                      },
                      onQuickPaste: _openQuickPasteDialog,
                    ),
                  const SizedBox(height: 16),
                  CourseAccessSelectorBox(
                    courses: widget.availableCourses,
                    selectedCourseIds: _selectedCourseIds,
                    onToggleCourse: _toggleCourse,
                    onToggleAll: _toggleAllCourses,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ProvisionProgressIndicatorButton(
            isSubmitting: _isSubmitting,
            completedCount: _completedCount,
            totalCount: _totalCount,
            activeTabIndex: _tabController.index,
            onSubmit: _submitProvisioning,
          ),
        ],
      ),
    );
  }
}
