import '../../core/api/api_client.dart';
import '../models/auth_models.dart';

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
}
