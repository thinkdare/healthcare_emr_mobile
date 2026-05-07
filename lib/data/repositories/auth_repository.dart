import 'package:dio/dio.dart';
import '../../core/api/api_client.dart';
import '../models/models.dart';
import '../models/auth_models.dart';

class AuthRepository {
  final ApiClient apiClient;

  AuthRepository({required this.apiClient});

  // ── Check email ──────────────────────────────────────────────────────────

  /// Step 1 of login: look up which facilities the email belongs to.
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

  // ── Login ────────────────────────────────────────────────────────────────

  /// Step 2: authenticate with password.
  ///
  /// Returns [LoginSuccess] (has token) or [LoginTwoFactorRequired]
  /// (has challenge_token, caller must call [verifyTwoFactor]).
  Future<LoginResult> login({
    required String email,
    required String password,
  }) async {
    final response = await apiClient.post(
      '/auth/login',
      data: {'email': email, 'password': password},
    );

    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Login failed');
    }

    final data = Map<String, dynamic>.from(response['data'] as Map);
    final result = loginResultFromJson(data);

    if (result is LoginSuccess) {
      await apiClient.saveToken(result.token);
    }

    return result;
  }

  // ── 2FA ─────────────────────────────────────────────────────────────────

  /// Exchange a challenge token + TOTP code (or backup code) for a full token.
  Future<LoginSuccess> verifyTwoFactor({
    required String challengeToken,
    required String code,
  }) async {
    // The challenge token is used as the Bearer token for this one call.
    final response = await apiClient.post(
      '/auth/2fa/verify',
      data: {'code': code},
      options: Options(headers: {'Authorization': 'Bearer $challengeToken'}),
    );

    if (response['success'] != true) {
      throw Exception(response['message'] ?? '2FA verification failed');
    }

    final data = Map<String, dynamic>.from(response['data'] as Map);
    final token = data['token'] as String;
    await apiClient.saveToken(token);

    return LoginSuccess(
      token: token,
      tokenType: data['token_type'] as String? ?? 'Bearer',
    );
  }

  // ── Current user ─────────────────────────────────────────────────────────

  /// Fetch the authenticated user's profile. Returns null if no token stored.
  Future<UserModel?> getCurrentUser() async {
    final token = await apiClient.getToken();
    if (token == null) return null;

    try {
      final response = await apiClient.get('/auth/me');
      if (response['success'] != true) return null;

      return UserModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map),
      );
    } catch (_) {
      return null;
    }
  }

  // ── Facilities ───────────────────────────────────────────────────────────

  /// List facilities the current user has active memberships at.
  Future<List<AuthFacilityModel>> getFacilities() async {
    final response = await apiClient.get('/auth/facilities');

    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to load facilities');
    }

    final data = Map<String, dynamic>.from(response['data'] as Map);
    final list = data['facilities'] as List? ?? [];
    return list
        .map((e) =>
            AuthFacilityModel.fromMembershipJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Switch active facility. Stores the tenant ID in secure storage so
  /// subsequent requests include X-Tenant-ID automatically.
  Future<FacilitySwitchResponse> selectFacility(String tenantId) async {
    final response = await apiClient.post(
      '/auth/facility',
      data: {'tenant_id': tenantId},
    );

    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to switch facility');
    }

    final result = FacilitySwitchResponse.fromJson(
      Map<String, dynamic>.from(response['data'] as Map),
    );
    await apiClient.saveTenantId(result.tenantId);
    return result;
  }

  // ── Session management ───────────────────────────────────────────────────

  Future<void> logout() async {
    try {
      await apiClient.post('/auth/logout');
    } catch (_) {
      // Even if the API call fails, clear local state.
    } finally {
      await apiClient.clearAll();
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await apiClient.put(
      '/auth/password',
      data: {
        'current_password': currentPassword,
        'password': newPassword,
        'password_confirmation': newPassword,
      },
    );

    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Password change failed');
    }
  }

  // ── 2FA setup ────────────────────────────────────────────────────────────

  /// Step 1: generate TOTP secret + QR code URI.
  /// Returns { 'secret': '...', 'qr_code_url': '...', 'qr_code_svg': '...' }
  Future<Map<String, dynamic>> twoFactorSetup() async {
    final response = await apiClient.post('/auth/2fa/setup');
    if (response['success'] != true) {
      throw Exception(response['message'] ?? '2FA setup failed');
    }
    return Map<String, dynamic>.from(response['data'] as Map);
  }

  /// Step 2: confirm the first TOTP code to activate 2FA.
  /// Returns backup codes on success.
  Future<List<String>> twoFactorEnable(String code) async {
    final response = await apiClient.post(
      '/auth/2fa/enable',
      data: {'code': code},
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Could not enable 2FA');
    }
    final data = Map<String, dynamic>.from(response['data'] as Map);
    return List<String>.from(data['backup_codes'] as List? ?? []);
  }

  /// Disable 2FA. Requires the current TOTP code (or a backup code).
  Future<void> twoFactorDisable(String code) async {
    final response = await apiClient.delete(
      '/auth/2fa',
      data: {'code': code},
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Could not disable 2FA');
    }
  }

  /// Get the count of remaining backup codes.
  Future<int> twoFactorBackupCodeCount() async {
    final response = await apiClient.get('/auth/2fa/backup-codes');
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to fetch backup codes');
    }
    final data = Map<String, dynamic>.from(response['data'] as Map);
    return (data['remaining'] as num?)?.toInt() ?? 0;
  }

  /// Regenerate backup codes. Returns the new list.
  Future<List<String>> twoFactorRegenerateBackupCodes() async {
    final response = await apiClient.post('/auth/2fa/backup-codes');
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to regenerate backup codes');
    }
    final data = Map<String, dynamic>.from(response['data'] as Map);
    return List<String>.from(data['backup_codes'] as List? ?? []);
  }
}
