// test/shared/adaptive_badge_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_emr_mobile/config/app_color_scope.dart';
import 'package:healthcare_emr_mobile/config/app_color_tokens.dart';
import 'package:healthcare_emr_mobile/presentation/shared/widgets/adaptive_badge.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        home: AppColorScope(
          tokens: AppColorTokens.light,
          child: Scaffold(body: child),
        ),
      );

  testWidgets('critical badge shows label and warning icon by default', (tester) async {
    await tester.pumpWidget(wrap(
      const AdaptiveBadge(label: 'ALLERGY', variant: BadgeVariant.critical),
    ));
    expect(find.text('ALLERGY'), findsOneWidget);
    expect(find.byIcon(Icons.warning_rounded), findsOneWidget);
  });

  testWidgets('accent badge uses accentTint background', (tester) async {
    await tester.pumpWidget(wrap(
      const AdaptiveBadge(label: 'Prescribe', variant: BadgeVariant.accent),
    ));
    final container = tester.widget<Container>(find.byType(Container).first);
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.color, AppColorTokens.light.accentTint);
  });
}
