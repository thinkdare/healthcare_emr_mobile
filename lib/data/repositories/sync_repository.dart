// lib/data/repositories/sync_repository.dart

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../core/api/api_client.dart';
import '../../core/database/local_database.dart';
import '../models/clinical_record_models.dart';
import '../models/patient_models.dart';
import '../models/sync_models.dart';

class SyncRepository {
  final ApiClient apiClient;
  final LocalDatabase _db;

  static const _prefClientId     = 'sync_client_id';
  static const _prefLastSyncedAt = 'sync_last_synced_at';

  SyncRepository({required this.apiClient, LocalDatabase? localDatabase})
      : _db = localDatabase ?? LocalDatabase.instance;

  // ── Client ID (stable UUID, generated once per install) ───────────────────

  Future<String> getOrCreateClientId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_prefClientId);
    if (existing != null) return existing;
    final newId = const Uuid().v4();
    await prefs.setString(_prefClientId, newId);
    return newId;
  }

  // ── Last synced timestamp ─────────────────────────────────────────────────

  Future<DateTime?> getLastSyncedAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefLastSyncedAt);
    return raw != null ? DateTime.tryParse(raw) : null;
  }

  Future<void> setLastSyncedAt(DateTime dt) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefLastSyncedAt, dt.toIso8601String());
  }

  // ── POST /api/v1/sync/register ────────────────────────────────────────────

  Future<void> registerDevice() async {
    final clientId = await getOrCreateClientId();
    await apiClient.post('/sync/register', data: {
      'client_id':   clientId,
      'device_type': 'mobile',
      'platform':    'ios',
      'app_version': '1.0.0',
    });
  }

  // ── POST /api/v1/sync/push ────────────────────────────────────────────────

  Future<SyncPushResult> push() async {
    final clientId = await getOrCreateClientId();
    final pending  = await _db.getPendingSyncItems();
    if (pending.isEmpty) {
      return const SyncPushResult(queued: 0, conflicts: 0, applied: 0);
    }

    final changes = pending.map((row) => SyncChange(
      resourceType:    row['resource_type'] as String,
      resourceId:      row['resource_id'] as String?,
      operation:       row['operation'] as String,
      payload:         Map<String, dynamic>.from(row['payload'] as Map),
      clientVersion:   row['client_version'] as int,
      clientTimestamp: row['queued_at'] as String,
    ).toJson()).toList();

    final response = await apiClient.post('/sync/push', data: {
      'client_id': clientId,
      'changes':   changes,
    });

    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Push failed');
    }

    await _db.clearPendingSync();

    return SyncPushResult.fromJson(
        Map<String, dynamic>.from(response['data'] as Map));
  }

  // ── GET /api/v1/sync/pull ─────────────────────────────────────────────────

  /// Applies pulled server changes to the local cache — scoped to patients,
  /// vitals, and diagnoses, the only resources with a local cache table.
  /// Everything else SyncController::pull() returns (appointments,
  /// prescriptions, lab_results, clinical_notes) is fetched straight from
  /// the API when needed and has no cache to apply into.
  Future<void> pull({DateTime? since}) async {
    final params = <String, dynamic>{};
    if (since != null) params['since'] = since.toIso8601String();

    final response =
        await apiClient.get('/sync/pull', queryParameters: params);
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Pull failed');
    }

    final data = Map<String, dynamic>.from(response['data'] as Map);
    final resources = Map<String, dynamic>.from(data['resources'] as Map? ?? {});

    await _applyPatients(resources['patients'] as List? ?? []);
    await _applyVitals(resources['vitals'] as List? ?? []);
    await _applyDiagnoses(resources['diagnoses'] as List? ?? []);
  }

  Future<void> _applyPatients(List entries) async {
    for (final entry in entries) {
      final row = Map<String, dynamic>.from(entry as Map);
      final recordData = Map<String, dynamic>.from(row['data'] as Map);
      if (row['deleted_at'] != null) {
        await _db.markPatientInactive(row['id'] as String);
        continue;
      }
      await _db.upsertPatient(PatientModel.fromJson(recordData));
    }
  }

  Future<void> _applyVitals(List entries) async {
    for (final entry in entries) {
      final row = Map<String, dynamic>.from(entry as Map);
      if (row['deleted_at'] != null) {
        await _db.deleteVitalFromCache(row['id'] as String);
        continue;
      }
      final recordData = Map<String, dynamic>.from(row['data'] as Map);
      await _db.upsertVital(VitalSignModel.fromJson(recordData));
    }
  }

  Future<void> _applyDiagnoses(List entries) async {
    for (final entry in entries) {
      final row = Map<String, dynamic>.from(entry as Map);
      if (row['deleted_at'] != null) {
        await _db.deleteDiagnosisFromCache(row['id'] as String);
        continue;
      }
      final recordData = Map<String, dynamic>.from(row['data'] as Map);
      await _db.upsertDiagnosis(DiagnosisModel.fromJson(recordData));
    }
  }

  // ── GET /api/v1/sync/conflicts ────────────────────────────────────────────

  Future<List<SyncConflict>> getConflicts({int page = 1}) async {
    final response = await apiClient.get(
      '/sync/conflicts',
      queryParameters: {'page': page},
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to load conflicts');
    }
    final raw = response['data'] as List? ?? [];
    return raw
        .map((e) => SyncConflict.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  // ── POST /api/v1/sync/conflicts/{id}/resolve ──────────────────────────────

  Future<SyncConflict> resolveConflict(
    String id,
    String strategy, {
    Map<String, dynamic>? mergedData,
    String? notes,
  }) async {
    final response = await apiClient.post('/sync/conflicts/$id/resolve', data: {
      'resolution_strategy': strategy,
      if (mergedData != null) 'merged_data': mergedData,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to resolve conflict');
    }
    return SyncConflict.fromJson(
        Map<String, dynamic>.from(response['data'] as Map));
  }

  // ── Pending count ─────────────────────────────────────────────────────────

  Future<int> getPendingCount() => _db.getPendingSyncCount();
}
