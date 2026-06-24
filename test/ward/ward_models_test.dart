import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_emr_mobile/data/models/ward_models.dart';

void main() {
  group('WardModel', () {
    test('fromJson parses all fields', () {
      final ward = WardModel.fromJson({
        'id': 'ward-1',
        'name': 'ICU',
        'bed_count': 10,
        'available_bed_count': 3,
      });

      expect(ward.id, 'ward-1');
      expect(ward.name, 'ICU');
      expect(ward.bedCount, 10);
      expect(ward.availableBedCount, 3);
    });
  });

  group('WardAccessGrantModel', () {
    test('fromJson parses required and optional fields', () {
      final grant = WardAccessGrantModel.fromJson({
        'id': 'grant-1',
        'ward_id': 'ward-1',
        'ward_name': 'ICU',
        'granted_at': '2026-06-01T10:00:00Z',
        'granted_by': 'user-1',
      });

      expect(grant.id, 'grant-1');
      expect(grant.wardId, 'ward-1');
      expect(grant.wardName, 'ICU');
      expect(grant.grantedBy, 'user-1');
    });

    test('fromJson handles null optional fields', () {
      final grant = WardAccessGrantModel.fromJson({
        'id': 'grant-2',
        'ward_id': 'ward-2',
        'ward_name': null,
        'granted_at': '2026-06-01T10:00:00Z',
        'granted_by': null,
      });

      expect(grant.wardName, isNull);
      expect(grant.grantedBy, isNull);
    });
  });

  group('AdmissionRequestModel', () {
    final baseJson = {
      'id': 'req-1',
      'patient_id': 'patient-1',
      'ward_id': 'ward-1',
      'bed_id': null,
      'admission_type': 'elective',
      'reason': 'Scheduled surgery recovery',
      'status': 'pending',
      'rejection_reason': null,
      'admission_id': null,
      'requested_at': '2026-06-01T10:00:00Z',
      'reviewed_at': null,
    };

    test('fromJson parses required fields', () {
      final model = AdmissionRequestModel.fromJson(Map.of(baseJson));
      expect(model.id, 'req-1');
      expect(model.admissionType, 'elective');
      expect(model.status, 'pending');
    });

    test('isPending is true only when status is pending', () {
      expect(AdmissionRequestModel.fromJson(Map.of(baseJson)).isPending, isTrue);
      final accepted = AdmissionRequestModel.fromJson(
          Map.of(baseJson)..['status'] = 'accepted');
      expect(accepted.isPending, isFalse);
    });
  });

  group('WardTransferRequestModel', () {
    test('fromJson parses required fields', () {
      final model = WardTransferRequestModel.fromJson({
        'id': 'tr-1',
        'patient_id': 'patient-1',
        'admission_id': 'adm-1',
        'from_ward_id': 'ward-1',
        'to_ward_id': 'ward-2',
        'from_bed_id': null,
        'to_bed_id': null,
        'reason': 'Needs ICU monitoring',
        'status': 'pending',
        'rejection_reason': null,
        'new_admission_id': null,
        'requested_at': '2026-06-01T10:00:00Z',
        'reviewed_at': null,
      });

      expect(model.id, 'tr-1');
      expect(model.toWardId, 'ward-2');
      expect(model.isPending, isTrue);
    });
  });

  group('DischargeRequestModel', () {
    test('fromJson parses signoffs and computes approval state', () {
      final model = DischargeRequestModel.fromJson({
        'id': 'dis-1',
        'patient_id': 'patient-1',
        'admission_id': 'adm-1',
        'status': 'pending',
        'discharge_type': 'routine',
        'discharge_summary': 'Recovered well',
        'approved_at': null,
        'discharged_at': null,
        'initiated_at': '2026-06-01T10:00:00Z',
        'signoffs': [
          {
            'id': 'so-1',
            'department_type': 'nursing',
            'status': 'approved',
            'signed_at': '2026-06-01T11:00:00Z',
            'notes': null,
            'overridden_at': null,
          },
          {
            'id': 'so-2',
            'department_type': 'billing',
            'status': 'pending',
            'signed_at': null,
            'notes': null,
            'overridden_at': null,
          },
        ],
      });

      expect(model.signoffs, hasLength(2));
      expect(model.allSignoffsApproved, isFalse);
      expect(model.canRecordsApprove, isFalse);
    });

    test('allSignoffsApproved is true when every signoff is approved or overridden', () {
      final model = DischargeRequestModel.fromJson({
        'id': 'dis-2',
        'patient_id': 'patient-1',
        'admission_id': 'adm-1',
        'status': 'pending',
        'discharge_type': 'routine',
        'discharge_summary': null,
        'approved_at': null,
        'discharged_at': null,
        'initiated_at': '2026-06-01T10:00:00Z',
        'signoffs': [
          {'id': 'so-1', 'department_type': 'nursing', 'status': 'approved'},
          {'id': 'so-2', 'department_type': 'billing', 'status': 'overridden'},
        ],
      });

      expect(model.allSignoffsApproved, isTrue);
      expect(model.canRecordsApprove, isTrue);
    });

    test('canExecute is true once status is records_approved', () {
      final model = DischargeRequestModel.fromJson({
        'id': 'dis-3',
        'patient_id': 'patient-1',
        'admission_id': 'adm-1',
        'status': 'records_approved',
        'discharge_type': 'routine',
        'discharge_summary': null,
        'approved_at': '2026-06-02T09:00:00Z',
        'discharged_at': null,
        'initiated_at': '2026-06-01T10:00:00Z',
        'signoffs': [],
      });

      expect(model.canExecute, isTrue);
    });
  });
}
