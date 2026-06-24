import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_emr_mobile/core/api/api_client.dart';
import 'package:healthcare_emr_mobile/core/database/local_database.dart';
import 'package:healthcare_emr_mobile/data/repositories/patient_repository.dart';

class _RecordingApiClient extends ApiClient {
  String? lastGetPath;
  Map<String, dynamic>? lastGetQuery;
  String? lastPostPath;
  Map<String, dynamic> getResponse;
  Map<String, dynamic> postResponse;

  _RecordingApiClient({required this.getResponse, required this.postResponse}) : super();

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    lastGetPath = path;
    lastGetQuery = queryParameters;
    return getResponse;
  }

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    lastPostPath = path;
    return postResponse;
  }
}

void main() {
  group('PatientRepository.getAuditLog', () {
    test('GETs the audit-log endpoint and returns the raw entries', () async {
      final fake = _RecordingApiClient(
        getResponse: {
          'success': true,
          'data': [
            {'id': 'log-1', 'action': 'viewed', 'resource_type': 'full_record'},
          ],
        },
        postResponse: {},
      );
      final repo = PatientRepository(apiClient: fake, localDatabase: LocalDatabase.instance);

      final result = await repo.getAuditLog('pat-1');

      expect(fake.lastGetPath, '/patients/pat-1/audit-log');
      expect(result, hasLength(1));
      expect(result.first['action'], 'viewed');
    });

    test('throws when the backend reports failure', () async {
      final fake = _RecordingApiClient(
        getResponse: {'success': false, 'message': 'Only the primary provider can view the patient audit log.'},
        postResponse: {},
      );
      final repo = PatientRepository(apiClient: fake, localDatabase: LocalDatabase.instance);

      expect(() => repo.getAuditLog('pat-1'), throwsA(isA<Exception>()));
    });
  });

  group('PatientRepository.activatePatient', () {
    test('POSTs to the activate endpoint and returns the activation fields', () async {
      final fake = _RecordingApiClient(
        getResponse: {},
        postResponse: {
          'success': true,
          'data': {
            'record_status': 'active',
            'activated_at': '2026-06-24T10:00:00Z',
            'activation_expires_at': '2026-06-25T10:00:00Z',
          },
        },
      );
      final repo = PatientRepository(apiClient: fake, localDatabase: LocalDatabase.instance);

      final result = await repo.activatePatient('pat-1');

      expect(fake.lastPostPath, '/patients/pat-1/activate');
      expect(result['record_status'], 'active');
    });
  });
}
