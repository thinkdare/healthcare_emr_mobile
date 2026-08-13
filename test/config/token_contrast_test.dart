// test/config/token_contrast_test.dart
//
// Enforces WCAG AA text contrast (>= 4.5:1) for the semantic tokens used
// as text-on-tint pairs throughout the app (critical allergy banners,
// success/warning badges). "Validated for WCAG AA" in the spec means this
// test passes — if you retune any of these hexes, rerun this file and
// adjust the shade (same hue) until it's green again.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_emr_mobile/config/app_color_tokens.dart';

double _linearize(double channel255) {
  final s = channel255 / 255.0;
  return s <= 0.03928 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
}

double relativeLuminance(Color c) {
  final r = _linearize(c.r * 255.0);
  final g = _linearize(c.g * 255.0);
  final b = _linearize(c.b * 255.0);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double contrastRatio(Color a, Color b) {
  final la = relativeLuminance(a);
  final lb = relativeLuminance(b);
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('WCAG AA contrast (>= 4.5:1) for text-on-tint token pairs', () {
    final pairs = {
      'light critical on criticalTint':
          (AppColorTokens.light.critical, AppColorTokens.light.criticalTint),
      'light success on successTint':
          (AppColorTokens.light.success, AppColorTokens.light.successTint),
      'light warning on warningTint':
          (AppColorTokens.light.warning, AppColorTokens.light.warningTint),
      'dark critical on criticalTint':
          (AppColorTokens.dark.critical, AppColorTokens.dark.criticalTint),
      'dark success on successTint':
          (AppColorTokens.dark.success, AppColorTokens.dark.successTint),
      'dark warning on warningTint':
          (AppColorTokens.dark.warning, AppColorTokens.dark.warningTint),
      'light critical on surface':
          (AppColorTokens.light.critical, AppColorTokens.light.surface),
      'dark critical on surface':
          (AppColorTokens.dark.critical, AppColorTokens.dark.surface),
    };

    for (final entry in pairs.entries) {
      test(entry.key, () {
        final ratio = contrastRatio(entry.value.$1, entry.value.$2);
        expect(ratio, greaterThanOrEqualTo(4.5),
            reason: '${entry.key} contrast ratio is ${ratio.toStringAsFixed(2)}:1, '
                'below WCAG AA 4.5:1. Darken/lighten the text color (same hue) '
                'in AppColorTokens and rerun.');
      });
    }
  });

  // The group above only ever checked the semantic colors in their
  // *foreground-on-tint* direction. The app also uses accent/critical/warning/
  // success as FILLS (app bar, filled buttons, FABs, badges, banners) with a
  // foreground on top — a direction no test covered, which is how dark mode
  // shipped with white-on-#FBBF24 at 1.67:1. These pairs lock in the fill
  // direction; use tokens.onAccent/onCritical/onWarning/onSuccess at the call
  // site, never a hard-coded Colors.white.
  group('WCAG AA contrast (>= 4.5:1) for fill + on-color token pairs', () {
    final pairs = {
      'light onAccent on accent':
          (AppColorTokens.light.onAccent, AppColorTokens.light.accent),
      'light onCritical on critical':
          (AppColorTokens.light.onCritical, AppColorTokens.light.critical),
      'light onWarning on warning':
          (AppColorTokens.light.onWarning, AppColorTokens.light.warning),
      'light onSuccess on success':
          (AppColorTokens.light.onSuccess, AppColorTokens.light.success),
      'dark onAccent on accent':
          (AppColorTokens.dark.onAccent, AppColorTokens.dark.accent),
      'dark onCritical on critical':
          (AppColorTokens.dark.onCritical, AppColorTokens.dark.critical),
      'dark onWarning on warning':
          (AppColorTokens.dark.onWarning, AppColorTokens.dark.warning),
      'dark onSuccess on success':
          (AppColorTokens.dark.onSuccess, AppColorTokens.dark.success),
    };

    for (final entry in pairs.entries) {
      test(entry.key, () {
        final ratio = contrastRatio(entry.value.$1, entry.value.$2);
        expect(ratio, greaterThanOrEqualTo(4.5),
            reason: '${entry.key} contrast ratio is ${ratio.toStringAsFixed(2)}:1, '
                'below WCAG AA 4.5:1. Adjust the on<Color> token (or the fill) '
                'in AppColorTokens and rerun — and re-check the '
                'foreground-on-tint group above, which pulls the other way.');
      });
    }
  });

  // `textSecondary` carries ~140 call sites (list subtitles, stat labels,
  // demographic lines). It shipped at 3.69:1 on `background`, a regression
  // against the static gray600 it replaced.
  group('WCAG AA contrast (>= 4.5:1) for secondary body text', () {
    final pairs = {
      'light textSecondary on background': (
        AppColorTokens.light.textSecondary,
        AppColorTokens.light.background
      ),
      'light textSecondary on surface': (
        AppColorTokens.light.textSecondary,
        AppColorTokens.light.surface
      ),
      'dark textSecondary on background': (
        AppColorTokens.dark.textSecondary,
        AppColorTokens.dark.background
      ),
      'dark textSecondary on surface': (
        AppColorTokens.dark.textSecondary,
        AppColorTokens.dark.surface
      ),
    };

    for (final entry in pairs.entries) {
      test(entry.key, () {
        final ratio = contrastRatio(entry.value.$1, entry.value.$2);
        expect(ratio, greaterThanOrEqualTo(4.5),
            reason: '${entry.key} contrast ratio is ${ratio.toStringAsFixed(2)}:1, '
                'below WCAG AA 4.5:1. Darken/lighten textSecondary (same hue) '
                'in AppColorTokens and rerun.');
      });
    }
  });
}
