import 'package:flutter/material.dart';
import '../../models/lesson.dart';

class LessonPlaylist extends StatelessWidget {
  final List<Lesson> lessons;
  final String selectedId;
  final bool enrolled;
  final Set<String> completedIds;
  final ValueChanged<Lesson> onSelected;
  const LessonPlaylist({
    super.key,
    required this.lessons,
    required this.selectedId,
    required this.enrolled,
    required this.completedIds,
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
        final unlocked = enrolled || lesson.isFreePreview;
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
            !unlocked
                ? Icons.lock_outline
                : completedIds.contains(lesson.id)
                ? Icons.check_circle_outline
                : selected
                ? Icons.play_circle
                : Icons.play_circle_outline,
          ),
          title: Text(lesson.title),
          subtitle: Text(
            !unlocked
                ? 'يتطلب الاشتراك في الكورس'
                : selected
                ? 'تشاهد الآن'
                : lesson.duration,
          ),
          trailing: selected ? null : const Icon(Icons.chevron_left),
          enabled: unlocked,
          onTap: !unlocked || selected ? null : () => onSelected(lesson),
        );
      }),
    ],
  );
}
