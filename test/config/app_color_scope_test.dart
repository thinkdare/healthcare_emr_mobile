import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_emr_mobile/config/app_color_scope.dart';
import 'package:healthcare_emr_mobile/config/app_color_tokens.dart';
import 'package:healthcare_emr_mobile/config/app_colors.dart';

void main() {
  testWidgets('AppColors.of(context) returns the nearest AppColorScope tokens',
      (tester) async {
    late AppColorTokens captured;
    await tester.pumpWidget(
      AppColorScope(
        tokens: AppColorTokens.dark,
        child: Builder(
          builder: (context) {
            captured = AppColors.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(captured, AppColorTokens.dark);
  });
}
