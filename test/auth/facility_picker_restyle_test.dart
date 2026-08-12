import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:healthcare_emr_mobile/config/app_color_scope.dart';
import 'package:healthcare_emr_mobile/config/app_color_tokens.dart';
import 'package:healthcare_emr_mobile/core/api/api_client.dart';
import 'package:healthcare_emr_mobile/data/providers/auth_provider.dart';
import 'package:healthcare_emr_mobile/data/repositories/auth_repository.dart';
import 'package:healthcare_emr_mobile/presentation/auth/screens/facility_picker_screen.dart';
import 'package:healthcare_emr_mobile/presentation/shared/widgets/adaptive_card.dart';

void main() {
  testWidgets('greeting card renders as an AdaptiveCard', (tester) async {
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(
            create: (_) => AuthProvider(repository: AuthRepository(apiClient: ApiClient()))),
      ],
      child: MaterialApp(
        home: AppColorScope(
          tokens: AppColorTokens.light,
          child: const FacilityPickerScreen(),
        ),
      ),
    ));
    expect(find.byType(AdaptiveCard), findsWidgets);
  });
}
