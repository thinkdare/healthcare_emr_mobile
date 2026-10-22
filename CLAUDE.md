# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Flutter app for point-of-care healthcare staff (nurses, ward staff, bedside clinicians) on the Healthcare EMR platform. It is the only client that stores clinical PHI offline. Back-office and desktop work happens in the Laravel web app (`../healthcare-emr`), which is always-online.

Status: development resumed on 2026-10-21 after a freeze. The decision and the work plan live in the backend repo:

- `../healthcare-emr/docs/adr/0001-point-of-care-flutter-back-office-livewire.md` (decision, local-first rule, order of work)
- `../healthcare-emr/docs/superpowers/specs/2026-10-21-offline-sync-contract.md` (the sync contract this app must implement)

Read both before changing anything in sync, storage or auth. Targets in the repo: Android, iOS and web shells, plus generated Linux, macOS and Windows runners (not a supported product surface).

## Current state versus the target (read this first)

**Vital signs are local-first** (first slice, `lib/core/localfirst/`). Every other module is still online-first with a queue bolted on. The local-first rules (ADR 0001):

1. Every clinical write goes to SQLCipher and the outbox in ONE local transaction. The network is never on the write path.
2. The UI reads only from the local database. A sync engine pushes the outbox and pulls changes.
3. Screens never call the API. `test/architecture/local_first_architecture_test.dart` enforces it, with a ratchet list of older screens that still import the API client (the list may only shrink).

Do not convert the next module (encounter notes, then prescriptions, patient lookup, handover) until vitals has passed the harness on real hardware (below). Do not add new modules on the old pattern.

### The local-first layer (`lib/core/localfirst/`)

| File | Role |
|---|---|
| `local_store.dart` | Per-user database (one file and one SQLCipher key per user): vitals, `outbox`, generic `records`, scope acks. Exact-bytes outbox. |
| `vitals_repository.dart` | The write path: validates at the bedside, writes reading + outbox entry in one transaction, amendments. No network imports. |
| `sync_engine.dart` | Push (exact stored bytes, dead-letter per entry, isolate a bad entry on a whole-request 422) then pull (cursor stored with the page, scope eviction with ack, keeps a patient while unsynced writes remain). |
| `sync_transport.dart` | The only file that imports the HTTP client. |
| `sync_coordinator.dart` | WHEN to sync: foreground, connectivity regained, after a write, a foreground timer, exponential backoff. |
| `offline_session_policy.dart` | 72h offline ceiling and logged break-glass continuation. |
| `local_first_session.dart` | Attaches the store, engine and coordinator to the signed-in user; wipes the store on sign-out only if nothing is unsynced. |

Entries are serialised once and the stored text is resent unchanged on every retry. The server hashes the RFC 8785 canonical form, so re-serialising would also work, but the client does not rely on that.

Not built yet, and required before any device goes to a real facility: device enrolment with Android Key Attestation / Play Integrity (iOS: App Attest), device-bound refresh tokens, sync telemetry and the unsynced-writes / silence alerts, remote wipe with quarantine upload, WorkManager as a background supplement, and a run of the harness on a physical mid-range Android device (ideally Transsion: Tecno, Infinix, itel). Background execution is not relied on: those phones kill it aggressively.

### The backend sync API is disabled

`/api/v1/sync/*` returns 404 unless the backend sets `SYNC_API_ENABLED=true`, and it always returns 404 in production. It was disabled on 2026-10-21 because it mass-assigned unvalidated payloads, allowed update and delete on append-only entities, and pulled the whole tenant. The existing `SyncRepository` (register, push, pull, conflicts, resolve) therefore fails against a default backend. For local work, enable the flag in the backend `.env`; expect the endpoints to change shape when the contract is implemented (cursor pull, insert-only push, payload-hashed idempotency, scoped pull). Do not build features that depend on the old pull semantics.

Backend rules that now apply to everything this app writes:

