import 'dart:async';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/responsive/responsive_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/feedback/app_empty_state.dart';
import '../../../core/widgets/feedback/app_error_state.dart';
import '../../../core/widgets/feedback/app_loading_indicator.dart';
import '../../../logic/courses/admin_courses_cubit.dart';
import '../../../logic/courses/admin_courses_state.dart';
import '../../../logic/students/admin_students_cubit.dart';
import '../../../logic/students/admin_students_state.dart';
import '../../../models/course.dart';
import '../../../models/registered_student.dart';
import '../../../services/firestore_service.dart';
import '../../students/provision_students_sheet.dart';
import '../widgets/student_card_item.dart';
import 'students_widgets/bulk_action_dock.dart';
import 'students_widgets/students_filter_bar.dart';

class StudentsTab extends StatefulWidget {
  const StudentsTab({super.key});

  @override
  State<StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends State<StudentsTab> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _filter = 'all';

  bool _selectionMode = false;
  final Set<String> _selectedStudentIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearSelection() {
    setState(() {
      _selectedStudentIds.clear();
      _selectionMode = false;
    });
  }

  void _selectAll(List<RegisteredStudent> students) {
    setState(() {
      _selectionMode = true;
      _selectedStudentIds.addAll(students.map((s) => s.id));
    });
  }

