import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_emr_mobile/core/api/api_client.dart';
import 'package:healthcare_emr_mobile/core/database/local_database.dart';
import 'package:healthcare_emr_mobile/data/models/clinical_models.dart';
import 'package:healthcare_emr_mobile/data/models/clinical_record_models.dart';
import 'package:healthcare_emr_mobile/data/repositories/clinical_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// ── Fakes ─────────────────────────────────────────────────────────────────────

class _SuccessApiClient extends ApiClient {
  final Map<String, dynamic> _response;
  _SuccessApiClient(this._response) : super();

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async =>
      _response;
}

class _NetworkErrorApiClient extends ApiClient {
  _NetworkErrorApiClient() : super();

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    throw Exception('SocketException: OS Error: Connection refused, errno = 111');
  }
}

// ── Test data factories ────────────────────────────────────────────────────────

Map<String, dynamic> _apptJson(String id, String patientId, {String status = 'scheduled'}) => {
      'id': id,
      'patient_id': patientId,
      'provider_id': 'prov-1',
      'appointment_date': '2026-07-01T09:00:00.000',
      'duration_minutes': 30,
      'appointment_type': 'consultation',
      'status': status,
      'reminder_sent': false,
    };

Map<String, dynamic> _rxJson(String id, String patientId) => {
      'id': id,
      'patient_id': patientId,
      'prescriber_id': 'doc-1',
      'medication_name': 'Amoxicillin',
      'dosage': '500mg',
      'frequency': 'TID',
      'refills_allowed': 2,
      'refills_remaining': 2,
      'status': 'active',
      'drug_interactions_checked': false,
    };

Map<String, dynamic> _labJson(String id, String patientId) => {
      'id': id,
      'patient_id': patientId,
      'ordered_by_id': 'doc-1',
      'test_name': 'CBC',
      'priority': 'routine',
      'abnormal_flags': ['WBC_HIGH'],
      'status': 'pending',
      'requires_followup': false,
    };

Map<String, dynamic> _vitalJson(String id, String patientId) => {
      'id': id,
      'patient_id': patientId,
      'recorded_by_id': 'nurse-1',
      'recorded_at': '2026-06-10T08:00:00.000',
      'blood_pressure_systolic': 120,
      'blood_pressure_diastolic': 80,
      'heart_rate': 72,
      'version': 1,
    };

Map<String, dynamic> _dxJson(String id, String patientId) => {
      'id': id,
      'patient_id': patientId,
      'diagnosed_by_id': 'doc-1',
      'description': 'Type 2 Diabetes',
      'diagnosis_type': 'primary',
      'status': 'active',
      'version': 1,
    };

// ── Helpers ───────────────────────────────────────────────────────────────────

AppointmentModel _makeAppt(String id, String patientId, {String status = 'scheduled'}) =>
    AppointmentModel.fromJson(_apptJson(id, patientId, status: status));

PrescriptionModel _makeRx(String id, String patientId) =>
    PrescriptionModel.fromJson(_rxJson(id, patientId));

LabResultModel _makeLab(String id, String patientId) =>
    LabResultModel.fromJson(_labJson(id, patientId));

VitalSignModel _makeVital(String id, String patientId) =>
    VitalSignModel.fromJson(_vitalJson(id, patientId));

