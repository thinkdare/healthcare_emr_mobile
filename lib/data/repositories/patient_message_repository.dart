// lib/data/repositories/patient_message_repository.dart

import '../../core/api/api_client.dart';
import '../models/patient_message_models.dart';

class PatientMessageRepository {
  final ApiClient apiClient;

  PatientMessageRepository({required this.apiClient});

  // ── GET /api/v1/patients/{patientId}/messages ───────────────────────────

  Future<List<PatientMessageModel>> getInbox(String patientId, {int page = 1}) async {
    final response = await apiClient.get(
      '/patients/$patientId/messages',
      queryParameters: {'page': page, 'per_page': 20},
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to load messages');
    }
    final raw = response['data'] as List? ?? [];
    return raw
        .map((e) => PatientMessageModel.fromJson(
              Map<String, dynamic>.from(e as Map),
            ))
        .toList();
  }

  // ── POST /api/v1/patients/{patientId}/messages/{id}/reply ──────────────

  Future<PatientMessageModel> reply(String patientId, String messageId, String body) async {
    final response = await apiClient.post(
      '/patients/$patientId/messages/$messageId/reply',
      data: {'body': body},
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to send reply');
    }
    return PatientMessageModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map));
  }
}
