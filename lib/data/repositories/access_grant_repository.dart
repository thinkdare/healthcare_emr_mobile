import '../../core/api/api_client.dart';
import '../models/access_grant_models.dart';

class AccessGrantRepository {
  final ApiClient apiClient;

  AccessGrantRepository({required this.apiClient});

  // ── GET /api/v1/access-grants ─────────────────────────────────────────────

  Future<({List<AccessGrantModel> pendingApproval, List<AccessGrantModel> myRequests})>
      getGrants() async {
    final response = await apiClient.get('/access-grants');
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to load access grants');
    }
    final data = response['data'] as Map<String, dynamic>;

    List<AccessGrantModel> parse(dynamic raw) =>
        (raw as List? ?? [])
            .map((e) => AccessGrantModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();

    return (
      pendingApproval: parse(data['pending_my_approval']),
      myRequests:      parse(data['my_requests']),
    );
  }

  // ── POST /api/v1/access-grants ────────────────────────────────────────────

  Future<AccessGrantModel> requestAccess(Map<String, dynamic> data) async {
    final response = await apiClient.post('/access-grants', data: data);
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to request access');
    }
    return AccessGrantModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map));
  }

  // ── POST /api/v1/access-grants/{id}/approve ───────────────────────────────

  Future<AccessGrantModel> approve(String id, {String? notes}) async {
    final response = await apiClient.post(
      '/access-grants/$id/approve',
      data: {if (notes != null && notes.isNotEmpty) 'notes': notes},
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to approve grant');
    }
    return AccessGrantModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map));
  }

  // ── POST /api/v1/access-grants/{id}/deny ─────────────────────────────────

  Future<AccessGrantModel> deny(String id, String reason) async {
    final response = await apiClient.post(
      '/access-grants/$id/deny',
      data: {'reason': reason},
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to deny grant');
    }
    return AccessGrantModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map));
  }

  // ── POST /api/v1/access-grants/{id}/revoke ───────────────────────────────

  Future<AccessGrantModel> revoke(String id, String reason) async {
    final response = await apiClient.post(
      '/access-grants/$id/revoke',
      data: {'reason': reason},
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to revoke grant');
    }
    return AccessGrantModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map));
  }
}
