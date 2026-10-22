import '../../../core/api/api_client.dart';
import '../models/emergency_access_models.dart';

/// How the server wants a break-glass trigger authorized.
/// `totp`: enter the authenticator code (or a backup code); nothing was sent.
/// `email`: a one-time code was emailed and is valid for [expiresInMinutes].
class EmergencyAuthorization {
  final String method;
  final int? expiresInMinutes;

  const EmergencyAuthorization({required this.method, this.expiresInMinutes});

  bool get isTotp => method == 'totp';

  factory EmergencyAuthorization.fromJson(Map<String, dynamic> json) =>
      EmergencyAuthorization(
        method: json['method'] as String? ?? 'email',
        expiresInMinutes: (json['expires_in_minutes'] as num?)?.toInt(),
      );
}

class EmergencyAccessRepository {
  final ApiClient apiClient;

  EmergencyAccessRepository({required this.apiClient});

  Future<({List<EmergencyAccessModel> items, bool hasMore, int currentPage})>
      getLogs({
    String? masterPatientId,
    bool unreviewedOnly = false,
    int page = 1,
    int perPage = 20,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'per_page': perPage,
      'master_patient_id': ?masterPatientId,
      if (unreviewedOnly) 'unreviewed_only': 1,
    };

    final response =
        await apiClient.get('/emergency-access', queryParameters: params);

    // BaseApiController::paginated(): `data` is the item list and the paging
    // block is `meta.pagination`.
    final rawItems = response['data'] as List? ?? [];
    final pagination = (response['meta'] as Map?)?['pagination'] as Map?;

    final items = rawItems
        .map((e) =>
            EmergencyAccessModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    final totalPages = (pagination?['last_page'] as num?)?.toInt() ?? 1;

    return (
      items: items,
      hasMore: page < totalPages,
      currentPage: page,
    );
  }

  /// POST /emergency-access/authorize
  ///
  /// Starts the second-factor step for a trigger: emails a code, or tells the
  /// user to use their authenticator. Call when the break-glass form opens.
  Future<EmergencyAuthorization> requestAuthorization() async {
    final response = await apiClient.post('/emergency-access/authorize');
    return EmergencyAuthorization.fromJson(
        Map<String, dynamic>.from(response['data'] as Map));
  }

  /// POST /emergency-access. [data] must include `authorization_code`.
  Future<EmergencyAccessModel> trigger(Map<String, dynamic> data) async {
    final response = await apiClient.post('/emergency-access', data: data);
    return EmergencyAccessModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map));
  }

  Future<EmergencyAccessModel> review(String id, String notes) async {
    final response = await apiClient
        .post('/emergency-access/$id/review', data: {'review_notes': notes});
    return EmergencyAccessModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map));
  }
}
