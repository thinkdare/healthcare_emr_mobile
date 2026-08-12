// test/config/app_color_tokens_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_emr_mobile/config/app_color_tokens.dart';

void main() {
  test('light and dark tokens have distinct, correctly-typed brightness', () {
    expect(AppColorTokens.light.brightness, Brightness.light);
    expect(AppColorTokens.dark.brightness, Brightness.dark);
    expect(AppColorTokens.light.background, isNot(AppColorTokens.dark.background));
    expect(AppColorTokens.light.accent, const Color(0xFF1D4ED8));
    expect(AppColorTokens.dark.accent, const Color(0xFF5B87FA));
  });
}
