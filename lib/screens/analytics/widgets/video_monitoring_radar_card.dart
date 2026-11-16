import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';

import '../../../../core/painters/radar_pulse_painter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/student_avatar.dart';
import '../../../../models/active_watch_session.dart';
import '../../../../models/course.dart';
import '../../../../models/registered_student.dart';
import '../../../../services/firestore_service.dart';

/// كارت رادار المراقبة الحي اللحظي لرصد حضور ومشاهدات الطلاب النشطين الآن.
/// يتميز بتصميم تنفيذي نظيف خالي من الحشو التقني، ويعرض تقدم المشاهدة الحي بالثانية.
class VideoMonitoringRadarCard extends StatefulWidget {
  final List<Course> courses;
  final List<RegisteredStudent> students;

  const VideoMonitoringRadarCard({
    super.key,
    this.courses = const [],
    this.students = const [],
  });

  @override
  State<VideoMonitoringRadarCard> createState() =>
      _VideoMonitoringRadarCardState();
}

class _VideoMonitoringRadarCardState extends State<VideoMonitoringRadarCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Stream<List<ActiveWatchSession>> _sessionsStream;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
    _sessionsStream = FirestoreService().streamActiveWatchSessions();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  RegisteredStudent? _findStudent(String studentId) {
    for (final s in widget.students) {
      if (s.id == studentId) return s;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Directionality.of(context) == TextDirection.rtl;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderHairline),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with Animated Radar Sonar Hub
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.royalNavy, Color(0xFF0F3288)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              children: [
                // Sonar Canvas Widget
                SizedBox(
                  width: 46,
                  height: 46,
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, _) {
                      return CustomPaint(
                        painter: RadarPulsePainter(
                          animationValue: _pulseController.value,
                          baseColor: Colors.white,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'dashboard.live_radar_title'.tr(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2.5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.greenAccent.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.greenAccent.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Colors.greenAccent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isAr ? 'بث حي' : 'LIVE',
                                  style: const TextStyle(
                                    color: Colors.greenAccent,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'dashboard.live_radar_subtitle'.tr(),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Live Active Students Stream Section
          StreamBuilder<List<ActiveWatchSession>>(
            stream: _sessionsStream,
            builder: (context, snapshot) {
              final activeList = snapshot.data ?? [];

              if (activeList.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 28,
                    horizontal: 20,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            color: AppColors.primaryLight,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.radar_rounded,
                            size: 32,
                            color: AppColors.royalNavy,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'dashboard.no_active_viewers'.tr(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isAr
                              ? 'سيرصد الرادار تلقائياً أي متدرب يشاهد محاضرة فور تشغيلها'
                              : 'The radar automatically displays active students as soon as they play a video',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.sensors_rounded,
                            color: AppColors.successDark,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${activeList.length} ${'dashboard.active_viewers_count'.tr()}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: AppColors.successDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: activeList.length,
                      separatorBuilder: (_, index) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final sess = activeList[index];
                        return _buildActiveSessionTile(sess, isAr);
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActiveSessionTile(ActiveWatchSession sess, bool isAr) {
    final student = _findStudent(sess.studentId);
    final displayName = student?.name.isNotEmpty == true
        ? student!.name
        : (sess.studentName.isNotEmpty
              ? sess.studentName
              : (isAr ? 'متدرب' : 'Student'));
    final displayEmail = student?.email ?? '';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLevel0,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StudentAvatar(
                name: displayName,
                photoUrl: student?.avatarUrl,
                radius: 17,
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
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.successLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.successDark,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'يشاهد الآن',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.successDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${sess.courseTitle} • ${sess.lessonTitle}',
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.royalNavy,
            ),
            maxLines: 1,
            overflow: TextOverflow.visible,
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: (sess.progressPercentage / 100.0).clamp(0.0, 1.0),
              backgroundColor: AppColors.borderHairline,
              color: AppColors.royalNavy,
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${sess.currentPositionFormatted} / ${sess.totalDurationFormatted}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                '${sess.progressPercentage.toInt()}%',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.royalNavy,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
