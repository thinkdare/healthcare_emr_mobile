import 'dart:async';

import 'package:flutter/foundation.dart';
import '../models/intra_grant_models.dart';
import '../repositories/intra_grant_repository.dart';

class IntraGrantProvider extends ChangeNotifier {
  final IntraGrantRepository repository;

  IntraGrantProvider({required this.repository});

  List<IntraAccessGrantModel> _incoming = [];
  List<IntraAccessGrantModel> _outgoing = [];
  bool _isLoading = false;
  String? _error;

  // ── Message thread state ──────────────────────────────────────────────────
  List<ConsultationMessageModel> _messages = [];
  bool _messagesLoading = false;
  String? _activeGrantId;
  Timer? _pollTimer;

  List<ConsultationMessageModel> get messages => _messages;
  bool get messagesLoading => _messagesLoading;

  List<IntraAccessGrantModel> get incoming => _incoming;
  List<IntraAccessGrantModel> get outgoing => _outgoing;
  bool get isLoading => _isLoading;
  String? get error => _error;

  int get pendingIncomingCount => _incoming.where((g) => g.isPending).length;

  // ── Grant list ────────────────────────────────────────────────────────────

  Future<void> loadGrants() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await repository.getGrants();
      _incoming = result.incoming;
      _outgoing = result.outgoing;
    } catch (e) {
      _error = _friendly(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<IntraAccessGrantModel?> create(Map<String, dynamic> data) async {
    _error = null;
    try {
      final grant = await repository.create(data);
      _outgoing = [grant, ..._outgoing];
      notifyListeners();
      return grant;
    } catch (e) {
      _error = _friendly(e);
      notifyListeners();
      return null;
    }
  }

  Future<bool> accept(String id) async {
    _error = null;
    try {
      final updated = await repository.accept(id);
      _replaceIncoming(updated);
      notifyListeners();
      return true;
    } catch (e) {
      _error = _friendly(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> decline(String id, String responseNote) async {
    _error = null;
    try {
      final updated = await repository.decline(id, responseNote);
      _replaceIncoming(updated);
      notifyListeners();
      return true;
    } catch (e) {
      _error = _friendly(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> complete(String id, String responseNote) async {
    _error = null;
    try {
      final updated = await repository.complete(id, responseNote);
      _replaceIncoming(updated);
      notifyListeners();
      return true;
    } catch (e) {
      _error = _friendly(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> cancel(String id) async {
    _error = null;
    try {
      await repository.cancel(id);
      _outgoing = _outgoing
          .map((g) => g.id == id ? _withStatus(g, 'cancelled') : g)
          .toList();
      notifyListeners();
      return true;
    } catch (e) {
      _error = _friendly(e);
      notifyListeners();
      return false;
    }
  }

  // ── Message thread polling ────────────────────────────────────────────────

  /// Start polling messages for an accepted grant.
  /// Call from IntraGrantDetailScreen.initState() when grant.isAccepted.
  void startMessagePolling(String grantId) {
    if (_activeGrantId == grantId && _pollTimer != null) return;
    _activeGrantId = grantId;
    _messages = [];
    _fetchMessages();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _pollTick(),
    );
  }

  /// Suspend polling — call on AppLifecycleState.paused.
  void pausePolling() => _pollTimer?.cancel();

  /// Resume polling — call on AppLifecycleState.resumed.
  void resumePolling() {
    if (_activeGrantId != null) {
      _pollTimer?.cancel();
      _pollTimer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => _pollTick(),
      );
    }
  }

  /// Stop polling entirely — call on dispose or when grant is no longer accepted.
  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _activeGrantId = null;
  }

  Future<ConsultationMessageModel?> sendMessage(String grantId, String body) async {
    try {
      final msg = await repository.sendMessage(grantId, body);
      _messages = [..._messages, msg];
      notifyListeners();
      return msg;
    } catch (e) {
      _error = _friendly(e);
      notifyListeners();
      return null;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }

  // ── Private ───────────────────────────────────────────────────────────────

  Future<void> _fetchMessages() async {
    if (_activeGrantId == null) return;
    _messagesLoading = true;
    notifyListeners();

    try {
      final msgs = await repository.getMessages(_activeGrantId!);
      _messages = msgs;

      // Check if grant is still accepted; if not, stop polling
      final grant = [..._incoming, ..._outgoing]
          .where((g) => g.id == _activeGrantId)
          .firstOrNull;
      if (grant != null && !grant.isAccepted) {
        stopPolling();
      }
    } catch (_) {
      // Polling errors are non-fatal — retry next tick
    } finally {
      _messagesLoading = false;
      notifyListeners();
    }
  }

  void _pollTick() => _fetchMessages();

  void _replaceIncoming(IntraAccessGrantModel updated) {
    _incoming = _incoming
        .map((g) => g.id == updated.id ? updated : g)
        .toList();
  }

  IntraAccessGrantModel _withStatus(IntraAccessGrantModel g, String status) {
    return IntraAccessGrantModel(
      id: g.id, status: status, patientId: g.patientId,
      patientName: g.patientName, patientMrn: g.patientMrn,
      grantedById: g.grantedById, grantedToId: g.grantedToId,
      accessLevel: g.accessLevel, question: g.question,
      response: g.response, respondedAt: g.respondedAt,
      expiresAt: g.expiresAt, createdAt: g.createdAt,
      isIncoming: g.isIncoming, rosterEntryId: g.rosterEntryId,
    );
  }

  String _friendly(Object e) {
    final s = e.toString();
    if (s.contains('403')) return 'You are not authorised to perform this action.';
    if (s.contains('422')) return s.replaceAll('Exception: ', '');
    if (s.contains('SocketException') || s.contains('Connection')) {
      return 'Cannot reach the server. Check your connection.';
    }
    return 'Something went wrong. Please try again.';
  }
}
