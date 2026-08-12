// test/config/theme_mode_provider_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:healthcare_emr_mobile/data/providers/theme_mode_provider.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('defaults to system, and persists an explicit override across loads', () async {
    final provider = ThemeModeProvider();
    await provider.load();
    expect(provider.mode, ThemeMode.system);

    await provider.setMode(ThemeMode.dark);
    expect(provider.mode, ThemeMode.dark);

    final reloaded = ThemeModeProvider();
    await reloaded.load();
    expect(reloaded.mode, ThemeMode.dark);
  });
}
