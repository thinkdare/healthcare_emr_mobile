// Extends the existing test/auth/login_screen_test.dart coverage — this
// file only asserts the visual-layer contract, not auth behavior (already
// covered there).
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:healthcare_emr_mobile/config/app_color_scope.dart';
import 'package:healthcare_emr_mobile/config/app_color_tokens.dart';
import 'package:healthcare_emr_mobile/core/api/api_client.dart';
import 'package:healthcare_emr_mobile/data/providers/auth_provider.dart';
import 'package:healthcare_emr_mobile/data/providers/organization_provider.dart';
import 'package:healthcare_emr_mobile/data/repositories/auth_repository.dart';
import 'package:healthcare_emr_mobile/data/repositories/organization_repository.dart';
import 'package:healthcare_emr_mobile/presentation/auth/screens/login_screen.dart';
import 'package:healthcare_emr_mobile/presentation/shared/widgets/adaptive_card.dart';

class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super();
  @override
  Future<Map<String, dynamic>> post(String path,
          {dynamic data, Map<String, dynamic>? queryParameters, Options? options}) async =>
      {'success': true, 'data': {}};
}

void main() {
  testWidgets('login form is wrapped in an AdaptiveCard and keeps its existing copy',
      (tester) async {
    final apiClient = _FakeApiClient();
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(
            create: (_) => AuthProvider(repository: AuthRepository(apiClient: apiClient))),
        ChangeNotifierProvider(
            create: (_) =>
                OrganizationProvider(repository: OrganizationRepository(apiClient: apiClient))),
      ],
      child: MaterialApp(
        home: AppColorScope(
          tokens: AppColorTokens.light,
          child: const LoginScreen(),
        ),
      ),
    ));

    expect(find.text('Healthcare EMR'), findsOneWidget);
    expect(find.text('Provider Login'), findsOneWidget);
    expect(find.byType(AdaptiveCard), findsOneWidget);
  });
}
