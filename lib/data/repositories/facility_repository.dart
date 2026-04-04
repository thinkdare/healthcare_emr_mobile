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
      if (organizationId != null) 'organization_id': organizationId,
      if (type != null) 'type': type,
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
        if (phone != null) 'phone': phone,
        if (operatingHours != null) 'operating_hours': operatingHours,
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
}