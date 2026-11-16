/// Pure Dart converter for DateTime handling across Firestore Timestamp,
/// ISO-8601 Strings, and epoch milliseconds without requiring cloud_firestore.
class FirestoreDateTimeConverter {
  const FirestoreDateTimeConverter._();

  /// Flexible parser supporting DateTime, cloud_firestore Timestamp (via duck typing),
  /// Map with '_seconds', int epoch milliseconds, and ISO-8601 Strings.
  static DateTime? fromValue(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;

    // Duck-typing for cloud_firestore Timestamp without importing the package
    try {
      final dynamic dyn = value;
      if (dyn.toDate != null && dyn.toDate is Function) {
        return dyn.toDate() as DateTime;
      }
    } catch (_) {}

    // Map format with _seconds or seconds (REST/emulator)
    if (value is Map) {
      if (value.containsKey('_seconds') && value['_seconds'] is num) {
        return DateTime.fromMillisecondsSinceEpoch(
          (value['_seconds'] as num).toInt() * 1000,
        );
      }
      if (value.containsKey('seconds') && value['seconds'] is num) {
        return DateTime.fromMillisecondsSinceEpoch(
          (value['seconds'] as num).toInt() * 1000,
        );
      }
    }

    // Integer / numeric epoch milliseconds
    if (value is num) {
      final intVal = value.toInt();
      // If small, it might be in seconds instead of milliseconds
      if (intVal < 10000000000) {
        return DateTime.fromMillisecondsSinceEpoch(intVal * 1000);
      }
      return DateTime.fromMillisecondsSinceEpoch(intVal);
    }

    // String ISO-8601
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      return DateTime.tryParse(trimmed);
    }

    return null;
  }

  /// Converts DateTime to ISO-8601 string representation.
  static String? toIso8601(DateTime? dateTime) {
    return dateTime?.toIso8601String();
  }
}
