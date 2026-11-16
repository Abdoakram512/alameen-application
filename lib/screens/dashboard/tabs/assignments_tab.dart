import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/feedback/app_loading_indicator.dart';
import '../../../logic/courses/admin_courses_cubit.dart';
import '../../../models/assignment_submission.dart';
import '../../../services/firestore_service.dart';
import 'analytics_widgets/grade_submission_dialog.dart';
import 'assignments_widgets/assignment_submission_card.dart';
import 'assignments_widgets/assignments_filter_header.dart';
import 'assignments_widgets/empty_assignments_view.dart';

/// مركز تصحيح ومراجعة تسليمات المتدربين ورصد الدرجات
class AssignmentsTab extends StatefulWidget {
  final VoidCallback? onBackToHome;

  const AssignmentsTab({super.key, this.onBackToHome});

  @override
  State<AssignmentsTab> createState() => _AssignmentsTabState();
}

class _AssignmentsTabState extends State<AssignmentsTab> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedCourseId;
  String _statusFilter = 'all'; // 'all' | 'pending' | 'graded'
  late final Stream<List<AssignmentSubmission>> _submissionsStream;

  @override
  void initState() {
    super.initState();
    _submissionsStream = FirestoreService().streamAllSubmissions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Directionality.of(context) == TextDirection.rtl;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildAppBarHeader(isAr),

            // Content Streams
            Expanded(
              child: Builder(
                builder: (context) {
                  final courses =
                      context.watch<AdminCoursesCubit>().state.courses;
                  final courseTitles = <String, String>{
                    for (final c in courses) c.id: c.title,
                  };

                  return StreamBuilder<List<AssignmentSubmission>>(
                    stream: _submissionsStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const AppLoadingIndicator(
                          message: 'جاري تحميل تسليمات المتدربين...',
                        );
                      }

                      final allSubmissions = snapshot.data ?? [];
                      if (allSubmissions.isEmpty) {
                        return EmptyAssignmentsView(isAr: isAr);
                      }

                      // Apply Filters
                      final filtered = allSubmissions.where((sub) {
                        final query = _searchQuery.toLowerCase().trim();
                        final matchQuery = query.isEmpty ||
                            sub.studentName.toLowerCase().contains(query) ||
                            sub.studentEmail.toLowerCase().contains(query) ||
                            sub.assignmentTitle.toLowerCase().contains(query);

                        final matchCourse = _selectedCourseId == null ||
                            sub.courseId == _selectedCourseId;

                        final matchStatus = _statusFilter == 'all' ||
                            (_statusFilter == 'pending' && !sub.isGraded) ||
                            (_statusFilter == 'graded' && sub.isGraded);

                        return matchQuery && matchCourse && matchStatus;
                      }).toList();

                      return Column(
                        children: [
                          AssignmentsFilterHeader(
                            isAr: isAr,
                            searchController: _searchController,
                            searchQuery: _searchQuery,
                            onSearchChanged: (val) =>
                                setState(() => _searchQuery = val),
                            onClearSearch: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                            courses: courses,
                            selectedCourseId: _selectedCourseId,
                            onCourseChanged: (val) =>
                                setState(() => _selectedCourseId = val),
                            statusFilter: _statusFilter,
                            onStatusChanged: (val) =>
                                setState(() => _statusFilter = val),
                            allSubmissions: allSubmissions,
                          ),
                          Expanded(
                            child: filtered.isEmpty
                                ? EmptyAssignmentsView(
                                    isAr: isAr,
                                    isFilterEmpty: true,
                                  )
                                : ListView.separated(
                                    padding: const EdgeInsets.all(16),
                                    itemCount: filtered.length,
                                    separatorBuilder: (_, index) =>
                                        const SizedBox(height: 12),
                                    itemBuilder: (context, index) {
                                      final sub = filtered[index];
                                      final cTitle =
                                          courseTitles[sub.courseId] ??
                                              'دورة تدريبية';
                                      return AssignmentSubmissionCard(
                                        submission: sub,
                                        courseTitle: cTitle,
                                        isAr: isAr,
                                        onGrade: () =>
                                            GradeSubmissionDialog.show(
                                          context,
                                          submission: sub,
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBarHeader(bool isAr) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AppColors.borderHairline),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              PhosphorIconsFill.checkCircle,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAr
                      ? 'مركز تصحيح ومراجعة تسليمات المتدربين'
                      : 'Submissions Review & Grading Center',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isAr
                      ? 'مراجعة المهام التطبيقية المرفوعة ورصد درجات المتدربين والملاحظات'
                      : 'Grade practical submissions, record scores, and send feedback',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
