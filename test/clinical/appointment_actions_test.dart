import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_emr_mobile/core/api/api_client.dart';
import 'package:healthcare_emr_mobile/core/database/local_database.dart';
import 'package:healthcare_emr_mobile/data/repositories/clinical_repository.dart';

Map<String, dynamic> _apptJson(String id, {String status = 'scheduled'}) => {
      'id': id,
      'patient_id': 'pat-1',
      'provider_id': 'doc-1',
      'appointment_date': '2026-07-01T09:00:00.000',
      'duration_minutes': 30,
      'appointment_type': 'consultation',
      'status': status,
      'reminder_sent': false,
    };

class _RecordingApiClient extends ApiClient {
  String? lastPath;
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
    lastData = data;
    return response;
  }
}

void main() {
  group('ClinicalRepository.completeAppointment', () {
    test('POSTs to the complete endpoint with notes', () async {
      final fake = _RecordingApiClient({
        'success': true,
        'data': _apptJson('appt-1', status: 'completed'),
      });
      final repo = ClinicalRepository(apiClient: fake, db: LocalDatabase.instance);

      final result = await repo.completeAppointment('pat-1', 'appt-1', notes: 'All good');

      expect(fake.lastPath, '/patients/pat-1/appointments/appt-1/complete');
      expect(fake.lastData, {'notes': 'All good'});
      expect(result.status, 'completed');
    });

    test('throws when the backend reports failure', () async {
      final fake = _RecordingApiClient({'success': false, 'message': 'Invalid transition'});
      final repo = ClinicalRepository(apiClient: fake, db: LocalDatabase.instance);

      expect(
        () => repo.completeAppointment('pat-1', 'appt-1'),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('ClinicalRepository.cancelAppointment', () {
    test('POSTs to the cancel endpoint with a reason', () async {
      final fake = _RecordingApiClient({
        'success': true,
        'data': _apptJson('appt-1', status: 'cancelled'),
      });
      final repo = ClinicalRepository(apiClient: fake, db: LocalDatabase.instance);

      final result = await repo.cancelAppointment('pat-1', 'appt-1', reason: 'Patient request');

      expect(fake.lastPath, '/patients/pat-1/appointments/appt-1/cancel');
      expect(fake.lastData, {'cancellation_reason': 'Patient request'});
      expect(result.status, 'cancelled');
    });
  });
}
