import 'package:flutter/material.dart';
import '../models/clinical_models.dart';
import '../models/clinical_record_models.dart';
import '../repositories/clinical_repository.dart';

/// ClinicalProvider
///
/// Holds clinical state for a single patient at a time (the "selected patient").
/// Call [loadAll] when entering a patient detail screen and [clear] on exit.
class ClinicalProvider extends ChangeNotifier {
  final ClinicalRepository repository;

  ClinicalProvider({required this.repository});

  // ── State ──────────────────────────────────────────────────────────────────

  String? _patientId;

  List<AppointmentModel> _appointments = [];
  List<PrescriptionModel> _prescriptions = [];
  List<LabResultModel> _labResults = [];
  List<MedicalDocumentModel> _documents = [];
  List<VitalSignModel> _vitalSigns = [];
  List<DiagnosisModel> _diagnoses = [];
  List<ProblemListModel> _problems = [];
  List<ProcedureModel> _procedures = [];
  List<ImmunizationModel> _immunizations = [];

  bool _isLoading = false;
  String? _error;

  // ── Getters ────────────────────────────────────────────────────────────────

  String? get patientId => _patientId;
  List<AppointmentModel> get appointments => _appointments;
  List<PrescriptionModel> get prescriptions => _prescriptions;
  List<LabResultModel> get labResults => _labResults;
  List<MedicalDocumentModel> get documents => _documents;
  List<VitalSignModel> get vitalSigns => _vitalSigns;
  List<DiagnosisModel> get diagnoses => _diagnoses;
  List<ProblemListModel> get problems => _problems;
  List<ProcedureModel> get procedures => _procedures;
  List<ImmunizationModel> get immunizations => _immunizations;

  List<DiagnosisModel> get activeDiagnoses =>
      _diagnoses.where((d) => d.isActive).toList();

  List<ProblemListModel> get activeProblems =>
      _problems.where((p) => p.isActive).toList();
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<AppointmentModel> get upcomingAppointments =>
      _appointments.where((a) => a.isUpcoming).toList()
        ..sort((a, b) => a.appointmentDate.compareTo(b.appointmentDate));

  List<PrescriptionModel> get activePrescriptions =>
      _prescriptions.where((p) => p.isActive).toList();

  List<LabResultModel> get pendingLabResults =>
      _labResults.where((l) => l.isPending).toList();

  List<LabResultModel> get urgentLabResults =>
      _labResults.where((l) => l.isUrgent && l.isPending).toList();

  // ── Load all data for a patient ────────────────────────────────────────────

