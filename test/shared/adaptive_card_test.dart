// test/shared/adaptive_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_emr_mobile/config/app_color_scope.dart';
import 'package:healthcare_emr_mobile/config/app_color_tokens.dart';
import 'package:healthcare_emr_mobile/presentation/shared/widgets/adaptive_card.dart';

void main() {
  testWidgets('renders child inside a rounded, surface-colored container', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AppColorScope(
        tokens: AppColorTokens.light,
        child: Scaffold(
          body: AdaptiveCard(child: const Text('inside')),
        ),
      ),
    ));

    expect(find.text('inside'), findsOneWidget);
    final container = tester.widget<Container>(find.byType(Container).first);
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.color, AppColorTokens.light.surface);
    expect((decoration.borderRadius as BorderRadius).topLeft.x, 16);
  });

  testWidgets('onTap makes the card tappable', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: AppColorScope(
        tokens: AppColorTokens.light,
        child: Scaffold(
          body: AdaptiveCard(onTap: () => tapped = true, child: const Text('tap me')),
        ),
      ),
    ));

    await tester.tap(find.text('tap me'));
    expect(tapped, isTrue);
  });
}
