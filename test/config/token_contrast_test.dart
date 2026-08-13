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
}
