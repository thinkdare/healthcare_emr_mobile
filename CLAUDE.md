# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Flutter mobile application for healthcare providers to manage Electronic Medical Records (EMR). Supports Android, iOS, Linux, macOS, and Windows.

## Commands

```bash
# Install dependencies
flutter pub get

# Run the app (development)
flutter run

# Run all tests
flutter test

# Run a single test file
flutter test test/widget_test.dart

# Static analysis / lint
flutter analyze

# Regenerate JSON serialization code (run after modifying @JsonSerializable models)
dart run build_runner build --delete-conflicting-outputs

# Build
flutter build apk        # Android
flutter build ios        # iOS
```

## Architecture

### Layer Structure

```
lib/
├── main.dart                    # Entry point: DI wiring + AuthWrapper
├── config/
│   ├── app_config.dart         # Base URLs, timeouts, type display maps
│   └── theme.dart              # Material Design 3 theme
├── core/
│   ├── api/api_client.dart     # Dio HTTP client with auth/tenant interceptors
│   └── database/local_database.dart  # SQLite singleton (sqflite)
├── data/
│   ├── models/                 # @JsonSerializable data classes
│   ├── repositories/           # One repo per domain; owns API + DB calls
│   └── providers/              # ChangeNotifier providers wrapping repositories
└── presentation/               # Screens + widgets, organized by feature
```

### Dependency Flow

`main.dart` constructs all infrastructure, repositories, and providers in one place — no service locator. All dependency injection happens at the top of `MyApp.build()`:

```
ApiClient + LocalDatabase → Repositories → ChangeNotifierProviders → Screens
```

Screens access state via `context.read<XProvider>()` (actions) and `Consumer<XProvider>` / `context.watch<XProvider>()` (reactive UI).

### Auth & Session Flow

1. `AuthWrapper` (in main.dart) listens to `AuthProvider.isAuthenticated` to decide between `LoginScreen` and `ProviderDashboardScreen`.
2. Login is two-step: email check (`/auth/check-email`) to discover facilities, then password login (`/auth/login`).
3. Optional 2FA challenge handled in `AuthProvider.verifyTwoFactor()`.
4. After login, if `AuthProvider.needsFacilitySelection` is true, the user picks an active facility before proceeding.
5. Token and active tenant ID are persisted in `FlutterSecureStorage`.

### Multi-Tenancy

Every API request to clinical routes gets an `X-Tenant-ID` header injected by `ApiClient`'s interceptor. The active tenant UUID is stored as `active_tenant_id` in secure storage and set via `AuthProvider.setActiveFacility()`.

### API Layer

`ApiClient` (Dio) handles:
- `Authorization: Bearer <token>` injection
- `X-Tenant-ID` injection for multi-tenant routes
- 401 → clears tokens and redirects to login
- All responses follow a `{success, message, data, meta}` envelope (Laravel backend)

Base URL is platform-aware in `lib/config/app_config.dart`:
- Android emulator: `http://10.0.3.2:8000/api/v1` (`10.0.3.2` is for Genymotion; use `10.0.2.2` for AVD)
- iOS/desktop: `http://localhost:8000/api/v1`

### Offline Caching (Phase 2)

`LocalDatabase` is a singleton SQLite database (`emr_cache.db`, WAL mode). Currently caches the `patients` table. Data is scoped per `provider_id` to support multiple providers on one device. Cache is plaintext (relies on OS-level encryption); full encryption planned for Phase 7.

### Navigation

No named routes or router package. Navigation is fully imperative using `Navigator.push()` / `Navigator.pushNamed()`. `AuthWrapper` is the root routing gate.

## Key Notes

- **JSON models require code gen**: After editing any class annotated with `@JsonSerializable`, run `dart run build_runner build --delete-conflicting-outputs` to regenerate `.g.dart` files.
- **Android emulator IP**: `10.0.3.2` is configured for Genymotion. Switch to `10.0.2.2` in `app_config.dart` for the standard Android emulator (AVD).
- **API contract**: `API_CONTRACT.md` at the repo root documents all 39 backend endpoints, request/response shapes, and error codes. Consult it before implementing new API calls.
- **Phase roadmap**: Current work is Phase 2 (offline SQLite caching). Phase 7 adds SQLCipher encryption and an offline write/sync queue. Do not assume full offline write support exists yet.
