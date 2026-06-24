import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_emr_mobile/core/api/api_client.dart';
import 'package:healthcare_emr_mobile/core/database/local_database.dart';
import 'package:healthcare_emr_mobile/data/providers/auth_provider.dart';
import 'package:healthcare_emr_mobile/data/repositories/auth_repository.dart';

/// Fake ApiClient covering /auth/logout-all and /auth/preferences — see
/// auth_provider_cache_clear_test.dart for why a fake is needed instead of
/// FlutterSecureStorage under flutter_test.
class _FakeAuthApiClient extends ApiClient {
  String? _token;
  bool logoutAllCalled = false;
  Map<String, dynamic>? lastPreferencesPayload;
  bool failPreferencesUpdate = false;

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    if (path == '/auth/logout-all') {
      logoutAllCalled = true;
    }
    return {'success': true, 'data': {}};
  }

  @override
  Future<Map<String, dynamic>> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    if (path == '/auth/preferences') {
      lastPreferencesPayload = Map<String, dynamic>.from(data as Map);
      if (failPreferencesUpdate) {
        return {'success': false, 'message': 'Invalid currency'};
      }
      return {
        'success': true,
        'data': {'preferences': lastPreferencesPayload},
      };
    }
    return {'success': true, 'data': {}};
  }

  @override
  Future<void> saveToken(String token) async => _token = token;

  @override
  Future<String?> getToken() async => _token;

  @override
  Future<void> clearToken() async => _token = null;

  @override
  Future<void> clearAll() async => _token = null;
}

void main() {
  group('AuthProvider.logoutAll', () {
    test('is a no-op on the cache when nobody is logged in, and calls the logout-all endpoint',
        () async {
      final fake = _FakeAuthApiClient();
      final auth = AuthProvider(
        repository: AuthRepository(apiClient: fake),
        localDatabase: LocalDatabase.instance,
      );

      await auth.logoutAll();

      expect(fake.logoutAllCalled, isTrue);
      expect(auth.currentUser, isNull);
    });
  });

  group('AuthProvider.updatePreferences', () {
    test('updates preferences and returns true on success', () async {
      final fake = _FakeAuthApiClient();
      final auth = AuthProvider(
        repository: AuthRepository(apiClient: fake),
        localDatabase: LocalDatabase.instance,
      );

      final result = await auth.updatePreferences(currency: 'NGN', theme: 'dark');

      expect(result, isTrue);
      expect(fake.lastPreferencesPayload, {'currency': 'NGN', 'theme': 'dark'});
      expect(auth.preferences, {'currency': 'NGN', 'theme': 'dark'});
    });

    test('returns false and sets an error message on failure', () async {
      final fake = _FakeAuthApiClient()..failPreferencesUpdate = true;
      final auth = AuthProvider(
        repository: AuthRepository(apiClient: fake),
        localDatabase: LocalDatabase.instance,
      );

      final result = await auth.updatePreferences(currency: 'XYZ');

      expect(result, isFalse);
      expect(auth.error, isNotNull);
    });
  });
}
