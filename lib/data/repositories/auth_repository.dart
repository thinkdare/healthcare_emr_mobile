import '../../core/api/api_client.dart';
import '../models/models.dart';

class AuthRepository {
  final ApiClient apiClient;

  AuthRepository({required this.apiClient});

  Future<LoginResponseModel> login({
    required String email,
    required String password,
    required String organizationId,
  }) async {
    try {
      final response = await apiClient.post(
        '/auth/login',
        data: {
          'email': email,
          'password': password,
          'organization_id': organizationId,
        },
      );

      // Laravel response format: { "success": true, "message": "...", "data": {...} }
      if (response['success'] != true) {
        throw Exception(response['message'] ?? 'Login failed');
      }

      final data = response['data'];
      if (data == null) {
        throw Exception('Invalid login response: missing data');
      }

      final loginResponse = LoginResponseModel.fromJson(
        Map<String, dynamic>.from(data),
      );

      // Save token to secure storage
      await apiClient.saveToken(loginResponse.token);

      return loginResponse;
    } catch (e) {
      print('Auth Repository Login Error: $e');
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      // Call logout endpoint
      await apiClient.post('/auth/logout');
    } catch (e) {
      print('Logout API error (continuing anyway): $e');
    } finally {
      // Always clear local token
      await apiClient.clearToken();
    }
  }

  Future<LoginResponseModel?> getCurrentUser() async {
    try {
      final token = await apiClient.getToken();
      if (token == null) {
        return null;
      }

      final response = await apiClient.get('/auth/user');

      if (response['success'] != true) {
        return null;
      }

      final data = response['data'];
      if (data == null) {
        return null;
      }

      // The /auth/user endpoint returns user with userable (provider) loaded
      // We need to transform it to match LoginResponseModel format
      final user = UserModel.fromJson(data);
      final provider = ProviderModel.fromJson(data['userable']);

      return LoginResponseModel(
        user: user,
        provider: provider,
        token: token,
        tokenType: 'Bearer',
      );
    } catch (e) {
      print('Get Current User Error: $e');
      return null;
    }
  }
}