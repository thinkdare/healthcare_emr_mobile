import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_emr_mobile/data/models/clinical_record_models.dart';

void main() {
  // ── VitalSignModel ──────────────────────────────────────────────────────────

  group('VitalSignModel', () {
    final baseJson = <String, dynamic>{
      'id': 'vs-1',
      'patient_id': 'pat-1',
      'recorded_by_id': 'nurse-1',
      'encounter_id': 'enc-1',
      'roster_entry_id': 'roster-1',
      'ward_id': 'ward-a',
      'recorded_at': '2026-06-09T08:00:00.000Z',
      'blood_pressure_systolic': 120,
      'blood_pressure_diastolic': 80,
      'heart_rate': 72,
      'respiratory_rate': 16,
      'temperature': 36.8,
      'temperature_unit': 'C',
      'oxygen_saturation': 98.0,
      'weight': 70.5,
      'weight_unit': 'kg',
      'height': 175.0,
      'height_unit': 'cm',
      'bmi': 23.0,
      'notes': 'Patient calm and cooperative',
      'version': 1,
      'created_at': '2026-06-09T08:00:00.000Z',
    };

    test('fromJson parses all required fields correctly', () {
      final model = VitalSignModel.fromJson(Map<String, dynamic>.from(baseJson));

      expect(model.id, equals('vs-1'));
      expect(model.patientId, equals('pat-1'));
      expect(model.recordedById, equals('nurse-1'));
      expect(model.encounterId, equals('enc-1'));
      expect(model.rosterEntryId, equals('roster-1'));
      expect(model.wardId, equals('ward-a'));
      expect(model.recordedAt, equals(DateTime.parse('2026-06-09T08:00:00.000Z')));
      expect(model.bloodPressureSystolic, equals(120));
      expect(model.bloodPressureDiastolic, equals(80));
      expect(model.heartRate, equals(72));
      expect(model.respiratoryRate, equals(16));
      expect(model.temperature, equals(36.8));
      expect(model.temperatureUnit, equals('C'));
      expect(model.oxygenSaturation, equals(98.0));
      expect(model.weight, equals(70.5));
      expect(model.weightUnit, equals('kg'));
      expect(model.height, equals(175.0));
      expect(model.heightUnit, equals('cm'));
      expect(model.bmi, equals(23.0));
      expect(model.notes, equals('Patient calm and cooperative'));
      expect(model.version, equals(1));
      expect(model.createdAt, isA<DateTime>());
    });

    test('fromJson handles null optional fields gracefully', () {
      final minimalJson = <String, dynamic>{
        'id': 'vs-min',
        'patient_id': 'pat-min',
        'recorded_by_id': 'nurse-min',
        'recorded_at': '2026-06-09T08:00:00.000Z',
      };

      final model = VitalSignModel.fromJson(minimalJson);

      expect(model.encounterId, isNull);
      expect(model.rosterEntryId, isNull);
      expect(model.wardId, isNull);
      expect(model.bloodPressureSystolic, isNull);
      expect(model.bloodPressureDiastolic, isNull);
      expect(model.heartRate, isNull);
      expect(model.respiratoryRate, isNull);
      expect(model.temperature, isNull);
      expect(model.temperatureUnit, isNull);
      expect(model.oxygenSaturation, isNull);
      expect(model.weight, isNull);
      expect(model.weightUnit, isNull);
      expect(model.height, isNull);
      expect(model.heightUnit, isNull);
      expect(model.bmi, isNull);
      expect(model.notes, isNull);
      expect(model.version, equals(1)); // default
      expect(model.createdAt, isNull);
    });

    test('bpDisplay returns formatted string when both values are present', () {
      final model = VitalSignModel.fromJson(Map<String, dynamic>.from(baseJson));
      expect(model.bpDisplay, equals('120/80 mmHg'));
    });

    test('bpDisplay returns em dash when systolic is null', () {
      final json = Map<String, dynamic>.from(baseJson)
        ..['blood_pressure_systolic'] = null;
      final model = VitalSignModel.fromJson(json);
      expect(model.bpDisplay, equals('—'));
    });

    test('bpDisplay returns em dash when diastolic is null', () {
      final json = Map<String, dynamic>.from(baseJson)
        ..['blood_pressure_diastolic'] = null;
      final model = VitalSignModel.fromJson(json);
      expect(model.bpDisplay, equals('—'));
    });

    test('bpDisplay returns em dash when both BP values are null', () {
      final json = Map<String, dynamic>.from(baseJson)
        ..['blood_pressure_systolic'] = null
        ..['blood_pressure_diastolic'] = null;
      final model = VitalSignModel.fromJson(json);
      expect(model.bpDisplay, equals('—'));
    });

    test('tempDisplay returns formatted temperature with unit', () {
      final model = VitalSignModel.fromJson(Map<String, dynamic>.from(baseJson));
      expect(model.tempDisplay, equals('36.8 °C'));
    });

    test('tempDisplay uses Fahrenheit unit when specified', () {
      final json = Map<String, dynamic>.from(baseJson)
        ..['temperature'] = 98.6
        ..['temperature_unit'] = 'F';
      final model = VitalSignModel.fromJson(json);
      expect(model.tempDisplay, equals('98.6 °F'));
    });

    test('tempDisplay defaults to Celsius unit when temperature_unit is null', () {
      final json = Map<String, dynamic>.from(baseJson)
        ..['temperature_unit'] = null;
      final model = VitalSignModel.fromJson(json);
      expect(model.tempDisplay, equals('36.8 °C'));
    });

    test('tempDisplay returns em dash when temperature is null', () {
      final json = Map<String, dynamic>.from(baseJson)..['temperature'] = null;
      final model = VitalSignModel.fromJson(json);
      expect(model.tempDisplay, equals('—'));
    });

    test('spo2Display returns formatted percentage when present', () {
      final model = VitalSignModel.fromJson(Map<String, dynamic>.from(baseJson));
      expect(model.spo2Display, equals('98%'));
    });

    test('spo2Display returns em dash when oxygenSaturation is null', () {
      final json = Map<String, dynamic>.from(baseJson)..['oxygen_saturation'] = null;
      final model = VitalSignModel.fromJson(json);
      expect(model.spo2Display, equals('—'));
    });

    test('spo2Display rounds to nearest integer', () {
      final json = Map<String, dynamic>.from(baseJson)..['oxygen_saturation'] = 97.6;
      final model = VitalSignModel.fromJson(json);
      expect(model.spo2Display, equals('98%'));
    });

    test('version defaults to 1 when absent', () {
      final json = Map<String, dynamic>.from(baseJson)..remove('version');
      final model = VitalSignModel.fromJson(json);
      expect(model.version, equals(1));
    });
  });

  // ── DiagnosisModel ──────────────────────────────────────────────────────────

  group('DiagnosisModel', () {
    final baseJson = <String, dynamic>{
      'id': 'dx-1',
      'patient_id': 'pat-1',
      'diagnosed_by_id': 'doc-1',
      'encounter_id': 'enc-1',
      'ward_id': 'ward-a',
      'icd_code': 'J18.9',
      'icd_version': '10',
      'description': 'Community-acquired pneumonia',
      'diagnosis_type': 'primary',
      'status': 'active',
      'onset_date': '2026-06-01T00:00:00.000Z',
      'resolved_date': null,
      'notes': 'Patient febrile on admission',
      'version': 2,
      'created_at': '2026-06-01T08:00:00.000Z',
      'updated_at': '2026-06-09T08:00:00.000Z',
    };

    test('fromJson parses all fields correctly', () {
      final model = DiagnosisModel.fromJson(Map<String, dynamic>.from(baseJson));

      expect(model.id, equals('dx-1'));
      expect(model.patientId, equals('pat-1'));
      expect(model.diagnosedById, equals('doc-1'));
      expect(model.encounterId, equals('enc-1'));
      expect(model.wardId, equals('ward-a'));
      expect(model.icdCode, equals('J18.9'));
      expect(model.icdVersion, equals('10'));
      expect(model.description, equals('Community-acquired pneumonia'));
      expect(model.diagnosisType, equals('primary'));
      expect(model.status, equals('active'));
      expect(model.onsetDate, isA<DateTime>());
      expect(model.resolvedDate, isNull);
      expect(model.notes, equals('Patient febrile on admission'));
      expect(model.version, equals(2));
      expect(model.createdAt, isA<DateTime>());
      expect(model.updatedAt, isA<DateTime>());
    });

    test('fromJson handles null optional fields gracefully', () {
      final minimalJson = <String, dynamic>{
        'id': 'dx-min',
        'patient_id': 'pat-min',
        'diagnosed_by_id': 'doc-min',
        'description': 'Hypertension',
      };

      final model = DiagnosisModel.fromJson(minimalJson);

      expect(model.encounterId, isNull);
      expect(model.wardId, isNull);
      expect(model.icdCode, isNull);
      expect(model.icdVersion, isNull);
      expect(model.diagnosisType, equals('primary')); // default
      expect(model.status, equals('active'));          // default
      expect(model.onsetDate, isNull);
      expect(model.resolvedDate, isNull);
      expect(model.notes, isNull);
      expect(model.version, equals(1));               // default
      expect(model.createdAt, isNull);
      expect(model.updatedAt, isNull);
    });

    test('isActive is true when status is active', () {
      final model = DiagnosisModel.fromJson(Map<String, dynamic>.from(baseJson));
      expect(model.isActive, isTrue);
    });

    test('isActive is true when status is in_remission', () {
      final json = Map<String, dynamic>.from(baseJson)..['status'] = 'in_remission';
      final model = DiagnosisModel.fromJson(json);
      expect(model.isActive, isTrue);
    });

    test('isActive is false when status is resolved', () {
      final json = Map<String, dynamic>.from(baseJson)..['status'] = 'resolved';
      final model = DiagnosisModel.fromJson(json);
      expect(model.isActive, isFalse);
    });

    test('isActive is false when status is ruled_out', () {
      final json = Map<String, dynamic>.from(baseJson)..['status'] = 'ruled_out';
      final model = DiagnosisModel.fromJson(json);
      expect(model.isActive, isFalse);
    });
  });

  // ── ProblemListModel ────────────────────────────────────────────────────────

  group('ProblemListModel', () {
    final baseJson = <String, dynamic>{
      'id': 'prob-1',
      'patient_id': 'pat-1',
      'recorded_by_id': 'doc-1',
      'icd_code': 'I10',
      'snomed_code': '38341003',
      'coding_system': 'ICD10',
      'description': 'Essential hypertension',
      'status': 'chronic',
      'onset_date': '2020-01-01T00:00:00.000Z',
      'resolved_date': null,
      'notes': 'On amlodipine 5mg daily',
      'version': 3,
      'created_at': '2026-01-01T08:00:00.000Z',
      'updated_at': '2026-06-09T08:00:00.000Z',
    };

    test('fromJson parses all fields correctly', () {
      final model = ProblemListModel.fromJson(Map<String, dynamic>.from(baseJson));

      expect(model.id, equals('prob-1'));
      expect(model.patientId, equals('pat-1'));
      expect(model.recordedById, equals('doc-1'));
      expect(model.icdCode, equals('I10'));
      expect(model.snomedCode, equals('38341003'));
      expect(model.codingSystem, equals('ICD10'));
      expect(model.description, equals('Essential hypertension'));
      expect(model.status, equals('chronic'));
      expect(model.onsetDate, isA<DateTime>());
      expect(model.resolvedDate, isNull);
      expect(model.notes, equals('On amlodipine 5mg daily'));
      expect(model.version, equals(3));
      expect(model.createdAt, isA<DateTime>());
      expect(model.updatedAt, isA<DateTime>());
    });

    test('fromJson handles null optional fields gracefully', () {
      final minimalJson = <String, dynamic>{
        'id': 'prob-min',
        'patient_id': 'pat-min',
        'recorded_by_id': 'doc-min',
        'description': 'Diabetes mellitus type 2',
      };

      final model = ProblemListModel.fromJson(minimalJson);

      expect(model.icdCode, isNull);
      expect(model.snomedCode, isNull);
      expect(model.codingSystem, equals('local')); // default
      expect(model.status, equals('active'));       // default
      expect(model.onsetDate, isNull);
      expect(model.resolvedDate, isNull);
      expect(model.notes, isNull);
      expect(model.version, equals(1));             // default
      expect(model.createdAt, isNull);
      expect(model.updatedAt, isNull);
    });

    test('isActive is true when status is active', () {
      final json = Map<String, dynamic>.from(baseJson)..['status'] = 'active';
      final model = ProblemListModel.fromJson(json);
      expect(model.isActive, isTrue);
    });

    test('isActive is true when status is chronic', () {
      final model = ProblemListModel.fromJson(Map<String, dynamic>.from(baseJson));
      expect(model.isActive, isTrue);
    });

    test('isActive is false when status is resolved', () {
      final json = Map<String, dynamic>.from(baseJson)..['status'] = 'resolved';
      final model = ProblemListModel.fromJson(json);
      expect(model.isActive, isFalse);
    });

    test('isActive is false when status is in_remission', () {
      final json = Map<String, dynamic>.from(baseJson)..['status'] = 'in_remission';
      final model = ProblemListModel.fromJson(json);
      expect(model.isActive, isFalse);
    });
  });

  // ── ProcedureModel ──────────────────────────────────────────────────────────

  group('ProcedureModel', () {
    final baseJson = <String, dynamic>{
      'id': 'proc-1',
      'patient_id': 'pat-1',
      'performed_by_id': 'doc-1',
      'encounter_id': 'enc-1',
      'ward_id': 'ward-a',
      'procedure_code': '0BH17EZ',
      'procedure_coding_system': 'ICD10_PCS',
      'description': 'Endotracheal intubation',
      'performed_at': '2026-06-09T10:00:00.000Z',
      'duration_minutes': 15,
      'status': 'completed',
      'notes': 'Rapid sequence induction used',
      'version': 1,
      'created_at': '2026-06-09T10:00:00.000Z',
      'updated_at': '2026-06-09T10:30:00.000Z',
    };

    test('fromJson parses all fields correctly', () {
      final model = ProcedureModel.fromJson(Map<String, dynamic>.from(baseJson));

      expect(model.id, equals('proc-1'));
      expect(model.patientId, equals('pat-1'));
      expect(model.performedById, equals('doc-1'));
      expect(model.encounterId, equals('enc-1'));
      expect(model.wardId, equals('ward-a'));
      expect(model.procedureCode, equals('0BH17EZ'));
      expect(model.procedureCodingSystem, equals('ICD10_PCS'));
      expect(model.description, equals('Endotracheal intubation'));
      expect(model.performedAt, isA<DateTime>());
      expect(model.durationMinutes, equals(15));
      expect(model.status, equals('completed'));
      expect(model.notes, equals('Rapid sequence induction used'));
      expect(model.version, equals(1));
      expect(model.createdAt, isA<DateTime>());
      expect(model.updatedAt, isA<DateTime>());
    });

    test('fromJson handles null optional fields gracefully', () {
      final minimalJson = <String, dynamic>{
        'id': 'proc-min',
        'patient_id': 'pat-min',
        'performed_by_id': 'doc-min',
        'description': 'Wound dressing',
      };

      final model = ProcedureModel.fromJson(minimalJson);

      expect(model.encounterId, isNull);
      expect(model.wardId, isNull);
      expect(model.procedureCode, isNull);
      expect(model.procedureCodingSystem, isNull);
      expect(model.performedAt, isNull);
      expect(model.durationMinutes, isNull);
      expect(model.status, equals('planned')); // default
      expect(model.notes, isNull);
      expect(model.version, equals(1));        // default
      expect(model.createdAt, isNull);
      expect(model.updatedAt, isNull);
    });

    test('isCompleted is true when status is completed', () {
      final model = ProcedureModel.fromJson(Map<String, dynamic>.from(baseJson));
      expect(model.isCompleted, isTrue);
    });

    test('isCompleted is false for planned, in_progress, cancelled', () {
      for (final s in ['planned', 'in_progress', 'cancelled']) {
        final json = Map<String, dynamic>.from(baseJson)..['status'] = s;
        final model = ProcedureModel.fromJson(json);
        expect(model.isCompleted, isFalse, reason: 'status=$s should not be completed');
      }
    });

    test('performedAt is parsed from ISO string', () {
      final model = ProcedureModel.fromJson(Map<String, dynamic>.from(baseJson));
      expect(model.performedAt, equals(DateTime.parse('2026-06-09T10:00:00.000Z')));
    });
  });

  // ── ImmunizationModel ───────────────────────────────────────────────────────

  group('ImmunizationModel', () {
    final baseJson = <String, dynamic>{
      'id': 'imm-1',
      'patient_id': 'pat-1',
      'administered_by_id': 'nurse-1',
      'vaccine_code': '08',
      'vaccine_name': 'Hepatitis B',
      'dose_number': 2,
      'series_total': 3,
      'administered_at': '2026-06-01T09:00:00.000Z',
      'lot_number': 'LOT-HBV-2026',
      'site': 'left_arm',
      'route': 'intramuscular',
      'expiration_date': '2027-01-01T00:00:00.000Z',
      'notes': 'No adverse reaction observed',
      'version': 1,
      'created_at': '2026-06-01T09:00:00.000Z',
    };

    test('fromJson parses all fields correctly', () {
      final model = ImmunizationModel.fromJson(Map<String, dynamic>.from(baseJson));

      expect(model.id, equals('imm-1'));
      expect(model.patientId, equals('pat-1'));
      expect(model.administeredById, equals('nurse-1'));
      expect(model.vaccineCode, equals('08'));
      expect(model.vaccineName, equals('Hepatitis B'));
      expect(model.doseNumber, equals(2));
      expect(model.seriesTotal, equals(3));
      expect(model.administeredAt, equals(DateTime.parse('2026-06-01T09:00:00.000Z')));
      expect(model.lotNumber, equals('LOT-HBV-2026'));
      expect(model.site, equals('left_arm'));
      expect(model.route, equals('intramuscular'));
      expect(model.expirationDate, isA<DateTime>());
      expect(model.notes, equals('No adverse reaction observed'));
      expect(model.version, equals(1));
      expect(model.createdAt, isA<DateTime>());
    });

    test('fromJson handles null optional fields gracefully', () {
      final minimalJson = <String, dynamic>{
        'id': 'imm-min',
        'patient_id': 'pat-min',
        'administered_by_id': 'nurse-min',
        'vaccine_code': '135',
        'vaccine_name': 'Influenza',
        'administered_at': '2026-06-01T09:00:00.000Z',
        'route': 'intramuscular',
      };

      final model = ImmunizationModel.fromJson(minimalJson);

      expect(model.doseNumber, equals(1));  // default
      expect(model.seriesTotal, isNull);
      expect(model.lotNumber, isNull);
      expect(model.site, isNull);
      expect(model.expirationDate, isNull);
      expect(model.notes, isNull);
      expect(model.version, equals(1));     // default
      expect(model.createdAt, isNull);
    });

    test('doseDisplay includes series total when seriesTotal is present', () {
      final model = ImmunizationModel.fromJson(Map<String, dynamic>.from(baseJson));
      expect(model.doseDisplay, equals('Dose 2 of 3'));
    });

    test('doseDisplay omits series total when seriesTotal is null', () {
      final json = Map<String, dynamic>.from(baseJson)..['series_total'] = null;
      final model = ImmunizationModel.fromJson(json);
      expect(model.doseDisplay, equals('Dose 2'));
    });

    test('doseDisplay reflects dose number 1 with no series', () {
      final json = Map<String, dynamic>.from(baseJson)
        ..['dose_number'] = 1
        ..['series_total'] = null;
      final model = ImmunizationModel.fromJson(json);
      expect(model.doseDisplay, equals('Dose 1'));
    });

    test('doseDisplay reflects dose number 1 of 1 with series', () {
      final json = Map<String, dynamic>.from(baseJson)
        ..['dose_number'] = 1
        ..['series_total'] = 1;
      final model = ImmunizationModel.fromJson(json);
      expect(model.doseDisplay, equals('Dose 1 of 1'));
    });

    test('administeredAt is parsed from ISO string', () {
      final model = ImmunizationModel.fromJson(Map<String, dynamic>.from(baseJson));
      expect(model.administeredAt, equals(DateTime.parse('2026-06-01T09:00:00.000Z')));
    });
  });

  // ── RosterEntryModel ────────────────────────────────────────────────────────

  group('RosterEntryModel', () {
    final baseJson = <String, dynamic>{
      'id': 'roster-1',
      'patient_id': 'pat-1',
      'ward_id': 'ward-a',
      'added_by_id': 'nurse-1',
      'date': '2026-06-09T00:00:00.000Z',
      'entry_type': 'walk_in',
      'appointment_id': null,
      'triage_severity': 'urgent',
      'chief_complaint': 'Severe headache',
      'status': 'waiting',
      'seen_by_id': null,
      'seen_by_name': null,
      'seen_at': null,
      'consultation_notes': null,
      'carry_over_count': 0,
      'original_roster_date': '2026-06-09T00:00:00.000Z',
      'is_carried_over': false,
      'is_terminal': false,
      'version': 1,
      'created_at': '2026-06-09T07:30:00.000Z',
    };

    test('fromJson parses all required fields correctly', () {
      final model = RosterEntryModel.fromJson(Map<String, dynamic>.from(baseJson));

      expect(model.id, equals('roster-1'));
      expect(model.patientId, equals('pat-1'));
      expect(model.wardId, equals('ward-a'));
      expect(model.addedById, equals('nurse-1'));
      expect(model.date, isA<DateTime>());
      expect(model.entryType, equals('walk_in'));
      expect(model.appointmentId, isNull);
      expect(model.triageSeverity, equals('urgent'));
      expect(model.chiefComplaint, equals('Severe headache'));
      expect(model.status, equals('waiting'));
      expect(model.seenById, isNull);
      expect(model.seenByName, isNull);
      expect(model.seenAt, isNull);
      expect(model.consultationNotes, isNull);
      expect(model.carryOverCount, equals(0));
      expect(model.originalRosterDate, isA<DateTime>());
      expect(model.isCarriedOver, isFalse);
      expect(model.isTerminal, isFalse);
      expect(model.version, equals(1));
      expect(model.createdAt, isA<DateTime>());
    });

    test('fromJson handles null optional fields gracefully', () {
      final minimalJson = <String, dynamic>{
        'id': 'roster-min',
        'patient_id': 'pat-min',
        'ward_id': 'ward-min',
        'added_by_id': 'nurse-min',
        'date': '2026-06-09T00:00:00.000Z',
        'entry_type': 'scheduled',
        'original_roster_date': '2026-06-09T00:00:00.000Z',
      };

      final model = RosterEntryModel.fromJson(minimalJson);

      expect(model.appointmentId, isNull);
      expect(model.triageSeverity, isNull);
      expect(model.chiefComplaint, isNull);
      expect(model.status, equals('waiting'));  // default
      expect(model.seenById, isNull);
      expect(model.seenByName, isNull);
      expect(model.seenAt, isNull);
      expect(model.consultationNotes, isNull);
      expect(model.carryOverCount, equals(0)); // default
      expect(model.isCarriedOver, isFalse);    // default
      expect(model.isTerminal, isFalse);       // default
      expect(model.version, equals(1));        // default
      expect(model.createdAt, isNull);
    });

    test('isWaiting is true when status is waiting', () {
      final model = RosterEntryModel.fromJson(Map<String, dynamic>.from(baseJson));
      expect(model.isWaiting, isTrue);
      expect(model.isInConsultation, isFalse);
    });

    test('isWaiting is false for non-waiting statuses', () {
      for (final s in ['in_consultation', 'seen', 'admitted', 'referred', 'carried_over']) {
        final json = Map<String, dynamic>.from(baseJson)..['status'] = s;
        final model = RosterEntryModel.fromJson(json);
        expect(model.isWaiting, isFalse, reason: 'status=$s should not be waiting');
      }
    });

    test('isInConsultation is true when status is in_consultation', () {
      final json = Map<String, dynamic>.from(baseJson)..['status'] = 'in_consultation';
      final model = RosterEntryModel.fromJson(json);
      expect(model.isInConsultation, isTrue);
      expect(model.isWaiting, isFalse);
    });

    test('isInConsultation is false for non-consultation statuses', () {
      for (final s in ['waiting', 'seen', 'admitted', 'referred', 'carried_over']) {
        final json = Map<String, dynamic>.from(baseJson)..['status'] = s;
        final model = RosterEntryModel.fromJson(json);
        expect(model.isInConsultation, isFalse, reason: 'status=$s should not be in_consultation');
      }
    });

    test('triagePriority is 0 for critical severity', () {
      final json = Map<String, dynamic>.from(baseJson)..['triage_severity'] = 'critical';
      final model = RosterEntryModel.fromJson(json);
      expect(model.triagePriority, equals(0));
    });

    test('triagePriority is 1 for urgent severity', () {
      final model = RosterEntryModel.fromJson(Map<String, dynamic>.from(baseJson));
      expect(model.triagePriority, equals(1));
    });

    test('triagePriority is 2 for moderate severity', () {
      final json = Map<String, dynamic>.from(baseJson)..['triage_severity'] = 'moderate';
      final model = RosterEntryModel.fromJson(json);
      expect(model.triagePriority, equals(2));
    });

    test('triagePriority is 3 for low severity', () {
      final json = Map<String, dynamic>.from(baseJson)..['triage_severity'] = 'low';
      final model = RosterEntryModel.fromJson(json);
      expect(model.triagePriority, equals(3));
    });

    test('triagePriority is 4 for null or unknown severity', () {
      final jsonNull = Map<String, dynamic>.from(baseJson)..['triage_severity'] = null;
      final modelNull = RosterEntryModel.fromJson(jsonNull);
      expect(modelNull.triagePriority, equals(4));

      final jsonUnknown = Map<String, dynamic>.from(baseJson)
        ..['triage_severity'] = 'unknown_value';
      final modelUnknown = RosterEntryModel.fromJson(jsonUnknown);
      expect(modelUnknown.triagePriority, equals(4));
    });

    test('seenByName and seenAt are populated after consultation', () {
      final json = Map<String, dynamic>.from(baseJson)
        ..['status'] = 'seen'
        ..['seen_by_id'] = 'doc-1'
        ..['seen_by_name'] = 'Dr. Adesanya'
        ..['seen_at'] = '2026-06-09T10:15:00.000Z';
      final model = RosterEntryModel.fromJson(json);

      expect(model.seenById, equals('doc-1'));
      expect(model.seenByName, equals('Dr. Adesanya'));
      expect(model.seenAt, equals(DateTime.parse('2026-06-09T10:15:00.000Z')));
    });

    test('isCarriedOver and carryOverCount reflect carried-over state', () {
      final json = Map<String, dynamic>.from(baseJson)
        ..['is_carried_over'] = true
        ..['carry_over_count'] = 2
        ..['original_roster_date'] = '2026-06-07T00:00:00.000Z';
      final model = RosterEntryModel.fromJson(json);

      expect(model.isCarriedOver, isTrue);
      expect(model.carryOverCount, equals(2));
      expect(model.originalRosterDate,
          equals(DateTime.parse('2026-06-07T00:00:00.000Z')));
    });

    test('isTerminal reflects terminal state', () {
      final json = Map<String, dynamic>.from(baseJson)..['is_terminal'] = true;
      final model = RosterEntryModel.fromJson(json);
      expect(model.isTerminal, isTrue);
    });
  });
}
