import '../../../core/api/api_client.dart';
import '../models/emergency_access_models.dart';

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

    final data = response['data'] as Map<String, dynamic>;
    final meta = data['pagination'] as Map<String, dynamic>?;
    final rawItems = data['items'] as List? ?? [];

    final items = rawItems
        .map((e) =>
            EmergencyAccessModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    final totalPages = meta?['last_page'] as int? ?? 1;

    return (
      items: items,
      hasMore: page < totalPages,
      currentPage: page,
    );
  }

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
