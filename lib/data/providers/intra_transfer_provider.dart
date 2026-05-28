import 'package:flutter/foundation.dart';
import '../models/intra_grant_models.dart';
import '../repositories/intra_transfer_repository.dart';

class IntraTransferProvider extends ChangeNotifier {
  final IntraTransferRepository repository;

  IntraTransferProvider({required this.repository});

  List<IntraTransferModel> _transfers = [];
  bool _isLoading = false;
  bool _isActing  = false; // loading state for accept/decline CTAs
  String? _error;

  List<IntraTransferModel> get transfers      => _transfers;
  List<IntraTransferModel> get pendingIncoming =>
      _transfers.where((t) => t.isPending && t.isIncoming).toList();
  bool get isLoading  => _isLoading;
  bool get isActing   => _isActing;
  String? get error   => _error;

  int get pendingIncomingCount => pendingIncoming.length;

  Future<void> load({String status = 'pending'}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _transfers = await repository.getTransfers(status: status);
    } catch (e) {
      _error = _friendly(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<IntraTransferModel?> create(String patientId, Map<String, dynamic> data) async {
    _error = null;
    try {
      final t = await repository.create(patientId, data);
      _transfers = [t, ..._transfers];
      notifyListeners();
      return t;
    } catch (e) {
      _error = _friendly(e);
      notifyListeners();
      return null;
    }
  }

  /// Confirmed (not optimistic) — returns true on 200, false on failure.
  Future<bool> accept(String id) async {
    _isActing = true;
    _error = null;
    notifyListeners();

    try {
      final updated = await repository.accept(id);
      _replace(updated);
      return true;
    } catch (e) {
      _error = _friendly(e);
      return false;
    } finally {
      _isActing = false;
      notifyListeners();
    }
  }

  Future<bool> decline(String id, {String? reason}) async {
    _isActing = true;
    _error = null;
    notifyListeners();

    try {
      final updated = await repository.decline(id, reason: reason);
      _replace(updated);
      return true;
    } catch (e) {
      _error = _friendly(e);
      return false;
    } finally {
      _isActing = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _replace(IntraTransferModel updated) {
    _transfers = _transfers.map((t) => t.id == updated.id ? updated : t).toList();
  }

  String _friendly(Object e) {
    final s = e.toString();
    if (s.contains('403')) return 'You are not the responsible provider for this patient.';
    if (s.contains('422')) return s.replaceAll('Exception: ', '');
    if (s.contains('SocketException') || s.contains('Connection')) {
      return 'Cannot reach the server. Check your connection.';
    }
    return 'Something went wrong. Please try again.';
  }
}
