import '../../core/api/api_client.dart';
import '../models/auth_models.dart';

class StaffRepository {
  final ApiClient apiClient;

  StaffRepository({required this.apiClient});

  /// Returns all staff members at the active facility (scoped by X-Tenant-ID header).
  Future<List<FacilityStaffMemberModel>> getStaffMemberships() async {
    final response = await apiClient.get(
      '/staff/memberships',
      queryParameters: {'per_page': 200},
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to load staff');
    }
    final data = response['data'];
    final raw = data is Map
        ? (data['data'] as List? ?? [])
        : (data as List? ?? []);
    return raw
        .map((e) => FacilityStaffMemberModel.fromJson(
            Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> updateMembership(
    String membershipId, {
    String? staffType,
    String? clinicalRankId,
    bool? isActive,
  }) async {
    final data = <String, dynamic>{
      'staff_type': ?staffType,
      'clinical_rank_id': ?clinicalRankId,
      'is_active': ?isActive,
    };
    final response = await apiClient.put(
      '/staff/memberships/$membershipId',
      data: data,
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to update membership');
    }
  }

  Future<void> deleteMembership(String membershipId, String reason) async {
    final response = await apiClient.delete(
      '/staff/memberships/$membershipId',
      data: {'reason': reason},
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to remove staff member');
    }
  }

  Future<List<ClinicalRankModel>> getClinicalRanks() async {
    final response = await apiClient.get('/clinical-ranks');
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to load clinical ranks');
    }
    final data = response['data'];
    final raw = data is Map
        ? (data['data'] as List? ?? [])
        : (data as List? ?? []);
    return raw
        .map((e) =>
            ClinicalRankModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}
