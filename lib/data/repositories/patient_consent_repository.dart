// lib/data/repositories/patient_consent_repository.dart

import '../../core/api/api_client.dart';
import '../models/patient_consent_models.dart';

class PatientConsentRepository {
  final ApiClient apiClient;

  PatientConsentRepository({required this.apiClient});

  // ── GET /api/v1/patients/{id}/consents ──────────────────────────────────

  Future<List<PatientConsentModel>> list(String patientId) async {
    final response = await apiClient.get('/patients/$patientId/consents');
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to load consent records');
    }
    final raw = response['data'] as List? ?? [];
    return raw
        .map((e) => PatientConsentModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  // ── POST /api/v1/patients/{id}/consents ─────────────────────────────────

  Future<PatientConsentModel> record(
    String patientId, {
    required String consentType,
    required String legalBasis,
    required bool given,
    required String documentVersion,
    String? notes,
  }) async {
    final response = await apiClient.post('/patients/$patientId/consents', data: {
      'consent_type': consentType,
      'legal_basis': legalBasis,
      'given': given,
      'document_version': documentVersion,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to record consent');
    }
    return PatientConsentModel.fromJson(Map<String, dynamic>.from(response['data'] as Map));
  }

  // ── DELETE /api/v1/patients/{id}/consents/{type} ────────────────────────

  Future<void> revoke(
    String patientId,
    String consentType, {
    required String documentVersion,
    String? notes,
  }) async {
    final response = await apiClient.delete(
      '/patients/$patientId/consents/$consentType',
      data: {
        'document_version': documentVersion,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to revoke consent');
    }
  }

  // ── GET /api/v1/patients/{id}/consents/history ──────────────────────────

  Future<List<PatientConsentEventModel>> history(String patientId) async {
    final response = await apiClient.get('/patients/$patientId/consents/history');
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to load consent history');
    }
    final raw = response['data'] as List? ?? [];
    return raw
        .map((e) => PatientConsentEventModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  // ── PUT /api/v1/patients/{id}/notification-preferences ──────────────────

  Future<NotificationPreferencesModel> updatePreferences(
      String patientId, NotificationPreferencesModel preferences) async {
    final response = await apiClient.put('/patients/$patientId/notification-preferences', data: {
      'preferences': {
        'appointment_reminders': preferences.appointmentReminders,
        'sms': preferences.sms,
        'email': preferences.email,
        'push': preferences.push,
      },
    });
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to update notification preferences');
    }
    final data = response['data'] as Map;
    return NotificationPreferencesModel.fromJson(
        data['preferences'] != null ? Map<String, dynamic>.from(data['preferences'] as Map) : null);
  }
}
