import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_emr_mobile/core/api/api_client.dart';
import 'package:healthcare_emr_mobile/core/database/local_database.dart';
import 'package:healthcare_emr_mobile/data/repositories/clinical_repository.dart';

Map<String, dynamic> _rxJson(String id, {String status = 'active', int refillsRemaining = 1}) => {
      'id': id,
      'patient_id': 'pat-1',
      'prescriber_id': 'doc-1',
      'medication_name': 'Amoxicillin',
      'dosage': '500mg',
      'frequency': 'TID',
      'refills_allowed': 2,
      'refills_remaining': refillsRemaining,
      'status': status,
      'drug_interactions_checked': false,
    };

class _RecordingApiClient extends ApiClient {
  String? lastPath;
  String? lastMethod;
  dynamic lastData;
  Map<String, dynamic> response;

  _RecordingApiClient(this.response) : super();

  @override
  Future<Map<String, dynamic>> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    lastPath = path;
    lastMethod = 'PUT';
    lastData = data;
    return response;
  }

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    lastPath = path;
    lastMethod = 'POST';
    lastData = data;
    return response;
  }
}

void main() {
  group('ClinicalRepository.updatePrescription', () {
    test('PUTs to the prescription endpoint with the given fields', () async {
      final fake = _RecordingApiClient({
        'success': true,
        'data': _rxJson('rx-1'),
      });
      final repo = ClinicalRepository(apiClient: fake, db: LocalDatabase.instance);

      final result = await repo.updatePrescription(
        'pat-1',
        'rx-1',
        {'dosage': '250mg'},
      );

      expect(fake.lastMethod, 'PUT');
      expect(fake.lastPath, '/patients/pat-1/prescriptions/rx-1');
      expect(fake.lastData, {'dosage': '250mg'});
      expect(result.id, 'rx-1');
    });

    test('throws when the backend reports failure', () async {
      final fake = _RecordingApiClient({'success': false, 'message': 'Invalid status'});
      final repo = ClinicalRepository(apiClient: fake, db: LocalDatabase.instance);

      expect(
        () => repo.updatePrescription('pat-1', 'rx-1', {'dosage': '250mg'}),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('ClinicalRepository.refillPrescription', () {
    test('POSTs to the refill endpoint', () async {
      final fake = _RecordingApiClient({
        'success': true,
        'data': _rxJson('rx-1', refillsRemaining: 1),
      });
      final repo = ClinicalRepository(apiClient: fake, db: LocalDatabase.instance);

      final result = await repo.refillPrescription('pat-1', 'rx-1');

      expect(fake.lastMethod, 'POST');
      expect(fake.lastPath, '/patients/pat-1/prescriptions/rx-1/refill');
      expect(result.refillsRemaining, 1);
    });
  });

  group('ClinicalRepository.printPrescription', () {
    test('POSTs to the print endpoint and returns the raw payload', () async {
      final payload = {
        'type': 'prescription',
        'prescription': {'medication_name': 'Amoxicillin'},
      };
      final fake = _RecordingApiClient({'success': true, 'data': payload});
      final repo = ClinicalRepository(apiClient: fake, db: LocalDatabase.instance);

      final result = await repo.printPrescription('pat-1', 'rx-1');

      expect(fake.lastMethod, 'POST');
      expect(fake.lastPath, '/patients/pat-1/prescriptions/rx-1/print');
      expect(result['type'], 'prescription');
    });
  });
}
