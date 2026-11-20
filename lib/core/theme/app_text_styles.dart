import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Alameen Center Typography System
/// Designed for natural Arabic ligatures (zero letterSpacing) in Cairo and clear numerals.
class AppTextStyles {
  AppTextStyles._();

  static const List<String> fontFallbacks = [
    'Cairo',
    'Plus Jakarta Sans',
    'Segoe UI',
    'Roboto',
    'sans-serif',
  ];

  static const TextStyle displayLarge = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    height: 1.35,
    fontFamilyFallback: fontFallbacks,
  );

  static const TextStyle heading1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    height: 1.35,
    fontFamilyFallback: fontFallbacks,
  );

  static const TextStyle heading2 = TextStyle(
    fontSize: 19,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.4,
    fontFamilyFallback: fontFallbacks,
  );

  static const TextStyle heading3 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.4,
    fontFamilyFallback: fontFallbacks,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 14.5,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
    height: 1.55,
    fontFamilyFallback: fontFallbacks,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
    height: 1.5,
    fontFamilyFallback: fontFallbacks,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 11.5,
    fontWeight: FontWeight.w500,
    color: AppColors.textMuted,
    height: 1.4,
    fontFamilyFallback: fontFallbacks,
  );

  static const TextStyle button = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: Colors.white,
    height: 1.0,
    leadingDistribution: TextLeadingDistribution.even,
    fontFamilyFallback: fontFallbacks,
  );

  static const TextStyle label = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: AppColors.textSecondary,
    fontFamilyFallback: fontFallbacks,
  );

  static const TextStyle metricLarge = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    color: Colors.white,
    height: 1.25,
    fontFamilyFallback: fontFallbacks,
  );

  // Material 3 semantic convenience aliases
  static const TextStyle titleMedium = heading3;
  static const TextStyle headlineSmall = heading2;
  static const TextStyle bodySmall = caption;
}
