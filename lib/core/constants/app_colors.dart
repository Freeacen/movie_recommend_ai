import 'package:flutter/material.dart';

/// Modern adaptive palette with dark-mode first cinema palette & clean light mode
class AppColors {
  static bool isDark = true;

  // Dark Palette
  static const Color darkBackground = Color(0xFF0D0E12);
  static const Color darkSurface = Color(0xFF161820);
  static const Color darkSurfaceElevated = Color(0xFF20232E);
  static const Color darkSurfaceHighlight = Color(0xFF2A2E3D);
  static const Color darkTextHigh = Color(0xFFF9FAFB);
  static const Color darkTextMedium = Color(0xFF9CA3AF);
  static const Color darkTextLow = Color(0xFF6B7280);
  static const Color darkBorder = Color(0xFF262936);
  static const Color darkBorderSubtle = Color(0xFF1E212B);
  static const Color darkBadgeBg = Color(0xFF222634);
  static const Color darkBadgeText = Color(0xFFE2E8F0);

  // Light Palette (Clean, modern Slate & White)
  static const Color lightBackground = Color(0xFFF8FAFC); // Slate-50
  static const Color lightSurface = Color(0xFFFFFFFF); // Pure White
  static const Color lightSurfaceElevated = Color(0xFFF1F5F9); // Slate-100
  static const Color lightSurfaceHighlight = Color(0xFFE2E8F0); // Slate-200
  static const Color lightTextHigh = Color(0xFF0F172A); // Slate-900 (High contrast readability)
  static const Color lightTextMedium = Color(0xFF475569); // Slate-600
  static const Color lightTextLow = Color(0xFF94A3B8); // Slate-400
  static const Color lightBorder = Color(0xFFE2E8F0); // Slate-200
  static const Color lightBorderSubtle = Color(0xFFF1F5F9); // Slate-100
  static const Color lightBadgeBg = Color(0xFFE2E8F0); // Slate-200
  static const Color lightBadgeText = Color(0xFF1E293B); // Slate-800

  // Dynamic getters based on isDark
  static Color get background => isDark ? darkBackground : lightBackground;
  static Color get surface => isDark ? darkSurface : lightSurface;
  static Color get surfaceElevated => isDark ? darkSurfaceElevated : lightSurfaceElevated;
  static Color get surfaceHighlight => isDark ? darkSurfaceHighlight : lightSurfaceHighlight;

  // Accents (Consistent across both themes)
  static const Color primaryBlue = Color(0xFF3B82F6); // Elektrik Okyanus Mavisi (Ana Vurgu)
  static const Color primaryAmber = primaryBlue; // Geriye dönük tam uyumluluk referansı
  static const Color secondaryBlue = Color(0xFF1D4ED8); // Derin Safir / Kraliyet Mavisi
  static const Color primaryIndigo = secondaryBlue; // Mor yerine uyumlu safir mavi
  static const Color accentNeon = Color(0xFF10B981);
  static const Color accentRose = Color(0xFFF43F5E);
  static const Color accentCyan = Color(0xFF06B6D4);

  // Dynamic text
  static Color get textHigh => isDark ? darkTextHigh : lightTextHigh;
  static Color get textMedium => isDark ? darkTextMedium : lightTextMedium;
  static Color get textLow => isDark ? darkTextLow : lightTextLow;
  static Color get textAccentBlue => isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB);

  // Dynamic borders & dividers
  static Color get border => isDark ? darkBorder : lightBorder;
  static Color get borderSubtle => isDark ? darkBorderSubtle : lightBorderSubtle;

  // Dynamic badge backgrounds
  static Color get badgeBg => isDark ? darkBadgeBg : lightBadgeBg;
  static Color get badgeText => isDark ? darkBadgeText : lightBadgeText;
}
