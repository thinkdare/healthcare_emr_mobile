# Org Admin Views — Design Spec

**Date:** 2026-05-24  
**Status:** Approved (revised after security review)

---

## Overview

Adds a dedicated Admin section to the app's navigation, visible only to org admins. Covers five deliverables: admin navigation injection, a new Organization Profile screen, a new Staff Management screen, a rewritten Invite Staff screen, and wiring the existing Facilities screens into navigation.

---

## 1. Access Gate

All admin UI is gated on `auth.isOrgAdmin` — a new convenience getter added to `AuthProvider`:

```dart
bool get isOrgAdmin => _currentUser?.isOrgAdmin ?? false;
```

`UserModel.isOrgAdmin` already exists (`userType == 'org_admin'`). `UserModel.userType` is populated from the `user_type` field in `GET /auth/me`. The backend enforces org-admin access on `PUT /organizations/{id}` and `DELETE /staff/memberships/{id}` at the controller level — the client gate is a UX decision only, not a security control.

**Why not `staffType == 'admin'`:** `staff_type` is a `TenantStaffMembership` field for clinical role categorisation. Backend admin enforcement uses `User.user_type === 'org_admin'`, which is unrelated. Gating on `staffType` would show admin UI to the wrong users.

---

## 2. Navigation — Admin Section

A flat "Admin" section is injected into both navigation surfaces, between the existing Clinical and Account groups. Rendered only when `auth.isOrgAdmin` is true — not rendered at all for non-admins.

### Android — `ProviderDashboardScreen` drawer

```
[section header] Admin
  Organization   → OrganizationProfileScreen
  Facilities     → FacilitiesListScreen
  Staff          → StaffManagementScreen
  Invite Staff   → ProviderInvitationScreen
```

### iOS — `MoreScreen`

`CupertinoListSection.insetGrouped` with header `"Admin"` (orange accent), same four destinations via `CupertinoPageRoute`.

All four entries navigate via `Navigator.push` — no new named routes required.

---

## 3. Organization Profile Screen

**File:** `lib/presentation/organization/screens/organization_profile_screen.dart`  
**APIs:** `GET /organizations/{id}` + `GET /organizations/{id}/stats` (parallel on load), `PUT /organizations/{id}`  
**Backend auth:** Enforced — controller returns 403 for non-org-admins.

### View mode

- **Gradient header card** — org name, type badge, subscription status, and a 3-column stats row (Facilities / Staff / Patients from the stats endpoint).
- **Organization Details card** — name, type, address, phone, email, tax ID (read-only rows).
- **Billing card** — billing email, billing address (read-only rows).
- Pencil icon in app bar toggles edit mode.

### Edit mode

- App bar shows Cancel (reverts controllers) and Save (calls `PUT /organizations/{id}`).
- Stats header remains read-only.
- All detail and billing fields become editable `TextFormField`s, with a type dropdown (values: `hospital`, `clinic`, `pharmacy`, `laboratory`, `diagnostic_center`, `hospital_group`, `other`).
- Required fields: name, type, address.

### Error & degraded-state contract

Both API calls are fired in parallel via `Future.wait`. Failure cases:

| Scenario | Behaviour |
|---|---|
| `/organizations/{id}` fails | Full-screen error with retry button. Edit mode blocked. |
| `/stats` fails but org data succeeds | Stats row shows `—` placeholders with a subtle warning icon. Edit mode remains accessible — stats failure does not block the core CRUD flow. |
| Both fail | Full-screen error with retry. |

Stats failures are non-blocking by design: the stats endpoint is a heavier aggregation query and is the more likely of the two to be slow or flaky.

### State

`StatefulWidget` with constructor-injected `OrganizationRepository`:

```dart
class OrganizationProfileScreen extends StatefulWidget {
  final OrganizationRepository repository;
  const OrganizationProfileScreen({required this.repository, super.key});
}
```

Caller (drawer / More tab) constructs the repository before pushing:
```dart
OrganizationProfileScreen(
  repository: OrganizationRepository(apiClient: context.read<ApiClient>()),
)
```

This keeps a DI seam for testing without requiring a root-level provider for a single-use screen.

### Repository & model additions

`OrganizationRepository` gets three new methods:
- `getOrganization(String id)` → `GET /organizations/{id}`, returns `OrganizationEnhancedModel`
- `getOrgStats(String id)` → `GET /organizations/{id}/stats`, returns `OrgStatsModel`
- `updateOrganization(String id, Map<String, dynamic> data)` → `PUT /organizations/{id}`, returns `OrganizationEnhancedModel`

New `OrgStatsModel` (add to `organization_models_enhanced.dart`):
```dart
@JsonSerializable()
class OrgStatsModel {
  @JsonKey(name: 'total_facilities') final int totalFacilities;
  @JsonKey(name: 'total_staff')      final int totalStaff;
  @JsonKey(name: 'total_patients')   final int totalPatients;
  @JsonKey(name: 'active_subscriptions') final int activeSubscriptions;
}
```

---

## 4. Staff Management Screen

**File:** `lib/presentation/staff/screens/staff_management_screen.dart`  
**APIs:** `GET /staff/memberships`, `GET /clinical-ranks`, `PUT /staff/memberships/{id}`, `DELETE /staff/memberships/{id}`  
**Backend auth:** `PUT` and `DELETE` enforced — 403 for non-org-admins.

