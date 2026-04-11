import 'package:flutter/material.dart';
import '../models/access_grant_models.dart';
import '../repositories/access_grant_repository.dart';

class AccessGrantProvider extends ChangeNotifier {
  final AccessGrantRepository repository;

  AccessGrantProvider({required this.repository});

  // ── State ──────────────────────────────────────────────────────────────────

  List<AccessGrantModel> _pendingApproval = [];
  List<AccessGrantModel> _myRequests = [];
  bool _isLoading = false;
  String? _error;

  // ── Getters ────────────────────────────────────────────────────────────────

  List<AccessGrantModel> get pendingApproval => _pendingApproval;
  List<AccessGrantModel> get myRequests => _myRequests;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get pendingCount => _pendingApproval.length;

  // ── Load ───────────────────────────────────────────────────────────────────

  Future<void> loadGrants() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await repository.getGrants();
      _pendingApproval = result.pendingApproval;
      _myRequests = result.myRequests;
    } catch (e) {
      _error = _friendly(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Request access ────────────────────────────────────────────────────────

  Future<AccessGrantModel?> requestAccess(Map<String, dynamic> data) async {
    try {
      final grant = await repository.requestAccess(data);
      _myRequests = [grant, ..._myRequests];
      notifyListeners();
      return grant;
    } catch (e) {
      _error = _friendly(e);
      notifyListeners();
      return null;
    }
  }

  // ── Approve ───────────────────────────────────────────────────────────────

  Future<bool> approve(String id, {String? notes}) async {
    try {
      final updated = await repository.approve(id, notes: notes);
      _pendingApproval =
          _pendingApproval.where((g) => g.id != id).toList();
      _myRequests = _myRequests.map((g) => g.id == id ? updated : g).toList();
      notifyListeners();
      return true;
    } catch (e) {
      _error = _friendly(e);
      notifyListeners();
      return false;
    }
  }

  // ── Deny ──────────────────────────────────────────────────────────────────

  Future<bool> deny(String id, String reason) async {
    try {
      final updated = await repository.deny(id, reason);
      _pendingApproval =
          _pendingApproval.where((g) => g.id != id).toList();
      _myRequests = _myRequests.map((g) => g.id == id ? updated : g).toList();
      notifyListeners();
      return true;
    } catch (e) {
      _error = _friendly(e);
      notifyListeners();
      return false;
    }
  }

  // ── Revoke ─────────────────────────────────────────────────────────────────

  Future<bool> revoke(String id, String reason) async {
    try {
      final updated = await repository.revoke(id, reason);
      _myRequests = _myRequests.map((g) => g.id == id ? updated : g).toList();
      notifyListeners();
      return true;
    } catch (e) {
      _error = _friendly(e);
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
    if (msg.contains('403')) return 'You do not have permission to perform this action.';
    if (msg.contains('ALREADY_HAS_ACCESS')) return 'You already have access to this patient.';
    if (msg.contains('SELF_ACCESS')) return 'You cannot request access to your own patient.';
    if (msg.contains('SAME_FACILITY')) return 'Patient is at your facility. No grant needed.';
    // Extract message from ApiException format: "ApiException(4xx): <message>"
    final match = RegExp(r'ApiException\(\d+\): (.+)').firstMatch(msg);
    if (match != null) return match.group(1)!;
    return msg.contains('Exception:') ? msg.split('Exception:').last.trim() : msg;
  }
}
