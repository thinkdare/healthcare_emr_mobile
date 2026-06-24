// lib/data/providers/ward_workflow_provider.dart

import 'package:flutter/foundation.dart';
import '../models/ward_models.dart';
import '../repositories/ward_workflow_repository.dart';

class WardWorkflowProvider extends ChangeNotifier {
  final WardWorkflowRepository repository;

  WardWorkflowProvider({required this.repository});

  // ── State ──────────────────────────────────────────────────────────────────

  List<WardModel> _wards = [];
  List<AdmissionRequestModel> _admissionRequests = [];
  List<WardTransferRequestModel> _transferRequests = [];
  List<DischargeRequestModel> _dischargeRequests = [];
  List<WardAccessGrantModel> _wardAccessGrants = [];

  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _error;

  // ── Getters ────────────────────────────────────────────────────────────────

  List<WardModel> get wards => _wards;
  List<AdmissionRequestModel> get admissionRequests => _admissionRequests;
  List<WardTransferRequestModel> get transferRequests => _transferRequests;
  List<DischargeRequestModel> get dischargeRequests => _dischargeRequests;
  List<WardAccessGrantModel> get wardAccessGrants => _wardAccessGrants;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get error => _error;

  // ── Load ───────────────────────────────────────────────────────────────────

  Future<void> loadAll(String patientId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        repository.listWards(),
        repository.listAdmissionRequests(patientId),
        repository.listTransferRequests(patientId),
        repository.listDischargeRequests(patientId),
      ]);
      _wards = results[0] as List<WardModel>;
      _admissionRequests = results[1] as List<AdmissionRequestModel>;
      _transferRequests = results[2] as List<WardTransferRequestModel>;
      _dischargeRequests = results[3] as List<DischargeRequestModel>;
    } catch (e) {
      _error = _friendly(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Admission ─────────────────────────────────────────────────────────────

  Future<bool> requestAdmission(
    String patientId, {
    required String wardId,
    required String admissionType,
    required String reason,
    String? bedId,
  }) =>
      _run(() async {
        final created = await repository.requestAdmission(
          patientId,
          wardId: wardId,
          admissionType: admissionType,
          reason: reason,
          bedId: bedId,
        );
        _admissionRequests = [created, ..._admissionRequests];
      });

  Future<bool> acceptAdmission(String patientId, String requestId,
          {String? bedId}) =>
      _run(() async {
        await repository.acceptAdmission(requestId, bedId: bedId);
        await loadAll(patientId);
      });

  Future<bool> rejectAdmission(
          String patientId, String requestId, String reason) =>
      _run(() async {
        await repository.rejectAdmission(requestId, reason);
        await loadAll(patientId);
      });

  Future<bool> cancelAdmission(String patientId, String requestId) => _run(() async {
        await repository.cancelAdmission(requestId);
        await loadAll(patientId);
      });

  Future<bool> forceAdmit(
    String patientId, {
    required String wardId,
    required String admissionType,
    required String reason,
    required String overrideReason,
    String? bedId,
  }) =>
      _run(() async {
        await repository.forceAdmit(
          patientId,
          wardId: wardId,
          admissionType: admissionType,
          reason: reason,
          overrideReason: overrideReason,
          bedId: bedId,
        );
        await loadAll(patientId);
      });

  // ── Transfer ──────────────────────────────────────────────────────────────

  Future<bool> requestTransfer(
    String patientId, {
    required String toWardId,
    required String reason,
    String? toBedId,
  }) =>
      _run(() async {
        final created = await repository.requestTransfer(
          patientId,
          toWardId: toWardId,
          reason: reason,
          toBedId: toBedId,
        );
        _transferRequests = [created, ..._transferRequests];
      });

  Future<bool> acceptTransfer(String patientId, String requestId,
          {String? toBedId}) =>
      _run(() async {
        await repository.acceptTransfer(requestId, toBedId: toBedId);
        await loadAll(patientId);
      });

  Future<bool> rejectTransfer(
          String patientId, String requestId, String reason) =>
      _run(() async {
        await repository.rejectTransfer(requestId, reason);
        await loadAll(patientId);
      });

  Future<bool> forceTransfer(
    String patientId, {
    required String toWardId,
    required String reason,
    required String overrideReason,
    String? toBedId,
  }) =>
      _run(() async {
        await repository.forceTransfer(
          patientId,
          toWardId: toWardId,
          reason: reason,
          overrideReason: overrideReason,
          toBedId: toBedId,
        );
        await loadAll(patientId);
      });

  // ── Discharge ─────────────────────────────────────────────────────────────

  Future<bool> requestDischarge(
    String patientId, {
    required String dischargeType,
    String? dischargeSummary,
  }) =>
      _run(() async {
        final created = await repository.requestDischarge(
          patientId,
          dischargeType: dischargeType,
          dischargeSummary: dischargeSummary,
        );
        _dischargeRequests = [created, ..._dischargeRequests];
      });

  Future<bool> approveSignoff(
          String patientId, String requestId, String signoffId,
          {String? notes}) =>
      _run(() async {
        await repository.approveSignoff(requestId, signoffId, notes: notes);
        await loadAll(patientId);
      });

  Future<bool> rejectSignoff(
          String patientId, String requestId, String signoffId, String reason) =>
      _run(() async {
        await repository.rejectSignoff(requestId, signoffId, reason);
        await loadAll(patientId);
      });

  Future<bool> overrideSignoff(String patientId, String requestId,
          String signoffId, String overrideReason) =>
      _run(() async {
        await repository.overrideSignoff(requestId, signoffId, overrideReason);
        await loadAll(patientId);
      });

  Future<bool> recordsApprove(String patientId, String requestId) => _run(() async {
        await repository.recordsApprove(requestId);
        await loadAll(patientId);
      });

  Future<bool> executeDischarge(String patientId, String requestId) => _run(() async {
        await repository.executeDischarge(requestId);
        await loadAll(patientId);
      });

  Future<bool> cancelDischarge(String patientId, String requestId) => _run(() async {
        await repository.cancelDischarge(requestId);
        await loadAll(patientId);
      });

  Future<bool> forceDischarge(
    String patientId, {
    required String dischargeType,
    required String overrideReason,
    String? dischargeSummary,
  }) =>
      _run(() async {
        await repository.forceDischarge(
          patientId,
          dischargeType: dischargeType,
          overrideReason: overrideReason,
          dischargeSummary: dischargeSummary,
        );
        await loadAll(patientId);
      });

  // ── Ward access grants ───────────────────────────────────────────────────

  Future<void> loadWardAccess(String membershipId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _wards = await repository.listWards();
      _wardAccessGrants = await repository.listWardAccess(membershipId);
    } catch (e) {
      _error = _friendly(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> grantWardAccess(String membershipId, String wardId) => _run(() async {
        await repository.grantWardAccess(membershipId, wardId);
        _wardAccessGrants = await repository.listWardAccess(membershipId);
      });

  Future<bool> revokeWardAccess(String membershipId, String grantId) =>
      _run(() async {
        await repository.revokeWardAccess(grantId);
        _wardAccessGrants = await repository.listWardAccess(membershipId);
      });

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<bool> _run(Future<void> Function() call) async {
    _isSubmitting = true;
    _error = null;
    notifyListeners();
    try {
      await call();
      _isSubmitting = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _friendly(e);
      _isSubmitting = false;
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  String _friendly(Object e) {
    final msg = e.toString();
    if (msg.contains('SocketException') || msg.contains('Connection')) {
      return 'No internet connection.';
    }
    if (msg.contains('401')) return 'Session expired. Please log in again.';
    if (msg.contains('403')) {
      return 'You do not have permission to perform this action.';
    }
    if (msg.contains('NOT_ADMITTED')) {
      return 'Patient is not currently admitted.';
    }
    final match = RegExp(r'ApiException\(\d+\): (.+)').firstMatch(msg);
    if (match != null) return match.group(1)!;
    return msg.contains('Exception:') ? msg.split('Exception:').last.trim() : msg;
  }
}
