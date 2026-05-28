import '../../core/api/api_client.dart';
import '../models/organization_models_enhanced.dart';

class FacilityRepository {
  final ApiClient apiClient;

  FacilityRepository({required this.apiClient});

  /// Get all facilities for current organization
  Future<List<FacilityModel>> getFacilities({
    String? organizationId,
    String? type,
    bool activeOnly = true,
  }) async {
    final queryParams = <String, dynamic>{
      'organization_id': ?organizationId,
      'type': ?type,
      'active_only': activeOnly,
    };

    final response = await apiClient.get(
      '/facilities',
      queryParameters: queryParams,
    );

    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to get facilities');
    }

    final data = response['data'] as List? ?? [];
    return data
        .map((e) => FacilityModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Get single facility
  Future<FacilityModel> getFacility(String id) async {
    final response = await apiClient.get('/facilities/$id');

    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to get facility');
    }

    return FacilityModel.fromJson(
      Map<String, dynamic>.from(response['data']),
    );
  }

  /// Create facility (admin only)
  Future<FacilityModel> createFacility({
    required String organizationId,
    required String name,
    required String type,
    required String address,
    String? phone,
    Map<String, dynamic>? operatingHours,
    required bool supportsEmergencyAccess,
  }) async {
    final response = await apiClient.post(
      '/facilities',
      data: {
        'organization_id': organizationId,
        'name': name,
        'type': type,
        'address': address,
        'phone': ?phone,
        'operating_hours': ?operatingHours,
        'supports_emergency_access': supportsEmergencyAccess,
      },
    );

    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to create facility');
    }

    return FacilityModel.fromJson(
      Map<String, dynamic>.from(response['data']),
    );
  }

  /// Update facility (admin only)
  Future<FacilityModel> updateFacility({
    required String id,
    String? name,
    String? type,
    String? address,
    String? phone,
    Map<String, dynamic>? operatingHours,
    bool? supportsEmergencyAccess,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (type != null) data['type'] = type;
    if (address != null) data['address'] = address;
    if (phone != null) data['phone'] = phone;
    if (operatingHours != null) data['operating_hours'] = operatingHours;
    if (supportsEmergencyAccess != null) {
      data['supports_emergency_access'] = supportsEmergencyAccess;
    }

    final response = await apiClient.patch('/facilities/$id', data: data);

    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to update facility');
    }

    return FacilityModel.fromJson(
      Map<String, dynamic>.from(response['data']),
    );
  }

  /// Delete facility (admin only)
  Future<void> deleteFacility(String id) async {
    final response = await apiClient.delete('/facilities/$id');

    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to delete facility');
    }
  }

  /// List all active tenants — used as destination picker in referral form.
  Future<List<Map<String, dynamic>>> listTenants() async {
    final response = await apiClient.get(
      '/tenants',
      queryParameters: {'per_page': 100, 'is_active': true},
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to load facilities');
    }
    final data = response['data'];
    final raw =
        data is Map ? (data['data'] as List? ?? []) : (data as List? ?? []);
    return raw
        .map((e) => {'id': e['id'], 'name': e['name']})
        .toList()
        .cast<Map<String, dynamic>>();
  }

  /// List active staff at a specific tenant — used as provider picker in referral form.
  Future<List<Map<String, dynamic>>> listStaffAtTenant(
      String tenantId) async {
    final response = await apiClient.get(
      '/staff/memberships',
      queryParameters: {'tenant_id': tenantId, 'per_page': 100},
    );
    if (response['success'] != true) return [];
    final data = response['data'];
    final raw =
        data is Map ? (data['data'] as List? ?? []) : (data as List? ?? []);
    return raw.map((e) {
      final user = e['user'] as Map?;
      return {
        'id': user?['id'] ?? e['user_id'],
        'name': user != null
            ? '${user['first_name']} ${user['last_name']}'
            : 'Provider',
      };
    }).toList().cast<Map<String, dynamic>>();
  }

  /// List colleagues at the current user's active tenant — used in intra-grant form.
  /// Returns membership_id alongside user info so the controller can target the correct membership.
  Future<List<Map<String, dynamic>>> listStaffAtCurrentTenant() async {
    final response = await apiClient.get(
      '/staff/memberships',
      queryParameters: {'per_page': 100},
    );
    if (response['success'] != true) return [];
    final data = response['data'];
    final raw =
        data is Map ? (data['data'] as List? ?? []) : (data as List? ?? []);
    return raw.map((e) {
      final user = e['user'] as Map?;
      return {
        'membership_id': e['id'],
        'user_id': user?['id'] ?? e['user_id'],
        'name': user != null
            ? '${user['first_name']} ${user['last_name']}'
            : 'Provider',
        'staff_type': e['staff_type'] ?? '',
      };
    }).toList().cast<Map<String, dynamic>>();
  }
}