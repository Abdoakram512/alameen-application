import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/student_avatar.dart';
import '../../../logic/courses/admin_courses_cubit.dart';
import '../../../logic/students/admin_students_cubit.dart';
import '../../../logic/students/admin_students_state.dart';
import '../../../models/course.dart';
import '../../../models/course_access_mode.dart';
import '../../../models/registered_student.dart';

/// حوار مخصص لتعيين طلاب لكورس محدد (سواء كورس مخصص لطلاب معينين أو لتسجيل مجموعة دفعة واحدة).
class AssignStudentsDialog extends StatefulWidget {
  final Course course;

  const AssignStudentsDialog({super.key, required this.course});

  static Future<void> show(BuildContext context, {required Course course}) {
    return showDialog(
      context: context,
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: context.read<AdminCoursesCubit>()),
          BlocProvider.value(value: context.read<AdminStudentsCubit>()),
        ],
        child: AssignStudentsDialog(course: course),
      ),
    );
  }

  @override
  State<AssignStudentsDialog> createState() => _AssignStudentsDialogState();
}

enum _StudentFilter { all, assigned, unassigned }

class _AssignStudentsDialogState extends State<AssignStudentsDialog> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedStudentIds = <String>{};
  final Set<String> _initialAssignedIds = <String>{};
  _StudentFilter _filter = _StudentFilter.all;
  bool _initialized = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _initSelections(List<RegisteredStudent> allStudents) {
    if (_initialized) return;
    _initialized = true;

    // A student is considered assigned if enrolled or in course.allowedStudentIds
    for (final s in allStudents) {
      if (s.isEnrolled(widget.course.id) ||
          widget.course.allowedStudentIds.contains(s.id)) {
        _selectedStudentIds.add(s.id);
        _initialAssignedIds.add(s.id);
      }
    }
  }

  List<RegisteredStudent> _filterStudents(List<RegisteredStudent> students) {
    final query = _searchController.text.trim().toLowerCase();
    return students.where((student) {
      final isCurrentlySelected = _selectedStudentIds.contains(student.id);

      if (_filter == _StudentFilter.assigned && !isCurrentlySelected) {
        return false;
      }
      if (_filter == _StudentFilter.unassigned && isCurrentlySelected) {
        return false;
      }

      if (query.isEmpty) return true;
      final name = student.name.toLowerCase();
      final email = student.email.toLowerCase();
      final phone = student.phone.toLowerCase();
      return name.contains(query) ||
          email.contains(query) ||
          phone.contains(query);
    }).toList();
  }

  Future<void> _saveChanges() async {
    if (_isSaving) return;

    final addedIds = _selectedStudentIds
        .difference(_initialAssignedIds)
        .toList();
    final removedIds = _initialAssignedIds
        .difference(_selectedStudentIds)
        .toList();

    if (addedIds.isEmpty && removedIds.isEmpty) {
      Navigator.pop(context);
      return;
    }

    setState(() => _isSaving = true);
    final cubit = context.read<AdminCoursesCubit>();

    bool success = true;
    if (addedIds.isNotEmpty) {
      final ok = await cubit.assignStudents(
        courseId: widget.course.id,
        studentIds: addedIds,
        grant: true,
      );
      if (!ok) success = false;
    }

    if (removedIds.isNotEmpty && success) {
      final ok = await cubit.assignStudents(
        courseId: widget.course.id,
        studentIds: removedIds,
        grant: false,
      );
      if (!ok) success = false;
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم تحديث طلاب كورس "${widget.course.title}" بنجاح (+${addedIds.length} / -${removedIds.length})',
          ),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = context.locale.languageCode == 'ar';

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: BlocBuilder<AdminStudentsCubit, AdminStudentsState>(
            builder: (context, state) {
              if (state is AdminStudentsLoading && !_initialized) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              final allStudents = state is AdminStudentsLoaded
                  ? state.students
                  : state is AdminStudentsError
                  ? state.students
                  : <RegisteredStudent>[];

              _initSelections(allStudents);
              final filtered = _filterStudents(allStudents);

              final addedCount = _selectedStudentIds
                  .difference(_initialAssignedIds)
                  .length;
              final removedCount = _initialAssignedIds
                  .difference(_selectedStudentIds)
                  .length;

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.royalNavy.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          PhosphorIconsRegular.usersThree,
                          color: AppColors.royalNavy,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isAr ? 'تعيين الطلاب للكورس' : 'Assign Students',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.course.title,
                              maxLines: 1,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.royalNavy,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Access Mode Notice
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: widget.course.accessMode.badgeBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: widget.course.accessMode.badgeBorder,
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          widget.course.accessMode.icon,
                          size: 15,
                          color: widget.course.accessMode.badgeFg,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.course.accessMode ==
                                    CourseAccessMode.assignedOnly
                                ? 'هذا الكورس بنمط "تعيين محدد": الطلاب المختارون فقط هم من يستطيعون رؤيته وفتحه.'
                                : 'حالة الكورس حالياً: "${widget.course.accessMode.labelAr}". تعيين الطالب هنا يمنحه اشتراكاً فورياً.',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: widget.course.accessMode.badgeFg,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Search Field
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: isAr
                          ? 'بحث بالاسم أو البريد أو الهاتف...'
                          : 'Search by name, email, or phone...',
                      hintStyle: const TextStyle(fontSize: 13),
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: AppColors.borderHairline,
                        ),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 10),

                  // Filter Chips & Select All Controls
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ChoiceChip(
                        label: Text(
                          'الكل (${allStudents.length})',
                          style: const TextStyle(fontSize: 11),
                        ),
                        selected: _filter == _StudentFilter.all,
                        onSelected: (_) =>
                            setState(() => _filter = _StudentFilter.all),
                      ),
                      ChoiceChip(
                        label: Text(
                          'المعينين (${_selectedStudentIds.length})',
                          style: const TextStyle(fontSize: 11),
                        ),
                        selected: _filter == _StudentFilter.assigned,
                        onSelected: (_) =>
                            setState(() => _filter = _StudentFilter.assigned),
                      ),
                      ChoiceChip(
                        label: Text(
                          'غير المعينين (${allStudents.length - _selectedStudentIds.length})',
                          style: const TextStyle(fontSize: 11),
                        ),
                        selected: _filter == _StudentFilter.unassigned,
                        onSelected: (_) =>
                            setState(() => _filter = _StudentFilter.unassigned),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.select_all_rounded, size: 16),
                        label: Text(
                          filtered.every(
                                (s) => _selectedStudentIds.contains(s.id),
                              )
                              ? 'إلغاء المفلتر'
                              : 'تحديد المفلتر',
                          style: const TextStyle(fontSize: 11),
                        ),
                        onPressed: filtered.isEmpty
                            ? null
                            : () {
                                final allFilteredSelected = filtered.every(
                                  (s) => _selectedStudentIds.contains(s.id),
                                );
                                setState(() {
                                  if (allFilteredSelected) {
                                    for (final s in filtered) {
                                      _selectedStudentIds.remove(s.id);
                                    }
                                  } else {
                                    for (final s in filtered) {
                                      _selectedStudentIds.add(s.id);
                                    }
                                  }
                                });
                              },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1, color: AppColors.divider),

                  // Students List
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                isAr
                                    ? 'لا يوجد طلاب مطابقين للبحث'
                                    : 'No students matching search',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 4),
                            itemBuilder: (context, index) {
                              final student = filtered[index];
                              final isSelected = _selectedStudentIds.contains(
                                student.id,
                              );
                              final wasInitial = _initialAssignedIds.contains(
                                student.id,
                              );

                              return Container(
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.royalNavy.withValues(
                                          alpha: 0.04,
                                        )
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.royalNavy.withValues(
                                            alpha: 0.2,
                                          )
                                        : Colors.transparent,
                                  ),
                                ),
                                child: CheckboxListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  value: isSelected,
                                  activeColor: AppColors.royalNavy,
                                  onChanged: (val) {
                                    setState(() {
                                      if (val == true) {
                                        _selectedStudentIds.add(student.id);
                                      } else {
                                        _selectedStudentIds.remove(student.id);
                                      }
                                    });
                                  },
                                  secondary: StudentAvatar(
                                    photoUrl: student.avatarUrl,
                                    name: student.name.isNotEmpty
                                        ? student.name
                                        : (student.email.isNotEmpty
                                              ? student.email
                                              : 'طالب'),
                                    radius: 18,
                                  ),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          student.name.isNotEmpty
                                              ? student.name
                                              : (student.email.isNotEmpty
                                                    ? student.email
                                                    : 'طالب بدون اسم'),
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      if (wasInitial && !isSelected)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.errorLight,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: const Text(
                                            'سيتم الإلغاء',
                                            style: TextStyle(
                                              color: AppColors.error,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        )
                                      else if (!wasInitial && isSelected)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.successLight,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: const Text(
                                            'تعيين جديد',
                                            style: TextStyle(
                                              color: AppColors.successDark,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  subtitle: Text(
                                    [
                                      if (student.phone.isNotEmpty)
                                        student.phone,
                                      if (student.email.isNotEmpty)
                                        student.email,
                                    ].join(' • '),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),

                  const SizedBox(height: 12),
                  const Divider(height: 1, color: AppColors.divider),
                  const SizedBox(height: 12),

                  // Bottom Action Bar
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // Status count summary
                      Text(
                        'المعينين: ${_selectedStudentIds.length} طالب'
                        '${addedCount > 0 ? " (+$addedCount)" : ""}'
                        '${removedCount > 0 ? " (-$removedCount)" : ""}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: _isSaving
                                ? null
                                : () => Navigator.pop(context),
                            child: Text('dialogs.cancel'.tr()),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.royalNavy,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: _isSaving ? null : _saveChanges,
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.check_rounded, size: 18),
                            label: Text(
                              _isSaving
                                  ? (isAr ? 'جاري الحفظ...' : 'Saving...')
                                  : 'حفظ التعيينات',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
