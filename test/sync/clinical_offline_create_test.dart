import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_emr_mobile/core/api/api_client.dart';
import 'package:healthcare_emr_mobile/core/database/local_database.dart';
import 'package:healthcare_emr_mobile/data/repositories/clinical_repository.dart';
import 'package:healthcare_emr_mobile/data/repositories/intra_grant_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _NetworkErrorApiClient extends ApiClient {
  _NetworkErrorApiClient() : super();

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    throw Exception('SocketException: OS Error: Connection refused, errno = 111');
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

  group('ClinicalRepository.createPrescription offline', () {
    test('caches a local placeholder and queues the write with a client-generated resource id',
        () async {
      final repo = ClinicalRepository(
        apiClient: _NetworkErrorApiClient(),
        db: LocalDatabase.instance,
      );

      await expectLater(
        repo.createPrescription('pat-1', {
          'medication_name': 'Amoxicillin',
          'dosage': '500mg',
          'frequency': 'TID',
          'refills_allowed': 2,
          'prescribed_date': '2026-06-01',
          'expires_date': '2026-09-01',
        }, prescriberId: 'doc-1'),
        throwsA(isA<Exception>()),
      );

      final cached = await LocalDatabase.instance.getPrescriptionsByPatient('pat-1');
      expect(cached, hasLength(1));
      expect(cached.first.medicationName, 'Amoxicillin');
      expect(cached.first.status, 'pending');

      final pending = await LocalDatabase.instance.getPendingSyncItems();
      expect(pending, hasLength(1));
      expect(pending.first['resource_type'], 'prescriptions');
      expect(pending.first['resource_id'], cached.first.id);
      expect(pending.first['operation'], 'create');
      expect(pending.first['payload']['patient_id'], 'pat-1');
    });
  });

  group('ClinicalRepository.createVitalSign offline', () {
    test('caches a local placeholder and queues the write with a client-generated resource id',
        () async {
      final repo = ClinicalRepository(
        apiClient: _NetworkErrorApiClient(),
        db: LocalDatabase.instance,
      );

      await expectLater(
        repo.createVitalSign('pat-1', {
          'recorded_at': '2026-06-01T09:00:00Z',
          'heart_rate': 78,
          'temperature': 36.8,
        }, recordedById: 'doc-1'),
        throwsA(isA<Exception>()),
      );

      final cached = await LocalDatabase.instance.getVitalSignsByPatient('pat-1');
      expect(cached, hasLength(1));
      expect(cached.first.heartRate, 78);
      expect(cached.first.recordedById, 'doc-1');

      final pending = await LocalDatabase.instance.getPendingSyncItems();
      expect(pending, hasLength(1));
      expect(pending.first['resource_type'], 'vitals');
      expect(pending.first['resource_id'], cached.first.id);
      expect(pending.first['payload']['patient_id'], 'pat-1');
    });
  });

  group('IntraGrantRepository.createNote offline', () {
    test('caches a local placeholder and queues the write with a client-generated resource id',
        () async {
      final repo = IntraGrantRepository(
        apiClient: _NetworkErrorApiClient(),
        localDatabase: LocalDatabase.instance,
      );

      await expectLater(
        repo.createNote(
          'pat-1',
          body: 'Patient stable, no new complaints.',
          authoredById: 'doc-1',
          authoredByName: 'Dr. Doe',
        ),
        throwsA(isA<Exception>()),
      );

      final cached = await LocalDatabase.instance.getClinicalNotesByPatient('pat-1');
      expect(cached, hasLength(1));
      expect(cached.first.body, 'Patient stable, no new complaints.');
      expect(cached.first.authoredByName, 'Dr. Doe');

      final pending = await LocalDatabase.instance.getPendingSyncItems();
      expect(pending, hasLength(1));
      expect(pending.first['resource_type'], 'clinical_notes');
      expect(pending.first['resource_id'], cached.first.id);
      expect(pending.first['payload']['patient_id'], 'pat-1');
    });
  });
}
