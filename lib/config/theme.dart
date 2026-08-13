import 'package:flutter/material.dart';
import 'app_color_tokens.dart';
import 'app_spacing.dart';

class AppTheme {
  static ThemeData get lightTheme => _build(AppColorTokens.light);
  static ThemeData get darkTheme => _build(AppColorTokens.dark);

  static ThemeData _build(AppColorTokens tokens) {
    return ThemeData(
      useMaterial3: true,
      brightness: tokens.brightness,
      fontFamily: 'Plus Jakarta Sans',
      scaffoldBackgroundColor: tokens.background,
      // Explicitly set every ColorScheme role a stock Material widget is
      // likely to pull from by default (outline, onSurface, secondary,
      // surfaceContainerHighest, etc.) rather than letting ColorScheme.fromSeed's
      // algorithmic tonal-palette derivation leak through for anything not
      // hand-restyled in this plan's flagship screens — otherwise those
      // roles silently diverge from the approved mockups/Task 31 contrast
      // tests with no token anywhere to trace the value back to.
      // Roles intentionally left seed-derived (rarely user-visible, not
      // worth expanding the token set for): tertiary*, inverseSurface,
      // inversePrimary, shadow, scrim, surfaceTint.
      colorScheme: ColorScheme.fromSeed(
        seedColor: tokens.accent,
        brightness: tokens.brightness,
        primary: tokens.accent,
        onPrimary: tokens.onAccent,
        primaryContainer: tokens.accentTint,
        onPrimaryContainer: tokens.accent,
        secondary: tokens.accent,
        onSecondary: tokens.onAccent,
        secondaryContainer: tokens.accentTint,
        onSecondaryContainer: tokens.accent,
        error: tokens.critical,
        onError: tokens.onCritical,
        errorContainer: tokens.criticalTint,
        onErrorContainer: tokens.critical,
        surface: tokens.surface,
        onSurface: tokens.textPrimary,
        onSurfaceVariant: tokens.textSecondary,
        surfaceContainerHighest: tokens.surfaceTint,
        outline: tokens.surfaceBorder,
        outlineVariant: tokens.surfaceBorder,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: tokens.accent,
        foregroundColor: tokens.onAccent,
        titleTextStyle: TextStyle(
          fontFamily: 'Plus Jakarta Sans',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: tokens.onAccent,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: tokens.accent,
          foregroundColor: tokens.onAccent,
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl, vertical: AppSpacing.lg),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
          elevation: 0,
          textStyle: const TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 16,
              fontWeight: FontWeight.w700),
        ),
      ),
      // Without this, Material 3's FAB defaults pull `onPrimaryContainer` for
      // its foreground — which this ColorScheme maps to `accent`, the same
      // color most FABs in the app set as their background. Pin both ends.
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: tokens.accent,
        foregroundColor: tokens.onAccent,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: tokens.accent,
          textStyle: const TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 16,
              fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: tokens.accent,
          side: BorderSide(color: tokens.accent, width: 1.5),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl, vertical: AppSpacing.lg),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
          textStyle: const TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 16,
              fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: BorderSide(color: tokens.surfaceBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: BorderSide(color: tokens.surfaceBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: BorderSide(color: tokens.accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: BorderSide(color: tokens.critical),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: BorderSide(color: tokens.critical, width: 2),
        ),
        filled: true,
        fillColor: tokens.surface,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
        labelStyle: TextStyle(color: tokens.textSecondary),
        hintStyle: TextStyle(color: tokens.textSecondary.withValues(alpha: 0.6)),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: tokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(color: tokens.surfaceBorder),
        ),
        margin: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      ),
      textTheme: Typography.material2021(platform: TargetPlatform.android)
          .black
          .apply(fontFamily: 'Plus Jakarta Sans', bodyColor: tokens.textPrimary,
              displayColor: tokens.textPrimary),
    );
  }
}
