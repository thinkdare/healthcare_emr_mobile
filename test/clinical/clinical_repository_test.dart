import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:healthcare_emr_mobile/core/api/api_client.dart';
import 'package:healthcare_emr_mobile/core/database/local_database.dart';
import 'package:healthcare_emr_mobile/data/repositories/clinical_repository.dart';

class _FakeApiClient extends ApiClient {
  final Map<String, dynamic> Function(String path, Map<String, dynamic>? qp)?
      getHandler;
  final Map<String, dynamic> Function(String path, dynamic data)? postHandler;

  _FakeApiClient({this.getHandler, this.postHandler}) : super();

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async =>
      getHandler!(path, queryParameters);

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
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() async {
    await LocalDatabase.instance.clearAll();
    await LocalDatabase.instance.clearPendingSync();
  });

  group('ClinicalRepository.createVitalSign', () {
    test('records via the API and caches the result', () async {
      final fake = _FakeApiClient(postHandler: (_, __) => {
            'success': true,
            'data': {
              'id': 'v1',
              'patient_id': 'patient-1',
              'recorded_by_id': 'dr-1',
              'recorded_at': DateTime.now().toIso8601String(),
              'heart_rate': 80,
              'version': 1,
            },
          });
      final repo = ClinicalRepository(
          apiClient: fake, localDatabase: LocalDatabase.instance);

      final vital = await repo.createVitalSign('patient-1', {
        'recorded_at': DateTime.now().toIso8601String(),
        'heart_rate': 80,
      });

      expect(vital.heartRate, 80);
      final cached = await LocalDatabase.instance.getCachedVitals('patient-1');
      expect(cached, hasLength(1));
    });

    test(
        'queues an offline write, caches a placeholder, and throws on a network error',
        () async {
      final fake = _FakeApiClient(
        postHandler: (_, __) => throw Exception('SocketException: offline'),
      );
      final repo = ClinicalRepository(
          apiClient: fake, localDatabase: LocalDatabase.instance);

      final recordedAt = DateTime.now().toIso8601String();

      await expectLater(
        () => repo.createVitalSign('patient-2', {
          'recorded_at': recordedAt,
          'heart_rate': 65,
          'recorded_by_id': 'dr-2',
        }),
        throwsA(isA<Exception>().having(
            (e) => e.toString(), 'message', contains('will sync when you reconnect'))),
      );

      final pending = await LocalDatabase.instance.getPendingSyncItems();
      expect(pending, hasLength(1));
      expect(pending.first['resource_type'], 'vitals');
      expect(pending.first['operation'], 'create');

      final cached = await LocalDatabase.instance.getCachedVitals('patient-2');
      expect(cached, hasLength(1),
          reason: 'offline create should still show up immediately via the cache placeholder');
      expect(cached.first.heartRate, 65);
    });
  });

  group('ClinicalRepository.getVitalSigns', () {
    test('rethrows a non-network failure rather than swallowing it', () async {
      final fake = _FakeApiClient(
        getHandler: (_, __) => {'success': false, 'message': 'Forbidden'},
      );
      final repo = ClinicalRepository(
          apiClient: fake, localDatabase: LocalDatabase.instance);

      expect(
        () => repo.getVitalSigns('patient-3'),
        throwsA(isA<Exception>()
            .having((e) => e.toString(), 'message', contains('Forbidden'))),
      );
    });
  });
}