- `patient_id` and the author column (`recorded_by_id` and similar) cannot change once set, in the model layer and by database trigger. The author is set by the server from the authenticated user and any value the client sends is ignored.
- `version` may only advance by one.
- Vitals and encounter notes are append-only: corrections are new amendment rows, never edits.

## Commands

```bash
flutter pub get
flutter run
flutter test                       # needs libsqlite3.so, see "Running tests"
flutter test test/localfirst       # the local-first layer and fault-injection harness
flutter analyze

# Regenerate JSON serialisation code after editing any @JsonSerializable class
dart run build_runner build --delete-conflicting-outputs

flutter build apk
flutter build ios
```

Pass the API base URL for anything but local dev: `--dart-define=API_BASE_URL=https://...`. Non-debug builds throw a `StateError` at startup unless `API_BASE_URL` and `AUTH_BASE_URL` are provided and start with `https://` (this used to be an `assert()`, which Dart strips from release builds). TLS pinning needs `--dart-define=TLS_CERT_PEM_B64=<base64 pem>` (see `lib/core/network/tls_pinning.dart`); without it pinning is off.

### Running tests

Database tests use `sqflite_common_ffi`, which loads `libsqlite3.so`. Many Linux machines only have `libsqlite3.so.0`, so every database test fails to load until it is on the library path:

```bash
mkdir -p ~/.local/lib/sqlite && ln -sf /usr/lib/x86_64-linux-gnu/libsqlite3.so.0 ~/.local/lib/sqlite/libsqlite3.so
LD_LIBRARY_PATH=~/.local/lib/sqlite flutter test
```

Also, `.dart_tool/package_config.json` embeds absolute pub-cache paths; after a machine or username change run `flutter pub get` (it rewrites the tracked `pubspec.lock` and the generated plugin registrants, so commit those deliberately).

`test/localfirst/live_backend_test.dart` runs the real engine and Dio transport against a real local backend and is skipped unless `SYNC_LIVE_TOKEN` and `SYNC_LIVE_TENANT` are set (also pass `--dart-define=API_BASE_URL=http://127.0.0.1:8180/api/v1`; the backend needs `SYNC_API_ENABLED=true`, non-production, and its PHP containers restarted after code changes because of opcache preload).

The harness (`test/localfirst/fault_injection_test.dart`) maps case by case to section 11 of the sync contract and runs against an in-memory server that implements the contract (`support/fake_server.dart`). `contract_fixture_test.dart` writes the real client entries to the backend repo's `tests/Fixtures/flutter_outbox_entries.json`, which `SyncFlutterContractTest` pushes at the real API.

## Architecture

```
lib/
  main.dart                 DI wiring + auth gate
  config/                   app_config.dart (URLs, timeouts), theme.dart, app_colors.dart
  core/
    api/                    api_client.dart (Dio), api_error.dart
    biometric/              biometric service + provider (local_auth)
    database/               local_database.dart (SQLite/SQLCipher singleton)
    network/                tls_pinning.dart
    notifications/          push_notification_service.dart (FCM + local notifications)
    security/               root_detection_provider.dart
    sync/                   sync_diff_helper.dart (pure Dart conflict diffing)
    localfirst/             local-first layer (see above)
    platform.dart           platform detection and adaptive UI helpers
  data/
    models/                 domain models; a few have generated *.g.dart files
    repositories/           one per domain; owns API and DB calls
    providers/              ChangeNotifier providers wrapping repositories
  presentation/             screens and widgets by feature
    shell/                  android_shell, ios_shell, clinical_web_shell and the
                            org_admin_* shells (Material, Cupertino, web)
```

### Dependency flow

`main.dart` builds everything in one place, with no service locator: `ApiClient` + `LocalDatabase` to repositories to `ChangeNotifier` providers to screens. Screens use `context.read<XProvider>()` for actions and `Consumer`/`context.watch` for reactive UI. State management is `provider`.

### Models and code generation

