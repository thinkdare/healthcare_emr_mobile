// lib/data/repositories/ward_workflow_repository.dart

import '../../core/api/api_client.dart';
import '../models/ward_models.dart';

class WardWorkflowRepository {
  final ApiClient apiClient;

  WardWorkflowRepository({required this.apiClient});

  // ── Wards ──────────────────────────────────────────────────────────────────

  Future<List<WardModel>> listWards() async {
    final response = await apiClient.get('/wards');
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to load wards');
    }
    final raw = response['data'] as List? ?? [];
    return raw
        .map((e) => WardModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  // ── Ward access grants ───────────────────────────────────────────────────

  Future<List<WardAccessGrantModel>> listWardAccess(String membershipId) async {
    final response = await apiClient.get('/staff/memberships/$membershipId/ward-access');
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to load ward access');
    }
    final raw = response['data'] as List? ?? [];
    return raw
        .map((e) => WardAccessGrantModel.fromJson(
              Map<String, dynamic>.from(e as Map),
            ))
        .toList();
  }

  Future<void> grantWardAccess(String membershipId, String wardId) async {
    final response = await apiClient.post(
      '/staff/memberships/$membershipId/ward-access',
      data: {'ward_id': wardId},
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to grant ward access');
    }
  }

  Future<void> revokeWardAccess(String grantId) async {
    final response = await apiClient.delete('/ward-access/$grantId');
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to revoke ward access');
    }
  }

  // ── Admission requests ───────────────────────────────────────────────────

  Future<List<AdmissionRequestModel>> listAdmissionRequests(
      String patientId) async {
    final response = await apiClient.get('/patients/$patientId/admission-requests');
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to load admission requests');
    }
    final raw = response['data'] as List? ?? [];
    return raw
        .map((e) => AdmissionRequestModel.fromJson(
              Map<String, dynamic>.from(e as Map),
            ))
        .toList();
  }

  Future<AdmissionRequestModel> requestAdmission(
    String patientId, {
    required String wardId,
    required String admissionType,
    required String reason,
    String? bedId,
  }) async {
    final response = await apiClient.post(
      '/patients/$patientId/admission-requests',
      data: {
        'ward_id': wardId,
        'admission_type': admissionType,
        'reason': reason,
        if (bedId != null) 'bed_id': bedId,
      },
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to submit admission request');
    }
    return AdmissionRequestModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map));
  }

  Future<void> acceptAdmission(String requestId, {String? bedId}) async {
    final response = await apiClient.post(
      '/admission-requests/$requestId/accept',
      data: {if (bedId != null) 'bed_id': bedId},
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to accept admission');
    }
  }

  Future<void> rejectAdmission(String requestId, String reason) async {
    final response = await apiClient.post(
      '/admission-requests/$requestId/reject',
      data: {'reason': reason},
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to reject admission');
    }
  }

  Future<void> cancelAdmission(String requestId) async {
    final response = await apiClient.delete('/admission-requests/$requestId');
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to cancel admission request');
    }
  }

  Future<void> forceAdmit(
    String patientId, {
    required String wardId,
    required String admissionType,
    required String reason,
    required String overrideReason,
    String? bedId,
  }) async {
    final response = await apiClient.post(
      '/patients/$patientId/force-admit',
      data: {
        'ward_id': wardId,
        'admission_type': admissionType,
        'reason': reason,
        'override_reason': overrideReason,
        if (bedId != null) 'bed_id': bedId,
      },
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to force-admit patient');
    }
  }

  // ── Ward transfer requests ───────────────────────────────────────────────

  Future<List<WardTransferRequestModel>> listTransferRequests(
      String patientId) async {
    final response = await apiClient.get('/patients/$patientId/transfer-requests');
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to load transfer requests');
    }
    final raw = response['data'] as List? ?? [];
    return raw
        .map((e) => WardTransferRequestModel.fromJson(
              Map<String, dynamic>.from(e as Map),
            ))
        .toList();
  }

  Future<WardTransferRequestModel> requestTransfer(
    String patientId, {
    required String toWardId,
    required String reason,
    String? toBedId,
  }) async {
    final response = await apiClient.post(
      '/patients/$patientId/transfer-requests',
      data: {
        'to_ward_id': toWardId,
        'reason': reason,
        if (toBedId != null) 'to_bed_id': toBedId,
      },
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to submit transfer request');
    }
    return WardTransferRequestModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map));
  }

  Future<void> acceptTransfer(String requestId, {String? toBedId}) async {
    final response = await apiClient.post(
      '/transfer-requests/$requestId/accept',
      data: {if (toBedId != null) 'to_bed_id': toBedId},
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to accept transfer');
    }
  }

  Future<void> rejectTransfer(String requestId, String reason) async {
    final response = await apiClient.post(
      '/transfer-requests/$requestId/reject',
      data: {'reason': reason},
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to reject transfer');
    }
  }

  Future<void> forceTransfer(
    String patientId, {
    required String toWardId,
    required String reason,
    required String overrideReason,
    String? toBedId,
  }) async {
    final response = await apiClient.post(
      '/patients/$patientId/force-transfer',
      data: {
        'to_ward_id': toWardId,
        'reason': reason,
        'override_reason': overrideReason,
        if (toBedId != null) 'to_bed_id': toBedId,
      },
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to force-transfer patient');
    }
  }

  // ── Discharge requests ───────────────────────────────────────────────────

  Future<List<DischargeRequestModel>> listDischargeRequests(
      String patientId) async {
    final response = await apiClient.get('/patients/$patientId/discharge-requests');
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to load discharge requests');
    }
    final raw = response['data'] as List? ?? [];
    return raw
        .map((e) => DischargeRequestModel.fromJson(
              Map<String, dynamic>.from(e as Map),
            ))
        .toList();
  }

  Future<DischargeRequestModel> requestDischarge(
    String patientId, {
    required String dischargeType,
    String? dischargeSummary,
  }) async {
    final response = await apiClient.post(
      '/patients/$patientId/discharge-requests',
      data: {
        'discharge_type': dischargeType,
        if (dischargeSummary != null) 'discharge_summary': dischargeSummary,
      },
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to initiate discharge');
    }
    return DischargeRequestModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map));
  }

  Future<void> approveSignoff(String requestId, String signoffId,
      {String? notes}) async {
    final response = await apiClient.post(
      '/discharge-requests/$requestId/signoffs/$signoffId/approve',
      data: {if (notes != null) 'notes': notes},
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to approve sign-off');
    }
  }

  Future<void> rejectSignoff(
      String requestId, String signoffId, String reason) async {
    final response = await apiClient.post(
      '/discharge-requests/$requestId/signoffs/$signoffId/reject',
      data: {'reason': reason},
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to reject sign-off');
    }
  }

  Future<void> overrideSignoff(
      String requestId, String signoffId, String overrideReason) async {
    final response = await apiClient.post(
      '/discharge-requests/$requestId/signoffs/$signoffId/override',
      data: {'override_reason': overrideReason},
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to override sign-off');
    }
  }

  Future<void> recordsApprove(String requestId) async {
    final response =
        await apiClient.post('/discharge-requests/$requestId/records-approve');
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to approve records for discharge');
    }
  }

  Future<void> executeDischarge(String requestId) async {
    final response = await apiClient.post('/discharge-requests/$requestId/execute');
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to execute discharge');
    }
  }

  Future<void> cancelDischarge(String requestId) async {
    final response = await apiClient.delete('/discharge-requests/$requestId');
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to cancel discharge request');
    }
  }

  Future<void> forceDischarge(
    String patientId, {
    required String dischargeType,
    required String overrideReason,
    String? dischargeSummary,
  }) async {
    final response = await apiClient.post(
      '/patients/$patientId/force-discharge',
      data: {
        'discharge_type': dischargeType,
        'override_reason': overrideReason,
        if (dischargeSummary != null) 'discharge_summary': dischargeSummary,
      },
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to force-discharge patient');
    }
  }
}
