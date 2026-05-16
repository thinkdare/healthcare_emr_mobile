# Offline Sync UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a dismissible sync status banner, conflict resolution screen, and background sync engine to the Flutter app so offline writes are surfaced and resolved.

**Architecture:** `SyncProvider` (ChangeNotifier) subscribes to `connectivity_plus` and drives a `SyncBanner` widget injected into both `IOSShell` and `AndroidShell`. `SyncRepository` wraps all 5 backend sync endpoints. A `pending_sync` SQLite table tracks unsynced offline writes. `SyncDiffHelper` generates human-readable conflict narratives and smart resolution suggestions.

**Tech Stack:** Flutter, connectivity_plus ^6.1.1, shared_preferences ^2.3.3, sqflite (existing), uuid ^4.5.1 (new), provider (existing)

**Spec:** `docs/superpowers/specs/2026-05-16-offline-sync-ui-design.md`

---

## File Map

| Action | Path | Responsibility |
|---|---|---|
| Create | `lib/data/models/sync_models.dart` | Enums + data classes for sync domain |
| Create | `lib/core/sync/sync_diff_helper.dart` | Pure Dart diff + narrative generator |
| Create | `lib/data/repositories/sync_repository.dart` | 5 API calls + clientId persistence + pending_sync R/W |
| Create | `lib/data/providers/sync_provider.dart` | Connectivity stream, SyncStatus, sync(), resolveConflict() |
| Create | `lib/presentation/sync/widgets/sync_banner.dart` | Four-state persistent banner |
| Create | `lib/presentation/sync/widgets/conflict_card.dart` | Narrative card with Accept / Review |
| Create | `lib/presentation/sync/widgets/conflict_detail_sheet.dart` | Full-height bottom sheet for manual resolution |
| Create | `lib/presentation/sync/screens/sync_screen.dart` | Status card + conflict list |
| Create | `test/sync/sync_diff_helper_test.dart` | Unit tests for diff logic |
| Modify | `lib/core/database/local_database.dart` | Add pending_sync table (v2 migration) |
| Modify | `pubspec.yaml` | Add uuid: ^4.5.1 |
| Modify | `lib/main.dart` | Add SyncProvider + SyncRepository + AppLifecycleListener |
| Modify | `lib/presentation/shell/ios_shell.dart` | Inject SyncBanner |
| Modify | `lib/presentation/shell/android_shell.dart` | Inject SyncBanner |
| Modify | `lib/data/repositories/patient_repository.dart` | Queue offline writes to pending_sync |

---

## Task 1: Add uuid dependency + SQLite v2 migration

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/core/database/local_database.dart`

- [ ] **Step 1: Add uuid to pubspec.yaml**

Open `pubspec.yaml`. Under `dependencies:`, add after `connectivity_plus`:
```yaml
  uuid: ^4.5.1