Only some models are `@JsonSerializable` (three `.g.dart` files today: `models.g.dart`, `organization_models_enhanced.g.dart`, `patient_models.g.dart`). Most others are hand-written `fromJson`. Follow the style of the file you are editing. The plan is to generate models from the backend OpenAPI spec (Scramble); until then keep hand-written models in step with `API_CONTRACT.md` and `API_REFERENCE.md`.

### Auth and session

1. Login is multi-step: `/auth/check-email` (discover facilities), `/auth/login`, optional `/auth/2fa/verify`, then facility selection via `/auth/facility`.
2. The Sanctum bearer token and the active tenant ID are stored in `FlutterSecureStorage`.
3. `ApiClient` adds `Authorization: Bearer ...` and `X-Tenant-ID` (active facility UUID) to clinical routes. A 401 clears tokens and returns to login.
4. Responses use the envelope `{success, message, data, meta}`.
5. The backend added mandatory step-up verification on its unified web login in September 2026. Check whether the API login the app uses was affected before relying on the flow above.

Target hardening (not built yet, see the contract spec section 7): 15 minute access tokens with rotating refresh tokens bound to a hardware-backed device key, device enrolment with attestation, a 72 hour offline ceiling with a logged break-glass continuation, one encrypted database per user on shared tablets, and remote wipe with quarantine upload.

### Local storage

`LocalDatabase` is a singleton SQLite database (`emr_cache.db`, WAL mode). On Android and iOS it is SQLCipher-encrypted with a random 32-byte key kept in `flutter_secure_storage` (`db_encryption_key_v1`); an existing plaintext install is migrated on first open. Schema version is `_kVersion = 4`; bump it and add a block in `_onUpgrade` for any change.

Tables: `patients_cache` (per provider), `appointments_cache`, `prescriptions_cache`, `lab_results_cache` (`abnormal_flags` as JSON), `vitals_cache`, `diagnoses_cache`, `clinical_notes_cache` (all per patient), `pending_sync` (the write queue), `cache_metadata`.

### Sync

`SyncRepository.pull()` applies server resources to the cache and removes soft-deleted records. `SyncRepository.push()` sends `pending_sync` to `POST /sync/push`. Conflicts are surfaced in `ConflictCard` / `ConflictDetailSheet`, including delete-versus-update conflicts. All of this is subject to the backend rewrite described above, including per-entry dead-letter handling, schema-versioned entries, and sync telemetry.

### Navigation

No router package. Navigation is imperative (`Navigator.push` / `pushNamed`), and `AuthWrapper` is the root gate.

## Key notes

- **Dev API address:** the debug fallback in `app_config.dart` is `http://10.0.2.2:8180/api/v1` on Android (the stock AVD's alias for the host) and `http://localhost:8180/api/v1` elsewhere. 8180 is the backend's `NGINX_PORT`; if you changed it, or you use Genymotion (`10.0.3.2`) or a real device, pass `--dart-define=API_BASE_URL=...`. Non-debug builds require an explicit https URL.
- **Break-glass needs a second factor.** `TriggerEmergencyAccessScreen` calls `POST /emergency-access/authorize` when it opens (the backend emails a code, or says to use the authenticator for 2FA accounts) and sends the result as `authorization_code`.
- **Plan gating for staff** uses `GET /billing/organizations/{orgId}/plan` (`PlanSummaryModel`); the full subscription endpoint is admin-only and returns 403 for staff.
- **Password reset** opens the backend's web flow in an external browser (`authBaseUrl`); it is not an API call.
- **Docs in this repo:** `API_CONTRACT.md` and `API_REFERENCE.md` describe the backend API as of the original build and may be stale; the backend repo's `API_HANDOVER.md` is the more current reference. `SCREENS.md` lists screens.
- **Security features present:** biometric unlock (`local_auth`), jailbreak/root detection (`flutter_jailbreak_detection`), optional TLS pinning, SQLCipher at rest, FCM push.
