import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/di/injection_container.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_directional_icons.dart';
import '../../logic/auth/auth_cubit.dart';
import '../../logic/auth/auth_state.dart';
import '../../logic/courses/courses_cubit.dart';
import '../../logic/courses/courses_state.dart';
import '../../models/assignment.dart';
import '../../models/assignment_submission.dart';
import '../../models/course.dart';
import '../../models/user_profile.dart';
import '../../repositories/student_learning_repository.dart';
import 'widgets/submit_assignment_sheet.dart';

class StudentAssignmentsScreen extends StatefulWidget {
  const StudentAssignmentsScreen({super.key});

  @override
  State<StudentAssignmentsScreen> createState() =>
      _StudentAssignmentsScreenState();
}

class _StudentAssignmentsScreenState extends State<StudentAssignmentsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  Stream<List<AssignmentSubmission>>? _submissionsStream;
  String? _lastStudentId;

  StudentLearningRepository get _repository =>
      sl.isRegistered<StudentLearningRepository>()
          ? sl<StudentLearningRepository>()
          : StudentLearningRepositoryImpl();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _checkStream(String? uid) {
    if (uid != _lastStudentId && uid != null && uid.isNotEmpty) {
      _lastStudentId = uid;
      _submissionsStream = _repository.streamStudentSubmissions(uid);
    }
  }

  void _openSubmitSheet(
    BuildContext context,
    Assignment assignment,
    UserModel user,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SubmitAssignmentSheet(
        assignment: assignment,
        user: user,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text(
          'التكليفات والتقييمات',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w800,
          ),
          unselectedLabelStyle: AppTextStyles.bodyMedium,
          tabs: const [
            Tab(text: 'الواجبات والتطبيقات'),
            Tab(text: 'المسلّمة والتقييمات'),
          ],
        ),
      ),
      body: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, authState) {
          final currentUser =
              authState is Authenticated ? authState.user : null;
          if (currentUser == null) {
            return const Center(child: Text('يرجى تسجيل الدخول أولاً'));
          }

          _checkStream(currentUser.uid);

          return BlocBuilder<CoursesCubit, CoursesState>(
            builder: (context, coursesState) {
              final allCourses = coursesState is CoursesLoaded
                  ? coursesState.allCourses
                  : const <Course>[];
              final enrolledCourses = allCourses
                  .where((c) =>
                      currentUser.isEnrolled(c.id) ||
                      c.allowedStudentIds.contains(currentUser.uid))
                  .toList();

              return StreamBuilder<List<AssignmentSubmission>>(
                stream: _submissionsStream,
                builder: (context, subSnap) {
                  final submissions =
                      subSnap.data ?? const <AssignmentSubmission>[];
                  final gradedSubs = submissions
                      .where((s) => s.isGraded && s.score != null)
                      .toList();
                  final avgScore = gradedSubs.isEmpty
                      ? 0
                      : (gradedSubs.map((s) => s.score!).reduce((a, b) => a + b) /
                              gradedSubs.length)
                          .round();

                  // تجمع كافة تكليفات الكورسات المشترك بها الطالب
                  final allCourseAssignments = <Assignment>[];
                  for (final c in enrolledCourses) {
                    for (final lvl in c.levels) {
                      for (final lsn in lvl.lessons) {
                        if (lsn.hasAssignment) {
                          allCourseAssignments.add(
                            Assignment(
                              id: lsn.assignmentId ?? 'asg_${lsn.id}',
                              courseId: c.id,
                              courseTitle: c.title,
                              lessonId: lsn.id,
                              title: 'تكليف: ${lsn.title}',
                              instructions: lsn.description,
                              createdAt: DateTime.now(),
                            ),
                          );
                        }
                      }
                    }
                  }

                  final submittedIds =
                      submissions.map((s) => s.assignmentId).toSet();
                  final pendingAssignments = allCourseAssignments
                      .where((a) => !submittedIds.contains(a.id))
                      .toList();

                  final submittedCount = submissions.length;
                  final pendingCount = pendingAssignments.length;

                  return ResponsiveCenter(
                    child: Column(
                      children: [
                        // KPI Summary Header
                        Container(
                          margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.borderHairline),
                            boxShadow: AppColors.cardShadow,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _KpiBox(
                                  title: 'تم تسليمها',
                                  value: '$submittedCount',
                                  icon: AppDirectionalIcons.checkCircle(
                                    color: AppColors.successDark,
                                    size: 18,
                                  ),
                                  color: AppColors.successLight,
                                  textColor: AppColors.successDark,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _KpiBox(
                                  title: 'متبقية',
                                  value: '$pendingCount',
                                  icon: const Icon(
                                    PhosphorIconsRegular.clock,
                                    color: AppColors.warningDark,
                                    size: 18,
                                  ),
                                  color: AppColors.warningLight,
                                  textColor: AppColors.warningDark,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _KpiBox(
                                  title: 'متوسط الدرجات',
                                  value: gradedSubs.isEmpty ? '—' : '$avgScore%',
                                  icon: const Icon(
                                    PhosphorIconsRegular.chartLineUp,
                                    color: AppColors.primary,
                                    size: 18,
                                  ),
                                  color: AppColors.primaryLight,
                                  textColor: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Tab Views
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              // Tab 1: الواجبات والتطبيقات المطلوبة
                              _PendingAssignmentsTab(
                                assignments: pendingAssignments,
                                onOpenSubmit: (asg) => _openSubmitSheet(
                                  context,
                                  asg,
                                  currentUser,
                                ),
                              ),

                              // Tab 2: المسلّمة والتقييمات
                              _SubmissionsHistoryTab(
                                submissions: submissions,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _KpiBox extends StatelessWidget {
  final String title;
  final String value;
  final Widget icon;
  final Color color;
  final Color textColor;

  const _KpiBox({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  title,
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppTextStyles.heading2.copyWith(
              fontWeight: FontWeight.w900,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingAssignmentsTab extends StatelessWidget {
  final List<Assignment> assignments;
  final ValueChanged<Assignment> onOpenSubmit;

  const _PendingAssignmentsTab({
    required this.assignments,
    required this.onOpenSubmit,
  });

  @override
  Widget build(BuildContext context) {
    if (assignments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppDirectionalIcons.checkCircle(
                color: AppColors.success,
                size: 54,
              ),
              const SizedBox(height: 12),
              Text(
                'رائع! لا توجد تكليفات معلقة حالياً',
                style: AppTextStyles.heading3.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'لقد سلمت جميع التطبيقات العملية الخاصة بمحاضراتك حتى الآن.',
                style: AppTextStyles.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: assignments.length,
      separatorBuilder: (ctx, idx) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final asg = assignments[i];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderHairline),
            boxShadow: AppColors.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      PhosphorIconsRegular.clipboardText,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          asg.title,
                          style: AppTextStyles.heading3.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          asg.courseTitle,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (asg.instructions.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(asg.instructions, style: AppTextStyles.bodyMedium),
              ],
              if (asg.hasAttachment) ...[
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.picture_as_pdf_rounded,
                        color: Color(0xFFDC2626),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          asg.pdfAttachmentName ??
                              'ملف ورقة عمل التكليف (PDF)',
                          style: AppTextStyles.bodySmall.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF991B1B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFDC2626),
                          visualDensity: VisualDensity.compact,
                          alignment: Alignment.center,
                        ),
                        icon: const Icon(Icons.download_rounded, size: 16),
                        label: const Text('فتح PDF'),
                        onPressed: () {
                          final uri = Uri.tryParse(asg.attachmentUrl);
                          if (uri != null) {
                            launchUrl(uri,
                                mode: LaunchMode.externalApplication);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    alignment: Alignment.center,
                    backgroundColor: AppColors.primary,
                  ),
                  onPressed: () => onOpenSubmit(asg),
                  icon: const Icon(Icons.upload_file_rounded, size: 18),
                  label: const Text('تسليم إجابة المهمة الآن'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SubmissionsHistoryTab extends StatelessWidget {
  final List<AssignmentSubmission> submissions;

  const _SubmissionsHistoryTab({required this.submissions});

  @override
  Widget build(BuildContext context) {
    if (submissions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                PhosphorIconsRegular.fileText,
                color: AppColors.textMuted,
                size: 54,
              ),
              const SizedBox(height: 12),
              Text(
                'لم تسلم أي تكليفات بعد',
                style: AppTextStyles.heading3.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'عند تسليم المهام العملية، ستظهر هنا درجات التقييم وملاحظات المحاضر بالتفصيل.',
                style: AppTextStyles.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: submissions.length,
      separatorBuilder: (ctx, idx) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final sub = submissions[i];
        final isGraded = sub.isGraded;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderHairline),
            boxShadow: AppColors.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isGraded
                          ? AppColors.successLight
                          : AppColors.warningLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isGraded
                          ? PhosphorIconsFill.checkCircle
                          : PhosphorIconsRegular.clock,
                      color: isGraded
                          ? AppColors.successDark
                          : AppColors.warningDark,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sub.assignmentTitle,
                          style: AppTextStyles.heading3.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'تاريخ التسليم: ${sub.submittedAt.year}/${sub.submittedAt.month.toString().padLeft(2, '0')}/${sub.submittedAt.day.toString().padLeft(2, '0')}',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: isGraded
                          ? AppColors.successLight
                          : AppColors.warningLight,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      isGraded
                          ? '${sub.score ?? 0} / ${sub.maxScore}'
                          : 'قيد المراجعة',
                      style: AppTextStyles.label.copyWith(
                        color: isGraded
                          ? AppColors.successDark
                          : AppColors.warningDark,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              if (sub.solutionText.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLevel2,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'إجابتك المسلّمة:',
                        style: AppTextStyles.caption.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        sub.solutionText,
                        style: AppTextStyles.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
              if (sub.attachmentUrl.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      PhosphorIconsRegular.paperclip,
                      size: 16,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'مرفق الحل:',
                      style: AppTextStyles.caption,
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () {
                        final uri = Uri.tryParse(sub.attachmentUrl);
                        if (uri != null) {
                          launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                      child: Text(
                        'عرض المرفق',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (sub.adminFeedback.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.successLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.successBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            PhosphorIconsRegular.chatCircleText,
                            color: AppColors.successDark,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'تقييم وملاحظات المحاضر:',
                            style: AppTextStyles.caption.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.successDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        sub.adminFeedback,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.successDark,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