> **⛔ Build blocker — endpoint contract unconfirmed.**  
> `GET /staff/memberships` is documented as "current user's memberships across all facilities." Backend investigation confirms it returns only the calling user's own memberships for regular staff; org admins receive memberships across their org (not scoped to the active tenant). This does not match the "all staff at the active facility" data shape this screen requires. A dedicated endpoint (`GET /tenants/{id}/staff` or equivalent) may be needed. **Build this screen last, after the endpoint contract is confirmed with the backend team.**

### List view

- App bar: "Staff" title + search icon (min 2 chars, client-side filter).
- **Staff type filter chips** (horizontal scroll): All / Doctor / Nurse / Pharmacist / Lab Tech / Radiologist / Physiotherapist / Dentist / Admin / Other.
- **Status filter:** Active / Inactive / All.
- All filtering is client-side.
- **Staff card:** avatar (initials, coloured by staff type), name, clinical rank name, active/inactive badge, capability chips (`Rx`, `Labs`, `Emergency`). Inactive cards at reduced opacity.

### Edit bottom sheet

`showModalBottomSheet` (drag handle). Constructor-injected `StaffRepository`.

- Read-only header: avatar, name, email.
- Staff Type dropdown.
- Clinical Rank selector — same rank cards as invite screen (loaded once, cached in sheet state).
- Active toggle — subtitle: "Inactive staff can no longer log in".
- **Save Changes** → `PUT /staff/memberships/{id}` with `{ staff_type, clinical_rank_id, is_active }`.
- **Remove from Facility** (destructive) → confirmation dialog → `DELETE /staff/memberships/{id}`. Requires a reason field (min 10 chars, matching backend validation).

### Repository

New `StaffRepository` (`lib/data/repositories/staff_repository.dart`), constructor-injected. Methods: `getStaffMemberships()`, `updateMembership(id, data)`, `deleteMembership(id)`.

---

## 5. Invite Staff Screen (rewrite)

**File:** `lib/presentation/providers/screens/provider_invitation_screen.dart`  
**API:** `POST /staff/invite` (requires `X-Tenant-ID`), `GET /clinical-ranks`

> **⚠️ Backend security gap — must be fixed before this screen ships.**  
> `POST /staff/invite` has no role check in the controller. Any authenticated staff member with a facility membership can call it directly. `TenantContext` middleware only switches the DB connection — it does not enforce admin-only access. A fix is needed in `StaffRegistrationController::invite()` before the invite endpoint is safe to expose via the app.

### What is removed

First name, last name, phone, license number, specialization, facility dropdown, emergency access toggle — the backend does not accept these fields.

### New form

- **Active facility banner** (read-only) — "Inviting to: [facility name]".
- **Email** — required.
- **Staff Type** — dropdown (valid values: `doctor`, `nurse`, `pharmacist`, `lab_tech`, `radiologist`, `physiotherapist`, `dentist`, `admin`, `other`).
- **Clinical Rank** — selectable card list. Each card shows rank name, hierarchy level, and capability chips (`Can Prescribe`, `Can Order Labs`, `Emergency Access`). Selected card gets a blue border + checkmark. Loaded from `GET /clinical-ranks` on `initState`.
- **Send Invitation** → `POST /staff/invite` with `{ email, staff_type, clinical_rank_id }`.

### On success

Snackbar: "Invitation sent to [email]". Form resets.

---

## 6. Facilities List & Form — Navigation Wiring

**Screens:** `FacilitiesListScreen`, `FacilityFormScreen` — no changes to the screens themselves.

Drawer entry:
```dart
Navigator.push(context, MaterialPageRoute(builder: (_) => const FacilitiesListScreen()))
```

More tab entry: same, `CupertinoPageRoute`.

Internal named routes (`/facilities/add`, `/facilities/edit`) continue as-is.

---

## Build Order

| Step | Deliverable | Rationale |
|---|---|---|
| 1 | Navigation wiring (Facilities) | Zero risk — no new code, no new API calls |
| 2 | Invite Staff rewrite | Self-contained, API contract confirmed (pending backend security fix) |
| 3 | Organization Profile | After confirming backend 403 enforcement (confirmed ✓) |
| 4 | Staff Management | Only after `GET /staff/memberships` contract is confirmed with backend |

---

## File Inventory

| Action | File |
|---|---|
| Edit | `lib/data/providers/auth_provider.dart` (add `isOrgAdmin` getter) |
| Edit | `lib/presentation/dashboard/screens/provider_dashboard_screen.dart` |
| Edit | `lib/presentation/more/more_screen.dart` |
| Edit | `lib/data/repositories/organization_repository.dart` |
| Edit | `lib/data/models/organization_models_enhanced.dart` (add `OrgStatsModel`) |
| **New** | `lib/data/repositories/staff_repository.dart` |
| **New** | `lib/presentation/organization/screens/organization_profile_screen.dart` |
| **New** | `lib/presentation/staff/screens/staff_management_screen.dart` |
| Edit (rewrite) | `lib/presentation/providers/screens/provider_invitation_screen.dart` |
| No change | `lib/presentation/facilities/screens/facilities_list_screen.dart` |
| No change | `lib/presentation/facilities/screens/facility_form_screen.dart` |

---

## Out of Scope

- Staff invitation acceptance / registration flow (web-portal-only).
- Organization creation (super-admin only, web admin panel).
- Billing/subscription admin views (already built, accessible to all staff).
