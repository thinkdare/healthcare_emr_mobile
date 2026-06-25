import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../../core/api/api_client.dart';
import '../../core/database/local_database.dart';
import '../models/clinical_models.dart';
import '../models/clinical_record_models.dart';

/// ClinicalRepository
///
/// All clinical data (appointments, prescriptions, lab results, documents)
/// is patient-scoped. Every method requires a patientId.
///
/// Route base: /api/v1/patients/{patientId}/...
/// All routes require the X-Tenant-ID header (set by ApiClient from auth state).
///
/// Read methods for cacheable resources (appointments, prescriptions, lab results,
/// vital signs, diagnoses) follow a cache-aside pattern: successful API responses
/// are written to SQLite, and on network failure the local cache is returned as a
/// fallback. A network error with an empty cache re-throws so the caller can surface
/// a proper error to the user.
class ClinicalRepository {
  final ApiClient apiClient;
  final LocalDatabase _db;

  ClinicalRepository({required this.apiClient, required LocalDatabase db}) : _db = db;

  bool _isNetworkError(Object e) {
    final msg = e.toString();
    return msg.contains('SocketException') ||
        msg.contains('Connection refused') ||
        msg.contains('Connection reset') ||
        msg.contains('Network is unreachable') ||
        msg.contains('HandshakeException');
  }

  // ── Appointments ──────────────────────────────────────────────────────────

  Future<List<AppointmentModel>> getAppointments(
    String patientId, {
    String? status,
    int page = 1,
  }) async {
    try {
      final response = await apiClient.get(
        '/patients/$patientId/appointments',
        queryParameters: {
          'page': page,
          'status': ?status,
        },
      );
      if (response['success'] != true) {
        throw Exception(response['message'] ?? 'Failed to load appointments');
      }
      final rawData = response['data'];
      final list = rawData is Map ? rawData['data'] as List? ?? [] : rawData as List? ?? [];
      final models = list
          .map((e) => AppointmentModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      for (final m in models) {
        await _db.upsertAppointment(m);
      }
      return models;
    } catch (e) {
      if (!_isNetworkError(e)) rethrow;
      final cached = await _db.getAppointmentsByPatient(patientId);
      if (cached.isEmpty) rethrow;
      return status != null ? cached.where((a) => a.status == status).toList() : cached;
    }
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

  Future<AppointmentModel> updateAppointmentStatus(
      String patientId, String appointmentId, String status) async {
    final response = await apiClient.put(
      '/patients/$patientId/appointments/$appointmentId',
      data: {'status': status},
    );
    if (response['success'] != true) {
      throw Exception(
          response['message'] ?? 'Failed to update appointment status');
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
      data: {'cancellation_reason': ?reason},
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to cancel appointment');
    }
    return AppointmentModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map));
  }

