# Offline Sync UI — Design Spec

**Date:** 2026-05-16
**Scope:** Flutter mobile app (`healthcare_emr_mobile`)
**Backend:** `SyncController` endpoints are complete — this spec covers mobile only.

---

## Problem

The backend sync API (`/api/v1/sync/*`) is fully implemented but has no mobile surface. The app brief explicitly promises offline-first behaviour with automatic sync on reconnect. Currently, staff have no visibility into sync status, pending changes, or conflicts — and conflicts sit unresolved indefinitely.

---

## Decisions Made

| Question | Decision |
|---|---|
| Indicator placement | Dismissible banner between nav bar and screen body |
| Conflict layout | Narrative summary + smart suggestion (one-tap accept) |
| Sync trigger | Auto (connectivity restore + app foreground) + manual "Sync Now" |
| Architecture | SyncProvider + SyncBanner injected into both shells |

---

## Architecture

```
connectivity_plus (stream)
  + AppLifecycleListener (foreground event)
          │
          ▼
  SyncProvider (ChangeNotifier)
    - syncStatus: SyncStatus enum
    - pendingConflicts: int
    - pendingLocalChanges: int
    - lastSyncedAt: DateTime?
    - sync()
    - resolveConflict(id, strategy, mergedData)
          │
          ├── SyncBanner (widget — IOSShell + AndroidShell)
          │
          └── SyncScreen
                ├── Status card + "Sync Now" button
                └── ConflictCard list
                      └── ConflictDetailSheet (bottom sheet)
```

### Data Flow

1. `SyncProvider` subscribes to `connectivity_plus` stream on init. On reconnect → calls `sync()`.
2. `AppLifecycleListener` in `main.dart` calls `syncProvider.sync()` on `AppLifecycleState.resumed`.
3. Manual "Sync Now" tap calls `syncProvider.sync()` directly.
4. `sync()` sequence:
   - Registers device if `SyncClient` record not yet created (`POST /sync/register`)
   - Pushes any pending offline writes (`POST /sync/push`)
   - Pulls server changes since `lastSyncedAt` (`GET /sync/pull?since=…`)
   - Fetches conflict count (`GET /sync/conflicts`)
   - Updates `lastSyncedAt` on success

---

## New Files

| File | Purpose |
|---|---|
| `lib/data/repositories/sync_repository.dart` | All 5 sync API calls; returns typed results |
| `lib/data/providers/sync_provider.dart` | State: status, conflict count, pending changes; triggers sync |
| `lib/presentation/sync/screens/sync_screen.dart` | Status card + conflict list |
| `lib/presentation/sync/widgets/sync_banner.dart` | Four-state persistent banner |
| `lib/presentation/sync/widgets/conflict_card.dart` | Narrative summary card with Accept / Review buttons |
| `lib/presentation/sync/widgets/conflict_detail_sheet.dart` | Full-height draggable bottom sheet for manual resolution |
| `lib/core/sync/sync_diff_helper.dart` | Pure Dart: diffs client_data vs server_data, returns narrative string + suggested strategy |

## Modified Files

| File | Change |
|---|---|
| `lib/main.dart` | Add `SyncProvider` to provider tree; add `AppLifecycleListener` |
| `lib/presentation/shell/ios_shell.dart` | Inject `SyncBanner` between nav bar and body |
| `lib/presentation/shell/android_shell.dart` | Inject `SyncBanner` between nav bar and body |

---

## SyncStatus Enum

```dart
enum SyncStatus { idle, syncing, synced, offline, error }
```

---

## Banner States

| Status | Colour | Content | Dismissible | Auto-dismiss |
|---|---|---|---|---|
| `offline` | Amber | "No connection — changes saved locally" | No | No |
| `syncing` | Blue | "⟳ Syncing [n] changes…" + `CupertinoActivityIndicator` / `CircularProgressIndicator` | No | No |
| `synced` | Green | "✓ All changes synced" | Yes (✕) | 3 seconds |
| conflicts > 0 | Orange | "⚠ [n] conflict(s) need attention — Tap to review" | No | No |

**Banner rules:**
- `offline` and conflicts banners are persistent; cannot be dismissed until underlying state clears.
- When device reconnects, status transitions directly from `offline` → `syncing` with no gap.
- Sync completing with zero conflicts → `synced` → auto-dismiss after 3 seconds.
- Sync completing with conflicts → `syncStatus` returns to `idle`; the conflicts banner is driven by `pendingConflicts > 0`, not by `syncStatus`. These are independent state variables.
- "Sync Now" button appears inside the banner only when: `status == idle || status == error` AND device is online. Tapping calls `syncProvider.sync()`.
- Tapping anywhere on the conflicts banner navigates to `SyncScreen`.

---

## SyncScreen

### Status Card

Always visible at the top of `SyncScreen`.

