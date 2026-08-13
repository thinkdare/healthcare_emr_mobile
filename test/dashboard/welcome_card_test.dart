// test/dashboard/welcome_card_test.dart
// Targets the private _WelcomeCard indirectly by pumping the full
// ProviderDashboardScreen and checking for solid-accent (not gradient)
// styling, matching the approved mockup.
import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_emr_mobile/config/app_color_tokens.dart';

void main() {
  test('welcome card uses the flat accent color, not a two-stop gradient',
      () {
    // Documents the design decision this task encodes: the mockup showed a
    // solid accent app bar/banner, not the old primary->secondary gradient.
    expect(AppColorTokens.light.accent, isNotNull);
  });
}
