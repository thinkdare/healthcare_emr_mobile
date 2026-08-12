import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../../core/api/api_client.dart';
import '../../core/database/local_database.dart';
import '../models/clinical_models.dart';
import '../models/clinical_record_models.dart';
import 'reporting_repository.dart' show AuditLogEntry;

/// ClinicalRepository
///
/// All clinical data (appointments, prescriptions, lab results, documents)
/// is patient-scoped. Every method requires a patientId.
///
/// Route base: /api/v1/patients/{patientId}/...
/// All routes require the X-Tenant-ID header (set by ApiClient from auth state).
///
/// Offline support (cache-first reads + offline-write queue) is scoped to
/// vitals and diagnoses only — see LocalDatabase's _migrateV2toV3 doc for
/// why. Every other resource here (appointments, prescriptions, labs,
/// documents, etc.) is online-only, matching PatientRepository's pattern
/// for the one resource that already had it.
class ClinicalRepository {
  final ApiClient apiClient;
  final LocalDatabase _db;

  ClinicalRepository({required this.apiClient, LocalDatabase? localDatabase})
    : _db = localDatabase ?? LocalDatabase.instance;

  // ── Appointments ──────────────────────────────────────────────────────────

  Future<List<AppointmentModel>> getAppointments(
    String patientId, {
    String? status,
    int page = 1,
  }) async {
    final response = await apiClient.get(
      '/patients/$patientId/appointments',
      queryParameters: {'page': page, if (status != null) 'status': status},
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to load appointments');
    }
    final rawData = response['data'];
    final list = rawData is Map
        ? rawData['data'] as List? ?? []
        : rawData as List? ?? [];
    return list
        .map(
          (e) => AppointmentModel.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<AppointmentModel> getAppointment(
    String patientId,
    String appointmentId,
  ) async {
    final response = await apiClient.get(
      '/patients/$patientId/appointments/$appointmentId',
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to load appointment');
    }
    return AppointmentModel.fromJson(
      Map<String, dynamic>.from(response['data'] as Map),
    );
  }

  Future<AppointmentModel> updateAppointmentStatus(
    String patientId,
    String appointmentId,
    String status,
  ) async {
    final response = await apiClient.put(
      '/patients/$patientId/appointments/$appointmentId',
      data: {'status': status},
    );
    if (response['success'] != true) {
      throw Exception(
        response['message'] ?? 'Failed to update appointment status',
      );
    }
    return AppointmentModel.fromJson(
      Map<String, dynamic>.from(response['data'] as Map),
    );
  }

  Future<AppointmentModel> createAppointment(
    String patientId,
    Map<String, dynamic> data,
  ) async {
    final response = await apiClient.post(
      '/patients/$patientId/appointments',
      data: data,
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to create appointment');
    }
    return AppointmentModel.fromJson(
      Map<String, dynamic>.from(response['data'] as Map),
    );
  }

  Future<AppointmentModel> cancelAppointment(
    String patientId,
    String appointmentId, {
    String? reason,
  }) async {
    final response = await apiClient.post(
      '/patients/$patientId/appointments/$appointmentId/cancel',
      data: {if (reason != null) 'cancellation_reason': reason},
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to cancel appointment');
    }
    return AppointmentModel.fromJson(
      Map<String, dynamic>.from(response['data'] as Map),
    );
  }

  // ── Prescriptions ─────────────────────────────────────────────────────────

  Future<List<PrescriptionModel>> getPrescriptions(
    String patientId, {
    String? status,
    int page = 1,
  }) async {
    final response = await apiClient.get(
      '/patients/$patientId/prescriptions',
      queryParameters: {'page': page, if (status != null) 'status': status},
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to load prescriptions');
    }
    final rawData = response['data'];
    final list = rawData is Map
        ? rawData['data'] as List? ?? []
        : rawData as List? ?? [];
    return list
        .map(
          (e) =>
              PrescriptionModel.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<PrescriptionModel> getPrescription(
    String patientId,
    String prescriptionId,
  ) async {
    final response = await apiClient.get(
      '/patients/$patientId/prescriptions/$prescriptionId',
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to load prescription');
    }
    return PrescriptionModel.fromJson(
      Map<String, dynamic>.from(response['data'] as Map),
    );
  }

  Future<PrescriptionModel> createPrescription(
    String patientId,
    Map<String, dynamic> data,
  ) async {
    final response = await apiClient.post(
      '/patients/$patientId/prescriptions',
      data: data,
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to create prescription');
    }
    return PrescriptionModel.fromJson(
      Map<String, dynamic>.from(response['data'] as Map),
    );
  }

  Future<PrescriptionModel> fillPrescription(
    String patientId,
    String prescriptionId, {
    required int quantityDispensed,
  }) async {
    final response = await apiClient.post(
      '/patients/$patientId/prescriptions/$prescriptionId/fill',
      data: {'quantity_dispensed': quantityDispensed},
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to fill prescription');
    }
    return PrescriptionModel.fromJson(
      Map<String, dynamic>.from(response['data'] as Map),
    );
  }

  Future<PrescriptionModel> discontinuePrescription(
    String patientId,
    String prescriptionId, {
    String? reason,
  }) async {
    final response = await apiClient.post(
      '/patients/$patientId/prescriptions/$prescriptionId/discontinue',
      data: {if (reason != null) 'discontinuation_reason': reason},
    );
    if (response['success'] != true) {
      throw Exception(
        response['message'] ?? 'Failed to discontinue prescription',
      );
    }
    return PrescriptionModel.fromJson(
      Map<String, dynamic>.from(response['data'] as Map),
    );
  }

  // ── Lab Results ───────────────────────────────────────────────────────────

  Future<List<LabResultModel>> getLabResults(
    String patientId, {
    String? status,
    int page = 1,
  }) async {
    final response = await apiClient.get(
      '/patients/$patientId/lab-results',
      queryParameters: {'page': page, if (status != null) 'status': status},
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to load lab results');
    }
    final rawData = response['data'];
    final list = rawData is Map
        ? rawData['data'] as List? ?? []
        : rawData as List? ?? [];
    return list
        .map(
          (e) => LabResultModel.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<LabResultModel> getLabResult(
    String patientId,
    String labResultId,
  ) async {
    final response = await apiClient.get(
      '/patients/$patientId/lab-results/$labResultId',
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to load lab result');
    }
    return LabResultModel.fromJson(
      Map<String, dynamic>.from(response['data'] as Map),
    );
  }

  Future<LabResultModel> createLabOrder(
    String patientId,
    Map<String, dynamic> data,
  ) async {
    final response = await apiClient.post(
      '/patients/$patientId/lab-results',
      data: data,
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to create lab order');
    }
    return LabResultModel.fromJson(
      Map<String, dynamic>.from(response['data'] as Map),
    );
  }

  Future<LabResultModel> recordLabResult(
    String patientId,
    String labResultId,
    Map<String, dynamic> data,
  ) async {
    final response = await apiClient.post(
      '/patients/$patientId/lab-results/$labResultId/record',
      data: data,
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to record lab result');
    }
    return LabResultModel.fromJson(
      Map<String, dynamic>.from(response['data'] as Map),
    );
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
    final list = rawData is Map
        ? rawData['data'] as List? ?? []
        : rawData as List? ?? [];
    return list
        .map(
          (e) => MedicalDocumentModel.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  /// Returns a model with a temporary signed URL for viewing.
  Future<MedicalDocumentModel> getDocumentUrl(
    String patientId,
    String documentId,
  ) async {
    final response = await apiClient.get(
      '/patients/$patientId/documents/$documentId',
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to get document URL');
    }
    return MedicalDocumentModel.fromJson(
      Map<String, dynamic>.from(response['data'] as Map),
    );
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
      Map<String, dynamic>.from(response['data'] as Map),
    );
  }

  Future<void> deleteDocument(String patientId, String documentId) async {
    final response = await apiClient.delete(
      '/patients/$patientId/documents/$documentId',
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to delete document');
    }
  }

  // ── Vital Signs ───────────────────────────────────────────────────────────

  /// Cache-first: tries the API, updates the cache on success. On a network
  /// error, falls back to whatever's cached for this patient rather than
  /// throwing — same contract as PatientRepository.getPatients.
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
      final list = rawData is Map
          ? rawData['data'] as List? ?? []
          : rawData as List? ?? [];
      final vitals = list
          .map(
            (e) => VitalSignModel.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
      if (page == 1) await _db.replaceVitals(patientId, vitals);
      return vitals;
    } catch (e) {
      if (_isNetworkError(e)) {
        final cached = await _db.getCachedVitals(patientId);
        if (cached.isNotEmpty || page == 1) return cached;
      }
      rethrow;
    }
  }

  /// On a network error, queues the create for sync and returns a
  /// locally-cached placeholder built from [data] so the UI can show it
  /// immediately — mirrors PatientRepository's offline-write contract,
  /// including the thrown "will sync when you reconnect" exception (the
  /// caller is expected to catch it and treat it as a soft-success, same
  /// as every other offline-write call site in this app).
  Future<VitalSignModel> createVitalSign(
    String patientId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await apiClient.post(
        '/patients/$patientId/vital-signs',
        data: data,
      );
      if (response['success'] != true) {
        throw Exception(response['message'] ?? 'Failed to record vital signs');
      }
      final vital = VitalSignModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map),
      );
      await _db.upsertVital(vital);
      return vital;
    } catch (e) {
      if (_isNetworkError(e)) {
        final id = const Uuid().v4();
        await _queueOfflineWrite(
          resourceType: 'vitals',
          operation: 'create',
          resourceId: id,
          payload: {...data, 'patient_id': patientId},
        );
        final placeholder = VitalSignModel.fromJson({
          ...data,
          'id': id,
          'patient_id': patientId,
          'recorded_by_id': data['recorded_by_id'] ?? '',
          'version': 1,
        });
        await _db.upsertVital(placeholder);
        throw Exception('Offline — will sync when you reconnect.');
      }
      rethrow;
    }
  }

  Future<void> deleteVitalSign(String patientId, String vitalSignId) async {
    final response = await apiClient.delete(
      '/patients/$patientId/vital-signs/$vitalSignId',
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to delete vital sign');
    }
    await _db.deleteVitalFromCache(vitalSignId);
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
        queryParameters: {'page': page, if (status != null) 'status': status},
      );
      if (response['success'] != true) {
        throw Exception(response['message'] ?? 'Failed to load diagnoses');
      }
      final rawData = response['data'];
      final list = rawData is Map
          ? rawData['data'] as List? ?? []
          : rawData as List? ?? [];
      final diagnoses = list
          .map(
            (e) => DiagnosisModel.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
      // Only cache the unfiltered first page — a status-filtered response
      // isn't the full picture and would otherwise evict cached rows that
      // just don't match this filter.
      if (page == 1 && status == null)
        await _db.replaceDiagnoses(patientId, diagnoses);
      return diagnoses;
    } catch (e) {
      if (_isNetworkError(e)) {
        var cached = await _db.getCachedDiagnoses(patientId);
        if (status != null)
          cached = cached.where((d) => d.status == status).toList();
        if (cached.isNotEmpty || page == 1) return cached;
      }
      rethrow;
    }
  }

  Future<DiagnosisModel> createDiagnosis(
    String patientId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await apiClient.post(
        '/patients/$patientId/diagnoses',
        data: data,
      );
      if (response['success'] != true) {
        throw Exception(response['message'] ?? 'Failed to record diagnosis');
      }
      final diagnosis = DiagnosisModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map),
      );
      await _db.upsertDiagnosis(diagnosis);
      return diagnosis;
    } catch (e) {
      if (_isNetworkError(e)) {
        final id = const Uuid().v4();
        await _queueOfflineWrite(
          resourceType: 'diagnoses',
          operation: 'create',
          resourceId: id,
          payload: {...data, 'patient_id': patientId},
        );
        final placeholder = DiagnosisModel.fromJson({
          ...data,
          'id': id,
          'patient_id': patientId,
          'diagnosed_by_id': data['diagnosed_by_id'] ?? '',
          'status': data['status'] ?? 'active',
          'version': 1,
        });
        await _db.upsertDiagnosis(placeholder);
        throw Exception('Offline — will sync when you reconnect.');
      }
      rethrow;
    }
  }

  Future<void> deleteDiagnosis(String patientId, String diagnosisId) async {
    final response = await apiClient.delete(
      '/patients/$patientId/diagnoses/$diagnosisId',
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to delete diagnosis');
    }
    await _db.deleteDiagnosisFromCache(diagnosisId);
  }

  // ── Problem List ──────────────────────────────────────────────────────────

  Future<List<ProblemListModel>> getProblems(
    String patientId, {
    String? status,
    int page = 1,
  }) async {
    final response = await apiClient.get(
      '/patients/$patientId/problems',
      queryParameters: {'page': page, if (status != null) 'status': status},
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to load problem list');
    }
    final rawData = response['data'];
    final list = rawData is Map
        ? rawData['data'] as List? ?? []
        : rawData as List? ?? [];
    return list
        .map(
          (e) => ProblemListModel.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<ProblemListModel> createProblem(
    String patientId,
    Map<String, dynamic> data,
  ) async {
    final response = await apiClient.post(
      '/patients/$patientId/problems',
      data: data,
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to record problem');
    }
    return ProblemListModel.fromJson(
      Map<String, dynamic>.from(response['data'] as Map),
    );
  }

  Future<void> deleteProblem(String patientId, String problemId) async {
    final response = await apiClient.delete(
      '/patients/$patientId/problems/$problemId',
    );
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
    final list = rawData is Map
        ? rawData['data'] as List? ?? []
        : rawData as List? ?? [];
    return list
        .map(
          (e) => ProcedureModel.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<ProcedureModel> createProcedure(
    String patientId,
    Map<String, dynamic> data,
  ) async {
    final response = await apiClient.post(
      '/patients/$patientId/procedures',
      data: data,
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to record procedure');
    }
    return ProcedureModel.fromJson(
      Map<String, dynamic>.from(response['data'] as Map),
    );
  }

  Future<void> deleteProcedure(String patientId, String procedureId) async {
    final response = await apiClient.delete(
      '/patients/$patientId/procedures/$procedureId',
    );
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
    final list = rawData is Map
        ? rawData['data'] as List? ?? []
        : rawData as List? ?? [];
    return list
        .map(
          (e) =>
              ImmunizationModel.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<ImmunizationModel> createImmunization(
    String patientId,
    Map<String, dynamic> data,
  ) async {
    final response = await apiClient.post(
      '/patients/$patientId/immunizations',
      data: data,
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to record immunization');
    }
    return ImmunizationModel.fromJson(
      Map<String, dynamic>.from(response['data'] as Map),
    );
  }

  Future<void> deleteImmunization(
    String patientId,
    String immunizationId,
  ) async {
    final response = await apiClient.delete(
      '/patients/$patientId/immunizations/$immunizationId',
    );
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
        if (date != null) 'date': date,
        if (status != null) 'status': status,
      },
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to load roster entries');
    }
    final rawData = response['data'];
    final list = rawData is Map
        ? rawData['data'] as List? ?? []
        : rawData as List? ?? [];
    return list
        .map(
          (e) => RosterEntryModel.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<RosterEntryModel> createRosterEntry(
    String patientId,
    Map<String, dynamic> data,
  ) async {
    final response = await apiClient.post(
      '/patients/$patientId/roster',
      data: data,
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to add patient to roster');
    }
    return RosterEntryModel.fromJson(
      Map<String, dynamic>.from(response['data'] as Map),
    );
  }

  Future<RosterEntryModel> updateRosterEntry(
    String patientId,
    String entryId,
    Map<String, dynamic> data,
  ) async {
    final response = await apiClient.put(
      '/patients/$patientId/roster/$entryId',
      data: data,
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to update roster entry');
    }
    return RosterEntryModel.fromJson(
      Map<String, dynamic>.from(response['data'] as Map),
    );
  }

  // ── Audit log ─────────────────────────────────────────────────────────────

  /// Restricted server-side to the patient's primary provider or a super
  /// admin (PatientController::auditLog) — expect a 403 for anyone else.
  Future<({List<AuditLogEntry> items, bool hasMore, int total})>
  getPatientAuditLog(String patientId, {int page = 1}) async {
    final response = await apiClient.get(
      '/patients/$patientId/audit-log',
      queryParameters: {'page': page, 'per_page': 30},
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to load audit log');
    }

    final list = (response['data'] as List? ?? [])
        .map((e) => AuditLogEntry.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    final meta = response['meta'] as Map? ?? {};
    final pagination = meta['pagination'] as Map? ?? {};
    final total = (pagination['total'] as num?)?.toInt() ?? list.length;
    final lastPage = (pagination['last_page'] as num?)?.toInt() ?? 1;

    return (items: list, hasMore: page < lastPage, total: total);
  }

  // ── Patient messaging ─────────────────────────────────────────────────────

  Future<List<PatientMessageModel>> getPatientMessages(String patientId) async {
    final response = await apiClient.get('/patients/$patientId/messages');
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to load messages');
    }
    final raw = response['data'];
    final list = raw is Map
        ? (raw['data'] as List? ?? [])
        : (raw as List? ?? []);
    return list
        .map(
          (e) =>
              PatientMessageModel.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  /// Replies threaded off [parentMessageId] — any existing message in the
  /// patient's thread works as the parent (the backend just checks it
  /// belongs to the same patient), so callers typically pass the most
  /// recent message's id to keep the thread linear.
  Future<PatientMessageModel> replyToPatientMessage(
    String patientId,
    String parentMessageId,
    String body,
  ) async {
    final response = await apiClient.post(
      '/patients/$patientId/messages/$parentMessageId/reply',
      data: {'body': body},
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to send reply');
    }
    return PatientMessageModel.fromJson(
      Map<String, dynamic>.from(response['data'] as Map),
    );
  }

  // ── Offline write helpers ────────────────────────────────────────────────

  Future<void> _queueOfflineWrite({
    required String resourceType,
    required String operation,
    String? resourceId,
    required Map<String, dynamic> payload,
  }) async {
    await _db.queuePendingSync(
      id: const Uuid().v4(),
      resourceType: resourceType,
      resourceId: resourceId,
      operation: operation,
      payload: payload,
    );
  }

  bool _isNetworkError(Object e) {
    final msg = e.toString();
    return msg.contains('SocketException') ||
        msg.contains('Connection refused') ||
        msg.contains('Connection reset') ||
        msg.contains('Network is unreachable') ||
        msg.contains('HandshakeException');
  }
}
