// lib/config/app_color_tokens.dart
import 'package:flutter/material.dart' show Color, Brightness;

/// Semantic color tokens for the app's warm-neutral / Clinical-Blue design
/// system. Values are shared between the Material (Android/web) and
/// Cupertino (iOS) shells via [AppColorScope] — see app_color_scope.dart.
class AppColorTokens {
  final Color background;
  final Color surface;
  final Color surfaceBorder;
  final Color surfaceTint;
  final Color textPrimary;
  final Color textSecondary;
  final Color textSecondaryAlt;
  final Color accent;
  final Color accentTint;
  final Color critical;
  final Color criticalTint;
  final Color criticalBorder;
  final Color success;
  final Color successTint;
  final Color warning;
  final Color warningTint;
  final Brightness brightness;

  const AppColorTokens({
    required this.background,
    required this.surface,
    required this.surfaceBorder,
    required this.surfaceTint,
    required this.textPrimary,
    required this.textSecondary,
    required this.textSecondaryAlt,
    required this.accent,
    required this.accentTint,
    required this.critical,
    required this.criticalTint,
    required this.criticalBorder,
    required this.success,
    required this.successTint,
    required this.warning,
    required this.warningTint,
    required this.brightness,
  });

  static const light = AppColorTokens(
    background: Color(0xFFFBF9F5),
    surface: Color(0xFFFFFFFF),
    surfaceBorder: Color(0xFFF0EBE0),
    surfaceTint: Color(0xFFEFEAE0),
    textPrimary: Color(0xFF292420),
    textSecondary: Color(0xFF8A8071),
    textSecondaryAlt: Color(0xFF6B6355),
    accent: Color(0xFF1D4ED8),
    accentTint: Color(0xFFDBE7FE),
    critical: Color(0xFFB0392C),
    criticalTint: Color(0xFFFBE4E1),
    criticalBorder: Color(0xFFE8998C),
    // Darker than the brand-blue-era originals for AA text contrast on a
    // light background — see Task 31 (contrast tests). Adjust shade (same
    // hue) if that test fails; do not change without re-running it.
    success: Color(0xFF15803D),
    successTint: Color(0xFFDCFCE7),
    warning: Color(0xFFB45309),
    warningTint: Color(0xFFFEF3C7),
    brightness: Brightness.light,
  );

  static const dark = AppColorTokens(
    background: Color(0xFF201C18),
    surface: Color(0xFF2C2420),
    surfaceBorder: Color(0xFF3A2F28),
    surfaceTint: Color(0xFF3A2F28),
    textPrimary: Color(0xFFF5EFE6),
    textSecondary: Color(0xFFA99C8C),
    textSecondaryAlt: Color(0xFFA99C8C),
    accent: Color(0xFF5B87FA),
    accentTint: Color(0xFF22335F),
    critical: Color(0xFFF5A398),
    criticalTint: Color(0xFF4A2420),
    criticalBorder: Color(0xFF5C2E28),
    success: Color(0xFF4ADE80),
    successTint: Color(0xFF14301F),
    warning: Color(0xFFFBBF24),
    warningTint: Color(0xFF3A2A0C),
    brightness: Brightness.dark,
  );
}
