import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_emr_mobile/core/api/api_client.dart';
import 'package:healthcare_emr_mobile/core/database/local_database.dart';
import 'package:healthcare_emr_mobile/data/models/clinical_models.dart';
import 'package:healthcare_emr_mobile/data/repositories/sync_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakeApiClient extends ApiClient {
  Map<String, dynamic> response;
  _FakeApiClient(this.response) : super();

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async =>
      response;

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async =>
      response;
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalDatabase.teardownForTesting();
    final rawDb = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await LocalDatabase.forTesting(rawDb);
  });

  tearDown(() async {
    await LocalDatabase.teardownForTesting();
  });

  group('SyncRepository.pull', () {
    test('upserts appointments from server resources into local cache', () async {
      final fake = _FakeApiClient({
        'success': true,
        'data': {
          'server_time': '2026-06-11T10:00:00Z',
          'resources': {
            'appointments': [
              {
                'id': 'appt-1',
                'version': 1,
                'updated_at': '2026-06-10T08:00:00Z',
                'deleted_at': null,
                'data': {
                  'id': 'appt-1',
                  'patient_id': 'pat-1',
                  'provider_id': 'prov-1',
                  'appointment_date': '2026-07-01T09:00:00Z',
                  'duration_minutes': 30,
                  'appointment_type': 'consultation',
                  'status': 'confirmed',
                  'reminder_sent': false,
                },
              },
            ],
          },
        },
      });

      final repo = SyncRepository(apiClient: fake);
      await repo.pull();

      final cached = await LocalDatabase.instance.getAppointmentsByPatient('pat-1');
      expect(cached, hasLength(1));
      expect(cached.first.id, 'appt-1');
      expect(cached.first.status, 'confirmed');
    });

    test('upserts prescriptions from server resources into local cache', () async {
      final fake = _FakeApiClient({
        'success': true,
        'data': {
          'server_time': '2026-06-11T10:00:00Z',
          'resources': {
            'prescriptions': [
              {
                'id': 'rx-1',
                'version': 2,
                'updated_at': '2026-06-10T08:00:00Z',
                'deleted_at': null,
                'data': {
                  'id': 'rx-1',
                  'patient_id': 'pat-1',
                  'prescriber_id': 'doc-1',
                  'medication_name': 'Metformin',
                  'dosage': '1000mg',
                  'frequency': 'BID',
                  'refills_allowed': 3,
                  'refills_remaining': 3,
                  'status': 'active',
                  'drug_interactions_checked': true,
                },
              },
            ],
          },
        },
      });

      final repo = SyncRepository(apiClient: fake);
      await repo.pull();

      final cached = await LocalDatabase.instance.getPrescriptionsByPatient('pat-1');
      expect(cached, hasLength(1));
      expect(cached.first.medicationName, 'Metformin');
    });

    test('removes soft-deleted appointments from local cache', () async {
      await LocalDatabase.instance
          .upsertAppointment(_makeAppt('appt-gone', 'pat-1'));
      expect(
        await LocalDatabase.instance.getAppointmentsByPatient('pat-1'),
        hasLength(1),
      );

      final fake = _FakeApiClient({
        'success': true,
        'data': {
          'server_time': '2026-06-11T10:00:00Z',
          'resources': {
            'appointments': [
              {
                'id': 'appt-gone',
                'version': 2,
                'updated_at': '2026-06-11T09:00:00Z',
                'deleted_at': '2026-06-11T09:00:00Z',
                'data': {'id': 'appt-gone'},
              },
            ],
          },
        },
      });

      final repo = SyncRepository(apiClient: fake);
      await repo.pull();

      final cached =
          await LocalDatabase.instance.getAppointmentsByPatient('pat-1');
      expect(cached, isEmpty);
    });

    test('removes soft-deleted lab results from local cache', () async {
      await LocalDatabase.instance.upsertLabResult(_makeLab('lab-gone', 'pat-1'));

      final fake = _FakeApiClient({
        'success': true,
        'data': {
          'server_time': '2026-06-11T10:00:00Z',
          'resources': {
            'lab_results': [
              {
                'id': 'lab-gone',
                'version': 3,
                'deleted_at': '2026-06-11T09:00:00Z',
                'data': {'id': 'lab-gone'},
              },
            ],
          },
        },
      });

      final repo = SyncRepository(apiClient: fake);
      await repo.pull();

      final cached =
          await LocalDatabase.instance.getLabResultsByPatient('pat-1');
      expect(cached, isEmpty);
    });

    test('updates lastSyncedAt from server_time', () async {
      final fake = _FakeApiClient({
        'success': true,
        'data': {
          'server_time': '2026-06-11T12:00:00Z',
          'resources': {},
        },
      });

      final repo = SyncRepository(apiClient: fake);
      await repo.pull();

      final last = await repo.getLastSyncedAt();
      expect(last, isNotNull);
      expect(last!.year, 2026);
      expect(last.month, 6);
      expect(last.day, 11);
    });
  });
}

// ── Helpers ─────────────────────────────────────────────────────────────────

AppointmentModel _makeAppt(String id, String patientId) => AppointmentModel(
      id: id,
      patientId: patientId,
      providerId: 'prov-1',
      appointmentDate: DateTime(2026, 7, 1, 9, 0),
      durationMinutes: 30,
      appointmentType: 'consultation',
      status: 'scheduled',
      reminderSent: false,
    );

LabResultModel _makeLab(String id, String patientId) => LabResultModel(
      id: id,
      patientId: patientId,
      orderedById: 'doc-1',
      testName: 'CBC',
      priority: 'routine',
      abnormalFlags: [],
      status: 'completed',
      requiresFollowup: false,
    );
