import 'package:flutter/foundation.dart';

import '../../core/localfirst/local_first_session.dart';
import '../../core/localfirst/local_store.dart';
import '../../core/localfirst/vitals_repository.dart';

/// UI state for vital signs, on the local-first path.
///
/// Reads come only from the local database. A save is committed locally (with
/// its outbox entry) before this returns; the sync engine takes it from there.
class VitalsLocalProvider extends ChangeNotifier {
  final LocalFirstSession session;

  String? _patientId;
  List<LocalVital> _items = [];
  List<OutboxEntry> _deadLetters = [];
  int _pending = 0;
  String? _error;

  VitalsLocalProvider(this.session) {
    // A finished sync round (or a user switch) may have changed what is stored.
    session.addListener(_refresh);
  }

  List<LocalVital> get items => _items;
  List<OutboxEntry> get deadLetters => _deadLetters;
  int get pendingCount => _pending;
  String? get error => _error;
  bool get available => session.isActive;
  String? get patientId => _patientId;

  Future<void> load(String patientId) async {
    _patientId = patientId;
    await _refresh();
  }

  Future<void> _refresh() async {
    final repo = session.vitals;
    final store = session.store;
    final patientId = _patientId;

    if (repo == null || store == null || patientId == null) {
      _items = [];
      _deadLetters = [];
      _pending = 0;
      notifyListeners();
      return;
    }

    _items = await repo.list(patientId);
    _deadLetters = (await store.deadLetters()).where((e) => e.patientId == patientId).toList();
    _pending = (await store.pending(limit: 1000)).where((e) => e.patientId == patientId).length;
    notifyListeners();
  }

  /// Saves a reading locally. Returns it, or null with [error] set.
  Future<LocalVital?> record(Map<String, dynamic> values) async {
    final repo = session.vitals;
    final patientId = _patientId;
    if (repo == null || patientId == null) {
      _error = 'Not ready: sign in first.';
      notifyListeners();
      return null;
    }

    try {
      _error = null;
      final saved = await repo.record(patientId: patientId, values: values);
      await _refresh();
      return saved;
    } on VitalsValidationException catch (e) {
      _error = e.errors.entries.map((x) => '${x.key.replaceAll('_', ' ')} ${x.value}').join('; ');
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
    return null;
  }

  Future<LocalVital?> amend(LocalVital original, Map<String, dynamic> corrections) async {
    final repo = session.vitals;
    if (repo == null) return null;

    try {
      _error = null;
      final saved = await repo.amend(original: original.vital, corrections: corrections);
      await _refresh();
      return saved;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Puts a retryable dead-lettered entry (e.g. access was granted since) back
  /// in the queue, with the same bytes.
  Future<void> retry(OutboxEntry entry) async {
    await session.store?.retryDeadLetter(entry.idempotencyKey);
    session.syncSoon();
    await _refresh();
  }

  @override
  void dispose() {
    session.removeListener(_refresh);
    super.dispose();
  }
}
