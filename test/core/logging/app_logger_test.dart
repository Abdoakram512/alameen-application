import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:secure_screen_app/core/logging/app_logger.dart';

class TestLogOutput extends LogOutput {
  final List<OutputEvent> events = [];

  @override
  void output(OutputEvent event) {
    events.add(event);
  }
}

void main() {
  group('AppLogger package tests', () {
    late TestLogOutput testOutput;

    setUp(() {
      testOutput = TestLogOutput();
      final customLogger = Logger(
        filter: ProductionFilter(),
        printer: SimplePrinter(colors: false),
        output: testOutput,
        level: Level.trace,
      );
      AppLogger.setInstance(customLogger);
    });

    tearDown(() {
      AppLogger.reset();
    });

    test('logs trace, debug, info, warning, error and fatal events correctly', () {
      AppLogger.t('trace message');
      AppLogger.d('debug message');
      AppLogger.i('info message');
      AppLogger.w('warning message');
      AppLogger.e('error message', 'sample error');
      AppLogger.f('fatal message');

      expect(testOutput.events.length, 6);
      expect(testOutput.events[0].level, Level.trace);
      expect(testOutput.events[0].lines.join(), contains('trace message'));

      expect(testOutput.events[1].level, Level.debug);
      expect(testOutput.events[1].lines.join(), contains('debug message'));

      expect(testOutput.events[2].level, Level.info);
      expect(testOutput.events[2].lines.join(), contains('info message'));

      expect(testOutput.events[3].level, Level.warning);
      expect(testOutput.events[3].lines.join(), contains('warning message'));

      expect(testOutput.events[4].level, Level.error);
      expect(testOutput.events[4].lines.join(), contains('error message'));

      expect(testOutput.events[5].level, Level.fatal);
      expect(testOutput.events[5].lines.join(), contains('fatal message'));
    });
  });
}
