import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_emr_mobile/data/models/cross_tenant_patient_models.dart';

void main() {
  group('CrossTenantPatientModel', () {
    test('fromJson parses demographic and clinical summary fields', () {
      final patient = CrossTenantPatientModel.fromJson({
        'id': 'patient-1',
        'full_name': 'Jane Doe',
        'first_name': 'Jane',
        'last_name': 'Doe',
        'date_of_birth': '1990-01-01',
        'gender': 'female',
        'blood_type': 'O+',
        'current_medications': 'Metformin',
        'allergies': 'Penicillin',
        'chronic_conditions': 'Diabetes',
        'medical_history': 'Appendectomy 2015',
      });

      expect(patient.fullName, 'Jane Doe');
      expect(patient.bloodType, 'O+');
      expect(patient.allergies, 'Penicillin');
    });

    test('fromJson handles missing optional clinical fields', () {
      final patient = CrossTenantPatientModel.fromJson({
        'id': 'patient-2',
        'full_name': 'John Smith',
        'first_name': 'John',
        'last_name': 'Smith',
      });

      expect(patient.allergies, isNull);
      expect(patient.currentMedications, isNull);
      expect(patient.chronicConditions, isNull);
      expect(patient.medicalHistory, isNull);
    });
  });

  group('CrossTenantPrescriptionModel', () {
    test('fromJson parses all fields', () {
      final p = CrossTenantPrescriptionModel.fromJson({
        'id': 'rx-1',
        'medication_name': 'Lisinopril',
        'dosage': '10mg',
        'frequency': 'Once daily',
        'status': 'active',
        'prescribed_date': '2026-01-01',
      });

      expect(p.medicationName, 'Lisinopril');
      expect(p.status, 'active');
    });
  });

  group('CrossTenantLabResultModel', () {
    test('fromJson parses all fields', () {
      final r = CrossTenantLabResultModel.fromJson({
        'id': 'lab-1',
        'test_name': 'CBC',
        'test_type': 'blood',
        'ordered_date': '2026-01-01',
        'status': 'completed',
        'results': {'wbc': 6.5},
      });

      expect(r.testName, 'CBC');
      expect(r.results, {'wbc': 6.5});
    });
  });

  group('CrossTenantAppointmentModel', () {
    test('fromJson parses all fields', () {
      final a = CrossTenantAppointmentModel.fromJson({
        'id': 'appt-1',
        'appointment_date': '2026-02-01',
        'appointment_type': 'follow_up',
        'status': 'scheduled',
      });

      expect(a.appointmentType, 'follow_up');
      expect(a.status, 'scheduled');
    });
  });
}
