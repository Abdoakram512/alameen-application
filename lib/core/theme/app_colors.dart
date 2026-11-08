import 'package:flutter/material.dart';

/// Alameen Center Design System - Clean Palette & Subtle Elevation
/// Strict brand identity (Navy Blue & Crisp White with Cobalt and Crimson accents).
class AppColors {
  AppColors._();

  // ═══════════════════════════════════════════════════════════════════
  // Primary Brand Palette (Royal Navy - الكحلي الملكي)
  // ═══════════════════════════════════════════════════════════════════
  static const Color primary = Color(0xFF012383); // Navy Blue (Brand Primary)
  static const Color primaryDark = Color(0xFF0F1B4D); // Deep Dark Navy
  static const Color royalNavy = Color(0xFF012383); // Royal Navy anchor
  static const Color primaryLight = Color(0xFFEAF1FB); // Clean Light Navy Tint
  static const Color primaryGlow = Color(0x1A1B2A6B); // Navy minimal tint
  static const Color primaryMedium = Color(0xFF273C8E); // Mid Navy

  // ═══════════════════════════════════════════════════════════════════
  // Secondary / Accents (Cobalt Electric Blue & Burgundy Crimson from Logo)
  // ═══════════════════════════════════════════════════════════════════
  static const Color secondary = Color(0xFF0B2A8F); // Bright Blue (Logo Gears)
  static const Color secondaryLight = Color(0xFFEFF6FF);
  static const Color secondaryDark = Color(0xFF1C54B2);
  static const Color secondaryGlow = Color(0x1A2979FF);

  static const Color accentCobalt = Color(0xFF0B2A8F); // Cobalt Blue
  static const Color accentCobaltLight = Color(0xFFEFF6FF);
  static const Color accentCobaltDark = Color(0xFF0B2A8F);

  static const Color crimsonAccent = Color(0xFF991B1B); // Crimson Red from logo
  static const Color crimsonLight = Color(0xFFFEF2F2);

  // ═══════════════════════════════════════════════════════════════════
  // Backgrounds & Clean Surfaces
  // ═══════════════════════════════════════════════════════════════════
  static const Color scaffoldBackground = Color(
    0xFFFAFCFF,
  ); // Neutral Crisp Canvas
  static const Color surface = Colors.white;
  static const Color surfaceLevel0 = Color(0xFFFAFCFF);
  static const Color surfaceLevel1 = Colors.white;
  static const Color surfaceLevel2 = Color(0xFFF1F5F9);
  static const Color cardBorder = Color(0xFFDEE8F7);
  static const Color borderHairline = Color(0xFFDEE8F7);
  static const Color divider = Color(0xFFEDF2F7);
  static const Color inputBackground = Color(0xFFFAFBFC);

  // ═══════════════════════════════════════════════════════════════════
  // Dark Backgrounds & Cards (for Auth / Splash)
  // ═══════════════════════════════════════════════════════════════════
  static const Color darkBackground = Color(0xFF0A0F1E); // Deep Navy/Black
  static const Color darkCard = Color(0xFF111728); // Dark Navy Card
  static const Color darkSurface = Color(0xFF161F36); // Dark Surface
  static const Color darkBorder = Color(0xFF1E293B); // Dark Border
  static const Color darkInput = Color(0xFF0E1424); // Dark Input Fill

  // ═══════════════════════════════════════════════════════════════════
  // Status Colors (Semantic & Clean Feedback)
  // ═══════════════════════════════════════════════════════════════════
  static const Color success = Color(0xFF16A34A); // Emerald Green
  static const Color successMint = Color(0xFF10B981); // Fresh Mint Green
  static const Color successLight = Color(0xFFECFDF5);
  static const Color successDark = Color(0xFF047857);
  static const Color successBorder = Color(0xFFA7F3D0);

  static const Color warning = Color(0xFFD97706); // Warm Amber
  static const Color warningAmber = Color(0xFFF59E0B); // Energetic Amber
  static const Color warningLight = Color(0xFFFFFBEB);
  static const Color warningDark = Color(0xFFB45309);
  static const Color warningBorder = Color(0xFFFDE68A);

  static const Color error = Color(0xFFDC2626); // Crimson Red
  static const Color errorLight = Color(0xFFFEF2F2);
  static const Color errorDark = Color(0xFF991B1B);
  static const Color errorBorder = Color(0xFFFECACA);

  static const Color info = Color(0xFF0B2A8F); // Cobalt Info
  static const Color infoLight = Color(0xFFEFF6FF);
  static const Color infoDark = Color(0xFF0B2A8F);

  // ═══════════════════════════════════════════════════════════════════
  // Text Colors
  // ═══════════════════════════════════════════════════════════════════
  static const Color textPrimary = Color(0xFF0F172A); // Crisp Slate-Black
  static const Color textSecondary = Color(0xFF475569); // Slate Gray
  static const Color textMuted = Color(0xFF64748B); // Light Slate
  static const Color textWhite = Colors.white;
  static const Color textWhite70 = Colors.white70;
  static const Color textWhite54 = Colors.white54;
  static const Color textOnPrimary = Colors.white;

  // ═══════════════════════════════════════════════════════════════════
  // Gradients
  // ═══════════════════════════════════════════════════════════════════
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF012383), Color(0xFF012383)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient bentoNavyGradient = LinearGradient(
    colors: [Color(0xFF012383), Color(0xFF012383)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cobaltGradient = LinearGradient(
    colors: [Color(0xFF0B2A8F), Color(0xFF0B2A8F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF012383), Color(0xFF1E3A8A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkCardGradient = LinearGradient(
    colors: [Color(0xFF111728), Color(0xFF161F36)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFFAFCFF)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF16A34A), Color(0xFF047857)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ═══════════════════════════════════════════════════════════════════
  // Natural Subtle Elevation (Zero unnecessary AI glow / heavy blur)
  // ═══════════════════════════════════════════════════════════════════
  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x06000000), blurRadius: 4, offset: Offset(0, 1)),
  ];

  static const List<BoxShadow> heroShadow = [
    BoxShadow(color: Color(0x10000000), blurRadius: 8, offset: Offset(0, 2)),
  ];

  static const List<BoxShadow> floatingDockShadow = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 2)),
  ];
}