  Future<void> loadAll(String patientId) async {
    _patientId = patientId;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        repository.getAppointments(patientId),
        repository.getPrescriptions(patientId),
        repository.getLabResults(patientId),
        repository.getDocuments(patientId),
        repository.getVitalSigns(patientId),
        repository.getDiagnoses(patientId),
        repository.getProblems(patientId),
        repository.getProcedures(patientId),
        repository.getImmunizations(patientId),
      ]);
      _appointments  = results[0] as List<AppointmentModel>;
      _prescriptions = results[1] as List<PrescriptionModel>;
      _labResults    = results[2] as List<LabResultModel>;
      _documents     = results[3] as List<MedicalDocumentModel>;
      _vitalSigns    = results[4] as List<VitalSignModel>;
      _diagnoses     = results[5] as List<DiagnosisModel>;
      _problems      = results[6] as List<ProblemListModel>;
      _procedures    = results[7] as List<ProcedureModel>;
      _immunizations = results[8] as List<ImmunizationModel>;
      _error = null;
    } catch (e) {
      _error = _friendlyError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Individual loaders (for tab refresh) ──────────────────────────────────

  Future<void> loadAppointments({String? status}) async {
    if (_patientId == null) return;
    try {
      _appointments = await repository.getAppointments(_patientId!, status: status);
      notifyListeners();
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
    }
  }

  Future<void> loadPrescriptions({String? status}) async {
    if (_patientId == null) return;
    try {
      _prescriptions = await repository.getPrescriptions(_patientId!, status: status);
      notifyListeners();
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
    }
  }

  Future<void> loadLabResults({String? status}) async {
    if (_patientId == null) return;
    try {
      _labResults = await repository.getLabResults(_patientId!, status: status);
      notifyListeners();
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
    }
  }

  Future<void> loadDocuments() async {
    if (_patientId == null) return;
    try {
      _documents = await repository.getDocuments(_patientId!);
      notifyListeners();
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
    }
  }

  Future<void> loadVitalSigns() async {
    if (_patientId == null) return;
    try {
      _vitalSigns = await repository.getVitalSigns(_patientId!);
      notifyListeners();
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
    }
  }

  Future<void> loadDiagnoses({String? status}) async {
    if (_patientId == null) return;
    try {
      _diagnoses = await repository.getDiagnoses(_patientId!, status: status);
      notifyListeners();
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
    }
  }

  Future<void> loadProblems({String? status}) async {
    if (_patientId == null) return;
    try {
      _problems = await repository.getProblems(_patientId!, status: status);
      notifyListeners();
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
    }
  }

  Future<void> loadProcedures() async {
    if (_patientId == null) return;
    try {
      _procedures = await repository.getProcedures(_patientId!);
      notifyListeners();
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
    }
  }

  Future<void> loadImmunizations() async {
    if (_patientId == null) return;
    try {
      _immunizations = await repository.getImmunizations(_patientId!);
      notifyListeners();
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
    }
  }

  // ── Write operations ───────────────────────────────────────────────────────

  Future<VitalSignModel?> createVitalSign(Map<String, dynamic> data) async {
    if (_patientId == null) return null;
    try {
      final v = await repository.createVitalSign(_patientId!, data);
      _vitalSigns = [v, ..._vitalSigns];
      notifyListeners();
      return v;
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
      return null;
    }
  }

  Future<bool> deleteVitalSign(String vitalSignId) async {
    if (_patientId == null) return false;
    try {
      await repository.deleteVitalSign(_patientId!, vitalSignId);
      _vitalSigns = _vitalSigns.where((v) => v.id != vitalSignId).toList();
      notifyListeners();
      return true;
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  Future<DiagnosisModel?> createDiagnosis(Map<String, dynamic> data) async {
    if (_patientId == null) return null;
    try {
      final d = await repository.createDiagnosis(_patientId!, data);
      _diagnoses = [d, ..._diagnoses];
      notifyListeners();
      return d;
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
      return null;
    }
  }

  Future<bool> deleteDiagnosis(String diagnosisId) async {
    if (_patientId == null) return false;
    try {
      await repository.deleteDiagnosis(_patientId!, diagnosisId);
      _diagnoses = _diagnoses.where((d) => d.id != diagnosisId).toList();
      notifyListeners();
      return true;
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  Future<ProblemListModel?> createProblem(Map<String, dynamic> data) async {
    if (_patientId == null) return null;
    try {
      final p = await repository.createProblem(_patientId!, data);
      _problems = [p, ..._problems];
      notifyListeners();
      return p;
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
      return null;
    }
  }

  Future<bool> deleteProblem(String problemId) async {
    if (_patientId == null) return false;
    try {
      await repository.deleteProblem(_patientId!, problemId);
      _problems = _problems.where((p) => p.id != problemId).toList();
      notifyListeners();
      return true;
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  Future<ProcedureModel?> createProcedure(Map<String, dynamic> data) async {
    if (_patientId == null) return null;
    try {
      final p = await repository.createProcedure(_patientId!, data);
      _procedures = [p, ..._procedures];
      notifyListeners();
      return p;
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
      return null;
    }
  }

  Future<bool> deleteProcedure(String procedureId) async {
    if (_patientId == null) return false;
    try {
      await repository.deleteProcedure(_patientId!, procedureId);
      _procedures = _procedures.where((p) => p.id != procedureId).toList();
      notifyListeners();
      return true;
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  Future<ImmunizationModel?> createImmunization(
      Map<String, dynamic> data) async {
    if (_patientId == null) return null;
    try {
      final i = await repository.createImmunization(_patientId!, data);
      _immunizations = [i, ..._immunizations];
      notifyListeners();
      return i;
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
      return null;
    }
  }

  Future<bool> deleteImmunization(String immunizationId) async {
    if (_patientId == null) return false;
    try {
      await repository.deleteImmunization(_patientId!, immunizationId);
      _immunizations =
          _immunizations.where((i) => i.id != immunizationId).toList();
      notifyListeners();
      return true;
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  Future<AppointmentModel?> createAppointment(
      Map<String, dynamic> data) async {
    if (_patientId == null) return null;
    try {
      final appt = await repository.createAppointment(_patientId!, data);
      _appointments = [appt, ..._appointments];
      notifyListeners();
      return appt;
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
      return null;
    }
  }

  Future<bool> cancelAppointment(String appointmentId, {String? reason}) async {
    if (_patientId == null) return false;
    try {
      final updated = await repository.cancelAppointment(
          _patientId!, appointmentId,
          reason: reason);
      _appointments = _appointments
          .map((a) => a.id == appointmentId ? updated : a)
          .toList();
      notifyListeners();
      return true;
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  Future<PrescriptionModel?> createPrescription(
      Map<String, dynamic> data) async {
    if (_patientId == null) return null;
    try {
      final rx = await repository.createPrescription(_patientId!, data);
      _prescriptions = [rx, ..._prescriptions];
      notifyListeners();
      return rx;
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
      return null;
    }
  }

  Future<PrescriptionModel?> fillPrescription(
      String prescriptionId, int quantityDispensed) async {
    if (_patientId == null) return null;
    try {
      final updated = await repository.fillPrescription(
          _patientId!, prescriptionId,
          quantityDispensed: quantityDispensed);
      _prescriptions = _prescriptions
          .map((p) => p.id == prescriptionId ? updated : p)
          .toList();
      notifyListeners();
      return updated;
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
      return null;
    }
  }

  Future<bool> discontinuePrescription(String prescriptionId,
      {String? reason}) async {
    if (_patientId == null) return false;
    try {
      final updated = await repository.discontinuePrescription(
          _patientId!, prescriptionId,
          reason: reason);
      _prescriptions = _prescriptions
          .map((p) => p.id == prescriptionId ? updated : p)
          .toList();
      notifyListeners();
      return true;
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  Future<LabResultModel?> createLabOrder(Map<String, dynamic> data) async {
    if (_patientId == null) return null;
    try {
      final lab = await repository.createLabOrder(_patientId!, data);
      _labResults = [lab, ..._labResults];
      notifyListeners();
      return lab;
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
      return null;
    }
  }

  Future<LabResultModel?> recordLabResult(
      String labResultId, Map<String, dynamic> data) async {
    if (_patientId == null) return null;
    try {
      final updated =
          await repository.recordLabResult(_patientId!, labResultId, data);
      _labResults = _labResults
          .map((l) => l.id == labResultId ? updated : l)
          .toList();
      notifyListeners();
      return updated;
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
      return null;
    }
  }

  Future<MedicalDocumentModel?> uploadDocument({
    required String filePath,
    required String fileName,
    required String title,
    required String documentType,
    String? notes,
    bool isConfidential = false,
  }) async {
    if (_patientId == null) return null;
    try {
      final doc = await repository.uploadDocument(
        _patientId!,
        filePath: filePath,
        fileName: fileName,
        title: title,
        documentType: documentType,
        notes: notes,
        isConfidential: isConfidential,
      );
      _documents = [doc, ..._documents];
      notifyListeners();
      return doc;
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
      return null;
    }
  }

  /// Returns a temporary signed download URL for a document, or null on error.
  Future<String?> getDocumentDownloadUrl(String documentId) async {
    if (_patientId == null) return null;
    try {
      final doc = await repository.getDocumentUrl(_patientId!, documentId);
      return doc.temporaryUrl;
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
      return null;
    }
  }

  Future<bool> deleteDocument(String documentId) async {
    if (_patientId == null) return false;
    try {
      await repository.deleteDocument(_patientId!, documentId);
      _documents = _documents.where((d) => d.id != documentId).toList();
      notifyListeners();
      return true;
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  // ── Housekeeping ───────────────────────────────────────────────────────────

  void clear() {
    _patientId = null;
    _appointments  = [];
    _prescriptions = [];
    _labResults    = [];
    _documents     = [];
    _vitalSigns    = [];
    _diagnoses     = [];
    _problems      = [];
    _procedures    = [];
    _immunizations = [];
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('SocketException') || msg.contains('Connection')) {
      return 'No internet connection.';
    }
    if (msg.contains('401')) return 'Session expired. Please log in again.';
    if (msg.contains('403')) return 'You do not have permission to view this data.';
    if (msg.contains('404')) return 'Record not found.';
    return 'Something went wrong. Please try again.';
  }
}
