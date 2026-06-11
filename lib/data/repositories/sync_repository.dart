// lib/data/repositories/sync_repository.dart

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../core/api/api_client.dart';
import '../../core/database/local_database.dart';
import '../models/clinical_models.dart';
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

  Future<void> pull({DateTime? since}) async {
    final params = <String, dynamic>{};
    if (since != null) params['since'] = since.toIso8601String();

    final response =
        await apiClient.get('/sync/pull', queryParameters: params);
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Pull failed');
    }

    final data = response['data'] as Map? ?? {};
    final resources = data['resources'] as Map? ?? {};

    await _applyPulledResources(resources);

    final serverTime = data['server_time'] as String?;
    if (serverTime != null) {
      await setLastSyncedAt(DateTime.parse(serverTime));
    }
  }

  Future<void> _applyPulledResources(Map<dynamic, dynamic> resources) async {
    // appointments
    final appointments = resources['appointments'] as List? ?? [];
    for (final item in appointments) {
      final m = Map<String, dynamic>.from(item as Map);
      if (m['deleted_at'] != null) {
        await _db.deleteAppointment(m['id'] as String);
      } else {
        final data = Map<String, dynamic>.from(m['data'] as Map);
        await _db.upsertAppointment(AppointmentModel.fromJson(data));
      }
    }

    // prescriptions
    final prescriptions = resources['prescriptions'] as List? ?? [];
    for (final item in prescriptions) {
      final m = Map<String, dynamic>.from(item as Map);
      if (m['deleted_at'] != null) {
        await _db.deletePrescription(m['id'] as String);
      } else {
        final data = Map<String, dynamic>.from(m['data'] as Map);
        await _db.upsertPrescription(PrescriptionModel.fromJson(data));
      }
    }

    // lab_results
    final labResults = resources['lab_results'] as List? ?? [];
    for (final item in labResults) {
      final m = Map<String, dynamic>.from(item as Map);
      if (m['deleted_at'] != null) {
        await _db.deleteLabResult(m['id'] as String);
      } else {
        final data = Map<String, dynamic>.from(m['data'] as Map);
        await _db.upsertLabResult(LabResultModel.fromJson(data));
      }
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
      'merged_data': ?mergedData,
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
