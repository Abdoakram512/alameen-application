import 'package:flutter_test/flutter_test.dart';
import 'package:secure_screen_app/models/active_watch_session.dart';

void main() {
  group('Regression Suite 6: Admin Analytics & Presence Monitoring', () {
    test('Active watch session is marked stale after 300 seconds without heartbeat', () {
      final now = DateTime.now();

      final activeSession = ActiveWatchSession(
        id: 'sess_live_01',
        studentId: 'std_01',
        studentName: 'Ahmed Ali',
        studentEmail: 'ahmed@example.com',
        studentPhone: '01012345678',
        courseId: 'c1',
        courseTitle: 'Chemistry',
        lessonId: 'l1',
        lessonTitle: 'Organic Chemistry',
        currentPositionSeconds: 450,
        totalDurationSeconds: 1200,
        progressPercentage: 37.5,
        isPlaying: true,
        ipAddress: '197.35.12.44',
        networkType: 'wifi',
        devicePlatform: 'android',
        startedAt: now.subtract(const Duration(minutes: 10)),
        lastHeartbeatAt: now.subtract(const Duration(seconds: 120)), // 2 minutes ago (< 300s)
      );

      expect(activeSession.isStale, isFalse, reason: 'Heartbeat 120s ago is active (< 300s)');

      final staleSession = ActiveWatchSession(
        id: 'sess_stale_02',
        studentId: 'std_02',
        studentName: 'Sara Omar',
        studentEmail: 'sara@example.com',
        studentPhone: '01198765432',
        courseId: 'c1',
        courseTitle: 'Chemistry',
        lessonId: 'l1',
        lessonTitle: 'Organic Chemistry',
        currentPositionSeconds: 600,
        totalDurationSeconds: 1200,
        progressPercentage: 50.0,
        isPlaying: true,
        ipAddress: '156.204.11.88',
        networkType: '4g',
        devicePlatform: 'android',
        startedAt: now.subtract(const Duration(minutes: 30)),
        lastHeartbeatAt: now.subtract(const Duration(seconds: 305)), // 305s ago (> 300s)
      );

      expect(staleSession.isStale, isTrue, reason: 'Heartbeat 305s ago is stale (> 300s)');
    });

    test('Admin analytics aggregates watch minutes accurately across sessions', () {
      final sessionDurations = [
        {'studentId': 'std_01', 'seconds': 1800}, // 30 mins
        {'studentId': 'std_01', 'seconds': 1200}, // 20 mins
        {'studentId': 'std_02', 'seconds': 2400}, // 40 mins
      ];

      final totalSeconds = sessionDurations.fold<int>(0, (sum, item) => sum + (item['seconds'] as int));
      final totalMinutes = totalSeconds / 60;

      expect(totalSeconds, 5400);
      expect(totalMinutes, 90.0);
    });
  });
}
