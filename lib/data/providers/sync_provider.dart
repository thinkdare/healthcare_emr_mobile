// lib/data/providers/sync_provider.dart

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../models/sync_models.dart';
import '../repositories/sync_repository.dart';

class SyncProvider extends ChangeNotifier {
  final SyncRepository repository;

  SyncProvider({required this.repository}) {
    _subscribeToConnectivity();
  }

  // ── State ──────────────────────────────────────────────────────────────────

  SyncStatus _status = SyncStatus.idle;
  int _pendingConflicts = 0;
  int _pendingLocalChanges = 0;
  DateTime? _lastSyncedAt;
  List<SyncConflict> _conflicts = [];
  bool _deviceRegistered = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  // ── Getters ────────────────────────────────────────────────────────────────

  SyncStatus get status => _status;
  int get pendingConflicts => _pendingConflicts;
  int get pendingLocalChanges => _pendingLocalChanges;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  List<SyncConflict> get conflicts => _conflicts;
  bool get isOnline => _status != SyncStatus.offline;
  bool get hasPendingConflicts => _pendingConflicts > 0;

  // ── Connectivity ───────────────────────────────────────────────────────────

  void _subscribeToConnectivity() {
    _connectivitySub = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      final online = results.isNotEmpty &&
          results.any((r) => r != ConnectivityResult.none);
      if (!online) {
        _status = SyncStatus.offline;
        notifyListeners();
      } else if (_status == SyncStatus.offline) {
        // Came back online — trigger sync automatically
        sync();
      }
    });

    // Check initial connectivity state
    Connectivity().checkConnectivity().then((results) {
      final online = results.isNotEmpty &&
          results.any((r) => r != ConnectivityResult.none);
      if (!online) {
        _status = SyncStatus.offline;
        notifyListeners();
      }
    });
  }

  // ── Sync ───────────────────────────────────────────────────────────────────

  Future<void> sync() async {
    if (_status == SyncStatus.syncing) return;

    _pendingLocalChanges = await repository.getPendingCount();
    _status = SyncStatus.syncing;
    notifyListeners();

    try {
      if (!_deviceRegistered) {
        await repository.registerDevice();
        _deviceRegistered = true;
      }

      await repository.push();

      final since = await repository.getLastSyncedAt();
      await repository.pull(since: since);

      final now = DateTime.now();
      await repository.setLastSyncedAt(now);
      _lastSyncedAt = now;

      await _refreshConflicts();

      _pendingLocalChanges = await repository.getPendingCount();
      _status = SyncStatus.synced;
    } on Exception catch (e) {
      debugPrint('[SyncProvider] sync error: $e');
      _status = SyncStatus.error;
    }

    notifyListeners();
  }

  // ── Conflicts ─────────────────────────────────────────────────────────────

  Future<void> _refreshConflicts() async {
    try {
      _conflicts = await repository.getConflicts();
      _pendingConflicts = _conflicts.where((c) => c.isPending).length;
    } catch (_) {
      // Non-fatal — count stays at previous value
    }
  }

  Future<void> loadConflicts() async {
    await _refreshConflicts();
    notifyListeners();
  }

  Future<bool> resolveConflict(
    String id,
    String strategy, {
    Map<String, dynamic>? mergedData,
    String? notes,
  }) async {
    try {
      await repository.resolveConflict(id, strategy,
          mergedData: mergedData, notes: notes);
      _conflicts = _conflicts.where((c) => c.id != id).toList();
      _pendingConflicts = _conflicts.where((c) => c.isPending).length;
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Cleanup ────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }
}
