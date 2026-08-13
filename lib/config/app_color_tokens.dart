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

  // ── "On" colors ────────────────────────────────────────────────────────────
  // Foreground (text/icon) color to use *on top of* the matching semantic color
  // when that color is used as a FILL (app bar, filled button, badge, banner,
  // FAB) rather than as foreground text.
  //
  // These are NOT interchangeable with Colors.white. In dark mode `accent`,
  // `critical`, `warning` and `success` are deliberately *light* colors — they
  // are tuned to read as foreground text on the dark surfaces (see
  // test/config/token_contrast_test.dart). White text on those light fills
  // measures as low as 1.67:1, far below WCAG AA's 4.5:1, which is why the
  // dark variants below are a near-black instead.
  //
  // Every fill+foreground pair is locked in by test/config/token_contrast_test.dart.
  final Color onAccent;
  final Color onCritical;
  final Color onWarning;
  final Color onSuccess;

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
    required this.onAccent,
    required this.onCritical,
    required this.onWarning,
    required this.onSuccess,
    required this.brightness,
  });

  static const light = AppColorTokens(
    background: Color(0xFFFBF9F5),
    surface: Color(0xFFFFFFFF),
    surfaceBorder: Color(0xFFF0EBE0),
    surfaceTint: Color(0xFFEFEAE0),
    textPrimary: Color(0xFF292420),
    // Same hue (36°) / saturation (10%) as the original #8A8071, darkened from
    // L 49% -> 42% so it clears WCAG AA on both `background` (4.84:1) and
    // `surface` (5.09:1). The original measured 3.69:1 / 3.88:1 — a regression
    // against the static gray600 it replaced. Locked in by
    // test/config/token_contrast_test.dart; do not lighten without rerunning it.
    textSecondary: Color(0xFF766D60),
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
    // Light-mode semantic colors are dark enough that plain white clears AA as
    // a foreground on all four fills (accent 6.70, critical 6.06, warning 5.02,
    // success 5.02).
    onAccent: Color(0xFFFFFFFF),
    onCritical: Color(0xFFFFFFFF),
    onWarning: Color(0xFFFFFFFF),
    onSuccess: Color(0xFFFFFFFF),
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
    // Deliberately near-black, not white. These four semantic colors are LIGHT
    // in dark mode because their primary job is foreground text on the dark
    // `surface`/`*Tint` backgrounds (dark accent-on-surface is only 4.56:1 as
    // it is — darkening them to make white legible would push all four below
    // AA in that, their original, direction). So the fill+foreground pair is
    // fixed from the foreground side instead: near-black on the light fill
    // measures accent 5.39, critical 9.05, warning 10.77, success 10.32.
    onAccent: Color(0xFF1A1613),
    onCritical: Color(0xFF1A1613),
    onWarning: Color(0xFF1A1613),
    onSuccess: Color(0xFF1A1613),
    brightness: Brightness.dark,
  );
}
