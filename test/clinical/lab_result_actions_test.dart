import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_emr_mobile/core/api/api_client.dart';
import 'package:healthcare_emr_mobile/core/database/local_database.dart';
import 'package:healthcare_emr_mobile/data/repositories/clinical_repository.dart';

Map<String, dynamic> _labJson(String id, {String status = 'pending'}) => {
      'id': id,
      'patient_id': 'pat-1',
      'ordered_by_id': 'doc-1',
      'test_name': 'CBC',
      'priority': 'routine',
      'abnormal_flags': [],
      'status': status,
      'requires_followup': false,
    };

class _RecordingApiClient extends ApiClient {
  String? lastPath;
  String? lastMethod;
  dynamic lastData;
  Map<String, dynamic> response;

  _RecordingApiClient(this.response) : super();

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
  group('ClinicalRepository.cancelLabResult', () {
    test('POSTs to the cancel endpoint', () async {
      final fake = _RecordingApiClient({
        'success': true,
        'data': _labJson('lab-1', status: 'cancelled'),
      });
      final repo = ClinicalRepository(apiClient: fake, db: LocalDatabase.instance);

      final result = await repo.cancelLabResult('pat-1', 'lab-1');

      expect(fake.lastMethod, 'POST');
      expect(fake.lastPath, '/patients/pat-1/lab-results/lab-1/cancel');
      expect(result.status, 'cancelled');
    });

    test('throws when the backend reports failure', () async {
      final fake = _RecordingApiClient({'success': false, 'message': 'Already completed'});
      final repo = ClinicalRepository(apiClient: fake, db: LocalDatabase.instance);

      expect(
        () => repo.cancelLabResult('pat-1', 'lab-1'),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('ClinicalRepository.reviewLabResult', () {
    test('POSTs to the review endpoint with interpretation/requires_followup', () async {
      final fake = _RecordingApiClient({
        'success': true,
        'data': _labJson('lab-1', status: 'completed'),
      });
      final repo = ClinicalRepository(apiClient: fake, db: LocalDatabase.instance);

      final result = await repo.reviewLabResult(
        'pat-1',
        'lab-1',
        interpretation: 'Within normal range',
        requiresFollowup: false,
      );

      expect(fake.lastMethod, 'POST');
      expect(fake.lastPath, '/patients/pat-1/lab-results/lab-1/review');
      expect(fake.lastData, {
        'interpretation': 'Within normal range',
        'requires_followup': false,
      });
      expect(result.status, 'completed');
    });

    test('throws when results are already reviewed', () async {
      final fake = _RecordingApiClient(
          {'success': false, 'message': 'These results have already been reviewed.'});
      final repo = ClinicalRepository(apiClient: fake, db: LocalDatabase.instance);

      expect(
        () => repo.reviewLabResult('pat-1', 'lab-1'),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('ClinicalRepository.printLabOrder', () {
    test('POSTs to the print endpoint and returns the raw payload', () async {
      final payload = {
        'type': 'lab_order',
        'lab_order': {'test_name': 'CBC'},
      };
      final fake = _RecordingApiClient({'success': true, 'data': payload});
      final repo = ClinicalRepository(apiClient: fake, db: LocalDatabase.instance);

      final result = await repo.printLabOrder('pat-1', 'lab-1');

      expect(fake.lastMethod, 'POST');
      expect(fake.lastPath, '/patients/pat-1/lab-results/lab-1/print');
      expect(result['type'], 'lab_order');
    });
  });
}
