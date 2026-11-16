import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/painters/watch_progress_arc_painter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/student_avatar.dart';
import '../../../logic/students/admin_students_cubit.dart';
import '../../../logic/students/admin_students_state.dart';
import '../../../models/lesson.dart';
import '../../../models/registered_student.dart';
import '../../../models/watch_log_entry.dart';
import '../../../services/firestore_service.dart';

/// نافذة مخصصة لعرض سجلات حضور ومشاهدات درس معين بدقة،
/// وتتيح معرفة من شاهد ومن لم يشاهد مع إمكانية التذكير عبر واتساب بضغطة واحدة.
class LessonAttendanceSheet extends StatefulWidget {
  final String courseId;
  final Lesson lesson;

  const LessonAttendanceSheet({
    super.key,
    required this.courseId,
    required this.lesson,
  });

  static Future<void> show(
    BuildContext context, {
    required String courseId,
    required Lesson lesson,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 620),
      builder: (_) => BlocProvider.value(
        value: context.read<AdminStudentsCubit>(),
        child: LessonAttendanceSheet(
          courseId: courseId,
          lesson: lesson,
        ),
      ),
    );
  }

  @override
  State<LessonAttendanceSheet> createState() => _LessonAttendanceSheetState();
}

class _LessonAttendanceSheetState extends State<LessonAttendanceSheet> {
  int _tabIndex = 0; // 0: Watched, 1: Unwatched