  Future<AppointmentModel> completeAppointment(
      String patientId, String appointmentId,
      {String? notes}) async {
    final response = await apiClient.post(
      '/patients/$patientId/appointments/$appointmentId/complete',
      data: {'notes': ?notes},
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to complete appointment');
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
    try {
      final response = await apiClient.get(
        '/patients/$patientId/prescriptions',
        queryParameters: {
          'page': page,
          'status': ?status,
        },
      );
      if (response['success'] != true) {
        throw Exception(response['message'] ?? 'Failed to load prescriptions');
      }
      final rawData = response['data'];
      final list = rawData is Map ? rawData['data'] as List? ?? [] : rawData as List? ?? [];
      final models = list
          .map((e) => PrescriptionModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      for (final m in models) {
        await _db.upsertPrescription(m);
      }
      return models;
    } catch (e) {
      if (!_isNetworkError(e)) rethrow;
      final cached = await _db.getPrescriptionsByPatient(patientId);
      if (cached.isEmpty) rethrow;
      return status != null ? cached.where((p) => p.status == status).toList() : cached;
    }
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

  Future<InteractionCheckResult> checkInteractions(
      String patientId, String medicationName) async {
    try {
      final response = await apiClient.post(
        '/patients/$patientId/prescriptions/check-interactions',
        data: {'medication_name': medicationName},
      );
      if (response['success'] != true) {
        return InteractionCheckResult.unavailable();
      }
      final data = Map<String, dynamic>.from(response['data'] as Map);
      final apiAvailable = data['api_available'] as bool? ?? false;
      if (!apiAvailable) return InteractionCheckResult.unavailable();
      final rawList = data['interactions'] as List? ?? [];
      final interactions = rawList
          .map((e) => DrugInteraction.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      return InteractionCheckResult(interactions: interactions, apiAvailable: true);
    } catch (_) {
      return InteractionCheckResult.unavailable();
    }
  }

  Future<PrescriptionModel> createPrescription(
    String patientId,
    Map<String, dynamic> data, {
    required String prescriberId,
  }) async {
    try {
      final response = await apiClient.post(
          '/patients/$patientId/prescriptions', data: data);
      if (response['success'] != true) {
        throw Exception(response['message'] ?? 'Failed to create prescription');
      }
      final prescription = PrescriptionModel.fromJson(
          Map<String, dynamic>.from(response['data'] as Map));
      await _db.upsertPrescription(prescription);
      return prescription;
    } catch (e) {
      if (!_isNetworkError(e)) rethrow;

      final newId = const Uuid().v4();
      final refills = data['refills_allowed'] as int? ?? 0;

      final placeholder = PrescriptionModel(
        id: newId,
        patientId: patientId,
        prescriberId: prescriberId,
        medicationName: data['medication_name'] as String,
        medicationCode: data['medication_code'] as String?,
        dosage: data['dosage'] as String,
        frequency: data['frequency'] as String,
        route: data['route'] as String?,
        durationDays: data['duration_days'] as int?,
        quantity: data['quantity'] as int?,
        refillsAllowed: refills,
        refillsRemaining: refills,
        prescribedDate: DateTime.tryParse(data['prescribed_date'] as String? ?? ''),
        expiresDate: DateTime.tryParse(data['expires_date'] as String? ?? ''),
        status: 'pending',
        specialInstructions: data['special_instructions'] as String?,
        drugInteractionsChecked: data['drug_interactions_checked'] as bool? ?? false,
      );
      await _db.upsertPrescription(placeholder);

      await _queueOfflineWrite(
        resourceType: 'prescriptions',
        resourceId: newId,
        payload: {...data, 'patient_id': patientId},
      );
      throw Exception(
          'Offline — prescription will be created when you reconnect.');
    }
  }

  Future<PrescriptionModel> updatePrescription(
      String patientId, String prescriptionId, Map<String, dynamic> data) async {
    final response = await apiClient.put(
      '/patients/$patientId/prescriptions/$prescriptionId',
      data: data,
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to update prescription');
    }
    return PrescriptionModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map));
  }

  Future<PrescriptionModel> refillPrescription(
      String patientId, String prescriptionId) async {
    final response = await apiClient.post(
      '/patients/$patientId/prescriptions/$prescriptionId/refill',
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to issue refill');
    }
    return PrescriptionModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map));
  }

  Future<Map<String, dynamic>> printPrescription(
      String patientId, String prescriptionId) async {
    final response = await apiClient.post(
      '/patients/$patientId/prescriptions/$prescriptionId/print',
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to load print payload');
    }
    return Map<String, dynamic>.from(response['data'] as Map);
  }

