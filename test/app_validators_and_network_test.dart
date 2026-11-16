import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_admin_app/core/utils/app_validators.dart';
import 'package:secure_admin_app/core/utils/network_error_mapper.dart';

void main() {
  group('Admin App AppValidators Tests', () {
    test('normalizeDigits converts Arabic-Indic digits to Western digits', () {
      expect(AppValidators.normalizeDigits('٠١٢٣٤٥٦٧٨٩'), '0123456789');
      expect(AppValidators.normalizeDigits('  ٠١٠١٢٣٤٥٦٧٨  '), '01012345678');
    });

    test('cleanEgyptianPhone normalizes and handles international prefixes', () {
      expect(AppValidators.cleanEgyptianPhone('+201012345678'), '01012345678');
      expect(AppValidators.cleanEgyptianPhone('00201123456789'), '01123456789');
    });

    test('validatePrice handles positive numbers, zero, and rejects invalid', () {
      expect(AppValidators.validatePrice('0'), isNull);
      expect(AppValidators.validatePrice('500'), isNull);
      expect(AppValidators.validatePrice('١٥٠'), isNull);
      expect(AppValidators.validatePrice('-10'), isNotNull);
      expect(AppValidators.validatePrice('abc'), isNotNull);
      expect(AppValidators.validatePrice(''), isNotNull);
    });

    test('validateEgyptianPhone validates correctly', () {
      expect(AppValidators.validateEgyptianPhone('01012345678'), isNull);
      expect(AppValidators.validateEgyptianPhone('01212345678'), isNull);
      expect(AppValidators.validateEgyptianPhone('01312345678'), isNotNull);
    });

    test('formatDurationArabic formats nicely', () {
      expect(AppValidators.formatDurationArabic('45'), '45 دقيقة');
      expect(AppValidators.formatDurationArabic('60'), 'ساعة واحدة');
    });
  });

  group('Admin NetworkErrorMapper Tests', () {
    test('maps Firebase permission-denied', () {
      final exc = FirebaseException(plugin: 'firestore', code: 'permission-denied');
      expect(NetworkErrorMapper.toArabicMessage(exc), contains('صلاحية'));
    });

    test('maps TimeoutException', () {
      final exc = TimeoutException('Timeout');
      expect(NetworkErrorMapper.toArabicMessage(exc), contains('مهلة'));
    });
  });
}