DiagnosisModel _makeDx(String id, String patientId) =>
    DiagnosisModel.fromJson(_dxJson(id, patientId));

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
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

  ClinicalRepository makeRepo(ApiClient client) =>
      ClinicalRepository(apiClient: client, db: LocalDatabase.instance);

  group('ClinicalRepository offline-first — getAppointments', () {
    test('upserts API results to local cache on success', () async {
      final repo = makeRepo(_SuccessApiClient({
        'success': true,
        'data': [_apptJson('appt-1', 'pat-1'), _apptJson('appt-2', 'pat-1')],
      }));

      await repo.getAppointments('pat-1');

      final cached = await LocalDatabase.instance.getAppointmentsByPatient('pat-1');
      expect(cached, hasLength(2));
      expect(cached.map((a) => a.id), containsAll(['appt-1', 'appt-2']));
    });

    test('returns cached data on network error', () async {
      await LocalDatabase.instance.upsertAppointment(_makeAppt('appt-1', 'pat-1'));
      await LocalDatabase.instance.upsertAppointment(_makeAppt('appt-2', 'pat-1'));

      final repo = makeRepo(_NetworkErrorApiClient());
      final results = await repo.getAppointments('pat-1');

      expect(results, hasLength(2));
    });

    test('rethrows on network error when cache is empty', () async {
      final repo = makeRepo(_NetworkErrorApiClient());

      expect(() => repo.getAppointments('pat-1'), throwsException);
    });

    test('filters cached results by status on network error', () async {
      await LocalDatabase.instance.upsertAppointment(_makeAppt('appt-s', 'pat-1', status: 'scheduled'));
      await LocalDatabase.instance.upsertAppointment(_makeAppt('appt-c', 'pat-1', status: 'cancelled'));

      final repo = makeRepo(_NetworkErrorApiClient());
      final results = await repo.getAppointments('pat-1', status: 'scheduled');

      expect(results, hasLength(1));
      expect(results.first.id, 'appt-s');
    });
  });

  group('ClinicalRepository offline-first — getPrescriptions', () {
    test('upserts API results to local cache on success', () async {
      final repo = makeRepo(_SuccessApiClient({
        'success': true,
        'data': [_rxJson('rx-1', 'pat-1')],
      }));

      await repo.getPrescriptions('pat-1');

      final cached = await LocalDatabase.instance.getPrescriptionsByPatient('pat-1');
      expect(cached, hasLength(1));
      expect(cached.first.id, 'rx-1');
    });

    test('returns cached data on network error', () async {
      await LocalDatabase.instance.upsertPrescription(_makeRx('rx-1', 'pat-1'));

      final repo = makeRepo(_NetworkErrorApiClient());
      final results = await repo.getPrescriptions('pat-1');

      expect(results, hasLength(1));
      expect(results.first.id, 'rx-1');
    });

    test('rethrows on network error when cache is empty', () async {
      final repo = makeRepo(_NetworkErrorApiClient());

      expect(() => repo.getPrescriptions('pat-1'), throwsException);
    });
  });

  group('ClinicalRepository offline-first — getLabResults', () {
    test('upserts API results to local cache on success', () async {
      final repo = makeRepo(_SuccessApiClient({
        'success': true,
        'data': [_labJson('lab-1', 'pat-1')],
      }));

      await repo.getLabResults('pat-1');

      final cached = await LocalDatabase.instance.getLabResultsByPatient('pat-1');
      expect(cached, hasLength(1));
      expect(cached.first.id, 'lab-1');
      expect(cached.first.abnormalFlags, ['WBC_HIGH']);
    });

    test('returns cached data on network error', () async {
      await LocalDatabase.instance.upsertLabResult(_makeLab('lab-1', 'pat-1'));

      final repo = makeRepo(_NetworkErrorApiClient());
      final results = await repo.getLabResults('pat-1');

      expect(results, hasLength(1));
    });

    test('rethrows on network error when cache is empty', () async {
      final repo = makeRepo(_NetworkErrorApiClient());

      expect(() => repo.getLabResults('pat-1'), throwsException);
    });
  });

  group('ClinicalRepository offline-first — getVitalSigns', () {
    test('upserts API results to local cache on success', () async {
      final repo = makeRepo(_SuccessApiClient({
        'success': true,
        'data': [_vitalJson('vs-1', 'pat-1')],
      }));

      await repo.getVitalSigns('pat-1');

      final cached = await LocalDatabase.instance.getVitalSignsByPatient('pat-1');
      expect(cached, hasLength(1));
      expect(cached.first.id, 'vs-1');
    });

    test('returns cached data on network error', () async {
      await LocalDatabase.instance.upsertVitalSign(_makeVital('vs-1', 'pat-1'));

      final repo = makeRepo(_NetworkErrorApiClient());
      final results = await repo.getVitalSigns('pat-1');

      expect(results, hasLength(1));
    });

    test('rethrows on network error when cache is empty', () async {
      final repo = makeRepo(_NetworkErrorApiClient());

      expect(() => repo.getVitalSigns('pat-1'), throwsException);
    });
  });

  group('ClinicalRepository offline-first — getDiagnoses', () {
    test('upserts API results to local cache on success', () async {
      final repo = makeRepo(_SuccessApiClient({
        'success': true,
        'data': [_dxJson('dx-1', 'pat-1')],
      }));

      await repo.getDiagnoses('pat-1');

      final cached = await LocalDatabase.instance.getDiagnosesByPatient('pat-1');
      expect(cached, hasLength(1));
      expect(cached.first.id, 'dx-1');
    });

    test('returns cached data on network error', () async {
      await LocalDatabase.instance.upsertDiagnosis(_makeDx('dx-1', 'pat-1'));

      final repo = makeRepo(_NetworkErrorApiClient());
      final results = await repo.getDiagnoses('pat-1');

      expect(results, hasLength(1));
    });

    test('rethrows on network error when cache is empty', () async {
      final repo = makeRepo(_NetworkErrorApiClient());

      expect(() => repo.getDiagnoses('pat-1'), throwsException);
    });
  });
}
