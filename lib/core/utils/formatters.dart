class AppFormatters {
  AppFormatters._();

  static String formatCurrency(num amount) {
    if (amount.truncateToDouble() == amount) {
      return '${amount.toInt()} ج.م';
    }
    return '${amount.toStringAsFixed(2)} ج.م';
  }

  static String formatPrice(num amount) {
    if (amount.truncateToDouble() == amount) {
      return amount.toInt().toString();
    }
    return amount.toString();
  }

  static String formatDuration(int minutes) {
    if (minutes < 60) {
      return '$minutes دقيقة';
    }
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (remainingMinutes == 0) {
      return '$hours ساعة';
    }
    return '$hours ساعة و $remainingMinutes دقيقة';
  }
}

