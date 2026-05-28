import '../models/intra_grant_models.dart';
import '../../core/api/api_client.dart';

class IntraTransferRepository {
  final ApiClient apiClient;

  IntraTransferRepository({required this.apiClient});

  Future<List<IntraTransferModel>> getTransfers({String status = 'pending'}) async {
    final response = await apiClient.get('/intra-transfers?status=$status');
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to load transfers');
    }
    final data   = response['data'] as Map<String, dynamic>;
    final items  = data['transfers'] as List? ?? [];
    return items
        .map((e) => IntraTransferModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<IntraTransferModel> create(String patientId, Map<String, dynamic> data) async {
    final response = await apiClient.post('/patients/$patientId/transfers', data: data);
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to create transfer request');
    }
    return IntraTransferModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map));
  }

  Future<IntraTransferModel> accept(String id) async {
    final response = await apiClient.post('/intra-transfers/$id/accept', data: {});
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to accept transfer');
    }
    return IntraTransferModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map));
  }

  Future<IntraTransferModel> decline(String id, {String? reason}) async {
    final response = await apiClient.post(
      '/intra-transfers/$id/decline',
      data: {'decline_reason': ?reason},
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to decline transfer');
    }
    return IntraTransferModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map));
  }
}
