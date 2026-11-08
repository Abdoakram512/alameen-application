import 'dart:async';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_screen_app/core/utils/app_validators.dart';
import 'package:secure_screen_app/core/utils/network_error_mapper.dart';

void main() {
  group('AppValidators Tests', () {
    test('normalizeDigits converts Arabic-Indic digits to Western digits', () {
      expect(AppValidators.normalizeDigits('٠١٢٣٤٥٦٧٨٩'), '0123456789');
      expect(AppValidators.normalizeDigits('۰۱۲۳۴۵۶۷۸۹'), '0123456789');
      expect(AppValidators.normalizeDigits('  ٠١٠١٢٣٤٥٦٧٨  '), '01012345678');
      expect(AppValidators.normalizeDigits(null), '');
    });

    test('cleanEgyptianPhone normalizes and handles international prefixes', () {
      expect(AppValidators.cleanEgyptianPhone('+201012345678'), '01012345678');
      expect(AppValidators.cleanEgyptianPhone('00201123456789'), '01123456789');
      expect(AppValidators.cleanEgyptianPhone('012 3456 7890'), '01234567890');
      expect(AppValidators.cleanEgyptianPhone('٠١٥١٢٣٤٥٦٧٨'), '01512345678');
    });

    test('validateEgyptianPhone accepts valid numbers and rejects invalid', () {
      expect(AppValidators.validateEgyptianPhone('01012345678'), isNull);
      expect(AppValidators.validateEgyptianPhone('01112345678'), isNull);
      expect(AppValidators.validateEgyptianPhone('01212345678'), isNull);
      expect(AppValidators.validateEgyptianPhone('01512345678'), isNull);
      expect(AppValidators.validateEgyptianPhone('+201012345678'), isNull);

      // Invalid length or prefix
      expect(AppValidators.validateEgyptianPhone('01312345678'), isNotNull);
      expect(AppValidators.validateEgyptianPhone('0101234567'), isNotNull);
      expect(AppValidators.validateEgyptianPhone('010123456789'), isNotNull);
      expect(AppValidators.validateEgyptianPhone(''), isNotNull);
      expect(AppValidators.validateEgyptianPhone(null), isNotNull);
    });

    test('validateWalletNumber checks specific providers accurately', () {
      expect(AppValidators.validateWalletNumber('01012345678', provider: 'فودافون كاش'), isNull);
      expect(AppValidators.validateWalletNumber('01212345678', provider: 'فودافون كاش'), isNotNull);

      expect(AppValidators.validateWalletNumber('01212345678', provider: 'أورنج كاش'), isNull);
      expect(AppValidators.validateWalletNumber('01112345678', provider: 'اتصالات كاش'), isNull);
      expect(AppValidators.validateWalletNumber('01512345678', provider: 'وي باي'), isNull);
    });

    test('validateInstaPay accepts IPA handles and registered phone numbers', () {
      expect(AppValidators.validateInstaPay('student@instapay'), isNull);
      expect(AppValidators.validateInstaPay('ahmed.aly@cib'), isNull);
      expect(AppValidators.validateInstaPay('01012345678'), isNull);
      expect(AppValidators.validateInstaPay('٠١١١٢٣٤٥٦٧٨'), isNull);

      expect(AppValidators.validateInstaPay('invalid-handle'), isNotNull);
      expect(AppValidators.validateInstaPay(''), isNotNull);
    });

    test('formatDurationArabic formats durations properly with Arabic units', () {
      expect(AppValidators.formatDurationArabic('30'), '30 دقيقة');
      expect(AppValidators.formatDurationArabic('1'), 'دقيقة واحدة');
      expect(AppValidators.formatDurationArabic('2'), 'دقيقتان');
      expect(AppValidators.formatDurationArabic('5'), '5 دقائق');
      expect(AppValidators.formatDurationArabic('60'), 'ساعة واحدة');
      expect(AppValidators.formatDurationArabic('120'), 'ساعتان');
      expect(AppValidators.formatDurationArabic('90'), '1 ساعة و 30 دقيقة');
      expect(AppValidators.formatDurationArabic('30 دقيقة'), '30 دقيقة');
    });

    test('validateUrl validates web links correctly', () {
      expect(AppValidators.validateUrl('https://drive.google.com/file/d/xyz'), isNull);
      expect(AppValidators.validateUrl('http://example.com/test'), isNull);
      expect(AppValidators.validateUrl('ftp://invalid.com'), isNotNull);
      expect(AppValidators.validateUrl('just-text'), isNotNull);
    });
  });

  group('NetworkErrorMapper Tests', () {
    test('maps Firebase permission-denied', () {
      final exc = FirebaseException(plugin: 'firestore', code: 'permission-denied');
      final msg = NetworkErrorMapper.toArabicMessage(exc);
      expect(msg, contains('صلاحية'));
    });

    test('maps Firebase unavailable / network error', () {
      final exc = FirebaseException(plugin: 'firestore', code: 'unavailable');
      final msg = NetworkErrorMapper.toArabicMessage(exc);
      expect(msg, contains('اتصال'));
    });

    test('maps TimeoutException to Arabic message', () {
      final exc = TimeoutException('Operation timed out');
      final msg = NetworkErrorMapper.toArabicMessage(exc);
      expect(msg, contains('مهلة'));
    });

    test('maps SocketException to Arabic message', () {
      const exc = SocketException('Failed host lookup');
      final msg = NetworkErrorMapper.toArabicMessage(exc);
      expect(msg, contains('الإنترنت'));
    });
  });
}

