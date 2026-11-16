import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/feedback/app_empty_state.dart';
import '../../../core/widgets/feedback/app_loading_indicator.dart';
import '../../../core/widgets/student_avatar.dart';
import '../../../logic/courses/admin_courses_cubit.dart';
import '../../../models/assignment_submission.dart';
import '../../../models/course.dart';
import '../../../services/firestore_service.dart';

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
            Container(
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
            ),

            // Content Streams
            Expanded(
              child: Builder(
                builder: (context) {
                  final courses = context.watch<AdminCoursesCubit>().state.courses;
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
                        return Center(
                          child: AppEmptyState(
                            title: isAr
                                ? 'لا توجد تسليمات حتى الآن'
                                : 'No Submissions Yet',
                            subtitle: isAr
                                ? 'سوف تظهر هنا تسليمات المتدربين ومرفقاتهم فور إرسالها من التطبيق.'
                                : 'Student practical submissions will appear here once sent.',
                            icon: PhosphorIconsRegular.tray,
                          ),
                        );
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
                          _buildFilterHeader(isAr, courses, allSubmissions),
                          Expanded(
                            child: filtered.isEmpty
                                ? Center(
                                    child: Text(
                                      isAr
                                          ? 'لا توجد تسليمات مطابقة للفلتر المحدد'
                                          : 'No matching submissions found',
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
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
                                      return _buildSubmissionCard(
                                        sub,
                                        cTitle,
                                        isAr,
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

  Widget _buildFilterHeader(
    bool isAr,
    List<Course> courses,
    List<AssignmentSubmission> allSubmissions,
  ) {
    final pendingCount = allSubmissions.where((s) => !s.isGraded).length;
    final gradedCount = allSubmissions.where((s) => s.isGraded).length;
    final gradedList = allSubmissions
        .where((s) => s.isGraded && s.score != null)
        .toList();
    final avgScore = gradedList.isEmpty
        ? 0
        : (gradedList.map((s) => s.score!).reduce((a, b) => a + b) /
                gradedList.length)
            .round();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: isAr
                        ? 'ابحث باسم المتدرب، البريد، أو التكليف...'
                        : 'Search by student name, email, or task...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: AppColors.borderHairline),
                    ),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),
              const SizedBox(width: 12),
              // Course filter dropdown
              DropdownButton<String?>(
                value: _selectedCourseId,
                hint: Text(
                  isAr ? 'جميع الكورسات' : 'All Courses',
                  style: const TextStyle(fontSize: 13),
                ),
                underline: const SizedBox.shrink(),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(
                      isAr ? 'جميع الكورسات' : 'All Courses',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  ...courses.map(
                    (c) => DropdownMenuItem<String?>(
                      value: c.id,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 180),
                        child: Text(
                          c.title,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                  ),
                ],
                onChanged: (val) => setState(() => _selectedCourseId = val),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Status Chips Filter
          Row(
            children: [
              _buildFilterChip(
                label: isAr
                    ? 'الكل (${allSubmissions.length})'
                    : 'All (${allSubmissions.length})',
                isSelected: _statusFilter == 'all',
                onSelected: () => setState(() => _statusFilter = 'all'),
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                label: isAr
                    ? 'قيد المراجعة ($pendingCount)'
                    : 'Pending ($pendingCount)',
                isSelected: _statusFilter == 'pending',
                onSelected: () => setState(() => _statusFilter = 'pending'),
                color: AppColors.warning,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                label: isAr
                    ? 'تم التقييم ($gradedCount)'
                    : 'Graded ($gradedCount)',
                isSelected: _statusFilter == 'graded',
                onSelected: () => setState(() => _statusFilter = 'graded'),
                color: AppColors.success,
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isAr ? 'متوسط الدرجات: $avgScore%' : 'Avg Score: $avgScore%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
    Color color = AppColors.primary,
  }) {
    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : color.withValues(alpha: 0.2),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : color,
          ),
        ),
      ),
    );
  }

  Widget _buildSubmissionCard(
    AssignmentSubmission sub,
    String courseTitle,
    bool isAr,
  ) {
    final dateFormat = DateFormat('yyyy/MM/dd - hh:mm a');
    final formattedDate = dateFormat.format(sub.submittedAt);
    final hasAttachment = sub.attachmentUrl.trim().isNotEmpty;
    final isGraded = sub.isGraded;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGraded ? AppColors.borderHairline : AppColors.warningBorder,
          width: isGraded ? 1 : 1.5,
        ),
        boxShadow: AppColors.cardShadow,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Student Info Row & Status Badge
          Row(
            children: [
              StudentAvatar(
                name: sub.studentName,
                radius: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sub.studentName.isNotEmpty
                          ? sub.studentName
                          : (isAr ? 'متدرب' : 'Student'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (sub.studentEmail.isNotEmpty)
                      Text(
                        sub.studentEmail,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              // Status Badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isGraded
                      ? AppColors.successLight
                      : AppColors.warningLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isGraded
                        ? AppColors.successBorder
                        : AppColors.warningBorder,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isGraded
                          ? PhosphorIconsFill.sealCheck
                          : PhosphorIconsFill.hourglassMedium,
                      color: isGraded
                          ? AppColors.successDark
                          : AppColors.warningDark,
                      size: 14,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isGraded
                          ? '${sub.score ?? 0} / ${sub.maxScore}'
                          : (isAr ? 'قيد المراجعة' : 'Pending'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isGraded
                            ? AppColors.successDark
                            : AppColors.warningDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 20, color: AppColors.borderHairline),

          // Course and Task Info
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceLevel0,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderHairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      PhosphorIconsRegular.graduationCap,
                      size: 15,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        courseTitle,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    Text(
                      formattedDate,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      PhosphorIconsRegular.bookmarkSimple,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${isAr ? "التكليف: " : "Task: "}${sub.assignmentTitle.isNotEmpty ? sub.assignmentTitle : (isAr ? "مهمة تدريبية" : "Assignment")}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Student Solution Text
          if (sub.solutionText.trim().isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderHairline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isAr
                            ? 'إجابة وحل المتدرب:'
                            : 'Student Submission Text:',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        tooltip: isAr ? 'نسخ النص' : 'Copy',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: sub.solutionText),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content:
                                  Text(isAr ? 'تم نسخ نص الإجابة' : 'Copied'),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    sub.solutionText,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Attachment Button
          if (hasAttachment) ...[
            SizedBox(
              height: 38,
              child: OutlinedButton.icon(
                icon: const Icon(PhosphorIconsRegular.paperclip, size: 16),
                label: Text(
                  isAr ? 'معاينة المرفق أو الملف' : 'View Attachment',
                  style: const TextStyle(fontSize: 12.5),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () async {
                  final uri = Uri.tryParse(sub.attachmentUrl);
                  if (uri != null) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Admin Evaluation & Feedback Box (if already graded)
          if (isGraded || sub.adminFeedback.trim().isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        PhosphorIconsFill.star,
                        size: 16,
                        color: Color(0xFF15803D),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${isAr ? "الدرجة المرصودة: " : "Score: "}${sub.score ?? 0} / ${sub.maxScore}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF15803D),
                        ),
                      ),
                    ],
                  ),
                  if (sub.adminFeedback.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      '${isAr ? "ملاحظة التوجيه: " : "Feedback: "}${sub.adminFeedback}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF166534),
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Grade / Evaluate Action Button
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor:
                    isGraded ? AppColors.secondary : AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: Icon(
                isGraded
                    ? PhosphorIconsRegular.pencilSimple
                    : PhosphorIconsRegular.checkCircle,
                size: 16,
              ),
              label: Text(
                isGraded
                    ? (isAr ? 'تعديل الدرجة والتقييم' : 'Update Grade')
                    : (isAr ? 'تصحيح ورصد الدرجة' : 'Grade Submission'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () => _openGradingDialog(sub, isAr),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openGradingDialog(
    AssignmentSubmission sub,
    bool isAr,
  ) async {
    final scoreCtrl = TextEditingController(
      text: sub.score != null ? sub.score.toString() : '',
    );
    final feedbackCtrl = TextEditingController(text: sub.adminFeedback);
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(PhosphorIconsRegular.exam, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              isAr
                  ? 'رصد الدرجة لـ ${sub.studentName}'
                  : 'Grade ${sub.studentName}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isAr
                    ? 'ستظهر الدرجة وملاحظاتك مباشرة في تطبيق الطالب ضمن ملفه التدريبي.'
                    : 'The score and feedback will appear directly in the student\'s app.',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              // Numeric Score Field
              TextFormField(
                controller: scoreCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: isAr ? 'الدرجة (من 100)' : 'Score (out of 100)',
                  prefixIcon: const Icon(PhosphorIconsRegular.star, size: 18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return isAr ? 'يرجى إدخال الدرجة' : 'Please enter a score';
                  }
                  final numVal = int.tryParse(val.trim());
                  if (numVal == null || numVal < 0 || numVal > 100) {
                    return isAr
                        ? 'الدرجة يجب أن تكون بين 0 و 100'
                        : 'Score must be between 0 and 100';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              // Feedback notes
              TextFormField(
                controller: feedbackCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: isAr
                      ? 'ملاحظات المحاضر وتوجيهاته'
                      : 'Instructor Feedback & Notes',
                  hintText: isAr
                      ? 'أحسنت! إجابة ممتازة مع تطبيق رائع للأسس النظرية...'
                      : 'Great effort! ...',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isAr ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              final score = int.parse(scoreCtrl.text.trim());
              final feedback = feedbackCtrl.text.trim();
              Navigator.pop(ctx);

              await FirestoreService().gradeSubmission(
                submissionId: sub.id,
                score: score,
                adminFeedback: feedback,
              );

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isAr
                          ? 'تم اعتماد الدرجة ($score/100) وإرسالها للمتدرب بنجاح.'
                          : 'Grade recorded successfully.',
                    ),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
            child: Text(isAr ? 'اعتماد الدرجة' : 'Submit Grade'),
          ),
        ],
      ),
    );
  }
}
