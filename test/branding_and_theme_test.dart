import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_admin_app/core/constants/app_constants.dart';
import 'package:secure_admin_app/core/theme/app_colors.dart';
import 'package:secure_admin_app/core/theme/app_theme.dart';

void main() {
  group('Alameen Center Branding & Design System Tests', () {
    test('AppConstants contains correct Alameen Center brand information', () {
      expect(AppConstants.appName, equals('Alameen Center'));
      expect(AppConstants.appNameAr, contains('الأمين'));
      expect(AppConstants.logoAsset, equals('assets/images/logo.png'));
    });

    test('AppColors palette matches Navy Blue and White brand requirements', () {
      // Primary is Navy Blue from the logo
      expect(AppColors.primary, equals(const Color(0xFF012383)));
      expect(AppColors.primaryDark, equals(const Color(0xFF0F1B4D)));
      // Secondary is Bright Blue from the gears
      expect(AppColors.secondary, equals(const Color(0xFF0B2A8F)));
      // Surfaces are clean white and off-white
      expect(AppColors.surface, equals(Colors.white));
      expect(AppColors.scaffoldBackground, equals(const Color(0xFFFAFCFF)));
    });

    test('AppTheme lightTheme applies Navy & White design tokens properly', () {
      final theme = AppTheme.lightTheme;
      expect(theme.colorScheme.primary, equals(AppColors.primary));
      expect(theme.colorScheme.secondary, equals(AppColors.secondary));
      expect(theme.scaffoldBackgroundColor, equals(AppColors.scaffoldBackground));
      expect(theme.appBarTheme.backgroundColor, equals(Colors.white));
    });

    test('Logo asset exists and is accessible in assets/images/logo.png', () {
      final file = File('assets/images/logo.png');
      expect(file.existsSync(), isTrue);
      expect(file.lengthSync(), greaterThan(1000));
    });

    test('All Android launcher mipmap icons have been generated from logo', () {
      final mipmaps = [
        'android/app/src/main/res/mipmap-mdpi/ic_launcher.png',
        'android/app/src/main/res/mipmap-hdpi/ic_launcher.png',
        'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png',
        'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png',
        'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png',
      ];

      for (final path in mipmaps) {
        final f = File(path);
        expect(f.existsSync(), isTrue, reason: '$path should exist');
        expect(f.lengthSync(), greaterThan(100), reason: '$path should be populated');
      }
    });
  });
}