  Future<void> _launchWhatsApp(String phone, String studentName) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.isEmpty) return;

    final isAr = Directionality.of(context) == TextDirection.rtl;
    final message = isAr
        ? 'أهلاً يا $studentName، تذكير ودي من مركز الأمين للتخاطب بضرورة استكمال مشاهدة محاضرة "${widget.lesson.title}". بالتوفيق دائماً!'
        : 'Hello $studentName, friendly reminder from Al-Ameen Center to complete lecture "${widget.lesson.title}". Best regards!';

    final uri = Uri.parse(
      'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}',
    );
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Directionality.of(context) == TextDirection.rtl;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.analytics_outlined,
                        color: AppColors.royalNavy,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'سجل حضور ومشاهدات المحاضرة',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            widget.lesson.title,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.visible,
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
              ),

              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.borderHairline),

              // Body with Realtime Watch Logs
              Expanded(
                child: BlocBuilder<AdminStudentsCubit, AdminStudentsState>(
                  builder: (context, studentsState) {
                    final allStudents = studentsState is AdminStudentsLoaded
                        ? studentsState.students
                        : <RegisteredStudent>[];

                    // Enrolled students in this specific course
                    final enrolledStudents = allStudents
                        .where((s) => s.isEnrolled(widget.courseId))
                        .toList();

                    return StreamBuilder<List<WatchLogEntry>>(
                      stream: FirestoreService().streamLessonWatchLogs(
                        courseId: widget.courseId,
                        lessonId: widget.lesson.id,
                      ),
                      builder: (context, snapshot) {
                        final logs = snapshot.data ?? [];
                        final watchedStudentIds =
                            logs.map((l) => l.studentId).toSet();

                        final watchedLogs = logs;
                        final unwatchedStudents = enrolledStudents
                            .where((s) => !watchedStudentIds.contains(s.id))
                            .toList();

                        return Column(
                          children: [
                            // Tab Selector
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _buildTabButton(
                                      index: 0,
                                      label: 'حضروا الدرس',
                                      count: watchedLogs.length,
                                      activeColor: AppColors.royalNavy,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _buildTabButton(
                                      index: 1,
                                      label: 'لم يحضروا بعد',
                                      count: unwatchedStudents.length,
                                      activeColor: AppColors.warningDark,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Tab List Content
                            Expanded(
                              child: _tabIndex == 0
                                  ? _buildWatchedList(
                                      watchedLogs,
                                      allStudents,
                                      isAr,
                                    )
                                  : _buildUnwatchedList(
                                      unwatchedStudents,
                                      isAr,
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
      ),
    );
  }

  Widget _buildTabButton({
    required int index,
    required String label,
    required int count,
    required Color activeColor,
  }) {
    final isSelected = _tabIndex == index;
    return InkWell(
      onTap: () => setState(() => _tabIndex = index),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : AppColors.surfaceLevel0,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? activeColor : AppColors.borderHairline,
          ),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.22)
                    : AppColors.borderHairline,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWatchedList(
    List<WatchLogEntry> logs,
    List<RegisteredStudent> allStudents,
    bool isAr,
  ) {
    if (logs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.people_outline_rounded,
                size: 40,
                color: AppColors.textMuted,
              ),
              const SizedBox(height: 10),
              Text(
                isAr
                    ? 'لم يقم أي متدرب بمشاهدة هذا الدرس حتى الآن'
                    : 'No students have watched this lesson yet',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: logs.length,
      separatorBuilder: (_, index) => const SizedBox(height: 8),
      itemBuilder: (context, idx) {
        final log = logs[idx];
        final student = allStudents.cast<RegisteredStudent?>().firstWhere(
              (s) => s?.id == log.studentId,
              orElse: () => null,
            );

        final displayName = student?.name.isNotEmpty == true
            ? student!.name
            : (log.studentName.isNotEmpty ? log.studentName : 'متدرب');
        final displayEmail = student?.email ?? '';
        final studentPhone = student?.phone ?? '';

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceLevel0,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderHairline),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Progress Arc
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: SizedBox(
                  width: 38,
                  height: 38,
                  child: CustomPaint(
                    painter: WatchProgressArcPainter(
                      percentage: log.completionPercentage,
                      isCompleted: log.isCompleted,
                    ),
                    child: Center(
                      child: Text(
                        '${log.completionPercentage.toInt()}%',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Student Avatar
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: StudentAvatar(
                  name: displayName,
                  photoUrl: student?.avatarUrl,
                  radius: 17,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.visible,
                    ),
                    if (displayEmail.isNotEmpty)
                      Text(
                        displayEmail,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.visible,
                      ),
                    const SizedBox(height: 4),
                    Text(
                      'الوقت المسجل: ${log.durationFormatted}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.royalNavy,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (log.isCompleted)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.successLight,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppColors.successBorder,
                      width: 0.8,
                    ),
                  ),
                  child: const Text(
                    'مكتمل',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.successDark,
                    ),
                  ),
                )
              else if (studentPhone.isNotEmpty)
                IconButton(
                  tooltip: 'تذكير واتساب',
                  style: IconButton.styleFrom(
                    backgroundColor:
                        const Color(0xFF25D366).withValues(alpha: 0.12),
                    foregroundColor: const Color(0xFF128C7E),
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(32, 32),
                  ),
                  icon: const Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 16,
                  ),
                  onPressed: () => _launchWhatsApp(studentPhone, displayName),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUnwatchedList(List<RegisteredStudent> students, bool isAr) {
    if (students.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle_outline_rounded,
                size: 40,
                color: AppColors.successDark,
              ),
              const SizedBox(height: 10),
              Text(
                isAr
                    ? '🎉 ممتاز! جميع الطلاب المسجلين شاهدوا هذا الدرس'
                    : '🎉 Great! All enrolled students have watched this lesson',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.successDark,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: students.length,
      separatorBuilder: (_, index) => const SizedBox(height: 8),
      itemBuilder: (context, idx) {
        final student = students[idx];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceLevel0,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderHairline),
          ),
          child: Row(
            children: [
              StudentAvatar(
                name: student.name,
                photoUrl: student.avatarUrl,
                radius: 17,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.visible,
                    ),
                    if (student.email.isNotEmpty)
                      Text(
                        student.email,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.visible,
                      ),
                    if (student.phone.isNotEmpty)
                      Text(
                        student.phone,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (student.phone.isNotEmpty)
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    minimumSize: const Size(0, 32),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () =>
                      _launchWhatsApp(student.phone, student.name),
                  icon: const Icon(Icons.chat_rounded, size: 13),
                  label: const Text(
                    'تذكير',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

