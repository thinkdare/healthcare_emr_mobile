import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:healthcare_emr_mobile/core/api/api_client.dart';
import 'package:healthcare_emr_mobile/core/database/local_database.dart';
import 'package:healthcare_emr_mobile/data/repositories/patient_repository.dart';

class _FakeApiClient extends ApiClient {
  final Map<String, dynamic> Function(String path)? getHandler;
  final Map<String, dynamic> Function(String path, dynamic data)? postHandler;

  _FakeApiClient({this.getHandler, this.postHandler}) : super();

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async =>
      getHandler!(path);

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async =>
      postHandler!(path, data);
}

Map<String, dynamic> _patientJson(String id, String providerId) => {
      'id': id,
      'primary_provider_id': providerId,
      'first_name': 'Jane',
      'last_name': 'Doe',
      'date_of_birth': '1990-01-01',
      'gender': 'female',
      'emergency_contact_name': 'John Doe',
      'emergency_contact_phone': '555-0100',
    };

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() async {
    // Tests share the LocalDatabase singleton (matches the real app, which
    // only ever wants one) — clear between tests to avoid cross-test bleed.
    await LocalDatabase.instance.clearAll();
  });

  group('PatientRepository.getPatients', () {
    test('fetches from the API and caches the first page', () async {
      const providerId = 'provider-happy';
      final fake = _FakeApiClient(getHandler: (_) => {
            'success': true,
            'data': [_patientJson('p1', providerId)],
          });
      final repo =
          PatientRepository(apiClient: fake, localDatabase: LocalDatabase.instance);

      final result = await repo.getPatients(providerId: providerId, forceRefresh: true);

      expect(result.isFromCache, isFalse);
      expect(result.patients, hasLength(1));
      expect(result.patients.first.firstName, 'Jane');

      // Cached as a side effect — a cache-fresh read should now see it
      // without needing the (still-set-to-throw-if-called-again) API.
      final cached = await LocalDatabase.instance
          .getPatients(providerId: providerId);
      expect(cached, hasLength(1));
    });

    test('falls back to the cache when the API call throws', () async {
      const providerId = 'provider-fallback';
      // Seed the cache directly via a successful fetch first.
      final seedFake = _FakeApiClient(getHandler: (_) => {
            'success': true,
            'data': [_patientJson('p2', providerId)],
          });
      await PatientRepository(
              apiClient: seedFake, localDatabase: LocalDatabase.instance)
          .getPatients(providerId: providerId, forceRefresh: true);

      // Now simulate the device going offline.
      final offlineFake =
          _FakeApiClient(getHandler: (_) => throw Exception('SocketException'));
      final repo = PatientRepository(
          apiClient: offlineFake, localDatabase: LocalDatabase.instance);

      final result =
          await repo.getPatients(providerId: providerId, forceRefresh: true);

      expect(result.isFromCache, isTrue);
      expect(result.patients, hasLength(1));
      expect(result.patients.first.id, 'p2');
    });
  });

  group('PatientRepository.createPatient', () {
    test('throws when the API responds with success: false', () async {
      final fake = _FakeApiClient(
        postHandler: (_, __) => {'success': false, 'message': 'Validation failed'},
      );
      final repo =
          PatientRepository(apiClient: fake, localDatabase: LocalDatabase.instance);

      expect(
        () => repo.createPatient({'first_name': 'X'}),
        throwsA(isA<Exception>().having(
            (e) => e.toString(), 'message', contains('Validation failed'))),
      );
    });

    // Regression: this used to queue the offline create with resourceId:
    // null. SyncController::push() requires 'changes.*.resource_id' (a
    // uuid) on every change — a null resource_id means the whole offline
    // patient create would be rejected by the backend the moment the
    // device reconnects and tries to sync it.
    test(
        'queues the offline create with a client-generated resource_id when the API is unreachable',
        () async {
      final fake = _FakeApiClient(
        postHandler: (_, __) => throw Exception('SocketException: offline'),
      );
      final repo = PatientRepository(
          apiClient: fake, localDatabase: LocalDatabase.instance);

      await expectLater(
        () => repo.createPatient({'first_name': 'Offline', 'last_name': 'Patient'}),
        throwsA(isA<Exception>().having(
            (e) => e.toString(), 'message', contains('will be created when you reconnect'))),
      );

      final pending = await LocalDatabase.instance.getPendingSyncItems();
      expect(pending, hasLength(1));
      expect(pending.first['resource_type'], 'patients');
      expect(pending.first['operation'], 'create');
      final resourceId = pending.first['resource_id'] as String?;
      expect(resourceId, isNotNull);
      expect(
        RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')
            .hasMatch(resourceId!),
        isTrue,
        reason: 'resource_id must be a valid uuid — the backend requires one',
      );

      await LocalDatabase.instance.clearPendingSync();
    });
  });
}