  Future<void> _handleAssignToCourse(Course course, int validityDays) async {
    final ids = _selectedStudentIds.toList();
    if (ids.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);
    _clearSelection();

    final count = await FirestoreService().assignStudentsToCourse(
      courseId: course.id,
      studentIds: ids,
      grant: true,
    );

    if (validityDays > 0) {
      for (final id in ids) {
        await FirestoreService().extendStudentCourseValidity(
          studentId: id,
          courseId: course.id,
          additionalDays: validityDays,
        );
      }
    }

    if (mounted) {
      unawaited(context.read<AdminStudentsCubit>().loadStudents());
      context.read<AdminCoursesCubit>().loadCourses();
      messenger.showSnackBar(
        SnackBar(
          content: Text('تم إلحاق $count طالباً بدورة "${course.title}" بنجاح.'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _handleRemoveFromCourse(Course course) async {
    final ids = _selectedStudentIds.toList();
    if (ids.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);
    _clearSelection();

    final count = await FirestoreService().assignStudentsToCourse(
      courseId: course.id,
      studentIds: ids,
      grant: false,
    );

    if (mounted) {
      unawaited(context.read<AdminStudentsCubit>().loadStudents());
      context.read<AdminCoursesCubit>().loadCourses();
      messenger.showSnackBar(
        SnackBar(
          content: Text('تم إلغاء تسجيل $count طالباً من دورة "${course.title}".'),
          backgroundColor: AppColors.warningDark,
        ),
      );
    }
  }

  Future<void> _handleExtendValidity(Course course, int days) async {
    final ids = _selectedStudentIds.toList();
    if (ids.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);
    _clearSelection();

    for (final id in ids) {
      await FirestoreService().extendStudentCourseValidity(
        studentId: id,
        courseId: course.id,
        additionalDays: days,
      );
    }

    if (mounted) {
      unawaited(context.read<AdminStudentsCubit>().loadStudents());
      messenger.showSnackBar(
        SnackBar(
          content: Text('تم تمديد الصلاحية بمقدار $days يوماً لـ ${ids.length} طالباً.'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _handleToggleSuspension(bool suspend, String? reason) async {
    final ids = _selectedStudentIds.toList();
    if (ids.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);
    _clearSelection();

    await FirestoreService().bulkSuspendStudents(
      studentIds: ids,
      suspend: suspend,
      reason: reason,
    );

    if (mounted) {
      unawaited(context.read<AdminStudentsCubit>().loadStudents());
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            suspend
                ? 'تم تعليق حسابات ${ids.length} طالباً بنجاح.'
                : 'تم تنشيط حسابات ${ids.length} طالباً بنجاح.',
          ),
          backgroundColor: suspend ? AppColors.warningDark : AppColors.success,
        ),
      );
    }
  }

  Future<void> _handleDeleteSelected() async {
    final ids = _selectedStudentIds.toList();
    if (ids.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الطلاب المحددين نهائياً'),
        content: Text(
          'تحذير شديد: هل أنت متأكد تماماً من حذف حسابات (${ids.length}) طلاب نهائياً من منصة مركز الأمين؟\n\nلا يمكن التراجع عن هذا الإجراء.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد الحذف النهائي'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      _clearSelection();
      await FirestoreService().bulkDeleteStudents(ids);
      if (mounted) {
        unawaited(context.read<AdminStudentsCubit>().loadStudents());
        messenger.showSnackBar(
          SnackBar(
            content: Text('تم حذف ${ids.length} حسابات طلاب نهائياً.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AdminStudentsCubit, AdminStudentsState>(
      builder: (context, studentsState) {
        return BlocBuilder<AdminCoursesCubit, AdminCoursesState>(
          builder: (context, coursesState) {
            final courses = coursesState is AdminCoursesLoaded
                ? coursesState.courses
                : <Course>[];

            if (studentsState is AdminStudentsLoading) {
              return AppLoadingIndicator(
                message: 'students.loading_students'.tr(),
              );
            }

            if (studentsState is AdminStudentsError &&
                studentsState.students.isEmpty) {
              return AppErrorState(
                message: studentsState.message,
                onRetry: context.read<AdminStudentsCubit>().loadStudents,
              );
            }

            final allStudents = studentsState is AdminStudentsLoaded
                ? studentsState.students
                : <RegisteredStudent>[];

            final enrolledCount = allStudents
                .where((s) => s.enrolledCourseIds.isNotEmpty)
                .length;
            final notEnrolledCount = allStudents.length - enrolledCount;

            final filteredStudents = allStudents.where((student) {
              final matchesQuery =
                  _searchQuery.isEmpty ||
                  student.name.toLowerCase().contains(
                    _searchQuery.toLowerCase(),
                  ) ||
                  student.email.toLowerCase().contains(
                    _searchQuery.toLowerCase(),
                  );

              if (!matchesQuery) return false;

              if (_filter == 'enrolled') {
                return student.enrolledCourseIds.isNotEmpty;
              } else if (_filter == 'notEnrolled') {
                return student.enrolledCourseIds.isEmpty;
              }
              return true;
            }).toList();

            return Stack(
              children: [
                RefreshIndicator(
                  color: AppColors.royalNavy,
                  onRefresh: () async {
                    context.read<AdminCoursesCubit>().loadCourses();
                    await context.read<AdminStudentsCubit>().loadStudents();
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.only(
                      top: 16,
                      bottom: _selectedStudentIds.isNotEmpty ? 130 : 88,
                    ),
                    children: [
                      ResponsiveCenter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (studentsState is AdminStudentsError)
                              ListTile(
                                leading: const Icon(Icons.error_outline),
                                title: Text(studentsState.message),
                                trailing: IconButton(
                                  tooltip: 'إعادة المحاولة',
                                  icon: const Icon(Icons.refresh),
                                  onPressed: context
                                      .read<AdminStudentsCubit>()
                                      .loadStudents,
                                ),
                              ),
                            StudentsFilterBar(
                              searchController: _searchController,
                              searchQuery: _searchQuery,
                              selectedFilter: _filter,
                              totalCount: allStudents.length,
                              enrolledCount: enrolledCount,
                              notEnrolledCount: notEnrolledCount,
                              onSearchChanged: (val) =>
                                  setState(() => _searchQuery = val.trim()),
                              onClearSearch: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                              onFilterChanged: (value) =>
                                  setState(() => _filter = value),
                            ),
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.borderHairline),
                                boxShadow: AppColors.cardShadow,
                              ),
                              child: Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 12,
                                runSpacing: 10,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        PhosphorIconsRegular.usersThree,
                                        size: 20,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'students.add_students_banner'.tr(),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13.5,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: _selectionMode
                                              ? AppColors.primary
                                              : AppColors.textSecondary,
                                          side: BorderSide(
                                            color: _selectionMode
                                                ? AppColors.primary
                                                : AppColors.borderHairline,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 9,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _selectionMode = !_selectionMode;
                                            if (!_selectionMode) {
                                              _selectedStudentIds.clear();
                                            }
                                          });
                                        },
                                        icon: Icon(
                                          _selectionMode
                                              ? Icons.close_rounded
                                              : Icons.checklist_rtl_rounded,
                                          size: 16,
                                        ),
                                        label: Text(
                                          _selectionMode
                                              ? 'إلغاء التحديد'
                                              : 'تحديد متعدد',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      FilledButton.icon(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 10,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                        onPressed: () => ProvisionStudentsSheet.show(
                                          context,
                                          availableCourses: courses,
                                        ),
                                        icon: const Icon(
                                          PhosphorIconsRegular.userPlus,
                                          size: 17,
                                        ),
                                        label: Text(
                                          'students.add_students_btn'.tr(),
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (filteredStudents.isEmpty)
                              AppEmptyState(
                                icon: PhosphorIconsRegular.magnifyingGlass,
                                title: _searchQuery.isNotEmpty
                                    ? 'students.no_students_found'.tr(args: [_searchQuery])
                                    : 'students.no_students_category'.tr(),
                                subtitle: 'students.no_students_subtitle'.tr(),
                                actionButtonText: 'students.add_students_btn'.tr(),
                                onActionButtonPressed: () =>
                                    ProvisionStudentsSheet.show(
                                      context,
                                      availableCourses: courses,
                                    ),
                              )
                            else
                              ResponsiveCardGrid(
                                minItemWidth: 380,
                                maxColumns: 2,
                                mainAxisSpacing: 4,
                                children: filteredStudents
                                    .map(
                                      (student) => StudentCardItem(
                                        student: student,
                                        courses: courses,
                                        isSelectionMode: _selectionMode,
                                        isSelected: _selectedStudentIds.contains(student.id),
                                        onSelectChanged: (val) {
                                          setState(() {
                                            if (val == true) {
                                              _selectedStudentIds.add(student.id);
                                            } else {
                                              _selectedStudentIds.remove(student.id);
                                            }
                                          });
                                        },
                                        onLongPress: () {
                                          setState(() {
                                            _selectionMode = true;
                                            _selectedStudentIds.add(student.id);
                                          });
                                        },
                                      ),
                                    )
                                    .toList(),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (_selectedStudentIds.isNotEmpty)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: BulkActionDock(
                      selectedCount: _selectedStudentIds.length,
                      availableCourses: courses,
                      onClearSelection: _clearSelection,
                      onSelectAll: () => _selectAll(filteredStudents),
                      onAssignToCourse: _handleAssignToCourse,
                      onRemoveFromCourse: _handleRemoveFromCourse,
                      onExtendValidity: _handleExtendValidity,
                      onToggleSuspension: _handleToggleSuspension,
                      onDeleteSelected: _handleDeleteSelected,
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
