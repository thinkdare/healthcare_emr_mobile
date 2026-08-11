import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:healthcare_emr_mobile/core/api/api_client.dart';
import 'package:healthcare_emr_mobile/core/database/local_database.dart';
import 'package:healthcare_emr_mobile/data/providers/auth_provider.dart';
import 'package:healthcare_emr_mobile/data/providers/organization_provider.dart';
import 'package:healthcare_emr_mobile/data/repositories/auth_repository.dart';
import 'package:healthcare_emr_mobile/data/repositories/organization_repository.dart';
import 'package:healthcare_emr_mobile/presentation/auth/screens/login_screen.dart';

/// Fakes only the network boundary (ApiClient.post) so the real
/// OrganizationRepository/AuthRepository and LoginScreen widget logic run
/// unmodified — same pattern as test/organization/organization_repository_test.dart.
class _FakeApiClient extends ApiClient {
  final Map<String, dynamic> Function(String path, dynamic data)? postHandler;

  _FakeApiClient({this.postHandler}) : super();

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async =>
      postHandler!(path, data);
}

Widget _wrap(ApiClient apiClient) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => AuthProvider(
          repository: AuthRepository(apiClient: apiClient),
          localDatabase: LocalDatabase.instance,
        ),
      ),
      ChangeNotifierProvider(
        create: (_) => OrganizationProvider(
          repository: OrganizationRepository(apiClient: apiClient),
        ),
      ),
    ],
    child: const MaterialApp(home: LoginScreen()),
  );
}

void main() {
  group('LoginScreen', () {
    testWidgets('renders the email step on initial load', (tester) async {
      await tester.pumpWidget(_wrap(_FakeApiClient()));

      expect(find.text('Healthcare EMR'), findsOneWidget);
      expect(find.text('Provider Login'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Password'), findsNothing);
      expect(find.text('Next'), findsOneWidget);
    });

    testWidgets('invalid email shows a validation error without calling the API',
        (tester) async {
      var called = false;
      await tester.pumpWidget(_wrap(_FakeApiClient(postHandler: (_, __) {
        called = true;
        return {'success': true, 'data': {}};
      })));

      await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'not-an-email');
      await tester.tap(find.text('Next'));
      await tester.pump();

      expect(find.text('Please enter a valid email address.'), findsOneWidget);
      expect(called, isFalse);
    });

    testWidgets(
        'checking a valid email reveals the facility and password step',
        (tester) async {
      await tester.pumpWidget(_wrap(_FakeApiClient(postHandler: (path, data) {
        expect(path, '/auth/check-email');
        expect(data, {'email': 'doctor@lagosgeneral.ng'});
        return {
          'success': true,
          'data': {
            'exists': true,
            'has_password': true,
            'facilities': [
              {
                'id': 'facility-1',
                'name': 'Lagos General Hospital (Main Campus)',
                'slug': 'lagos-main',
                'type': 'hospital',
                'organization': {
                  'id': 'org-1',
                  'name': 'Lagos General Hospital Group',
                },
              },
            ],
          },
        };
      })));

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'doctor@lagosgeneral.ng',
      );
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Lagos General Hospital (Main Campus)'), findsOneWidget);
      expect(find.text('Lagos General Hospital Group'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
      expect(find.text('Login'), findsOneWidget);
    });

    testWidgets('unknown email shows a not-found error', (tester) async {
      await tester.pumpWidget(_wrap(_FakeApiClient(postHandler: (_, __) => {
            'success': true,
            'data': {'exists': false, 'has_password': false, 'facilities': []},
          })));

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'nobody@nowhere.ng',
      );
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('No account found for this email address.'), findsOneWidget);
    });

    testWidgets('a connection failure shows a distinct error from unknown email',
        (tester) async {
      await tester.pumpWidget(_wrap(_FakeApiClient(postHandler: (_, __) {
        throw ApiException('Network error: connection timed out');
      })));

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'doctor@lagosgeneral.ng',
      );
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('No account found for this email address.'), findsNothing);
      expect(
        find.text('Unable to reach the server. Check your connection and try again.'),
        findsOneWidget,
      );
    });
  });
}
