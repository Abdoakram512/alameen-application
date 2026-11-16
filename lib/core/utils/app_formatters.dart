import 'package:intl/intl.dart';

/// Pure Dart date, time, and duration formatters for the Alameen platform.
class AppFormatters {
  AppFormatters._();

  static final DateFormat _arabicDateFormat = DateFormat('yyyy/MM/dd', 'ar');
  static final DateFormat _arabicDateTimeFormat = DateFormat('yyyy/MM/dd HH:mm', 'ar');
  static final NumberFormat _currencyFormat = NumberFormat('#,##0', 'ar');

  /// Formats seconds into HH:MM:SS or MM:SS format.
  /// Used by MuxService, CourseCubits, and Video player.
  static String formatDuration(int totalSeconds) {
    if (totalSeconds <= 0) return '00:00';
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    final minutesStr = minutes.toString().padLeft(2, '0');
    final secondsStr = seconds.toString().padLeft(2, '0');

    if (hours > 0) {
      final hoursStr = hours.toString().padLeft(2, '0');
      return '$hoursStr:$minutesStr:$secondsStr';
    }
    return '$minutesStr:$secondsStr';
  }

  /// Formats a DateTime to Arabic date string (yyyy/MM/dd).
  static String formatDate(DateTime? date) {
    if (date == null) return '';
    try {
      return _arabicDateFormat.format(date);
    } catch (_) {
      return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
    }
  }

  /// Formats a DateTime to Arabic date-time string (yyyy/MM/dd HH:mm).
  static String formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    try {
      return _arabicDateTimeFormat.format(dateTime);
    } catch (_) {
      final d = formatDate(dateTime);
      final t = '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
      return '$d $t';
    }
  }

  /// Formats numeric currency with Egyptian Pound suffix.
  static String formatCurrency(num? amount, [String suffix = 'ج.م']) {
    if (amount == null) return '0 $suffix';
    try {
      return '${_currencyFormat.format(amount)} $suffix';
    } catch (_) {
      return '$amount $suffix';
    }
  }
}
