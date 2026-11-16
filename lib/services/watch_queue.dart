import 'dart:async';
import 'dart:convert';
import 'dart:math';

/// Serializes durable writes and retries. The sender must deduplicate by id.
class WatchQueue {
  final Future<String?> Function(String key) read;
  final Future<void> Function(String key, String value) write;
  final Future<void> Function(Map<String, dynamic> event) send;
  Future<void> _tail = Future.value();
  WatchQueue({required this.read, required this.write, required this.send});

  Future<void> _serial(Future<void> Function() work) {
    final result = _tail.then((_) => work());
    _tail = result.catchError((Object _) {});
    return result;
  }

  String _key(String uid) => 'watch.queue.v1.$uid';
  Future<List<Map<String, dynamic>>> _load(String uid) async {
    final raw = await read(_key(uid));
    if (raw == null) return [];
    return (jsonDecode(raw) as List).map((item) => Map<String, dynamic>.from(item)).toList();
  }

  Future<void> enqueue({
    required String uid,
    required String courseId,
    required String lessonId,
    required int seconds,
    int? sessionSeconds,
    bool? isSessionEnd,
    String? studentName,
    String? studentEmail,
    String? lessonTitle,
    String? ipAddress,
    String? networkType,
    String? devicePlatform,
    int? totalDurationSeconds,
    int? maxPlayheadSeconds,
    double? completionPercentage,
    bool? isCompleted,
    String? sessionId,
    String? coverageRanges,
  }) =>
      _serial(() async {
        if (seconds <= 0 && isSessionEnd != true && isCompleted != true) return;
        final events = await _load(uid);
        events.add({
          'id':
              '${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 32)}',
          'uid': uid,
          'courseId': courseId,
          'lessonId': lessonId,
          'seconds': seconds,
          'sessionSeconds': ?sessionSeconds,
          'isSessionEnd': ?isSessionEnd,
          'studentName': ?studentName,
          'studentEmail': ?studentEmail,
          'lessonTitle': ?lessonTitle,
          'ipAddress': ?ipAddress,
          'networkType': ?networkType,
          'devicePlatform': ?devicePlatform,
          'totalDurationSeconds': ?totalDurationSeconds,
          'maxPlayheadSeconds': ?maxPlayheadSeconds,
          'completionPercentage': ?completionPercentage,
          'isCompleted': ?isCompleted,
          'sessionId': ?sessionId,
          'coverageRanges': ?coverageRanges,
        });
        await write(_key(uid), jsonEncode(events));
      });

  Future<void> flush(String uid) => _serial(() async {
    final events = await _load(uid);
    while (events.isNotEmpty) {
      await send(events.first);
      events.removeAt(0);
      await write(_key(uid), jsonEncode(events));
    }
  });
}