- Last synced: relative timestamp (e.g. "2 minutes ago") or "Never"
- Pending local changes: count of offline writes not yet pushed
- "Sync Now" button — disabled while `status == syncing` OR `status == offline` (can't sync without a connection)

### Conflict List

One `ConflictCard` per pending conflict from `GET /sync/conflicts`.

Empty state: "No conflicts — all changes are in sync." shown when list is empty.

---

## ConflictCard

Displays a single conflict using the narrative pattern:

**Header:** Resource type + identifier
- e.g. "Prescription — Amoxicillin 500mg" or "Patient — Adaobi Nwosu"
- Resource identifier resolved by reading the `name` / `full_name` / `test_name` field from `server_data`

**Narrative body:** Generated by `SyncDiffHelper`
- e.g. *"You changed dosage to 750mg while offline. Dr Adeyemi updated the status to Filled on the server."*
- If only non-overlapping fields changed: *"No fields overlap — both changes can be kept."*

**Smart suggestion chip:**
- Non-overlapping fields → suggest `merged` → label: "Merge both changes"
- Same field changed on both sides → suggest `server_wins` → label: "Use server version (more recent)"
- Only client changed → suggest `client_wins` → label: "Keep your change"

**Action row:**
- **Accept** — calls `resolveConflict` with suggested strategy; removes card on success
- **Review manually** — opens `ConflictDetailSheet`

---

## ConflictDetailSheet

Full-height `DraggableScrollableSheet`. Shows all fields from `server_data` with client-changed fields highlighted.

**Resolution buttons (bottom):**
| Label | Strategy | Notes |
|---|---|---|
| Keep mine | `client_wins` | Applies `client_data` to server record |
| Use server | `server_wins` | No write — server state kept |
| Use server + keep my notes | `merged` | Pre-fills `merged_data` from server with client's free-text field overlaid (`notes` for appointments/lab_results, `special_instructions` for prescriptions). Button hidden if resource has no such field. |
| I'll type it | `manual` | Text field for `resolution_notes`; submits with `manual` strategy |

Confirm button submits; sheet dismisses on success and removes the card from the list.

---

## SyncDiffHelper

Pure Dart class. No Flutter dependencies — fully unit-testable.

```dart
class SyncDiffHelper {
  static SyncDiff diff({
    required Map<String, dynamic> clientData,
    required Map<String, dynamic> serverData,
    required String resourceType,
  });
}

class SyncDiff {
  final String narrative;         // human-readable summary
  final String suggestion;        // "Merge both changes" / "Use server version" / "Keep your change"
  final String strategy;          // 'merged' | 'server_wins' | 'client_wins'
  final Map<String, dynamic>? mergedData;  // pre-computed merge if strategy == 'merged'
  final List<String> changedByClient;
  final List<String> changedByServer;
  final List<String> overlappingFields;
}
```

Fields excluded from diff (internal / not user-facing): `id`, `version`, `created_at`, `updated_at`, `deleted_at`, `user_id`, `membership_id`.

---

## SyncRepository

Wraps all 5 backend endpoints. Stores `clientId` (a stable UUID generated once per device install, persisted in `SharedPreferences`) and `lastSyncedAt`.

```dart
Future<void> registerDevice()
Future<SyncPushResult> push(List<SyncChange> changes)
Future<SyncPullResult> pull({DateTime? since})
Future<List<SyncConflict>> getConflicts({int page = 1})
Future<SyncConflict> resolveConflict(String id, String strategy, {Map<String, dynamic>? mergedData, String? notes})
```

Pending local changes: for Phase 1, `pendingLocalChanges` is tracked as the count of records in a `pending_sync` SQLite table (new table in `LocalDatabase`). Write operations in `PatientRepository` and `ClinicalRepository` that succeed offline write a row here; `SyncRepository.push()` reads and clears these rows on success.

---

## Adaptive UI

| Element | iOS | Android |
|---|---|---|
| Loading indicator in banner | `CupertinoActivityIndicator` | `CircularProgressIndicator` (small) |
| Conflict detail sheet | `CupertinoActionSheet` for resolution options | `ModalBottomSheet` |
| Dismiss button | Standard `✕` icon | Standard `✕` icon |

Uses `kIsIOS` from `lib/core/platform.dart` — consistent with rest of app.

---

## Error Handling

- Push/pull failure: `syncStatus = error`; banner shows "Sync failed — Tap to retry" with "Retry" as the manual action.
- `UNREGISTERED_DEVICE` error from push: calls `registerDevice()` then retries push once.
- Conflict resolution failure: show `showAdaptiveToast` with error message; sheet stays open.
- All sync failures are non-fatal — offline data is never lost.

---

## Out of Scope

- Syncing the 6 newer clinical resources (vital signs, diagnoses, problems, procedures, immunizations, roster entries) — the backend `SyncController` only syncs `patients`, `appointments`, `prescriptions`, `lab_results`. Extending sync to the new resources is a backend task.
- Push notifications for sync events — requires FCM/APNs (separate work item).
- Conflict resolution for `delete` operations — backend marks these as completed automatically; surfacing them in the UI is deferred.
