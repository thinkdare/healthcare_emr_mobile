import 'package:flutter/material.dart';
import '../models/emergency_access_models.dart';
import '../repositories/emergency_access_repository.dart';

class EmergencyAccessProvider extends ChangeNotifier {
  final EmergencyAccessRepository repository;

  EmergencyAccessProvider({required this.repository});

  // ── State ──────────────────────────────────────────────────────────────────

  List<EmergencyAccessModel> _logs = [];
  bool _isLoading = false;
  bool _hasMore = false;
  int _currentPage = 1;
  String? _error;

  // ── Getters ────────────────────────────────────────────────────────────────

  List<EmergencyAccessModel> get logs => _logs;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  String? get error => _error;

  int get unreviewedCount =>
      _logs.where((l) => l.needsReview).length;

  // ── Load ───────────────────────────────────────────────────────────────────

  Future<void> loadLogs({String? masterPatientId, bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _logs = [];
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await repository.getLogs(
        masterPatientId: masterPatientId,
        page: _currentPage,
      );
      _logs = refresh
          ? result.items
          : [..._logs, ...result.items];
      _hasMore = result.hasMore;
      _currentPage = result.currentPage + 1;
    } catch (e) {
      _error = _friendly(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore({String? masterPatientId}) async {
    if (!_hasMore || _isLoading) return;
    await loadLogs(masterPatientId: masterPatientId);
  }

  // ── Trigger ────────────────────────────────────────────────────────────────

  Future<EmergencyAccessModel?> trigger(Map<String, dynamic> data) async {
    try {
      final log = await repository.trigger(data);
      _logs = [log, ..._logs];
      notifyListeners();
      return log;
    } catch (e) {
      _error = _friendly(e);
      notifyListeners();
      return null;
    }
  }

  // ── Review ─────────────────────────────────────────────────────────────────

  Future<bool> review(String id, String notes) async {
    try {
      final updated = await repository.review(id, notes);
      _logs = _logs.map((l) => l.id == id ? updated : l).toList();
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
    if (msg.contains('403')) {
      if (msg.contains('EMERGENCY_ACCESS_NOT_PERMITTED')) {
        return 'You do not have emergency access capability at this facility.';
      }
      return 'You do not have permission to perform this action.';
    }
    if (msg.contains('ALREADY_REVIEWED')) {
      return 'This event has already been reviewed.';
    }
    final match = RegExp(r'ApiException\(\d+\): (.+)').firstMatch(msg);
    if (match != null) return match.group(1)!;
    return msg.contains('Exception:') ? msg.split('Exception:').last.trim() : msg;
  }
}
