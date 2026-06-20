import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_emr_mobile/core/api/api_client.dart';
import 'package:healthcare_emr_mobile/core/database/local_database.dart';
import 'package:healthcare_emr_mobile/data/models/patient_models.dart';
import 'package:healthcare_emr_mobile/data/providers/auth_provider.dart';
import 'package:healthcare_emr_mobile/data/repositories/auth_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Fake ApiClient that switches its response by path and keeps token/tenant
/// state in plain instance fields instead of FlutterSecureStorage — there's
/// no platform channel available for secure storage under flutter_test, so
/// AuthRepository's real storage calls (saveToken/getToken/clearAll) need a
/// substitute the same way _FakeApiClient in sync_repository_pull_test.dart
/// substitutes get/post.
class _FakeAuthApiClient extends ApiClient {
  String? _token;
  String? _tenantId;

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    if (path == '/auth/login') {
      return {
        'success': true,
        'data': {'access_token': 'fake-token', 'token_type': 'Bearer'},
      };
    }
    return {'success': true, 'data': {}};
  }

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    if (path == '/auth/me') {
      return {
        'success': true,
        'data': {
          'id': 'prov-1',
          'email': 'doc@test.com',
          'full_name': 'Dr Test',
          'user_type': 'org_admin', // org admins skip facility loading
        },
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
  Future<void> saveTenantId(String tenantId) async => _tenantId = tenantId;

  @override
  Future<String?> getTenantId() async => _tenantId;

  @override
  Future<void> clearTenantId() async => _tenantId = null;

  @override
  Future<void> clearAll() async {
    _token = null;
    _tenantId = null;
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    await LocalDatabase.teardownForTesting();
    final rawDb = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await LocalDatabase.forTesting(rawDb);
  });

  tearDown(() async {
    await LocalDatabase.teardownForTesting();
  });

  group('AuthProvider.logout', () {
    test('clears the cached clinical data for the logged-in provider',
        () async {
      final fake = _FakeAuthApiClient();
      final auth = AuthProvider(
        repository: AuthRepository(apiClient: fake),
        localDatabase: LocalDatabase.instance,
      );

      await auth.login(email: 'doc@test.com', password: 'whatever');
      expect(auth.currentUserId, 'prov-1');

      await LocalDatabase.instance.upsertPatient(PatientModel(
        id: 'pat-1',
        primaryProviderId: 'prov-1',
        firstName: 'Test',
        lastName: 'Patient',
        dateOfBirth: '1990-01-01',
        gender: 'male',
        emergencyContactName: 'Contact',
        emergencyContactPhone: '000',
        allergies: const [],
        currentMedications: const [],
        chronicConditions: const [],
        patientPortalEnabled: false,
        isActive: true,
      ));
      await LocalDatabase.instance.queuePendingSync(
        id: 'sync-1',
        resourceType: 'patients',
        resourceId: 'pat-1',
        operation: 'update',
        payload: {'medical_history': 'Unsynced offline edit'},
      );

      await auth.logout();

      expect(
        await LocalDatabase.instance.getPatients(providerId: 'prov-1'),
        isEmpty,
      );
      // Unsynced offline writes must survive logout — they aren't lost just
      // because the user logged out before the next sync ran.
      expect(await LocalDatabase.instance.getPendingSyncCount(), 1);
    });

    test('is a no-op on the cache when nobody is logged in', () async {
      final fake = _FakeAuthApiClient();
      final auth = AuthProvider(
        repository: AuthRepository(apiClient: fake),
        localDatabase: LocalDatabase.instance,
      );

      // No login() call — _currentUser is null. Must not throw.
      await auth.logout();
    });
  });
}