  Future<PrescriptionModel> fillPrescription(
      String patientId, String prescriptionId,
      {required int quantityDispensed}) async {
    final response = await apiClient.post(
      '/patients/$patientId/prescriptions/$prescriptionId/fill',
      data: {'quantity_dispensed': quantityDispensed},
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to fill prescription');
    }
    return PrescriptionModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map));
  }

  Future<PrescriptionModel> discontinuePrescription(
      String patientId, String prescriptionId,
      {String? reason}) async {
    final response = await apiClient.post(
      '/patients/$patientId/prescriptions/$prescriptionId/discontinue',
      data: {'discontinuation_reason': ?reason},
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
    try {
      final response = await apiClient.get(
        '/patients/$patientId/lab-results',
        queryParameters: {
          'page': page,
          'status': ?status,
        },
      );
      if (response['success'] != true) {
        throw Exception(response['message'] ?? 'Failed to load lab results');
      }
      final rawData = response['data'];
      final list = rawData is Map ? rawData['data'] as List? ?? [] : rawData as List? ?? [];
      final models = list
          .map((e) => LabResultModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      for (final m in models) {
        await _db.upsertLabResult(m);
      }
      return models;
    } catch (e) {
      if (!_isNetworkError(e)) rethrow;
      final cached = await _db.getLabResultsByPatient(patientId);
      if (cached.isEmpty) rethrow;
      return status != null ? cached.where((l) => l.status == status).toList() : cached;
    }
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

  Future<LabResultModel> recordLabResult(
      String patientId, String labResultId, Map<String, dynamic> data) async {
    final response = await apiClient.post(
      '/patients/$patientId/lab-results/$labResultId/record',
      data: data,
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to record lab result');
    }
    return LabResultModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map));
  }

  Future<LabResultModel> reviewLabResult(
    String patientId,
    String labResultId, {
    String? interpretation,
    bool? requiresFollowup,
  }) async {
    final response = await apiClient.post(
      '/patients/$patientId/lab-results/$labResultId/review',
      data: {
        'interpretation': ?interpretation,
        'requires_followup': ?requiresFollowup,
      },
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to review lab result');
    }
    return LabResultModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map));
  }

  Future<LabResultModel> cancelLabResult(
      String patientId, String labResultId) async {
    final response = await apiClient.post(
      '/patients/$patientId/lab-results/$labResultId/cancel',
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to cancel lab test');
    }
    return LabResultModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map));
  }

  Future<Map<String, dynamic>> printLabOrder(
      String patientId, String labResultId) async {
    final response = await apiClient.post(
      '/patients/$patientId/lab-results/$labResultId/print',
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to load print payload');
    }
    return Map<String, dynamic>.from(response['data'] as Map);
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
        'document_type': ?documentType,
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

  // ── Vital Signs ───────────────────────────────────────────────────────────

  Future<List<VitalSignModel>> getVitalSigns(
    String patientId, {
    int page = 1,
  }) async {
    try {
      final response = await apiClient.get(
        '/patients/$patientId/vital-signs',
        queryParameters: {'page': page},
      );
      if (response['success'] != true) {
        throw Exception(response['message'] ?? 'Failed to load vital signs');
      }
      final rawData = response['data'];
      final list = rawData is Map ? rawData['data'] as List? ?? [] : rawData as List? ?? [];
      final models = list
          .map((e) => VitalSignModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      for (final m in models) {
        await _db.upsertVitalSign(m);
      }
      return models;
    } catch (e) {
      if (!_isNetworkError(e)) rethrow;
      final cached = await _db.getVitalSignsByPatient(patientId);
      if (cached.isEmpty) rethrow;
      return cached;
    }
  }

  Future<VitalSignModel> createVitalSign(
    String patientId,
    Map<String, dynamic> data, {
    required String recordedById,
  }) async {
    try {
      final response =
          await apiClient.post('/patients/$patientId/vital-signs', data: data);
      if (response['success'] != true) {
        throw Exception(response['message'] ?? 'Failed to record vital signs');
      }
      final vital = VitalSignModel.fromJson(
          Map<String, dynamic>.from(response['data'] as Map));
      await _db.upsertVitalSign(vital);
      return vital;
    } catch (e) {
      if (!_isNetworkError(e)) rethrow;

      final newId = const Uuid().v4();
      final placeholder = VitalSignModel(
        id: newId,
        patientId: patientId,
        recordedById: recordedById,
        encounterId: data['encounter_id'] as String?,
        rosterEntryId: data['roster_entry_id'] as String?,
        wardId: data['ward_id'] as String?,
        recordedAt: DateTime.tryParse(data['recorded_at'] as String? ?? '') ?? DateTime.now(),
        bloodPressureSystolic: data['blood_pressure_systolic'] as int?,
        bloodPressureDiastolic: data['blood_pressure_diastolic'] as int?,
        heartRate: data['heart_rate'] as int?,
        respiratoryRate: data['respiratory_rate'] as int?,
        temperature: (data['temperature'] as num?)?.toDouble(),
        temperatureUnit: data['temperature_unit'] as String?,
        oxygenSaturation: (data['oxygen_saturation'] as num?)?.toDouble(),
        weight: (data['weight'] as num?)?.toDouble(),
        weightUnit: data['weight_unit'] as String?,
        height: (data['height'] as num?)?.toDouble(),
        heightUnit: data['height_unit'] as String?,
        notes: data['notes'] as String?,
        version: 1,
      );
      await _db.upsertVitalSign(placeholder);

      await _queueOfflineWrite(
        resourceType: 'vitals',
        resourceId: newId,
        payload: {...data, 'patient_id': patientId},
      );
      throw Exception(
          'Offline — vital signs will be recorded when you reconnect.');
    }
  }

  Future<void> deleteVitalSign(String patientId, String vitalSignId) async {
    final response =
        await apiClient.delete('/patients/$patientId/vital-signs/$vitalSignId');
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to delete vital sign');
    }
  }

  // ── Diagnoses ─────────────────────────────────────────────────────────────

  Future<List<DiagnosisModel>> getDiagnoses(
    String patientId, {
    String? status,
    int page = 1,
  }) async {
    try {
      final response = await apiClient.get(
        '/patients/$patientId/diagnoses',
        queryParameters: {
          'page': page,
          'status': ?status,
        },
      );
      if (response['success'] != true) {
        throw Exception(response['message'] ?? 'Failed to load diagnoses');
      }
      final rawData = response['data'];
      final list = rawData is Map ? rawData['data'] as List? ?? [] : rawData as List? ?? [];
      final models = list
          .map((e) => DiagnosisModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      for (final m in models) {
        await _db.upsertDiagnosis(m);
      }
      return models;
    } catch (e) {
      if (!_isNetworkError(e)) rethrow;
      final cached = await _db.getDiagnosesByPatient(patientId);
      if (cached.isEmpty) rethrow;
      return status != null ? cached.where((d) => d.status == status).toList() : cached;
    }
  }

  Future<DiagnosisModel> createDiagnosis(
      String patientId, Map<String, dynamic> data) async {
    final response =
        await apiClient.post('/patients/$patientId/diagnoses', data: data);
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to record diagnosis');
    }
    return DiagnosisModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map));
  }

  Future<void> deleteDiagnosis(String patientId, String diagnosisId) async {
    final response =
        await apiClient.delete('/patients/$patientId/diagnoses/$diagnosisId');
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to delete diagnosis');
    }
  }

  // ── Problem List ──────────────────────────────────────────────────────────

  Future<List<ProblemListModel>> getProblems(
    String patientId, {
    String? status,
    int page = 1,
  }) async {
    final response = await apiClient.get(
      '/patients/$patientId/problems',
      queryParameters: {
        'page': page,
        'status': ?status,
      },
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to load problem list');
    }
    final rawData = response['data'];
    final list = rawData is Map ? rawData['data'] as List? ?? [] : rawData as List? ?? [];
    return list
        .map((e) => ProblemListModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<ProblemListModel> createProblem(
      String patientId, Map<String, dynamic> data) async {
    final response =
        await apiClient.post('/patients/$patientId/problems', data: data);
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to record problem');
    }
    return ProblemListModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map));
  }

  Future<void> deleteProblem(String patientId, String problemId) async {
    final response =
        await apiClient.delete('/patients/$patientId/problems/$problemId');
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to delete problem');
    }
  }

  // ── Procedures ────────────────────────────────────────────────────────────

  Future<List<ProcedureModel>> getProcedures(
    String patientId, {
    int page = 1,
  }) async {
    final response = await apiClient.get(
      '/patients/$patientId/procedures',
      queryParameters: {'page': page},
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to load procedures');
    }
    final rawData = response['data'];
    final list = rawData is Map ? rawData['data'] as List? ?? [] : rawData as List? ?? [];
    return list
        .map((e) => ProcedureModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<ProcedureModel> createProcedure(
      String patientId, Map<String, dynamic> data) async {
    final response =
        await apiClient.post('/patients/$patientId/procedures', data: data);
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to record procedure');
    }
    return ProcedureModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map));
  }

  Future<void> deleteProcedure(String patientId, String procedureId) async {
    final response =
        await apiClient.delete('/patients/$patientId/procedures/$procedureId');
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to delete procedure');
    }
  }

  // ── Immunizations ─────────────────────────────────────────────────────────

  Future<List<ImmunizationModel>> getImmunizations(
    String patientId, {
    int page = 1,
  }) async {
    final response = await apiClient.get(
      '/patients/$patientId/immunizations',
      queryParameters: {'page': page},
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to load immunizations');
    }
    final rawData = response['data'];
    final list = rawData is Map ? rawData['data'] as List? ?? [] : rawData as List? ?? [];
    return list
        .map((e) => ImmunizationModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<ImmunizationModel> createImmunization(
      String patientId, Map<String, dynamic> data) async {
    final response =
        await apiClient.post('/patients/$patientId/immunizations', data: data);
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to record immunization');
    }
    return ImmunizationModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map));
  }

  Future<void> deleteImmunization(
      String patientId, String immunizationId) async {
    final response = await apiClient
        .delete('/patients/$patientId/immunizations/$immunizationId');
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to delete immunization');
    }
  }

  // ── Daily Roster ──────────────────────────────────────────────────────────

  Future<List<RosterEntryModel>> getRosterEntries(
    String patientId, {
    String? date,
    String? status,
    int page = 1,
  }) async {
    final response = await apiClient.get(
      '/patients/$patientId/roster',
      queryParameters: {
        'page': page,
        'date': ?date,
        'status': ?status,
      },
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to load roster entries');
    }
    final rawData = response['data'];
    final list = rawData is Map ? rawData['data'] as List? ?? [] : rawData as List? ?? [];
    return list
        .map((e) => RosterEntryModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<RosterEntryModel> createRosterEntry(
      String patientId, Map<String, dynamic> data) async {
    final response =
        await apiClient.post('/patients/$patientId/roster', data: data);
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to add patient to roster');
    }
    return RosterEntryModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map));
  }

  Future<RosterEntryModel> updateRosterEntry(
      String patientId, String entryId, Map<String, dynamic> data) async {
    final response = await apiClient.put(
      '/patients/$patientId/roster/$entryId',
      data: data,
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to update roster entry');
    }
    return RosterEntryModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map));
  }

  // ── OFFLINE WRITE HELPERS ─────────────────────────────────────────────────

  Future<void> _queueOfflineWrite({
    required String resourceType,
    String? resourceId,
    required Map<String, dynamic> payload,
  }) async {
    await _db.queuePendingSync(
      id: const Uuid().v4(),
      resourceType: resourceType,
      resourceId: resourceId,
      operation: 'create',
      payload: payload,
    );
  }
}
