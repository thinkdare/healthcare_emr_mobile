// lib/data/providers/referral_provider.dart

import 'package:flutter/foundation.dart';
import '../models/referral_models.dart';
import '../repositories/referral_repository.dart';

class ReferralProvider extends ChangeNotifier {
  final ReferralRepository repository;

  ReferralProvider({required this.repository});

  // ── State ──────────────────────────────────────────────────────────────────

  List<ReferralModel> _all = [];
  ReferralFilter _filter = ReferralFilter.all;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  int _currentPage = 1;
  bool _hasMore = true;

  final Map<String, List<ReferralMessageModel>> _messages = {};
  bool _isSendingMessage = false;

  // ── Getters ────────────────────────────────────────────────────────────────

  ReferralFilter get filter        => _filter;
  bool get isLoading               => _isLoading;
  bool get isLoadingMore           => _isLoadingMore;
  String? get error                => _error;
  bool get isSendingMessage        => _isSendingMessage;

  List<ReferralModel> get referrals =>
      _all.where((r) => _filter.matches(r.status)).toList();

  // Count of referrals where current user is the receiving facility + pending
  int get pendingActionCount =>
      _all.where((r) => r.isReceived && r.status == 'pending').length;

  List<ReferralMessageModel> messagesFor(String referralId) =>
      _messages[referralId] ?? [];

  // ── Load ───────────────────────────────────────────────────────────────────

  Future<void> loadReferrals({
    bool refresh = false,
    String currentTenantId = '',
  }) async {
    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
    }
    repository.currentTenantId = currentTenantId;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final fetched = await repository.list(page: _currentPage);
      if (refresh || _currentPage == 1) {
        _all = fetched;
      } else {
        _all = [..._all, ...fetched];
      }
      _hasMore = fetched.length >= 50;
    } catch (e) {
      _error = _friendly(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore({String currentTenantId = ''}) async {
    if (_isLoadingMore || !_hasMore) return;
    _currentPage++;
    repository.currentTenantId = currentTenantId;
    _isLoadingMore = true;
    notifyListeners();

    try {
      final fetched = await repository.list(page: _currentPage);
      _all = [..._all, ...fetched];
      _hasMore = fetched.length >= 50;
    } catch (_) {
      _currentPage--;
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  void setFilter(ReferralFilter f) {
    if (_filter == f) return;
    _filter = f;
    notifyListeners();
  }

  // ── Write ops ─────────────────────────────────────────────────────────────

  Future<ReferralModel?> create(Map<String, dynamic> data) async {
    try {
      final created = await repository.create(data);
      _all = [created, ..._all];
      notifyListeners();
      return created;
    } catch (e) {
      _error = _friendly(e);
      notifyListeners();
      return null;
    }
  }

  Future<bool> accept(String id) =>
      _transition(id, () => repository.accept(id));

  Future<bool> schedule(String id, String date, String? location) =>
      _transition(id, () => repository.schedule(id, date, location));

  Future<bool> complete(String id, String notes, String? recs) =>
      _transition(id, () => repository.complete(id, notes, recs));

  Future<bool> cancel(String id, String reason) =>
      _transition(id, () => repository.cancel(id, reason));

  Future<bool> _transition(
      String id, Future<ReferralModel> Function() call) async {
    try {
      final updated = await call();
      _all = _all.map((r) => r.id == id ? updated : r).toList();
      notifyListeners();
      return true;
    } catch (e) {
      _error = _friendly(e);
      notifyListeners();
      return false;
    }
  }

  // ── Messages ──────────────────────────────────────────────────────────────

  Future<void> loadMessages(String referralId) async {
    try {
      final msgs = await repository.getMessages(referralId);
      _messages[referralId] = msgs;
      notifyListeners();
    } catch (e) {
      _error = _friendly(e);
      notifyListeners();
    }
  }

  Future<bool> sendMessage(String referralId, String message) async {
    _isSendingMessage = true;
    notifyListeners();
    try {
      final msg = await repository.sendMessage(referralId, message);
      _messages[referralId] = [...(_messages[referralId] ?? []), msg];
      _isSendingMessage = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _friendly(e);
      _isSendingMessage = false;
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
    if (msg.contains('PATIENT_CONSENT_REQUIRED')) {
      return 'This patient has not enabled cross-facility data sharing.';
    }
    if (msg.contains('SAME_FACILITY')) {
      return 'Cannot refer to your own facility.';
    }
    if (msg.contains('RECEIVING_PROVIDER_NOT_CREDENTIALED')) {
      return 'That provider is not registered at the selected facility.';
    }
    if (msg.contains('INVALID_STATUS_TRANSITION')) {
      return 'This action is no longer available — the referral status has changed.';
    }
    if (msg.contains('REFERRAL_CLOSED')) {
      return 'Cannot send messages on a completed or cancelled referral.';
    }
    final match = RegExp(r'ApiException\(\d+\): (.+)').firstMatch(msg);
    if (match != null) return match.group(1)!;
    return msg.contains('Exception:')
        ? msg.split('Exception:').last.trim()
        : msg;
  }
}
