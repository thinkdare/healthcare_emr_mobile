import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:healthcare_emr_mobile/config/app_color_scope.dart';
import 'package:healthcare_emr_mobile/config/app_color_tokens.dart';
import 'package:healthcare_emr_mobile/data/providers/theme_mode_provider.dart';

void main() {
  testWidgets('tapping Dark in the Appearance segmented control calls setMode(dark)',
      (tester) async {
    final provider = ThemeModeProvider();
    await tester.pumpWidget(
      MultiProvider(
        providers: [ChangeNotifierProvider.value(value: provider)],
        child: MaterialApp(
          home: AppColorScope(
            tokens: AppColorTokens.light,
            child: Scaffold(
              body: Consumer<ThemeModeProvider>(
                builder: (context, tm, _) => SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                    ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                    ButtonSegment(value: ThemeMode.system, label: Text('System')),
                  ],
                  selected: {tm.mode},
                  onSelectionChanged: (s) => tm.setMode(s.first),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Dark'));
    await tester.pump();
    expect(provider.mode, ThemeMode.dark);
  });
}
