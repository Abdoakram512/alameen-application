import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// Centralized application logger powered by the [logger] package.
/// Provides structured, level-aware logging across the entire application
/// (Presentation, Cubits, Domain, Repositories, and Network).
class AppLogger {
  AppLogger._();

  static Logger _instance = _createDefaultLogger();

  static Logger get instance => _instance;

  /// Visible for testing to inject custom loggers or outputs.
  static void setInstance(Logger customLogger) {
    _instance = customLogger;
  }

  static void reset() {
    _instance = _createDefaultLogger();
  }

  static Logger _createDefaultLogger() {
    return Logger(
      filter: DevelopmentFilter(),
      printer: PrettyPrinter(
        methodCount: 1,
        errorMethodCount: 5,
        lineLength: 90,
        colors: true,
        printEmojis: true,
        dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
      ),
      level: kDebugMode ? Level.trace : Level.off,
    );
  }

  /// Log a trace / verbose message.
  static void t(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _instance.t(message, error: error, stackTrace: stackTrace);
  }

  /// Log a debug message.
  static void d(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _instance.d(message, error: error, stackTrace: stackTrace);
  }

  /// Log an informational message.
  static void i(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _instance.i(message, error: error, stackTrace: stackTrace);
  }

  /// Log a warning message.
  static void w(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _instance.w(message, error: error, stackTrace: stackTrace);
  }

  /// Log an error message.
  static void e(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _instance.e(message, error: error, stackTrace: stackTrace);
  }

  /// Log a fatal error message.
  static void f(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _instance.f(message, error: error, stackTrace: stackTrace);
  }
}
