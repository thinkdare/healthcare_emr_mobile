import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_emr_mobile/data/models/clinical_models.dart';

void main() {
  // ── AppointmentModel ────────────────────────────────────────────────────────

  group('AppointmentModel', () {
    final baseJson = <String, dynamic>{
      'id': 'appt-1',
      'patient_id': 'pat-1',
      'provider_id': 'prov-1',
      'appointment_date': '2026-08-15T09:30:00.000Z',
      'duration_minutes': 45,
      'appointment_type': 'follow_up',
      'status': 'scheduled',
      'reason': 'Blood pressure review',
      'notes': 'Patient on lisinopril',
      'cancellation_reason': null,
      'reminder_sent': true,
      'checked_in_at': '2026-08-15T09:25:00.000Z',
      'completed_at': null,
      'created_at': '2026-08-01T08:00:00.000Z',
      'updated_at': '2026-08-01T08:00:00.000Z',
      'ward_id': 'ward-a',
    };

    test('fromJson parses all required fields correctly', () {
      final model = AppointmentModel.fromJson(Map<String, dynamic>.from(baseJson));

      expect(model.id, equals('appt-1'));
      expect(model.patientId, equals('pat-1'));
      expect(model.providerId, equals('prov-1'));
      expect(model.appointmentDate, equals(DateTime.parse('2026-08-15T09:30:00.000Z')));
      expect(model.durationMinutes, equals(45));
      expect(model.appointmentType, equals('follow_up'));
      expect(model.status, equals('scheduled'));
      expect(model.reason, equals('Blood pressure review'));
      expect(model.notes, equals('Patient on lisinopril'));
      expect(model.reminderSent, isTrue);
      expect(model.checkedInAt, equals(DateTime.parse('2026-08-15T09:25:00.000Z')));
      expect(model.completedAt, isNull);
      expect(model.createdAt, isNotNull);
      expect(model.updatedAt, isNotNull);
      expect(model.wardId, equals('ward-a'));
    });

    test('fromJson handles null optional fields gracefully', () {
      final minimalJson = <String, dynamic>{
        'id': 'appt-min',
        'patient_id': 'pat-min',
        'provider_id': 'prov-min',
        'appointment_date': '2026-09-01T08:00:00.000Z',
      };

      final model = AppointmentModel.fromJson(minimalJson);

      expect(model.durationMinutes, equals(30)); // default
      expect(model.appointmentType, equals('consultation')); // default
      expect(model.status, equals('scheduled')); // default
      expect(model.reason, isNull);
      expect(model.notes, isNull);
      expect(model.cancellationReason, isNull);
      expect(model.reminderSent, isFalse); // default
      expect(model.checkedInAt, isNull);
      expect(model.completedAt, isNull);
      expect(model.createdAt, isNull);
      expect(model.updatedAt, isNull);
      expect(model.wardId, isNull);
    });

    test('isCompleted is true when status is completed', () {
      final json = Map<String, dynamic>.from(baseJson)..['status'] = 'completed';
      final model = AppointmentModel.fromJson(json);
      expect(model.isCompleted, isTrue);
      expect(model.isCancelled, isFalse);
    });

    test('isCompleted is false for non-completed statuses', () {
      for (final s in ['scheduled', 'confirmed', 'checked_in', 'cancelled', 'no_show']) {
        final json = Map<String, dynamic>.from(baseJson)..['status'] = s;
        final model = AppointmentModel.fromJson(json);
        expect(model.isCompleted, isFalse, reason: 'status=$s should not be completed');
      }
    });

    test('isCancelled is true when status is cancelled', () {
      final json = Map<String, dynamic>.from(baseJson)..['status'] = 'cancelled';
      final model = AppointmentModel.fromJson(json);
      expect(model.isCancelled, isTrue);
      expect(model.isCompleted, isFalse);
    });

    test('isCancelled is false for non-cancelled statuses', () {
      for (final s in ['scheduled', 'confirmed', 'checked_in', 'completed', 'no_show']) {
        final json = Map<String, dynamic>.from(baseJson)..['status'] = s;
        final model = AppointmentModel.fromJson(json);
        expect(model.isCancelled, isFalse, reason: 'status=$s should not be cancelled');
      }
    });

    test('isUpcoming is true for future scheduled appointment', () {
      final json = Map<String, dynamic>.from(baseJson)
        ..['appointment_date'] = '2099-01-01T08:00:00.000Z'
        ..['status'] = 'scheduled';
      final model = AppointmentModel.fromJson(json);
      expect(model.isUpcoming, isTrue);
    });

    test('isUpcoming is false for completed appointment even in future', () {
      final json = Map<String, dynamic>.from(baseJson)
        ..['appointment_date'] = '2099-01-01T08:00:00.000Z'
        ..['status'] = 'completed';
      final model = AppointmentModel.fromJson(json);
      expect(model.isUpcoming, isFalse);
    });

    test('isUpcoming is false for cancelled appointment even in future', () {
      final json = Map<String, dynamic>.from(baseJson)
        ..['appointment_date'] = '2099-01-01T08:00:00.000Z'
        ..['status'] = 'cancelled';
      final model = AppointmentModel.fromJson(json);
      expect(model.isUpcoming, isFalse);
    });

    test('isUpcoming is false for past appointment', () {
      final json = Map<String, dynamic>.from(baseJson)
        ..['appointment_date'] = '2000-01-01T08:00:00.000Z'
        ..['status'] = 'scheduled';
      final model = AppointmentModel.fromJson(json);
      expect(model.isUpcoming, isFalse);
    });

    test('isToday is true when appointmentDate is today', () {
      final now = DateTime.now();
      final todayIso =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}T10:00:00.000Z';
      final json = Map<String, dynamic>.from(baseJson)
        ..['appointment_date'] = todayIso;
      final model = AppointmentModel.fromJson(json);
      expect(model.isToday, isTrue);
    });

    test('isToday is false when appointmentDate is yesterday', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final iso =
          '${yesterday.year.toString().padLeft(4, '0')}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}T10:00:00.000Z';
      final json = Map<String, dynamic>.from(baseJson)..['appointment_date'] = iso;
      final model = AppointmentModel.fromJson(json);
      expect(model.isToday, isFalse);
    });

    test('isToday is false when appointmentDate is tomorrow', () {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final iso =
          '${tomorrow.year.toString().padLeft(4, '0')}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}T10:00:00.000Z';
      final json = Map<String, dynamic>.from(baseJson)..['appointment_date'] = iso;
      final model = AppointmentModel.fromJson(json);
      expect(model.isToday, isFalse);
    });

    test('cancellationReason is parsed when present', () {
      final json = Map<String, dynamic>.from(baseJson)
        ..['cancellation_reason'] = 'Patient no-show';
      final model = AppointmentModel.fromJson(json);
      expect(model.cancellationReason, equals('Patient no-show'));
    });

    test('DateTime fields are parsed from ISO strings', () {
      final model = AppointmentModel.fromJson(Map<String, dynamic>.from(baseJson));
      expect(model.appointmentDate, isA<DateTime>());
      expect(model.checkedInAt, isA<DateTime>());
      expect(model.createdAt, isA<DateTime>());
    });
  });

  // ── PrescriptionModel ───────────────────────────────────────────────────────

  group('PrescriptionModel', () {
    final baseJson = <String, dynamic>{
      'id': 'rx-1',
      'patient_id': 'pat-1',
      'prescriber_id': 'doc-1',
      'medication_name': 'Amoxicillin',
      'medication_code': 'AMX500',
      'dosage': '500mg',
      'frequency': 'TDS',
      'route': 'oral',
      'duration_days': 7,
      'quantity': 21,
      'refills_allowed': 2,
      'refills_remaining': 2,
      'prescribed_date': '2026-06-01T00:00:00.000Z',
      'start_date': '2026-06-01T00:00:00.000Z',
      'end_date': '2026-06-08T00:00:00.000Z',
      'expires_date': '2026-09-01T00:00:00.000Z',
      'status': 'active',
      'special_instructions': 'Take with food',
      'discontinuation_reason': null,
      'drug_interactions_checked': true,
      'ward_id': 'ward-a',
      'medication_coding_system': 'ATC',
      'created_at': '2026-06-01T08:00:00.000Z',
      'updated_at': '2026-06-01T08:00:00.000Z',
    };

    test('fromJson parses all required fields correctly', () {
      final model = PrescriptionModel.fromJson(Map<String, dynamic>.from(baseJson));

      expect(model.id, equals('rx-1'));
      expect(model.patientId, equals('pat-1'));
      expect(model.prescriberId, equals('doc-1'));
      expect(model.medicationName, equals('Amoxicillin'));
      expect(model.medicationCode, equals('AMX500'));
      expect(model.dosage, equals('500mg'));
      expect(model.frequency, equals('TDS'));
      expect(model.route, equals('oral'));
      expect(model.durationDays, equals(7));
      expect(model.quantity, equals(21));
      expect(model.refillsAllowed, equals(2));
      expect(model.refillsRemaining, equals(2));
      expect(model.prescribedDate, isA<DateTime>());
      expect(model.startDate, isA<DateTime>());
      expect(model.endDate, isA<DateTime>());
      expect(model.expiresDate, isA<DateTime>());
      expect(model.status, equals('active'));
      expect(model.specialInstructions, equals('Take with food'));
      expect(model.discontinuationReason, isNull);
      expect(model.drugInteractionsChecked, isTrue);
      expect(model.wardId, equals('ward-a'));
      expect(model.medicationCodingSystem, equals('ATC'));
      expect(model.createdAt, isA<DateTime>());
      expect(model.updatedAt, isA<DateTime>());
    });

    test('fromJson handles null optional fields gracefully', () {
      final minimalJson = <String, dynamic>{
        'id': 'rx-min',
        'patient_id': 'pat-min',
        'prescriber_id': 'doc-min',
        'medication_name': 'Paracetamol',
      };

      final model = PrescriptionModel.fromJson(minimalJson);

      expect(model.medicationCode, isNull);
      expect(model.dosage, equals(''));         // default
      expect(model.frequency, equals(''));      // default
      expect(model.route, isNull);
      expect(model.durationDays, isNull);
      expect(model.quantity, isNull);
      expect(model.refillsAllowed, equals(0)); // default
      expect(model.refillsRemaining, equals(0)); // default
      expect(model.prescribedDate, isNull);
      expect(model.startDate, isNull);
      expect(model.endDate, isNull);
      expect(model.expiresDate, isNull);
      expect(model.status, equals('active')); // default
      expect(model.specialInstructions, isNull);
      expect(model.discontinuationReason, isNull);
      expect(model.drugInteractionsChecked, isFalse); // default
      expect(model.wardId, isNull);
      expect(model.medicationCodingSystem, isNull);
      expect(model.createdAt, isNull);
      expect(model.updatedAt, isNull);
    });

    test('isActive is true for active status', () {
      final model = PrescriptionModel.fromJson(Map<String, dynamic>.from(baseJson));
      expect(model.isActive, isTrue);
    });

    test('isActive is true for pending and filled statuses', () {
      for (final s in ['pending', 'filled']) {
        final json = Map<String, dynamic>.from(baseJson)..['status'] = s;
        final model = PrescriptionModel.fromJson(json);
        expect(model.isActive, isTrue, reason: 'status=$s should be active');
      }
    });

    test('isActive is false for expired, cancelled, discontinued', () {
      for (final s in ['expired', 'cancelled', 'discontinued']) {
        final json = Map<String, dynamic>.from(baseJson)..['status'] = s;
        final model = PrescriptionModel.fromJson(json);
        expect(model.isActive, isFalse, reason: 'status=$s should not be active');
      }
    });

    test('canRefill is true when active and refillsRemaining > 0', () {
      final model = PrescriptionModel.fromJson(Map<String, dynamic>.from(baseJson));
      expect(model.canRefill, isTrue);
    });

    test('canRefill is false when active but refillsRemaining is 0', () {
      final json = Map<String, dynamic>.from(baseJson)..['refills_remaining'] = 0;
      final model = PrescriptionModel.fromJson(json);
      expect(model.canRefill, isFalse);
    });

    test('canRefill is false when inactive even if refillsRemaining > 0', () {
      final json = Map<String, dynamic>.from(baseJson)
        ..['status'] = 'expired'
        ..['refills_remaining'] = 3;
      final model = PrescriptionModel.fromJson(json);
      expect(model.canRefill, isFalse);
    });

    test('doseDisplay includes dosage, frequency, and route when route is present', () {
      final model = PrescriptionModel.fromJson(Map<String, dynamic>.from(baseJson));
      expect(model.doseDisplay, equals('500mg · TDS · oral'));
    });

    test('doseDisplay omits route separator when route is null', () {
      final json = Map<String, dynamic>.from(baseJson)..remove('route');
      final model = PrescriptionModel.fromJson(json);
      expect(model.doseDisplay, equals('500mg · TDS'));
    });

    test('DateTime fields are parsed from ISO strings', () {
      final model = PrescriptionModel.fromJson(Map<String, dynamic>.from(baseJson));
      expect(model.prescribedDate, equals(DateTime.parse('2026-06-01T00:00:00.000Z')));
      expect(model.startDate, equals(DateTime.parse('2026-06-01T00:00:00.000Z')));
      expect(model.endDate, equals(DateTime.parse('2026-06-08T00:00:00.000Z')));
      expect(model.expiresDate, equals(DateTime.parse('2026-09-01T00:00:00.000Z')));
    });
  });

  // ── LabResultModel ──────────────────────────────────────────────────────────

  group('LabResultModel', () {
    final baseJson = <String, dynamic>{
      'id': 'lab-1',
      'patient_id': 'pat-1',
      'ordered_by_id': 'doc-1',
      'performed_by_id': 'tech-1',
      'reviewed_by_id': 'doc-2',
      'test_name': 'Full Blood Count',
      'test_code': 'FBC',
      'test_type': 'haematology',
      'priority': 'urgent',
      'results': 'Hb: 8.2 g/dL, WBC: 12.1 x10³/µL',
      'interpretation': 'Mild anaemia with leukocytosis',
      'abnormal_flags': ['low_haemoglobin', 'high_wbc'],
      'status': 'completed',
      'ordered_date': '2026-06-01T08:00:00.000Z',
      'sample_collected_at': '2026-06-01T09:00:00.000Z',
      'completed_at': '2026-06-01T14:00:00.000Z',
      'reviewed_at': '2026-06-01T15:00:00.000Z',
      'file_path': 'lab-reports/lab-1.pdf',
      'requires_followup': true,
      'ward_id': 'ward-a',
      'created_at': '2026-06-01T08:00:00.000Z',
      'updated_at': '2026-06-01T15:00:00.000Z',
    };

    test('fromJson parses all required fields correctly', () {
      final model = LabResultModel.fromJson(Map<String, dynamic>.from(baseJson));

      expect(model.id, equals('lab-1'));
      expect(model.patientId, equals('pat-1'));
      expect(model.orderedById, equals('doc-1'));
      expect(model.performedById, equals('tech-1'));
      expect(model.reviewedById, equals('doc-2'));
      expect(model.testName, equals('Full Blood Count'));
      expect(model.testCode, equals('FBC'));
      expect(model.testType, equals('haematology'));
      expect(model.priority, equals('urgent'));
      expect(model.results, equals('Hb: 8.2 g/dL, WBC: 12.1 x10³/µL'));
      expect(model.interpretation, equals('Mild anaemia with leukocytosis'));
      expect(model.abnormalFlags, equals(['low_haemoglobin', 'high_wbc']));
      expect(model.status, equals('completed'));
      expect(model.orderedDate, isA<DateTime>());
      expect(model.sampleCollectedAt, isA<DateTime>());
      expect(model.completedAt, isA<DateTime>());
      expect(model.reviewedAt, isA<DateTime>());
      expect(model.filePath, equals('lab-reports/lab-1.pdf'));
      expect(model.requiresFollowup, isTrue);
      expect(model.wardId, equals('ward-a'));
      expect(model.createdAt, isA<DateTime>());
      expect(model.updatedAt, isA<DateTime>());
    });

    test('fromJson handles null optional fields gracefully', () {
      final minimalJson = <String, dynamic>{
        'id': 'lab-min',
        'patient_id': 'pat-min',
        'ordered_by_id': 'doc-min',
        'test_name': 'Urine MCS',
      };

      final model = LabResultModel.fromJson(minimalJson);

      expect(model.performedById, isNull);
      expect(model.reviewedById, isNull);
      expect(model.testCode, isNull);
      expect(model.testType, isNull);
      expect(model.priority, equals('routine')); // default
      expect(model.results, isNull);
      expect(model.interpretation, isNull);
      expect(model.abnormalFlags, isEmpty);
      expect(model.status, equals('pending')); // default
      expect(model.orderedDate, isNull);
      expect(model.sampleCollectedAt, isNull);
      expect(model.completedAt, isNull);
      expect(model.reviewedAt, isNull);
      expect(model.filePath, isNull);
      expect(model.requiresFollowup, isFalse); // default
      expect(model.wardId, isNull);
      expect(model.createdAt, isNull);
      expect(model.updatedAt, isNull);
    });

    test('isCompleted is true when status is completed', () {
      final model = LabResultModel.fromJson(Map<String, dynamic>.from(baseJson));
      expect(model.isCompleted, isTrue);
    });

    test('isCompleted is false for non-completed statuses', () {
      for (final s in ['pending', 'sample_collected', 'processing', 'cancelled']) {
        final json = Map<String, dynamic>.from(baseJson)..['status'] = s;
        final model = LabResultModel.fromJson(json);
        expect(model.isCompleted, isFalse, reason: 'status=$s should not be completed');
      }
    });

    test('isPending is true for pending, sample_collected, and processing', () {
      for (final s in ['pending', 'sample_collected', 'processing']) {
        final json = Map<String, dynamic>.from(baseJson)..['status'] = s;
        final model = LabResultModel.fromJson(json);
        expect(model.isPending, isTrue, reason: 'status=$s should be pending');
      }
    });

    test('isPending is false for completed and cancelled', () {
      for (final s in ['completed', 'cancelled']) {
        final json = Map<String, dynamic>.from(baseJson)..['status'] = s;
        final model = LabResultModel.fromJson(json);
        expect(model.isPending, isFalse, reason: 'status=$s should not be pending');
      }
    });

    test('isUrgent is true for urgent priority', () {
      final model = LabResultModel.fromJson(Map<String, dynamic>.from(baseJson));
      expect(model.isUrgent, isTrue);
    });

    test('isUrgent is true for stat priority', () {
      final json = Map<String, dynamic>.from(baseJson)..['priority'] = 'stat';
      final model = LabResultModel.fromJson(json);
      expect(model.isUrgent, isTrue);
    });

    test('isUrgent is false for routine priority', () {
      final json = Map<String, dynamic>.from(baseJson)..['priority'] = 'routine';
      final model = LabResultModel.fromJson(json);
      expect(model.isUrgent, isFalse);
    });

    test('hasAbnormalResults is true when abnormalFlags is non-empty', () {
      final model = LabResultModel.fromJson(Map<String, dynamic>.from(baseJson));
      expect(model.hasAbnormalResults, isTrue);
    });

    test('hasAbnormalResults is false when abnormalFlags is empty', () {
      final json = Map<String, dynamic>.from(baseJson)..['abnormal_flags'] = <String>[];
      final model = LabResultModel.fromJson(json);
      expect(model.hasAbnormalResults, isFalse);
    });

    test('hasAbnormalResults is false when abnormal_flags is absent', () {
      final json = Map<String, dynamic>.from(baseJson)..remove('abnormal_flags');
      final model = LabResultModel.fromJson(json);
      expect(model.hasAbnormalResults, isFalse);
    });

    test('DateTime fields parsed from ISO strings', () {
      final model = LabResultModel.fromJson(Map<String, dynamic>.from(baseJson));
      expect(model.orderedDate, equals(DateTime.parse('2026-06-01T08:00:00.000Z')));
      expect(model.completedAt, equals(DateTime.parse('2026-06-01T14:00:00.000Z')));
    });
  });

  // ── MedicalDocumentModel ────────────────────────────────────────────────────

  group('MedicalDocumentModel', () {
    final baseJson = <String, dynamic>{
      'id': 'doc-1',
      'patient_id': 'pat-1',
      'uploaded_by_id': 'user-1',
      'title': 'Chest X-Ray Report',
      'document_type': 'radiology',
      'original_filename': 'chest-xray.pdf',
      'mime_type': 'application/pdf',
      'file_size': 2097152, // 2 MB
      'notes': 'PA view, no consolidation',
      'is_confidential': true,
      'created_at': '2026-06-01T08:00:00.000Z',
      'updated_at': '2026-06-01T08:00:00.000Z',
      'temporary_url': 'https://storage.example.com/signed/doc-1',
    };

    test('fromJson parses all required fields correctly', () {
      final model = MedicalDocumentModel.fromJson(Map<String, dynamic>.from(baseJson));

      expect(model.id, equals('doc-1'));
      expect(model.patientId, equals('pat-1'));
      expect(model.uploadedById, equals('user-1'));
      expect(model.title, equals('Chest X-Ray Report'));
      expect(model.documentType, equals('radiology'));
      expect(model.originalFilename, equals('chest-xray.pdf'));
      expect(model.mimeType, equals('application/pdf'));
      expect(model.fileSize, equals(2097152));
      expect(model.notes, equals('PA view, no consolidation'));
      expect(model.isConfidential, isTrue);
      expect(model.createdAt, isA<DateTime>());
      expect(model.updatedAt, isA<DateTime>());
      expect(model.temporaryUrl, equals('https://storage.example.com/signed/doc-1'));
    });

    test('fromJson handles null optional fields gracefully', () {
      final minimalJson = <String, dynamic>{
        'id': 'doc-min',
        'patient_id': 'pat-min',
        'uploaded_by_id': 'user-min',
      };

      final model = MedicalDocumentModel.fromJson(minimalJson);

      expect(model.title, equals('Untitled Document')); // default
      expect(model.documentType, equals('other'));       // default
      expect(model.originalFilename, isNull);
      expect(model.mimeType, isNull);
      expect(model.fileSize, isNull);
      expect(model.notes, isNull);
      expect(model.isConfidential, isFalse); // default
      expect(model.createdAt, isNull);
      expect(model.updatedAt, isNull);
      expect(model.temporaryUrl, isNull);
    });

    test('isPdf is true when mimeType is application/pdf', () {
      final model = MedicalDocumentModel.fromJson(Map<String, dynamic>.from(baseJson));
      expect(model.isPdf, isTrue);
    });

    test('isPdf is false for non-pdf mime types', () {
      final json = Map<String, dynamic>.from(baseJson)..['mime_type'] = 'image/jpeg';
      final model = MedicalDocumentModel.fromJson(json);
      expect(model.isPdf, isFalse);
    });

    test('isPdf is false when mimeType is null', () {
      final json = Map<String, dynamic>.from(baseJson)..['mime_type'] = null;
      final model = MedicalDocumentModel.fromJson(json);
      expect(model.isPdf, isFalse);
    });

    test('isImage is true for image/jpeg', () {
      final json = Map<String, dynamic>.from(baseJson)..['mime_type'] = 'image/jpeg';
      final model = MedicalDocumentModel.fromJson(json);
      expect(model.isImage, isTrue);
    });

    test('isImage is true for image/png', () {
      final json = Map<String, dynamic>.from(baseJson)..['mime_type'] = 'image/png';
      final model = MedicalDocumentModel.fromJson(json);
      expect(model.isImage, isTrue);
    });

    test('isImage is false for application/pdf', () {
      final model = MedicalDocumentModel.fromJson(Map<String, dynamic>.from(baseJson));
      expect(model.isImage, isFalse);
    });

    test('isImage is false when mimeType is null', () {
      final json = Map<String, dynamic>.from(baseJson)..['mime_type'] = null;
      final model = MedicalDocumentModel.fromJson(json);
      expect(model.isImage, isFalse);
    });

    test('fileSizeDisplay returns empty string when fileSize is null', () {
      final json = Map<String, dynamic>.from(baseJson)..['file_size'] = null;
      final model = MedicalDocumentModel.fromJson(json);
      expect(model.fileSizeDisplay, equals(''));
    });

    test('fileSizeDisplay returns bytes notation for fileSize < 1024', () {
      final json = Map<String, dynamic>.from(baseJson)..['file_size'] = 512;
      final model = MedicalDocumentModel.fromJson(json);
      expect(model.fileSizeDisplay, equals('512B'));
    });

    test('fileSizeDisplay returns KB notation for fileSize between 1024 and 1MB', () {
      final json = Map<String, dynamic>.from(baseJson)..['file_size'] = 51200; // 50 KB
      final model = MedicalDocumentModel.fromJson(json);
      expect(model.fileSizeDisplay, equals('50.0KB'));
    });

    test('fileSizeDisplay returns MB notation for fileSize >= 1MB', () {
      final json = Map<String, dynamic>.from(baseJson)..['file_size'] = 2097152; // 2 MB
      final model = MedicalDocumentModel.fromJson(json);
      expect(model.fileSizeDisplay, equals('2.0MB'));
    });

    test('fileSizeDisplay returns fractional MB for non-round megabytes', () {
      final json = Map<String, dynamic>.from(baseJson)..['file_size'] = 1572864; // 1.5 MB
      final model = MedicalDocumentModel.fromJson(json);
      expect(model.fileSizeDisplay, equals('1.5MB'));
    });

    test('fileSizeDisplay boundary: exactly 1024 bytes is KB, not bytes', () {
      final json = Map<String, dynamic>.from(baseJson)..['file_size'] = 1024;
      final model = MedicalDocumentModel.fromJson(json);
      expect(model.fileSizeDisplay, equals('1.0KB'));
    });

    test('DateTime fields are parsed from ISO strings', () {
      final model = MedicalDocumentModel.fromJson(Map<String, dynamic>.from(baseJson));
      expect(model.createdAt, equals(DateTime.parse('2026-06-01T08:00:00.000Z')));
      expect(model.updatedAt, equals(DateTime.parse('2026-06-01T08:00:00.000Z')));
    });
  });

  // ── DrugInteraction ─────────────────────────────────────────────────────────

  group('DrugInteraction', () {
    final baseJson = <String, dynamic>{
      'severity': 'high',
      'drugs': ['Warfarin', 'Aspirin'],
      'description': 'Increased risk of bleeding when used concomitantly.',
    };

    test('fromJson parses all fields correctly', () {
      final model = DrugInteraction.fromJson(Map<String, dynamic>.from(baseJson));

      expect(model.severity, equals('high'));
      expect(model.drugs, equals(['Warfarin', 'Aspirin']));
      expect(model.description, equals('Increased risk of bleeding when used concomitantly.'));
    });

    test('fromJson applies defaults for missing fields', () {
      final model = DrugInteraction.fromJson({});

      expect(model.severity, equals('minor'));    // default
      expect(model.drugs, isEmpty);               // default
      expect(model.description, equals(''));      // default
    });

    test('fromJson parses moderate severity', () {
      final json = Map<String, dynamic>.from(baseJson)..['severity'] = 'moderate';
      final model = DrugInteraction.fromJson(json);
      expect(model.severity, equals('moderate'));
    });

    test('fromJson handles empty drugs list', () {
      final json = Map<String, dynamic>.from(baseJson)..['drugs'] = <String>[];
      final model = DrugInteraction.fromJson(json);
      expect(model.drugs, isEmpty);
    });

    test('toJson round-trips all fields', () {
      final model = DrugInteraction.fromJson(Map<String, dynamic>.from(baseJson));
      final json = model.toJson();

      expect(json['severity'], equals('high'));
      expect(json['drugs'], equals(['Warfarin', 'Aspirin']));
      expect(json['description'], equals('Increased risk of bleeding when used concomitantly.'));
    });
  });

  // ── InteractionCheckResult ──────────────────────────────────────────────────

  group('InteractionCheckResult', () {
    test('unavailable() factory returns empty interactions and apiAvailable=false', () {
      final result = InteractionCheckResult.unavailable();

      expect(result.interactions, isEmpty);
      expect(result.apiAvailable, isFalse);
      expect(result.hasInteractions, isFalse);
    });

    test('hasInteractions is true when interactions list is non-empty', () {
      final interaction = DrugInteraction.fromJson({
        'severity': 'moderate',
        'drugs': ['Drug A', 'Drug B'],
        'description': 'Some interaction',
      });
      final result = InteractionCheckResult(
        interactions: [interaction],
        apiAvailable: true,
      );

      expect(result.hasInteractions, isTrue);
      expect(result.apiAvailable, isTrue);
    });

    test('hasInteractions is false when interactions list is empty', () {
      const result = InteractionCheckResult(interactions: [], apiAvailable: true);
      expect(result.hasInteractions, isFalse);
    });

    test('constructor stores multiple interactions', () {
      final interactions = [
        DrugInteraction.fromJson({
          'severity': 'high',
          'drugs': ['Warfarin', 'Aspirin'],
          'description': 'Bleeding risk',
        }),
        DrugInteraction.fromJson({
          'severity': 'minor',
          'drugs': ['Ibuprofen', 'Paracetamol'],
          'description': 'Minor hepatic effect',
        }),
      ];
      final result = InteractionCheckResult(
        interactions: interactions,
        apiAvailable: true,
      );

      expect(result.interactions.length, equals(2));
      expect(result.interactions.first.severity, equals('high'));
      expect(result.interactions.last.severity, equals('minor'));
    });
  });
}
