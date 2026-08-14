import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_emr_mobile/config/app_color_scope.dart';
import 'package:healthcare_emr_mobile/config/app_color_tokens.dart';
import 'package:healthcare_emr_mobile/presentation/shared/widgets/stat_tile.dart';

void main() {
  testWidgets('shows value and label, and is tappable when onTap is provided',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: AppColorScope(
        tokens: AppColorTokens.light,
        child: Scaffold(
          body: StatTile(
            icon: Icons.people,
            label: 'Total Patients',
            value: '248',
            color: AppColorTokens.light.accent,
            onTap: () => tapped = true,
          ),
        ),
      ),
    ));

    expect(find.text('248'), findsOneWidget);
    expect(find.text('Total Patients'), findsOneWidget);
    await tester.tap(find.byType(StatTile));
    expect(tapped, isTrue);
  });
}
