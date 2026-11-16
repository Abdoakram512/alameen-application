import '../models/active_watch_session.dart';
import '../models/watch_log_entry.dart';

abstract class AdminAnalyticsRepository {
  Stream<List<WatchLogEntry>> streamAllWatchLogs({int limit = 50});
  Future<List<WatchLogEntry>> getRecentWatchLogs({int limit = 50});
  Stream<List<WatchLogEntry>> streamStudentWatchLogs(String studentId);
  Stream<List<ActiveWatchSession>> streamActiveWatchSessions({
    String? courseId,
    String? lessonId,
  });
  Stream<List<WatchLogEntry>> streamLessonWatchLogs({
    required String courseId,
    required String lessonId,
  });
}
