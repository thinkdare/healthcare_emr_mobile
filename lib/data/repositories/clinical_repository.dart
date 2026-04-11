import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';
import '../models/clinical_models.dart';

/// ClinicalRepository
///
/// All clinical data (appointments, prescriptions, lab results, documents)
/// is patient-scoped. Every method requires a patientId.
///
/// Route base: /api/v1/patients/{patientId}/...
/// All routes require the X-Tenant-ID header (set by ApiClient from auth state).
class ClinicalRepository {
  final ApiClient apiClient;

  ClinicalRepository({required this.apiClient});

  // ── Appointments ──────────────────────────────────────────────────────────

  Future<List<AppointmentModel>> getAppointments(
    String patientId, {
    String? status,
    int page = 1,
  }) async {
    final response = await apiClient.get(
      '/patients/$patientId/appointments',
      queryParameters: {
        'page': page,
        if (status != null) 'status': status,
      },
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to load appointments');
    }
    final rawData = response['data'];
    final list = rawData is Map ? rawData['data'] as List? ?? [] : rawData as List? ?? [];
    return list
        .map((e) => AppointmentModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<AppointmentModel> getAppointment(
      String patientId, String appointmentId) async {
    final response =
        await apiClient.get('/patients/$patientId/appointments/$appointmentId');
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to load appointment');
    }
    return AppointmentModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map));
  }

  Future<AppointmentModel> createAppointment(
      String patientId, Map<String, dynamic> data) async {
    final response =
        await apiClient.post('/patients/$patientId/appointments', data: data);
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to create appointment');
    }
    return AppointmentModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map));
  }

  Future<AppointmentModel> cancelAppointment(
      String patientId, String appointmentId,
      {String? reason}) async {
    final response = await apiClient.post(
      '/patients/$patientId/appointments/$appointmentId/cancel',
      data: {if (reason != null) 'cancellation_reason': reason},
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to cancel appointment');
    }
    return AppointmentModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map));
  }

  // ── Prescriptions ─────────────────────────────────────────────────────────

  Future<List<PrescriptionModel>> getPrescriptions(
    String patientId, {
    String? status,
    int page = 1,
  }) async {
    final response = await apiClient.get(
      '/patients/$patientId/prescriptions',
      queryParameters: {
        'page': page,
        if (status != null) 'status': status,
      },
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to load prescriptions');
    }
    final rawData = response['data'];
    final list = rawData is Map ? rawData['data'] as List? ?? [] : rawData as List? ?? [];
    return list
        .map((e) => PrescriptionModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<PrescriptionModel> getPrescription(
      String patientId, String prescriptionId) async {
    final response = await apiClient
        .get('/patients/$patientId/prescriptions/$prescriptionId');
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to load prescription');
    }
    return PrescriptionModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map));
  }

  Future<PrescriptionModel> createPrescription(
      String patientId, Map<String, dynamic> data) async {
    final response =
        await apiClient.post('/patients/$patientId/prescriptions', data: data);
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to create prescription');
    }
    return PrescriptionModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map));
  }

  Future<PrescriptionModel> discontinuePrescription(
      String patientId, String prescriptionId,
      {String? reason}) async {
    final response = await apiClient.post(
      '/patients/$patientId/prescriptions/$prescriptionId/discontinue',
      data: {if (reason != null) 'discontinuation_reason': reason},
    );
    if (response['success'] != true) {
      throw Exception(
          response['message'] ?? 'Failed to discontinue prescription');
    }
    return PrescriptionModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map));
  }

  // ── Lab Results ───────────────────────────────────────────────────────────

  Future<List<LabResultModel>> getLabResults(
    String patientId, {
    String? status,
    int page = 1,
  }) async {
    final response = await apiClient.get(
      '/patients/$patientId/lab-results',
      queryParameters: {
        'page': page,
        if (status != null) 'status': status,
      },
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to load lab results');
    }
    final rawData = response['data'];
    final list = rawData is Map ? rawData['data'] as List? ?? [] : rawData as List? ?? [];
    return list
        .map((e) => LabResultModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<LabResultModel> getLabResult(
      String patientId, String labResultId) async {
    final response =
        await apiClient.get('/patients/$patientId/lab-results/$labResultId');
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to load lab result');
    }
    return LabResultModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map));
  }

  Future<LabResultModel> createLabOrder(
      String patientId, Map<String, dynamic> data) async {
    final response =
        await apiClient.post('/patients/$patientId/lab-results', data: data);
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to create lab order');
    }
    return LabResultModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map));
  }

  // ── Medical Documents ─────────────────────────────────────────────────────

  Future<List<MedicalDocumentModel>> getDocuments(
    String patientId, {
    String? documentType,
    int page = 1,
  }) async {
    final response = await apiClient.get(
      '/patients/$patientId/documents',
      queryParameters: {
        'page': page,
        if (documentType != null) 'document_type': documentType,
      },
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to load documents');
    }
    final rawData = response['data'];
    final list = rawData is Map ? rawData['data'] as List? ?? [] : rawData as List? ?? [];
    return list
        .map((e) =>
            MedicalDocumentModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Returns a model with a temporary signed URL for viewing.
  Future<MedicalDocumentModel> getDocumentUrl(
      String patientId, String documentId) async {
    final response =
        await apiClient.get('/patients/$patientId/documents/$documentId');
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to get document URL');
    }
    return MedicalDocumentModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map));
  }

  /// Uploads a file as a multipart POST.
  /// [filePath] must be a valid path on disk (use file_picker with withData: false).
  Future<MedicalDocumentModel> uploadDocument(
    String patientId, {
    required String filePath,
    required String fileName,
    required String title,
    required String documentType,
    String? notes,
    bool isConfidential = false,
  }) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
      'title': title,
      'document_type': documentType,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      'is_confidential': isConfidential ? 1 : 0,
    });
    final response = await apiClient.post(
      '/patients/$patientId/documents',
      data: formData,
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to upload document');
    }
    return MedicalDocumentModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map));
  }

  Future<void> deleteDocument(String patientId, String documentId) async {
    final response =
        await apiClient.delete('/patients/$patientId/documents/$documentId');
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to delete document');
    }
  }
}
