import 'dart:convert';

/// يتتبع النطاقات الزمنية الفريدة التي شاهدها المتدرب بالفعل في المحاضرة.
/// يضمن عدم احتساب المقاطع التي تم القفز عنها (Forward Seeking) أو تكرار
/// نفس الثواني عند إعادة المشاهدة (Rewatching).
class LessonCoverageTracker {
  final Set<int> _coveredSeconds = <int>{};

  LessonCoverageTracker([Set<int>? initial]) {
    if (initial != null) _coveredSeconds.addAll(initial);
  }

  /// تسجيل ثانية واحدة تم تشغيلها فعلياً
  void markSecond(int second) {
    if (second >= 0) _coveredSeconds.add(second);
  }

  /// تسجيل تقدم التشغيل التلقائي مع حماية السرعات المتغيرة (1.25x, 1.5x, 2.0x) والقفز
  void markPlayback({
    required int currentPosition,
    required int lastPosition,
    bool isSeeking = false,
  }) {
    if (currentPosition < 0) return;
    if (isSeeking || lastPosition < 0 || currentPosition < lastPosition || (currentPosition - lastPosition) > 4) {
      // قفز يدوي (Seek) أو بداية جديدة: نسجل فقط الموضع الحالي
      markSecond(currentPosition);
    } else {
      // تشغيل طبيعي (بما في ذلك السرعات المضاعفة حتى 2x): نسجل كافة الثواني البينية
      for (int s = lastPosition; s <= currentPosition; s++) {
        markSecond(s);
      }
    }
  }

  /// دمج نطاقات مشاهدة من جهاز آخر أو جلسة أخرى (اتحاد المجموعات الحسابي)
  void merge(LessonCoverageTracker other) {
    _coveredSeconds.addAll(other._coveredSeconds);
  }

  /// إجمالي عدد الثواني الفريدة غير المتكررة التي تمت مشاهدتها
  int get uniqueSeconds => _coveredSeconds.length;
  int get watchedSecondsCount => uniqueSeconds;

  /// فحص ما إذا كانت ثانية معينة تمت مشاهدتها
  bool isSecondWatched(int second) => _coveredSeconds.contains(second);

  /// نسبة التغطية الفعلية الفريدة من إجمالي مدة المحاضرة (0.0% إلى 100.0%)
  double coveragePercentage(int totalDurationSeconds) {
    if (totalDurationSeconds <= 0) return 0.0;
    return ((uniqueSeconds / totalDurationSeconds) * 100.0).clamp(0.0, 100.0);
  }
  double calculateCoveragePercentage(int totalDurationSeconds) => coveragePercentage(totalDurationSeconds);

  /// التحقق الصارم من استيفاء شرط نسبة الإكمال المحددة (مثلاً 95.0%)
  bool isComplete(int totalDurationSeconds, num thresholdPercentage) {
    if (totalDurationSeconds <= 0) return false;
    return coveragePercentage(totalDurationSeconds) >= thresholdPercentage.toDouble();
  }

  /// ضغط النطاقات الزمنية المشاهدة إلى مصفوفة JSON خفيفة لتخزينها محلياً
  String encodeRanges() {
    if (_coveredSeconds.isEmpty) return '[]';
    final sorted = _coveredSeconds.toList()..sort();
    final ranges = <List<int>>[];
    int start = sorted.first;
    int end = start;

    for (int i = 1; i < sorted.length; i++) {
      if (sorted[i] == end + 1) {
        end = sorted[i];
      } else {
        ranges.add([start, end]);
        start = sorted[i];
        end = start;
      }
    }
    ranges.add([start, end]);
    return jsonEncode(ranges);
  }

  /// استرجاع النطاقات الزمنية المخزنة مسبقاً
  static LessonCoverageTracker decodeRanges(String rawJson) {
    final tracker = LessonCoverageTracker();
    if (rawJson.trim().isEmpty) return tracker;
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is List) {
        for (final item in decoded) {
          if (item is List && item.length >= 2) {
            final start = (item[0] as num).toInt();
            final end = (item[1] as num).toInt();
            for (int s = start; s <= end; s++) {
              tracker.markSecond(s);
            }
          }
        }
      }
    } catch (_) {}
    return tracker;
  }
  static LessonCoverageTracker fromRanges(String rawJson) => decodeRanges(rawJson);
}
