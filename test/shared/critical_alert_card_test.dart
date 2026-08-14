import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_emr_mobile/config/app_color_scope.dart';
import 'package:healthcare_emr_mobile/config/app_color_tokens.dart';
import 'package:healthcare_emr_mobile/presentation/shared/widgets/critical_alert_card.dart';

void main() {
  testWidgets('renders title and every item, high-contrast critical styling', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AppColorScope(
        tokens: AppColorTokens.light,
        child: Scaffold(
          body: CriticalAlertCard(
            title: 'CRITICAL ALLERGY',
            items: const ['Penicillin — Anaphylaxis', 'Peanuts — Severe'],
          ),
        ),
      ),
    ));

    expect(find.text('CRITICAL ALLERGY'), findsOneWidget);
    expect(find.text('Penicillin — Anaphylaxis'), findsOneWidget);
    expect(find.text('Peanuts — Severe'), findsOneWidget);

    final container = tester.widget<Container>(find.byType(Container).first);
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.color, AppColorTokens.light.criticalTint);
  });
}
