import '../../core/api/api_client.dart';
import '../models/auth_models.dart';
import '../models/organization_models_enhanced.dart';

class OrganizationRepository {
  final ApiClient apiClient;

  OrganizationRepository({required this.apiClient});

  /// Pre-login email check.
  ///
  /// Returns the list of facilities associated with this email address.
  /// The list is shown in the login screen so the user can confirm they are
  /// logging into the right place.  The actual login does NOT send a facility
  /// or organisation ID — that selection happens after a successful login.
  Future<CheckEmailResponse> checkEmail(String email) async {
    final response = await apiClient.post(
      '/auth/check-email',
      data: {'email': email},
    );

    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Email check failed');
    }

    return CheckEmailResponse.fromJson(
      Map<String, dynamic>.from(response['data'] as Map),
    );
  }

  Future<OrganizationEnhancedModel> getOrganization(String id) async {
    final response = await apiClient.get('/organizations/$id');
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to load organization');
    }
    return OrganizationEnhancedModel.fromJson(
      Map<String, dynamic>.from(response['data'] as Map),
    );
  }

  Future<OrgStatsModel> getOrgStats(String id) async {
    final response = await apiClient.get('/organizations/$id/stats');
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to load org stats');
    }
    return OrgStatsModel.fromJson(
      Map<String, dynamic>.from(response['data'] as Map),
    );
  }

  Future<OrganizationEnhancedModel> updateOrganization(
    String id,
    UpdateOrganizationRequest request,
  ) async {
    final response = await apiClient.put(
      '/organizations/$id',
      data: request.toJson(),
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to update organization');
    }
    return OrganizationEnhancedModel.fromJson(
      Map<String, dynamic>.from(response['data'] as Map),
    );
  }
}