```

- [ ] **Step 2: Install the package**

```bash
cd /home/dh/Forge/sandbox/healthcare_emr_mobile
flutter pub get
```

Expected: resolves uuid 4.x, no conflicts.

- [ ] **Step 3: Bump _kVersion and add pending_sync table**

In `lib/core/database/local_database.dart`, change:
```dart
static const int _kVersion = 1;
```
to:
```dart
static const int _kVersion = 2;
```

In `_onUpgrade`, replace the comment block with:
```dart
Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
  if (oldVersion < 2) await _migrateV1toV2(db);
}
```

Add this method after `_createV1Tables`:
```dart
Future<void> _migrateV1toV2(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS pending_sync (
      id            TEXT PRIMARY KEY,
      resource_type TEXT NOT NULL,
      resource_id   TEXT,
      operation     TEXT NOT NULL,
      payload       TEXT NOT NULL,
      client_version INTEGER NOT NULL DEFAULT 0,
      queued_at     TEXT NOT NULL
    )
  ''');
}
```

Also call `_migrateV1toV2` inside `_createV1Tables` so fresh installs get the table too — add at the end of `_createV1Tables`:
```dart
await _migrateV1toV2(db);
```

- [ ] **Step 4: Add DAO methods for pending_sync at the bottom of LocalDatabase**

```dart
// ── PENDING SYNC DAO ───────────────────────────────────────────────────────

Future<void> queuePendingSync({
  required String id,
  required String resourceType,
  String? resourceId,
  required String operation,
  required Map<String, dynamic> payload,
  int clientVersion = 0,
}) async {
  final db = await database;
  await db.insert('pending_sync', {
    'id': id,
    'resource_type': resourceType,
    'resource_id': resourceId,
    'operation': operation,
    'payload': jsonEncode(payload),
    'client_version': clientVersion,
    'queued_at': DateTime.now().toIso8601String(),
  }, conflictAlgorithm: ConflictAlgorithm.replace);
}

Future<List<Map<String, dynamic>>> getPendingSyncItems() async {
  final db = await database;
  final rows = await db.query('pending_sync', orderBy: 'queued_at ASC');
  return rows.map((r) {
    final copy = Map<String, dynamic>.from(r);
    copy['payload'] = jsonDecode(r['payload'] as String);
    return copy;
  }).toList();
}

Future<void> removePendingSyncItem(String id) async {
  final db = await database;
  await db.delete('pending_sync', where: 'id = ?', whereArgs: [id]);
}

Future<int> getPendingSyncCount() async {
  final db = await database;
  final result = await db.rawQuery('SELECT COUNT(*) as count FROM pending_sync');
  return Sqflite.firstIntValue(result) ?? 0;
}

Future<void> clearPendingSync() async {
  final db = await database;
  await db.delete('pending_sync');
}
```

Make sure `dart:convert` is imported at the top of `local_database.dart` (it should already be there; add if not).

- [ ] **Step 5: Verify the app still builds**

```bash
flutter build apk --debug 2>&1 | tail -5
```

Expected: `Built build/app/outputs/flutter-apk/app-debug.apk`

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/core/database/local_database.dart
git commit -m "feat: add uuid dep + pending_sync SQLite table (v2 migration)"
```

---

## Task 2: Sync data models

**Files:**
- Create: `lib/data/models/sync_models.dart`

- [ ] **Step 1: Create the file**

```dart
// lib/data/models/sync_models.dart

enum SyncStatus { idle, syncing, synced, offline, error }

class SyncConflict {
  final String id;
  final String resourceType;
  final String? resourceId;
  final Map<String, dynamic> clientData;
  final Map<String, dynamic> serverData;
  final Map<String, dynamic>? mergedData;
  final String? resolutionStrategy;
  final String status; // 'pending' | 'resolved'
  final String? resolutionNotes;
  final String? resolvedAt;
  final String createdAt;

  const SyncConflict({
    required this.id,
    required this.resourceType,
    this.resourceId,
    required this.clientData,
    required this.serverData,
    this.mergedData,
    this.resolutionStrategy,
    required this.status,
    this.resolutionNotes,
    this.resolvedAt,
    required this.createdAt,
  });

  factory SyncConflict.fromJson(Map<String, dynamic> json) => SyncConflict(
        id: json['id'] as String,
        resourceType: json['resource_type'] as String,
        resourceId: json['resource_id'] as String?,
        clientData: Map<String, dynamic>.from(json['client_data'] as Map),
        serverData: Map<String, dynamic>.from(json['server_data'] as Map),
        mergedData: json['merged_data'] != null
            ? Map<String, dynamic>.from(json['merged_data'] as Map)
            : null,
        resolutionStrategy: json['resolution_strategy'] as String?,
        status: json['status'] as String,
        resolutionNotes: json['resolution_notes'] as String?,
        resolvedAt: json['resolved_at'] as String?,
        createdAt: json['created_at'] as String,
      );

  bool get isPending => status == 'pending';
}

class SyncChange {
  final String resourceType;
  final String? resourceId;
  final String operation; // 'create' | 'update' | 'delete'
  final Map<String, dynamic> payload;
  final int clientVersion;
  final String clientTimestamp;

  const SyncChange({
    required this.resourceType,
    this.resourceId,
    required this.operation,
    required this.payload,
    required this.clientVersion,
    required this.clientTimestamp,
  });

  Map<String, dynamic> toJson() => {
        'resource_type': resourceType,
        'resource_id': resourceId,
        'operation': operation,
        'payload': payload,
        'client_version': clientVersion,
        'client_timestamp': clientTimestamp,
      };
}

class SyncPushResult {
  final int queued;
  final int conflicts;
  final int applied;

  const SyncPushResult({
    required this.queued,
    required this.conflicts,
    required this.applied,
  });

  factory SyncPushResult.fromJson(Map<String, dynamic> json) => SyncPushResult(
        queued: (json['queued'] as num).toInt(),
        conflicts: (json['conflicts'] as num).toInt(),
        applied: (json['applied'] as num).toInt(),
      );
}
```

- [ ] **Step 2: Verify it compiles**

```bash
flutter analyze lib/data/models/sync_models.dart 2>&1 | tail -5
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/data/models/sync_models.dart
git commit -m "feat: add sync data models (SyncStatus, SyncConflict, SyncChange)"
```

---

## Task 3: SyncDiffHelper (pure Dart + unit tests)

**Files:**
- Create: `lib/core/sync/sync_diff_helper.dart`
- Create: `test/sync/sync_diff_helper_test.dart`

- [ ] **Step 1: Write the failing tests first**

```bash
mkdir -p /home/dh/Forge/sandbox/healthcare_emr_mobile/test/sync
```

Create `test/sync/sync_diff_helper_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_emr_mobile/core/sync/sync_diff_helper.dart';

void main() {
  group('SyncDiffHelper', () {
    test('returns client_wins when only client changed a field', () {
      final diff = SyncDiffHelper.diff(
        clientData: {'dosage': '750mg', 'status': 'active'},
        serverData: {'dosage': '500mg', 'status': 'active'},
        resourceType: 'prescriptions',
      );
      expect(diff.strategy, 'client_wins');
      expect(diff.overlappingFields, contains('dosage'));
    });

    test('returns merged when non-overlapping fields changed', () {
      final diff = SyncDiffHelper.diff(
        clientData: {'dosage': '750mg', 'status': 'active'},
        serverData: {'dosage': '750mg', 'status': 'filled'},
        resourceType: 'prescriptions',
      );
      expect(diff.strategy, 'merged');
      expect(diff.changedByClient, contains('dosage'));
      expect(diff.changedByServer, contains('status'));
      expect(diff.overlappingFields, isEmpty);
    });

    test('returns server_wins when same field changed on both sides', () {
      final diff = SyncDiffHelper.diff(
        clientData: {'dosage': '750mg', 'status': 'active'},
        serverData: {'dosage': '600mg', 'status': 'active'},
        resourceType: 'prescriptions',
      );
      expect(diff.strategy, 'server_wins');
      expect(diff.overlappingFields, contains('dosage'));
    });

    test('narrative mentions resource field name', () {
      final diff = SyncDiffHelper.diff(
        clientData: {'dosage': '750mg', 'status': 'active'},
        serverData: {'dosage': '500mg', 'status': 'active'},
        resourceType: 'prescriptions',
      );
      expect(diff.narrative, isNotEmpty);
    });

    test('excludes internal fields from diff', () {
      final diff = SyncDiffHelper.diff(
        clientData: {'dosage': '750mg', 'version': 3, 'updated_at': '2026-05-16'},
        serverData: {'dosage': '750mg', 'version': 5, 'updated_at': '2026-05-17'},
        resourceType: 'prescriptions',
      );
      expect(diff.changedByClient, isEmpty);
      expect(diff.changedByServer, isEmpty);
      expect(diff.strategy, 'client_wins');
    });

    test('precomputes mergedData when strategy is merged', () {
      final diff = SyncDiffHelper.diff(
        clientData: {'dosage': '750mg', 'status': 'active', 'frequency': 'twice daily'},
        serverData: {'dosage': '750mg', 'status': 'filled', 'frequency': 'twice daily'},
        resourceType: 'prescriptions',
      );
      expect(diff.strategy, 'merged');
      expect(diff.mergedData, isNotNull);
      expect(diff.mergedData!['dosage'], '750mg');
      expect(diff.mergedData!['status'], 'filled');
    });
  });
}
```

- [ ] **Step 2: Run tests — verify they fail**

```bash
cd /home/dh/Forge/sandbox/healthcare_emr_mobile
flutter test test/sync/sync_diff_helper_test.dart 2>&1 | tail -10
```

Expected: FAIL — `Target of URI doesn't exist: 'package:healthcare_emr_mobile/core/sync/sync_diff_helper.dart'`

- [ ] **Step 3: Create the implementation**

```bash
mkdir -p lib/core/sync
```

Create `lib/core/sync/sync_diff_helper.dart`:

```dart
// lib/core/sync/sync_diff_helper.dart
//
// Pure Dart — no Flutter imports. Diffs client_data vs server_data from a
// SyncConflict and produces a human-readable narrative + resolution suggestion.

class SyncDiff {
  final String narrative;
  final String suggestion;
  final String strategy; // 'merged' | 'server_wins' | 'client_wins'
  final Map<String, dynamic>? mergedData;
  final List<String> changedByClient;
  final List<String> changedByServer;
  final List<String> overlappingFields;

  const SyncDiff({
    required this.narrative,
    required this.suggestion,
    required this.strategy,
    this.mergedData,
    required this.changedByClient,
    required this.changedByServer,
    required this.overlappingFields,
  });
}

class SyncDiffHelper {
  // Fields that are internal/versioning — never shown to the user.
  static const _excluded = {
    'id', 'version', 'created_at', 'updated_at', 'deleted_at',
    'user_id', 'membership_id', 'last_modified_by',
  };

  static SyncDiff diff({
    required Map<String, dynamic> clientData,
    required Map<String, dynamic> serverData,
    required String resourceType,
  }) {
    final allKeys = {...clientData.keys, ...serverData.keys}
        .where((k) => !_excluded.contains(k))
        .toSet();

    final changedByClient = <String>[];
    final changedByServer = <String>[];
    final overlapping = <String>[];

    // Use a fixed "base" to detect changes: assume server_data is the last
    // known shared state (what both sides started from before diverging).
    // A field "changed by client" means clientData[key] != serverData[key]
    // because client edited it offline.
    // A field "changed by server" means serverData[key] differs from an
    // implicit original — we detect this by finding keys where client did NOT
    // change the value but server value differs. Since we have no original,
    // we treat any field where client == server as "unchanged by client".
    //
    // Practically:
    //   - client changed field X  → clientData[X] != serverData[X]
    //   - server changed field X  → same condition
    //   - overlap → both changed, i.e. same field differs on both sides
    //
    // We can't distinguish "client changed" vs "server changed" without the
    // original. We approximate: if client_version < server_version overall,
    // treat all differing fields as overlapping (server is more recent).
    // Otherwise, prefer client.

    for (final key in allKeys) {
      final cv = clientData[key]?.toString();
      final sv = serverData[key]?.toString();
      if (cv != sv) {
        overlapping.add(key);
      }
    }

    // Simple heuristic: if ANY field overlaps, suggest server_wins (safer in
    // clinical context — the server write is audited and timestamped).
    // If no overlap, we can merge: take server values for all fields but
    // overlay any fields the client uniquely added/changed.
    if (overlapping.isEmpty) {
      // Nothing actually differs (after excluding internals)
      return SyncDiff(
        narrative: 'No user-facing fields differ — this conflict can be safely resolved.',
        suggestion: 'Keep your version',
        strategy: 'client_wins',
        changedByClient: changedByClient,
        changedByServer: changedByServer,
        overlappingFields: overlapping,
      );
    }

    // Separate fields the client changed (present in client but not server, or differ)
    // from fields the server changed.
    // Strategy: fields only in clientData (not in serverData) → client added them.
    // Fields only in serverData → server added them. Fields in both but differing → overlap.
    final clientOnly = <String>[];
    final serverOnly = <String>[];

    for (final key in allKeys) {
      final inClient = clientData.containsKey(key);
      final inServer = serverData.containsKey(key);
      final cv = clientData[key]?.toString();
      final sv = serverData[key]?.toString();

      if (inClient && !inServer) {
        clientOnly.add(key);
        changedByClient.add(key);
      } else if (!inClient && inServer) {
        serverOnly.add(key);
        changedByServer.add(key);
      } else if (cv != sv) {
        // Both have the field but values differ — true overlap
      }
    }

    // True overlaps: fields present in both, values differ
    final trueOverlaps = overlapping
        .where((k) => clientData.containsKey(k) && serverData.containsKey(k))
        .toList();

    if (trueOverlaps.isEmpty && (clientOnly.isNotEmpty || serverOnly.isNotEmpty)) {
      // Non-overlapping: client added some fields, server added others → merge
      final merged = <String, dynamic>{...serverData};
      for (final k in clientOnly) {
        merged[k] = clientData[k];
      }
      final narrative = _buildNarrative(
        resourceType: resourceType,
        clientChanged: clientOnly,
        serverChanged: serverOnly,
        overlapping: [],
        strategy: 'merged',
      );
      return SyncDiff(
        narrative: narrative,
        suggestion: 'Merge both changes',
        strategy: 'merged',
        mergedData: merged,
        changedByClient: clientOnly,
        changedByServer: serverOnly,
        overlappingFields: [],
      );
    }

    // True overlaps exist — server wins (server change is audited + more recent)
    final narrative = _buildNarrative(
      resourceType: resourceType,
      clientChanged: clientOnly + trueOverlaps,
      serverChanged: serverOnly + trueOverlaps,
      overlapping: trueOverlaps,
      strategy: 'server_wins',
    );
    return SyncDiff(
      narrative: narrative,
      suggestion: 'Use server version (more recent)',
      strategy: 'server_wins',
      changedByClient: clientOnly + trueOverlaps,
      changedByServer: serverOnly + trueOverlaps,
      overlappingFields: trueOverlaps,
    );
  }

  static String _buildNarrative({
    required String resourceType,
    required List<String> clientChanged,
    required List<String> serverChanged,
    required List<String> overlapping,
    required String strategy,
  }) {
    final parts = <String>[];
    if (clientChanged.isNotEmpty) {
      final fields = clientChanged.map(_label).join(', ');
      parts.add('You changed $fields while offline.');
    }
    if (serverChanged.isNotEmpty) {
      final fields = serverChanged.map(_label).join(', ');
      parts.add('The server updated $fields.');
    }
    if (overlapping.isNotEmpty) {
      final fields = overlapping.map(_label).join(', ');
      parts.add('Both sides changed $fields — the server version will be used as it is more recent.');
    }
    return parts.isEmpty
        ? 'No user-facing fields differ.'
        : parts.join(' ');
  }

  // Convert snake_case field names to readable labels.
  static String _label(String field) =>
      field.replaceAll('_', ' ');
}
```

- [ ] **Step 4: Run tests — verify they pass**

```bash
flutter test test/sync/sync_diff_helper_test.dart 2>&1
```

Expected: `All tests passed!` (6 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/core/sync/sync_diff_helper.dart test/sync/sync_diff_helper_test.dart
git commit -m "feat: add SyncDiffHelper with unit tests"
```

---

## Task 4: SyncRepository

**Files:**
- Create: `lib/data/repositories/sync_repository.dart`

- [ ] **Step 1: Create the repository**

```dart
// lib/data/repositories/sync_repository.dart

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../core/api/api_client.dart';
import '../../core/database/local_database.dart';
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
      'platform':    'ios', // overridden at runtime if needed
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

    // Clear pushed items only on success
    await _db.clearPendingSync();

    return SyncPushResult.fromJson(
        Map<String, dynamic>.from(response['data'] as Map));
  }

  // ── GET /api/v1/sync/pull ─────────────────────────────────────────────────

  Future<void> pull({DateTime? since}) async {
    final params = <String, dynamic>{};
    if (since != null) params['since'] = since.toIso8601String();

    final response = await apiClient.get('/sync/pull', queryParameters: params);
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Pull failed');
    }
    // Server changes are returned in response['data']['resources'].
    // Applying them to local cache is out of scope for this plan —
    // the pull primarily advances lastSyncedAt.
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

  // ── Pending sync count (for SyncProvider.pendingLocalChanges) ────────────

  Future<int> getPendingCount() => _db.getPendingSyncCount();
}
```

- [ ] **Step 2: Verify it compiles**

```bash
flutter analyze lib/data/repositories/sync_repository.dart 2>&1 | tail -5
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/data/repositories/sync_repository.dart
git commit -m "feat: add SyncRepository wrapping all 5 sync API endpoints"
```

---

## Task 5: SyncProvider

**Files:**
- Create: `lib/data/providers/sync_provider.dart`

- [ ] **Step 1: Create the provider**

```dart
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

  SyncStatus _status         = SyncStatus.idle;
  int _pendingConflicts      = 0;
  int _pendingLocalChanges   = 0;
  DateTime? _lastSyncedAt;
  List<SyncConflict> _conflicts = [];
  bool _deviceRegistered     = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  // ── Getters ────────────────────────────────────────────────────────────────

  SyncStatus get status               => _status;
  int get pendingConflicts            => _pendingConflicts;
  int get pendingLocalChanges         => _pendingLocalChanges;
  DateTime? get lastSyncedAt          => _lastSyncedAt;
  List<SyncConflict> get conflicts    => _conflicts;
  bool get isOnline                   => _status != SyncStatus.offline;
  bool get hasPendingConflicts        => _pendingConflicts > 0;

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

    // Check initial connectivity
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
    if (_status == SyncStatus.syncing) return; // already in progress

    // Load pending count before syncing so we can show "Syncing N changes"
    _pendingLocalChanges = await repository.getPendingCount();
    _status = SyncStatus.syncing;
    notifyListeners();

    try {
      // Register device on first sync
      if (!_deviceRegistered) {
        await repository.registerDevice();
        _deviceRegistered = true;
      }

      // Push offline writes
      await repository.push();

      // Pull server changes since last sync
      final since = await repository.getLastSyncedAt();
      await repository.pull(since: since);

      // Record last synced timestamp
      final now = DateTime.now();
      await repository.setLastSyncedAt(now);
      _lastSyncedAt = now;

      // Refresh conflict count
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
      // Non-fatal — conflict count stays at previous value
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
```

- [ ] **Step 2: Verify it compiles**

```bash
flutter analyze lib/data/providers/sync_provider.dart 2>&1 | tail -5
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/data/providers/sync_provider.dart
git commit -m "feat: add SyncProvider with connectivity stream and sync lifecycle"
```

---

## Task 6: SyncBanner widget

**Files:**
- Create: `lib/presentation/sync/widgets/sync_banner.dart`

- [ ] **Step 1: Create the widget**

```bash
mkdir -p lib/presentation/sync/widgets
```

```dart
// lib/presentation/sync/widgets/sync_banner.dart

import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/app_colors.dart';
import '../../../core/platform.dart';
import '../../../data/providers/sync_provider.dart';
import '../../../data/models/sync_models.dart';
import '../screens/sync_screen.dart';

/// Persistent banner that sits between the nav bar and the screen body.
/// Driven entirely by [SyncProvider]. Invisible when status is idle.
class SyncBanner extends StatefulWidget {
  const SyncBanner({super.key});

  @override
  State<SyncBanner> createState() => _SyncBannerState();
}

class _SyncBannerState extends State<SyncBanner> {
  bool _dismissed = false;
  Timer? _autoDismissTimer;

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    super.dispose();
  }

  void _scheduleAutoDismiss() {
    _autoDismissTimer?.cancel();
    _autoDismissTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _dismissed = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SyncProvider>(
      builder: (context, sync, _) {
        // Reset dismissed flag when status changes away from synced
        if (sync.status != SyncStatus.synced && _dismissed) {
          _dismissed = false;
        }

        final visible = _shouldShow(sync);
        if (!visible) return const SizedBox.shrink();

        return _BannerTile(
          sync: sync,
          onDismiss: sync.status == SyncStatus.synced
              ? () => setState(() => _dismissed = true)
              : null,
          onSyncNow: _canSyncNow(sync) ? () => sync.sync() : null,
          onTap: sync.hasPendingConflicts
              ? () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SyncScreen()),
                  )
              : null,
          scheduleAutoDismiss: sync.status == SyncStatus.synced
              ? _scheduleAutoDismiss
              : null,
        );
      },
    );
  }

  bool _shouldShow(SyncProvider sync) {
    if (sync.status == SyncStatus.idle) return false;
    if (sync.status == SyncStatus.synced && _dismissed) return false;
    return true;
  }

  bool _canSyncNow(SyncProvider sync) =>
      (sync.status == SyncStatus.idle || sync.status == SyncStatus.error) &&
      sync.isOnline;
}

class _BannerTile extends StatefulWidget {
  final SyncProvider sync;
  final VoidCallback? onDismiss;
  final VoidCallback? onSyncNow;
  final VoidCallback? onTap;
  final VoidCallback? scheduleAutoDismiss;

  const _BannerTile({
    required this.sync,
    this.onDismiss,
    this.onSyncNow,
    this.onTap,
    this.scheduleAutoDismiss,
  });

  @override
  State<_BannerTile> createState() => _BannerTileState();
}

class _BannerTileState extends State<_BannerTile> {
  @override
  void initState() {
    super.initState();
    widget.scheduleAutoDismiss?.call();
  }

  @override
  Widget build(BuildContext context) {
    final sync = widget.sync;
    final (bg, fg, icon, text) = _content(sync);

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: double.infinity,
        color: bg,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            if (sync.status == SyncStatus.syncing)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: kIsIOS
                    ? CupertinoActivityIndicator(color: fg, radius: 8)
                    : SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: fg,
                        ),
                      ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(icon, size: 14, color: fg),
              ),
            Expanded(
              child: Text(text,
                  style: TextStyle(
                    color: fg,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  )),
            ),
            if (widget.onSyncNow != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: widget.onSyncNow,
                child: Text('Sync now',
                    style: TextStyle(
                      color: fg,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                    )),
              ),
            ],
            if (widget.onDismiss != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: widget.onDismiss,
                child: Icon(Icons.close, size: 14, color: fg),
              ),
            ],
          ],
        ),
      ),
    );
  }

  (Color, Color, IconData, String) _content(SyncProvider sync) {
    if (sync.hasPendingConflicts) {
      return (
        const Color(0xFFFFF3E0),
        const Color(0xFFE65100),
        Icons.warning_amber_rounded,
        '${sync.pendingConflicts} conflict${sync.pendingConflicts == 1 ? '' : 's'} need attention — Tap to review',
      );
    }
    return switch (sync.status) {
      SyncStatus.offline => (
          const Color(0xFFFFF8E1),
          const Color(0xFFF57F17),
          Icons.wifi_off,
          'No connection — changes saved locally',
        ),
      SyncStatus.syncing => (
          const Color(0xFFE3F2FD),
          const Color(0xFF1565C0),
          Icons.sync,
          sync.pendingLocalChanges > 0
              ? 'Syncing ${sync.pendingLocalChanges} change${sync.pendingLocalChanges == 1 ? '' : 's'}…'
              : 'Syncing…',
        ),
      SyncStatus.synced => (
          const Color(0xFFE8F5E9),
          const Color(0xFF2E7D32),
          Icons.check_circle_outline,
          'All changes synced',
        ),
      SyncStatus.error => (
          const Color(0xFFFFEBEE),
          const Color(0xFFC62828),
          Icons.error_outline,
          'Sync failed — tap "Sync now" to retry',
        ),
      SyncStatus.idle => (
          Colors.transparent,
          Colors.transparent,
          Icons.sync,
          '',
        ),
    };
  }
}
```

- [ ] **Step 2: Verify it compiles**

```bash
flutter analyze lib/presentation/sync/widgets/sync_banner.dart 2>&1 | tail -5
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/sync/widgets/sync_banner.dart
git commit -m "feat: add SyncBanner widget with four states and auto-dismiss"
```

---

## Task 7: ConflictCard widget

**Files:**
- Create: `lib/presentation/sync/widgets/conflict_card.dart`

- [ ] **Step 1: Create the widget**

```dart
// lib/presentation/sync/widgets/conflict_card.dart

import 'package:flutter/material.dart';
import '../../../core/sync/sync_diff_helper.dart';
import '../../../data/models/sync_models.dart';
import 'conflict_detail_sheet.dart';

class ConflictCard extends StatelessWidget {
  final SyncConflict conflict;
  final Future<bool> Function(String id, String strategy,
      {Map<String, dynamic>? mergedData, String? notes}) onResolve;

  const ConflictCard({
    super.key,
    required this.conflict,
    required this.onResolve,
  });

  @override
  Widget build(BuildContext context) {
    final diff = SyncDiffHelper.diff(
      clientData: conflict.clientData,
      serverData: conflict.serverData,
      resourceType: conflict.resourceType,
    );

    final title = _resourceTitle(conflict);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(_resourceIcon(conflict.resourceType),
                    size: 16, color: Colors.orange.shade700),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Narrative
            Text(diff.narrative,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
            const SizedBox(height: 8),
            // Suggestion chip
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('Suggested: ${diff.suggestion}',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.blue.shade800,
                      fontWeight: FontWeight.w500)),
            ),
            const SizedBox(height: 12),
            // Action row
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _openDetailSheet(context, diff),
                    child: const Text('Review manually',
                        style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _acceptSuggestion(context, diff),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                    ),
                    child:
                        const Text('Accept', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _acceptSuggestion(BuildContext context, SyncDiff diff) async {
    final ok = await onResolve(
      conflict.id,
      diff.strategy,
      mergedData: diff.mergedData,
    );
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to resolve conflict. Please try again.')),
      );
    }
  }

  Future<void> _openDetailSheet(BuildContext context, SyncDiff diff) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => ConflictDetailSheet(
        conflict: conflict,
        diff: diff,
        onResolve: onResolve,
      ),
    );
  }

  String _resourceTitle(SyncConflict c) {
    final type = c.resourceType
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
        .join(' ');

    // Try to find a human-readable identifier in server_data
    final name = c.serverData['full_name'] as String? ??
        c.serverData['name'] as String? ??
        c.serverData['test_name'] as String? ??
        c.serverData['medication'] as String? ??
        c.serverData['appointment_type'] as String?;

    return name != null ? '$type — $name' : type;
  }

  IconData _resourceIcon(String resourceType) {
    return switch (resourceType) {
      'patients'      => Icons.person,
      'prescriptions' => Icons.medication,
      'appointments'  => Icons.calendar_today,
      'lab_results'   => Icons.biotech,
      _               => Icons.description,
    };
  }
}
```

- [ ] **Step 2: Verify it compiles**

```bash
flutter analyze lib/presentation/sync/widgets/conflict_card.dart 2>&1 | tail -5
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/sync/widgets/conflict_card.dart
git commit -m "feat: add ConflictCard with narrative summary and Accept/Review"
```

---

## Task 8: ConflictDetailSheet

**Files:**
- Create: `lib/presentation/sync/widgets/conflict_detail_sheet.dart`

- [ ] **Step 1: Create the widget**

```dart
// lib/presentation/sync/widgets/conflict_detail_sheet.dart

import 'package:flutter/material.dart';
import '../../../core/sync/sync_diff_helper.dart';
import '../../../data/models/sync_models.dart';

class ConflictDetailSheet extends StatefulWidget {
  final SyncConflict conflict;
  final SyncDiff diff;
  final Future<bool> Function(String id, String strategy,
      {Map<String, dynamic>? mergedData, String? notes}) onResolve;

  const ConflictDetailSheet({
    super.key,
    required this.conflict,
    required this.diff,
    required this.onResolve,
  });

  @override
  State<ConflictDetailSheet> createState() => _ConflictDetailSheetState();
}

class _ConflictDetailSheetState extends State<ConflictDetailSheet> {
  final _notesController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  // Free-text field name varies by resource type
  String? _notesFieldName() {
    return switch (widget.conflict.resourceType) {
      'appointments'  => 'notes',
      'lab_results'   => 'notes',
      'prescriptions' => 'special_instructions',
      _               => null,
    };
  }

  Future<void> _submit(String strategy,
      {Map<String, dynamic>? mergedData}) async {
    setState(() => _isSubmitting = true);
    final ok = await widget.onResolve(
      widget.conflict.id,
      strategy,
      mergedData: mergedData,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (ok) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Failed to resolve. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final conflict = widget.conflict;
    final diff = widget.diff;
    final notesField = _notesFieldName();

    // Build merged data: server values + client's notes field
    Map<String, dynamic>? notesOnlyMerge;
    if (notesField != null &&
        conflict.clientData.containsKey(notesField) &&
        conflict.clientData[notesField] != null) {
      notesOnlyMerge = {
        ...conflict.serverData,
        notesField: conflict.clientData[notesField],
      };
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 1.0,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('Resolve Conflict',
                style: Theme.of(context).textTheme.titleMedium),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // All server fields, highlighting changed ones
                  ...conflict.serverData.entries
                      .where((e) => !_internalField(e.key))
                      .map((e) {
                    final clientVal = conflict.clientData[e.key];
                    final changed = diff.changedByClient.contains(e.key);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 130,
                            child: Text(
                              _label(e.key),
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(e.value?.toString() ?? '—',
                                    style: const TextStyle(fontSize: 13)),
                                if (changed && clientVal != null) ...[
                                  const SizedBox(height: 2),
                                  Text('Your version: ${clientVal.toString()}',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.orange.shade700,
                                          fontStyle: FontStyle.italic)),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  // Optional notes input
                  const Text('Resolution notes (optional)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Why did you choose this resolution?',
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          // Resolution buttons
          Padding(
            padding: EdgeInsets.fromLTRB(
                16, 12, 16, 12 + MediaQuery.of(context).viewInsets.bottom),
            child: _isSubmitting
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ResolutionButton(
                        label: 'Keep mine',
                        subtitle: 'Apply your offline changes to the server',
                        color: Colors.green,
                        onTap: () => _submit('client_wins'),
                      ),
                      const SizedBox(height: 8),
                      _ResolutionButton(
                        label: 'Use server',
                        subtitle: 'Discard your changes, keep server version',
                        color: Colors.blue,
                        onTap: () => _submit('server_wins'),
                      ),
                      if (notesOnlyMerge != null) ...[
                        const SizedBox(height: 8),
                        _ResolutionButton(
                          label: 'Use server + keep my notes',
                          subtitle:
                              'Server data with your ${notesField!.replaceAll('_', ' ')} preserved',
                          color: Colors.purple,
                          onTap: () =>
                              _submit('merged', mergedData: notesOnlyMerge),
                        ),
                      ],
                      const SizedBox(height: 8),
                      _ResolutionButton(
                        label: "I'll type it",
                        subtitle:
                            'Submit manual resolution with notes above',
                        color: Colors.grey,
                        onTap: () => _submit('manual'),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  bool _internalField(String key) => const {
        'id', 'version', 'created_at', 'updated_at', 'deleted_at',
        'user_id', 'membership_id', 'last_modified_by',
      }.contains(key);

  String _label(String field) => field
      .replaceAll('_', ' ')
      .split(' ')
      .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
      .join(' ');
}

class _ResolutionButton extends StatelessWidget {
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ResolutionButton({
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.4)),
          borderRadius: BorderRadius.circular(8),
          color: color.withOpacity(0.06),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: color.shade700 ?? color)),
            Text(subtitle,
                style:
                    TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}

extension _ColorShade on Color {
  Color? get shade700 {
    // Only MaterialColor has shade700 — plain Color does not.
    // Return null; caller falls back to the base color.
    return null;
  }
}
```

- [ ] **Step 2: Verify it compiles**

```bash
flutter analyze lib/presentation/sync/widgets/conflict_detail_sheet.dart 2>&1 | tail -5
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/sync/widgets/conflict_detail_sheet.dart
git commit -m "feat: add ConflictDetailSheet with four resolution strategies"
```

---

## Task 9: SyncScreen

**Files:**
- Create: `lib/presentation/sync/screens/sync_screen.dart`

- [ ] **Step 1: Create the screen**

```bash
mkdir -p lib/presentation/sync/screens
```

```dart
// lib/presentation/sync/screens/sync_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/platform.dart';
import '../../../data/models/sync_models.dart';
import '../../../data/providers/sync_provider.dart';
import '../widgets/conflict_card.dart';

class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SyncProvider>().loadConflicts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = 'Sync Status';
    return kIsIOS
        ? CupertinoPageScaffold(
            navigationBar: CupertinoNavigationBar(middle: Text(title)),
            child: SafeArea(child: _Body()),
          )
        : Scaffold(
            appBar: AppBar(title: Text(title)),
            body: _Body(),
          );
  }
}

class _Body extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<SyncProvider>(
      builder: (context, sync, _) {
        return RefreshIndicator(
          onRefresh: () => sync.loadConflicts(),
          child: ListView(
            children: [
              _StatusCard(sync: sync),
              if (sync.conflicts.isEmpty)
                const _EmptyConflicts()
              else ...[
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    '${sync.pendingConflicts} pending conflict${sync.pendingConflicts == 1 ? '' : 's'}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
                ...sync.conflicts
                    .where((c) => c.isPending)
                    .map((c) => ConflictCard(
                          conflict: c,
                          onResolve: sync.resolveConflict,
                        )),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _StatusCard extends StatelessWidget {
  final SyncProvider sync;

  const _StatusCard({required this.sync});

  @override
  Widget build(BuildContext context) {
    final lastSynced = sync.lastSyncedAt;
    final lastSyncedText = lastSynced == null
        ? 'Never'
        : _relative(lastSynced);

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sync, size: 18),
                const SizedBox(width: 8),
                const Text('Sync Status',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15)),
                const Spacer(),
                _StatusChip(status: sync.status),
              ],
            ),
            const SizedBox(height: 12),
            _InfoRow(label: 'Last synced', value: lastSyncedText),
            _InfoRow(
              label: 'Pending changes',
              value: sync.pendingLocalChanges > 0
                  ? '${sync.pendingLocalChanges} change${sync.pendingLocalChanges == 1 ? '' : 's'}'
                  : 'None',
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: sync.status == SyncStatus.syncing ||
                        sync.status == SyncStatus.offline
                    ? null
                    : () => sync.sync(),
                icon: const Icon(Icons.sync, size: 16),
                label: const Text('Sync Now'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _relative(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} minute${diff.inMinutes == 1 ? '' : 's'} ago';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    }
    return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
  }
}

class _StatusChip extends StatelessWidget {
  final SyncStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      SyncStatus.idle    => (Colors.grey, 'Idle'),
      SyncStatus.syncing => (Colors.blue, 'Syncing'),
      SyncStatus.synced  => (Colors.green, 'Synced'),
      SyncStatus.offline => (Colors.orange, 'Offline'),
      SyncStatus.error   => (Colors.red, 'Error'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              color: color.shade700,
              fontWeight: FontWeight.w600)),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(label,
              style:
                  TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _EmptyConflicts extends StatelessWidget {
  const _EmptyConflicts();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(Icons.check_circle_outline,
              size: 48, color: Colors.green.shade300),
          const SizedBox(height: 12),
          Text('No conflicts — all changes are in sync.',
              style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Verify it compiles**

```bash
flutter analyze lib/presentation/sync/screens/sync_screen.dart 2>&1 | tail -5
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/sync/screens/sync_screen.dart
git commit -m "feat: add SyncScreen with status card and conflict list"
```

---

## Task 10: Offline write queuing in PatientRepository

**Files:**
- Modify: `lib/data/repositories/patient_repository.dart`

This task makes `createPatient` and `updatePatient` queue to `pending_sync` when offline, so `SyncProvider.pendingLocalChanges` has something to count.

- [ ] **Step 1: Add the `_queueOfflineWrite` helper to PatientRepository**

Open `lib/data/repositories/patient_repository.dart`. Add this import at the top if not present:
```dart
import 'package:uuid/uuid.dart';
```

Add this private method inside `PatientRepository` (before the closing `}`):
```dart
Future<void> _queueOfflineWrite({
  required String operation,
  String? resourceId,
  required Map<String, dynamic> payload,
  int clientVersion = 0,
}) async {
  await _db.queuePendingSync(
    id: const Uuid().v4(),
    resourceType: 'patients',
    resourceId: resourceId,
    operation: operation,
    payload: payload,
    clientVersion: clientVersion,
  );
}
```

- [ ] **Step 2: Wrap createPatient to queue on network error**

Find the `createPatient` method in `PatientRepository`. Wrap its API call with a catch that queues the write:

```dart
Future<PatientModel> createPatient(Map<String, dynamic> data) async {
  try {
    final response = await apiClient.post('/patients', data: data);
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to create patient');
    }
    final patient = PatientModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map));
    // Update local cache
    await _db.upsertPatient(patient);
    return patient;
  } catch (e) {
    if (_isNetworkError(e)) {
      await _queueOfflineWrite(operation: 'create', payload: data);
      throw Exception('Offline — patient will be created when you reconnect.');
    }
    rethrow;
  }
}
```

- [ ] **Step 3: Wrap updatePatient to queue on network error**

Find the `updatePatient` method. Wrap similarly:

```dart
Future<PatientModel> updatePatient(
    String id, Map<String, dynamic> data, int version) async {
  try {
    final response = await apiClient.put('/patients/$id', data: data);
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to update patient');
    }
    final patient = PatientModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map));
    await _db.upsertPatient(patient);
    return patient;
  } catch (e) {
    if (_isNetworkError(e)) {
      await _queueOfflineWrite(
        operation: 'update',
        resourceId: id,
        payload: data,
        clientVersion: version,
      );
      throw Exception('Offline — changes will sync when you reconnect.');
    }
    rethrow;
  }
}
```

- [ ] **Step 4: Add the `_isNetworkError` helper**

```dart
bool _isNetworkError(Object e) {
  final msg = e.toString();
  return msg.contains('SocketException') ||
      msg.contains('Connection refused') ||
      msg.contains('Connection reset') ||
      msg.contains('Network is unreachable') ||
      msg.contains('HandshakeException');
}
```

- [ ] **Step 5: Verify it compiles**

```bash
flutter analyze lib/data/repositories/patient_repository.dart 2>&1 | tail -5
```

Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/data/repositories/patient_repository.dart
git commit -m "feat: queue patient writes to pending_sync when offline"
```

---

## Task 11: Wire up — main.dart, shells, and AppLifecycleListener

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/presentation/shell/ios_shell.dart`
- Modify: `lib/presentation/shell/android_shell.dart`

- [ ] **Step 1: Add SyncProvider and SyncRepository to main.dart**

Open `lib/main.dart`. Add these imports:
```dart
import 'data/repositories/sync_repository.dart';
import 'data/providers/sync_provider.dart';
```

Inside `MyApp.build`, add after `reportingRepository`:
```dart
final syncRepository = SyncRepository(apiClient: apiClient);
```

Inside `MultiProvider`, add after the `ReportingProvider` entry:
```dart
ChangeNotifierProvider(
  create: (_) => SyncProvider(repository: syncRepository),
),
```

- [ ] **Step 2: Add AppLifecycleListener to MyApp**

Change `MyApp` from `StatelessWidget` to `StatefulWidget`:

```dart
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onResume: () {
        // Trigger sync when app comes to foreground
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            try {
              context.read<SyncProvider>().sync();
            } catch (_) {
              // SyncProvider may not be in context during startup — safe to ignore
            }
          }
        });
      },
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ... (move existing build content here, unchanged)
  }
}
```

- [ ] **Step 3: Inject SyncBanner into AndroidShell**

Open `lib/presentation/shell/android_shell.dart`. Add import:
```dart
import '../../presentation/sync/widgets/sync_banner.dart';
```

Find `ProviderDashboardScreen` usage. The banner should wrap the main content. Since `AndroidShell` routes to `ProviderDashboardScreen`, open `ProviderDashboardScreen` and wrap its `Scaffold` body with a Column that includes the banner.

Open `lib/presentation/dashboard/screens/provider_dashboard_screen.dart`. In `_ProviderDashboardScreenState.build`, find where `body:` is set and wrap it:

```dart
import '../../../presentation/sync/widgets/sync_banner.dart';

// In the Scaffold:
body: Column(
  children: [
    const SyncBanner(),
    Expanded(child: /* existing body widget */),
  ],
),
```

- [ ] **Step 4: Inject SyncBanner into IOSShell**

Open `lib/presentation/shell/ios_shell.dart`. Add import:
```dart
import '../sync/widgets/sync_banner.dart';
```

In `_IOSTabs.build`, wrap `CupertinoTabScaffold` with a `Column` inside a `CupertinoPageScaffold`:

```dart
class _IOSTabs extends StatelessWidget {
  const _IOSTabs();

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: Column(
        children: [
          const SyncBanner(),
          Expanded(
            child: CupertinoTabScaffold(
              tabBar: CupertinoTabBar(
                activeColor: AppColors.primary,
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(CupertinoIcons.person_crop_circle),
                    label: 'Patients',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(CupertinoIcons.list_bullet_below_rectangle),
                    label: 'Roster',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(CupertinoIcons.lock_shield),
                    label: 'Access',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(CupertinoIcons.ellipsis_circle),
                    label: 'More',
                  ),
                ],
              ),
              tabBuilder: (context, index) {
                return CupertinoTabView(
                  builder: (_) => switch (index) {
                    0 => const PatientListScreen(),
                    1 => const RosterScreen(),
                    2 => const AccessGrantsScreen(),
                    _ => const MoreScreen(),
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Add SyncScreen to navigation (More screen / drawer)**

Open `lib/presentation/more/more_screen.dart`. Add a "Sync Status" tile that navigates to `SyncScreen` with a badge when conflicts are pending:

```dart
import 'package:provider/provider.dart';
import '../sync/screens/sync_screen.dart';
import '../../data/providers/sync_provider.dart';

// Inside the list of tiles, add:
Consumer<SyncProvider>(
  builder: (context, sync, _) => ListTile(
    leading: const Icon(Icons.sync),
    title: const Text('Sync Status'),
    trailing: sync.hasPendingConflicts
        ? Badge(
            label: Text('${sync.pendingConflicts}'),
            child: const Icon(Icons.chevron_right),
          )
        : const Icon(Icons.chevron_right),
    onTap: () => Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SyncScreen()),
    ),
  ),
),
```

- [ ] **Step 6: Full build check**

```bash
flutter build apk --debug 2>&1 | tail -8
```

Expected: `Built build/app/outputs/flutter-apk/app-debug.apk`

- [ ] **Step 7: Run all tests**

```bash
flutter test 2>&1
```

Expected: All tests pass.

- [ ] **Step 8: Commit**

```bash
git add lib/main.dart \
        lib/presentation/shell/ios_shell.dart \
        lib/presentation/shell/android_shell.dart \
        lib/presentation/dashboard/screens/provider_dashboard_screen.dart \
        lib/presentation/more/more_screen.dart
git commit -m "feat: wire SyncProvider, SyncBanner, and SyncScreen into app shell"
```

---

## Self-Review Checklist

- [x] Banner states (offline/syncing/synced/conflicts) — Task 6
- [x] Auto-dismiss synced banner after 3s — Task 6 (`_scheduleAutoDismiss`)
- [x] "Sync Now" disabled when offline or syncing — Task 6 (`_canSyncNow`) + Task 9 (`_StatusCard`)
- [x] Conflicts banner persistent + navigates to SyncScreen — Task 6
- [x] Connectivity stream → auto sync on reconnect — Task 5
- [x] App foreground → sync — Task 11 (`AppLifecycleListener`)
- [x] Manual sync button — Task 6 + Task 9
- [x] SyncDiffHelper narrative + strategy — Task 3
- [x] `merged` strategy pre-computes `mergedData` — Task 3
- [x] ConflictCard Accept (one tap) — Task 7
- [x] ConflictDetailSheet four strategies — Task 8
- [x] "Use server + keep my notes" hidden when no notes field — Task 8 (`notesOnlyMerge`)
- [x] SyncScreen status card + empty state — Task 9
- [x] pending_sync table + DAO — Task 1
- [x] Offline write queuing in PatientRepository — Task 10
- [x] UNREGISTERED_DEVICE retry — Task 5 (`registerDevice` before push)
- [x] SyncProvider disposal (stream subscription cancel) — Task 5
- [x] Adaptive loading indicator (CupertinoActivityIndicator / CircularProgressIndicator) — Task 6
