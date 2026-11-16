import 'package:flutter/material.dart';
import '../../models/lesson.dart';

class LessonPlaylist extends StatelessWidget {
  final List<Lesson> lessons;
  final String selectedId;
  final bool enrolled;
  final Set<String> completedIds;
  final Map<String, String> lockedReasons;
  final ValueChanged<Lesson> onSelected;

  const LessonPlaylist({
    super.key,
    required this.lessons,
    required this.selectedId,
    required this.enrolled,
    required this.completedIds,
    this.lockedReasons = const {},
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'محتوى الكورس · ${lessons.length} درس',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 12),
      ...lessons.map((lesson) {
        final isLockedByAssignment = lockedReasons.containsKey(lesson.id);
        final isUnavailable = !lesson.isAvailableNow;
        final unlocked = (enrolled || lesson.isFreePreview) &&
            !isLockedByAssignment &&
            !isUnavailable;
        final selected = selectedId == lesson.id;
        return ListTile(
          key: ValueKey('playlist-${lesson.id}'),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 4,
          ),
          selected: selected,
          selectedTileColor: const Color(0xFFEAF1FB),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          leading: Icon(
            isUnavailable
                ? (lesson.isScheduled
                    ? Icons.access_time_rounded
                    : Icons.lock_outline)
                : isLockedByAssignment
                    ? Icons.lock_clock_rounded
                    : !unlocked
                        ? Icons.lock_outline
                        : completedIds.contains(lesson.id)
                            ? Icons.check_circle_outline
                            : selected
                                ? Icons.play_circle
                                : Icons.play_circle_outline,
            color: isUnavailable && lesson.isScheduled
                ? const Color(0xFF6B21A8)
                : isLockedByAssignment
                    ? const Color(0xFFB45309)
                    : null,
          ),
          title: Text(lesson.title),
          subtitle: Text(
            isUnavailable
                ? (lesson.isScheduled
                    ? 'محاضرة مجدولة: ${lesson.scheduledPublishAt!.month}/${lesson.scheduledPublishAt!.day} ${lesson.scheduledPublishAt!.hour.toString().padLeft(2, '0')}:${lesson.scheduledPublishAt!.minute.toString().padLeft(2, '0')}'
                    : 'المحاضرة غير متاحة حالياً')
                : isLockedByAssignment
                    ? 'مغلق: يتطلب تسليم تكليف (${lockedReasons[lesson.id]})'
                    : !unlocked
                        ? 'يتطلب الاشتراك في الكورس'
                        : selected
                            ? 'تشاهد الآن'
                            : lesson.duration,
            style: TextStyle(
              color: isUnavailable && lesson.isScheduled
                  ? const Color(0xFF6B21A8)
                  : isLockedByAssignment
                      ? const Color(0xFFB45309)
                      : null,
              fontSize: 12,
            ),
          ),
          trailing: selected ? null : const Icon(Icons.chevron_left),
          enabled: unlocked,
          onTap: !unlocked || selected ? null : () => onSelected(lesson),
        );
      }),
    ],
  );
}
