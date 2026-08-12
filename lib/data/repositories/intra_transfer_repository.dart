import '../../core/api/api_client.dart';
import '../models/intra_transfer_model.dart';

/// Covers the create side only (TransferRequestSheet's one use case).
/// The backend also has accept/decline/list endpoints for the receiving
/// provider (IntraPatientTransferController), but there's no screen for
/// that side of the flow yet — add them here when that screen gets built,
/// rather than speculatively now.
class IntraTransferRepository {
  final ApiClient apiClient;

  IntraTransferRepository({required this.apiClient});

  /// POST /api/v1/patients/{patientId}/transfers
  Future<IntraTransferModel> create(
    String patientId,
    Map<String, dynamic> data,
  ) async {
    final response = await apiClient.post(
      '/patients/$patientId/transfers',
      data: data,
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to send transfer request');
    }
    return IntraTransferModel.fromJson(
      Map<String, dynamic>.from(response['data'] as Map),
    );
  }
}
