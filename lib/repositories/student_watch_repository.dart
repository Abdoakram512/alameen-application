import '../models/active_watch_session.dart';
import '../models/watch_log_entry.dart';

abstract class StudentWatchRepository {
  Stream<List<WatchLogEntry>> streamStudentWatchLogs(String studentId);
  Future<void> updateActiveWatchSession(ActiveWatchSession session);
  Future<void> removeActiveWatchSession(String sessionId);
  Future<String?> getLatestLessonCoverage({
    required String uid,
    required String courseId,
    required String lessonId,
  });
  Future<void> recordWatchEvent(Map<String, dynamic> event);
  Future<void> toggleLessonCompletion(
    String uid,
    String lessonId,
    bool isCompleted,
  );
}
