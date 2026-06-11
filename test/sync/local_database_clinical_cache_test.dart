import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_emr_mobile/core/database/local_database.dart';
import 'package:healthcare_emr_mobile/data/models/clinical_models.dart';
import 'package:healthcare_emr_mobile/data/models/clinical_record_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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

  // ── Appointments ──────────────────────────────────────────────────────────

  group('appointments_cache', () {
    test('upsertAppointment and getAppointmentsByPatient round-trips correctly',
        () async {
      final appt = AppointmentModel(
        id: 'appt-1',
        patientId: 'pat-1',
        providerId: 'prov-1',
        appointmentDate: DateTime(2026, 7, 1, 9, 0),
        durationMinutes: 30,
        appointmentType: 'consultation',
        status: 'scheduled',
        reminderSent: false,
      );

      await LocalDatabase.instance.upsertAppointment(appt);
      final results = await LocalDatabase.instance.getAppointmentsByPatient('pat-1');

      expect(results, hasLength(1));
      expect(results.first.id, 'appt-1');
      expect(results.first.status, 'scheduled');
      expect(results.first.durationMinutes, 30);
    });

    test('upsertAppointment replaces existing row on same id', () async {
      final original = AppointmentModel(
        id: 'appt-2',
        patientId: 'pat-1',
        providerId: 'prov-1',
        appointmentDate: DateTime(2026, 7, 2, 10, 0),
        durationMinutes: 30,
        appointmentType: 'follow_up',
        status: 'scheduled',
        reminderSent: false,
      );
      await LocalDatabase.instance.upsertAppointment(original);

      final updated = AppointmentModel(
        id: 'appt-2',
        patientId: 'pat-1',
        providerId: 'prov-1',
        appointmentDate: DateTime(2026, 7, 2, 10, 0),
        durationMinutes: 45,
        appointmentType: 'follow_up',
        status: 'confirmed',
        reminderSent: true,
      );
      await LocalDatabase.instance.upsertAppointment(updated);

      final results = await LocalDatabase.instance.getAppointmentsByPatient('pat-1');
      expect(results, hasLength(1));
      expect(results.first.status, 'confirmed');
      expect(results.first.durationMinutes, 45);
    });

    test('deleteAppointment removes specific row', () async {
      final appt = AppointmentModel(
        id: 'appt-del',
        patientId: 'pat-1',
        providerId: 'prov-1',
        appointmentDate: DateTime(2026, 7, 3, 9, 0),
        durationMinutes: 30,
        appointmentType: 'consultation',
        status: 'cancelled',
        reminderSent: false,
      );
      await LocalDatabase.instance.upsertAppointment(appt);
      await LocalDatabase.instance.deleteAppointment('appt-del');

      final results = await LocalDatabase.instance.getAppointmentsByPatient('pat-1');
      expect(results, isEmpty);
    });

    test('clearAppointmentsForPatient deletes only that patient', () async {
      for (int i = 0; i < 2; i++) {
        await LocalDatabase.instance.upsertAppointment(AppointmentModel(
          id: 'appt-p1-$i',
          patientId: 'pat-1',
          providerId: 'prov-1',
          appointmentDate: DateTime(2026, 7, i + 1, 9, 0),
          durationMinutes: 30,
          appointmentType: 'consultation',
          status: 'scheduled',
          reminderSent: false,
        ));
      }
      await LocalDatabase.instance.upsertAppointment(AppointmentModel(
        id: 'appt-p2-0',
        patientId: 'pat-2',
        providerId: 'prov-1',
        appointmentDate: DateTime(2026, 7, 5, 9, 0),
        durationMinutes: 30,
        appointmentType: 'consultation',
        status: 'scheduled',
        reminderSent: false,
      ));

      await LocalDatabase.instance.clearAppointmentsForPatient('pat-1');

      final p1Results = await LocalDatabase.instance.getAppointmentsByPatient('pat-1');
      final p2Results = await LocalDatabase.instance.getAppointmentsByPatient('pat-2');
      expect(p1Results, isEmpty);
      expect(p2Results, hasLength(1));
    });
  });

  // ── Prescriptions ─────────────────────────────────────────────────────────

  group('prescriptions_cache', () {
    test('upsertPrescription and getPrescriptionsByPatient round-trips correctly',
        () async {
      final rx = PrescriptionModel(
        id: 'rx-1',
        patientId: 'pat-1',
        prescriberId: 'doc-1',
        medicationName: 'Amoxicillin',
        dosage: '500mg',
        frequency: 'TID',
        refillsAllowed: 2,
        refillsRemaining: 2,
        status: 'active',
        drugInteractionsChecked: false,
      );

      await LocalDatabase.instance.upsertPrescription(rx);
      final results = await LocalDatabase.instance.getPrescriptionsByPatient('pat-1');

      expect(results, hasLength(1));
      expect(results.first.id, 'rx-1');
      expect(results.first.medicationName, 'Amoxicillin');
      expect(results.first.status, 'active');
    });

    test('deletePrescription removes specific row', () async {
      final rx = PrescriptionModel(
        id: 'rx-del',
        patientId: 'pat-1',
        prescriberId: 'doc-1',
        medicationName: 'Ibuprofen',
        dosage: '200mg',
        frequency: 'BID',
        refillsAllowed: 0,
        refillsRemaining: 0,
        status: 'expired',
        drugInteractionsChecked: true,
      );
      await LocalDatabase.instance.upsertPrescription(rx);
      await LocalDatabase.instance.deletePrescription('rx-del');

      final results = await LocalDatabase.instance.getPrescriptionsByPatient('pat-1');
      expect(results, isEmpty);
    });
  });

  // ── Lab Results ───────────────────────────────────────────────────────────

  group('lab_results_cache', () {
    test('upsertLabResult stores abnormal_flags as JSON and retrieves correctly',
        () async {
      final lab = LabResultModel(
        id: 'lab-1',
        patientId: 'pat-1',
        orderedById: 'doc-1',
        testName: 'Complete Blood Count',
        priority: 'routine',
        abnormalFlags: ['WBC_HIGH', 'RBC_LOW'],
        status: 'completed',
        requiresFollowup: true,
      );

      await LocalDatabase.instance.upsertLabResult(lab);
      final results = await LocalDatabase.instance.getLabResultsByPatient('pat-1');

      expect(results, hasLength(1));
      expect(results.first.id, 'lab-1');
      expect(results.first.abnormalFlags, ['WBC_HIGH', 'RBC_LOW']);
      expect(results.first.requiresFollowup, isTrue);
    });

    test('deleteLabResult removes specific row', () async {
      final lab = LabResultModel(
        id: 'lab-del',
        patientId: 'pat-1',
        orderedById: 'doc-1',
        testName: 'Urinalysis',
        priority: 'routine',
        abnormalFlags: [],
        status: 'cancelled',
        requiresFollowup: false,
      );
      await LocalDatabase.instance.upsertLabResult(lab);
      await LocalDatabase.instance.deleteLabResult('lab-del');

      final results = await LocalDatabase.instance.getLabResultsByPatient('pat-1');
      expect(results, isEmpty);
    });
  });

  // ── Vital Signs ───────────────────────────────────────────────────────────

  group('vitals_cache', () {
    test('upsertVitalSign and getVitalSignsByPatient round-trips correctly',
        () async {
      final vital = VitalSignModel(
        id: 'vs-1',
        patientId: 'pat-1',
        recordedById: 'nurse-1',
        recordedAt: DateTime(2026, 6, 10, 8, 30),
        bloodPressureSystolic: 120,
        bloodPressureDiastolic: 80,
        heartRate: 72,
        temperature: 37.0,
        temperatureUnit: 'C',
        oxygenSaturation: 98.0,
        version: 1,
      );

      await LocalDatabase.instance.upsertVitalSign(vital);
      final results = await LocalDatabase.instance.getVitalSignsByPatient('pat-1');

      expect(results, hasLength(1));
      expect(results.first.id, 'vs-1');
      expect(results.first.bloodPressureSystolic, 120);
      expect(results.first.temperature, 37.0);
    });
  });

  // ── Diagnoses ─────────────────────────────────────────────────────────────

  group('diagnoses_cache', () {
    test('upsertDiagnosis and getDiagnosesByPatient round-trips correctly',
        () async {
      final dx = DiagnosisModel(
        id: 'dx-1',
        patientId: 'pat-1',
        diagnosedById: 'doc-1',
        description: 'Type 2 Diabetes Mellitus',
        diagnosisType: 'primary',
        status: 'active',
        icdCode: 'E11',
        version: 1,
      );

      await LocalDatabase.instance.upsertDiagnosis(dx);
      final results = await LocalDatabase.instance.getDiagnosesByPatient('pat-1');

      expect(results, hasLength(1));
      expect(results.first.id, 'dx-1');
      expect(results.first.icdCode, 'E11');
      expect(results.first.status, 'active');
    });
  });
}
