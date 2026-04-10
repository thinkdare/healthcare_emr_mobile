import 'package:flutter/material.dart';
import '../models/clinical_models.dart';
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

  bool _isLoading = false;
  String? _error;

  // ── Getters ────────────────────────────────────────────────────────────────

  String? get patientId => _patientId;
  List<AppointmentModel> get appointments => _appointments;
  List<PrescriptionModel> get prescriptions => _prescriptions;
  List<LabResultModel> get labResults => _labResults;
  List<MedicalDocumentModel> get documents => _documents;
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
      ]);
      _appointments = results[0] as List<AppointmentModel>;
      _prescriptions = results[1] as List<PrescriptionModel>;
      _labResults = results[2] as List<LabResultModel>;
      _documents = results[3] as List<MedicalDocumentModel>;
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

  // ── Write operations ───────────────────────────────────────────────────────

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
    _appointments = [];
    _prescriptions = [];
    _labResults = [];
    _documents = [];
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
