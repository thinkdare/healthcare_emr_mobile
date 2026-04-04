import '../../core/api/api_client.dart';
import '../models/models.dart';

class OrganizationRepository {
  final ApiClient apiClient;

  OrganizationRepository({required this.apiClient});

  Future<List<OrganizationLiteModel>> checkEmail(String email) async {
    final response = await apiClient.post(
      '/auth/check-email',
      data: {
        'email': email,
      },
    );

    // Response is Map<String, dynamic> from ApiClient
    if (response['data'] == null) {
      throw Exception('Invalid check-email response');
    }

    final data = response['data'] as Map<String, dynamic>;
    final List organizations = data['organizations'] as List;

    return organizations
        .map(
          (e) => OrganizationLiteModel.fromJson(
            Map<String, dynamic>.from(e),
          ),
        )
        .toList();
  }
}