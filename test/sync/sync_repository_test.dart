import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:healthcare_emr_mobile/core/api/api_client.dart';
import 'package:healthcare_emr_mobile/core/database/local_database.dart';
import 'package:healthcare_emr_mobile/data/models/clinical_record_models.dart';
import 'package:healthcare_emr_mobile/data/repositories/sync_repository.dart';

VitalSignModel _seedVital(String id, String patientId) => VitalSignModel(
      id: id,
      patientId: patientId,
      recordedById: 'dr-1',
      recordedAt: DateTime.now(),
      heartRate: 70,
      version: 1,
    );

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    await LocalDatabase.instance.clearAll();
    await LocalDatabase.instance.clearPendingSync();
  });

  group('SyncRepository.pull', () {
    test('applies a pulled patient into the local cache', () async {
      final fake = _FakeApiClient(getHandler: (_) => {
            'success': true,
            'data': {
              'server_time': DateTime.now().toIso8601String(),
              'resources': {
                'patients': [
                  {
                    'id': 'pull-patient-1',
                    'version': 2,
                    'updated_at': DateTime.now().toIso8601String(),
                    'deleted_at': null,
                    'data': {
                      'id': 'pull-patient-1',
                      'primary_provider_id': 'dr-1',
                      'first_name': 'Pulled',
                      'last_name': 'Patient',
                      'date_of_birth': '1990-01-01',
                      'gender': 'male',
                      'emergency_contact_name': 'X',
                      'emergency_contact_phone': '000',
                    },
                  },
                ],
                'vitals': [],
                'diagnoses': [],
              },
            },
          });
      final repo = SyncRepository(
          apiClient: fake, localDatabase: LocalDatabase.instance);

      await repo.pull();

      final cached = await LocalDatabase.instance.getPatient('pull-patient-1');
      expect(cached, isNotNull);
      expect(cached!.firstName, 'Pulled');
    });

    test('removes a soft-deleted vital from the local cache', () async {
      // Seed the cache with a vital that the next pull will report deleted.
      await LocalDatabase.instance.upsertVital(
        _seedVital('vital-to-delete', 'patient-x'),
      );
      var cached = await LocalDatabase.instance.getCachedVitals('patient-x');
      expect(cached, hasLength(1));

      final fake = _FakeApiClient(getHandler: (_) => {
            'success': true,
            'data': {
              'server_time': DateTime.now().toIso8601String(),
              'resources': {
                'patients': [],
                'vitals': [
                  {
                    'id': 'vital-to-delete',
                    'version': 2,
                    'updated_at': DateTime.now().toIso8601String(),
                    'deleted_at': DateTime.now().toIso8601String(),
                    'data': <String, dynamic>{},
                  },
                ],
                'diagnoses': [],
              },
            },
          });
      final repo = SyncRepository(
          apiClient: fake, localDatabase: LocalDatabase.instance);

      await repo.pull();

      cached = await LocalDatabase.instance.getCachedVitals('patient-x');
      expect(cached, isEmpty);
    });
  });

  group('SyncRepository.push', () {
    test('throws when the API responds with success: false', () async {
      await LocalDatabase.instance.queuePendingSync(
        id: 'q1',
        resourceType: 'vitals',
        resourceId: 'v1',
        operation: 'create',
        payload: {'patient_id': 'patient-1'},
      );

      final fake = _FakeApiClient(
        postHandler: (_, __) => {'success': false, 'message': 'Push rejected'},
      );
      final repo = SyncRepository(
          apiClient: fake, localDatabase: LocalDatabase.instance);

      expect(
        () => repo.push(),
        throwsA(isA<Exception>().having(
            (e) => e.toString(), 'message', contains('Push rejected'))),
      );
    });
  });
}
