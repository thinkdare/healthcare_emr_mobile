// lib/data/repositories/referral_repository.dart

import '../../core/api/api_client.dart';
import '../models/referral_models.dart';

class ReferralRepository {
  final ApiClient apiClient;

  // Set by ReferralProvider before each list/show/create call so that
  // isSent/isReceived role flags are computed with the correct tenant.
  String currentTenantId = '';

  ReferralRepository({required this.apiClient});

  List<ReferralModel> _parseList(List raw) => raw
      .map((e) => ReferralModel.fromJson(
            Map<String, dynamic>.from(e as Map),
            currentTenantId: currentTenantId,
          ))
      .toList();

  ReferralModel _parseOne(Map raw) => ReferralModel.fromJson(
        Map<String, dynamic>.from(raw),
        currentTenantId: currentTenantId,
      );

  // ── GET /api/v1/referrals ─────────────────────────────────────────────────

  Future<List<ReferralModel>> list({int page = 1}) async {
    final response = await apiClient.get(
      '/referrals',
      queryParameters: {'page': page, 'per_page': 50},
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to load referrals');
    }
    final data = response['data'];
    final raw =
        data is Map ? (data['data'] as List? ?? []) : (data as List? ?? []);
    return _parseList(raw);
  }

  // ── GET /api/v1/referrals/{id} ────────────────────────────────────────────

  Future<ReferralModel> show(String id) async {
    final response = await apiClient.get('/referrals/$id');
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to load referral');
    }
    return _parseOne(response['data'] as Map);
  }

  // ── POST /api/v1/referrals ────────────────────────────────────────────────

  Future<ReferralModel> create(Map<String, dynamic> data) async {
    final response = await apiClient.post('/referrals', data: data);
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to create referral');
    }
    return _parseOne(response['data'] as Map);
  }

  // ── POST /api/v1/referrals/{id}/accept ───────────────────────────────────

  Future<ReferralModel> accept(String id) async {
    final response = await apiClient.post('/referrals/$id/accept');
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to accept referral');
    }
    return _parseOne(response['data'] as Map);
  }

  // ── POST /api/v1/referrals/{id}/schedule ─────────────────────────────────

  Future<ReferralModel> schedule(
      String id, String appointmentDate, String? location) async {
    final response = await apiClient.post('/referrals/$id/schedule', data: {
      'appointment_date': appointmentDate,
      if (location != null && location.isNotEmpty)
        'appointment_location': location,
    });
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to schedule referral');
    }
    return _parseOne(response['data'] as Map);
  }

  // ── POST /api/v1/referrals/{id}/complete ─────────────────────────────────

  Future<ReferralModel> complete(
      String id, String notes, String? recommendations) async {
    final response = await apiClient.post('/referrals/$id/complete', data: {
      'consultation_notes': notes,
      if (recommendations != null && recommendations.isNotEmpty)
        'recommendations': recommendations,
    });
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to complete referral');
    }
    return _parseOne(response['data'] as Map);
  }

  // ── POST /api/v1/referrals/{id}/cancel ───────────────────────────────────

  Future<ReferralModel> cancel(String id, String reason) async {
    final response = await apiClient.post(
      '/referrals/$id/cancel',
      data: {'reason': reason},
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to cancel referral');
    }
    return _parseOne(response['data'] as Map);
  }

  // ── GET /api/v1/referrals/{id}/messages ──────────────────────────────────

  Future<List<ReferralMessageModel>> getMessages(String id) async {
    final response = await apiClient.get('/referrals/$id/messages');
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to load messages');
    }
    final raw = response['data'] as List? ?? [];
    return raw
        .map((e) => ReferralMessageModel.fromJson(
              Map<String, dynamic>.from(e as Map),
            ))
        .toList();
  }

  // ── POST /api/v1/referrals/{id}/messages ─────────────────────────────────

  Future<ReferralMessageModel> sendMessage(String id, String message) async {
    final response = await apiClient.post(
      '/referrals/$id/messages',
      data: {'message': message},
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to send message');
    }
    return ReferralMessageModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map));
  }
}
