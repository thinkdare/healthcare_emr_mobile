// test/shared/adaptive_list_row_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_emr_mobile/config/app_color_scope.dart';
import 'package:healthcare_emr_mobile/config/app_color_tokens.dart';
import 'package:healthcare_emr_mobile/presentation/shared/widgets/adaptive_list_row.dart';

void main() {
  testWidgets('renders leading, title, subtitle and trailing; onTap fires', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: AppColorScope(
        tokens: AppColorTokens.light,
        child: Scaffold(
          body: AdaptiveListRow(
            leading: const CircleAvatar(child: Text('JB')),
            title: 'James Bello',
            subtitle: 'M · 42y · O+',
            trailing: const Icon(Icons.chevron_right),
            onTap: () => tapped = true,
          ),
        ),
      ),
    ));

    expect(find.text('James Bello'), findsOneWidget);
    expect(find.text('M · 42y · O+'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    await tester.tap(find.text('James Bello'));
    expect(tapped, isTrue);
  });
}
