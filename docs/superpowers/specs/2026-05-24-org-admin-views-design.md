# Org Admin Views — Design Spec

**Date:** 2026-05-24  
**Status:** Approved

---

## Overview

Adds a dedicated Admin section to the app's navigation, visible only to staff with `staff_type == 'admin'`. Covers five deliverables: admin navigation injection, a new Organization Profile screen, a new Staff Management screen, a rewritten Invite Staff screen, and wiring the existing Facilities screens into navigation.

---

## 1. Access Gate

All admin UI is gated on `auth.staffType == 'admin'` (already exposed by `AuthProvider`). Non-admin users see no Admin section — it is not rendered, not greyed out.

---

## 2. Navigation — Admin Section (Enhanced approach B)

A flat "Admin" section is injected into both navigation surfaces, between the existing Clinical and Account groups.

### Android — `ProviderDashboardScreen` drawer

Add an `if (auth.staffType == 'admin')` block:

```
[section header] Admin
  Organization   → OrganizationProfileScreen
  Facilities     → FacilitiesListScreen
  Staff          → StaffManagementScreen
  Invite Staff   → ProviderInvitationScreen
```

### iOS — `MoreScreen`

Add a `CupertinoListSection.insetGrouped` with header `"Admin"` (orange accent colour to distinguish from other sections), containing the same four destinations via `CupertinoPageRoute`.

All four admin entries navigate via `Navigator.push` — no new named routes required.

---

## 3. Organization Profile Screen

**File:** `lib/presentation/organization/screens/organization_profile_screen.dart`  
**APIs:** `GET /organizations/{id}` + `GET /organizations/{id}/stats` (parallel on load), `PUT /organizations/{id}`

### View mode

- **Gradient header card** — org name, type badge, subscription status, and a 3-column stats row (Facilities / Staff / Patients counts from the stats endpoint).
- **Organization Details card** — name, type, address, phone, email, tax ID (read-only rows).
- **Billing card** — billing email, billing address (read-only rows).
- Pencil icon in app bar toggles edit mode.

### Edit mode

- App bar shows Cancel (reverts controllers) and Save (calls `PUT /organizations/{id}`).
- Stats header remains read-only.
- All detail and billing fields become editable `TextFormField`s, with a type dropdown (values: `hospital`, `clinic`, `pharmacy`, `laboratory`, `diagnostic_center`, `hospital_group`, `other`).
- Required fields: name, type, address.

### State

`StatefulWidget` — manages its own loading, org data, stats data, and `_isEditing` bool. No new provider needed (single-use screen not shared across the app).

### Repository & model additions

`OrganizationRepository` (edit existing file) gets three new methods:
- `getOrganization(String id)` — `GET /organizations/{id}`, returns `OrganizationEnhancedModel`
- `getOrgStats(String id)` — `GET /organizations/{id}/stats`, returns `OrgStatsModel`
- `updateOrganization(String id, Map<String, dynamic> data)` — `PUT /organizations/{id}`, returns `OrganizationEnhancedModel`

New `OrgStatsModel` (add to `organization_models_enhanced.dart`):
```dart
class OrgStatsModel {
  final int totalFacilities;
  final int totalStaff;
  final int totalPatients;
  final int activeSubscriptions;
}
```
Stats come from `GET /organizations/{id}/stats` response: `total_facilities`, `total_staff`, `total_patients`, `active_subscriptions`.

`OrganizationProfileScreen` constructs `OrganizationRepository` inline via `context.read<ApiClient>()` — same pattern as `FacilitiesListScreen`. No changes to `OrganizationProvider`.

---

## 4. Staff Management Screen

**File:** `lib/presentation/staff/screens/staff_management_screen.dart`  
**APIs:** `GET /staff/memberships` (with `X-Tenant-ID`), `GET /clinical-ranks`, `PUT /staff/memberships/{id}`, `DELETE /staff/memberships/{id}`

New `StaffRepository` (`lib/data/repositories/staff_repository.dart`) — constructs inline via `context.read<ApiClient>()`. Methods: `getStaffMemberships()`, `updateMembership(id, data)`, `deleteMembership(id)`. Clinical ranks loaded via existing `ClinicalRepository` if it exposes `GET /clinical-ranks`, otherwise added to `StaffRepository`.

> **API assumption:** `GET /staff/memberships` returns all staff at the active facility when called by an admin with `X-Tenant-ID`. The API contract documents it as "current user's memberships" — verify with backend before building. If incorrect, a `GET /tenants/{id}/staff` endpoint may be needed.

### List view

- **App bar:** "Staff" title + search icon (toggles inline search field, min 2 chars).
- **Staff type filter chips** (horizontal scroll): All / Doctor / Nurse / Pharmacist / Lab Tech / Radiologist / Physiotherapist / Dentist / Admin / Other.
- **Status filter:** Active / Inactive / All pills.
- Filtering is client-side on the loaded list — no additional API calls.
- **Staff card** per member:
  - Avatar circle with initials (colour from staff type).
  - Name, clinical rank name, active/inactive badge.
  - Capability chips: `Rx` (can prescribe), `Labs` (can order labs), `Emergency` (can emergency access).
  - Inactive cards are rendered at reduced opacity.
  - Chevron indicating tap target.

### Edit bottom sheet

Triggered by tapping any staff card. `showModalBottomSheet` (drag handle, not full-screen).

- Read-only header: avatar, name, email.
- **Staff Type dropdown** — same valid values as invite form.
- **Clinical Rank dropdown** — loads from `GET /clinical-ranks` once on first sheet open, cached. Each option shows rank name, hierarchy level, and capability chips so the admin can see what they're granting.
- **Active toggle** — with "Inactive staff can no longer log in" subtitle.
- **Save Changes** button — calls `PUT /staff/memberships/{id}` with `{ staff_type, clinical_rank_id, is_active }`, refreshes list on success.
- **Remove from Facility** button (destructive, red border) — confirmation dialog → `DELETE /staff/memberships/{id}`, removes card from list on success.

---

## 5. Invite Staff Screen (rewrite)

**File:** `lib/presentation/providers/screens/provider_invitation_screen.dart`  
**API:** `POST /staff/invite` (requires `X-Tenant-ID`), `GET /clinical-ranks`

### What is removed

First name, last name, phone, license number, specialization, facility dropdown, emergency access toggle — the backend does not accept these fields.

### New form

- **Active facility banner** (read-only, blue) — "Inviting to: [facility name]".
- **Email** — required text field.
- **Staff Type** — dropdown with all valid `staff_type` values.
- **Clinical Rank** — expanded selectable card list (not a dropdown). Each card shows rank name, hierarchy level, and capability chips (`Can Prescribe`, `Can Order Labs`, `Emergency Access`). The selected card gets a blue border and checkmark. Cards loaded from `GET /clinical-ranks` on `initState`.
- **Send Invitation** button — calls `POST /staff/invite` with `{ email, staff_type, clinical_rank_id }`.

### On success

Snackbar: "Invitation sent to [email]". Form resets (email clears, staff type resets to first value, rank deselects).

---

## 6. Facilities List & Form — Navigation Wiring

**Screens:** `FacilitiesListScreen`, `FacilityFormScreen` — no changes to the screens themselves.

**Change 1:** `ProviderDashboardScreen` drawer — "Facilities" admin entry calls:
```dart
Navigator.push(context, MaterialPageRoute(builder: (_) => const FacilitiesListScreen()))
```

**Change 2:** `MoreScreen` — same, using `CupertinoPageRoute`.

The screens' internal named routes (`/facilities/add`, `/facilities/edit`) continue to work as-is.

---

## File Inventory

| Action | File |
|---|---|
| Edit | `lib/presentation/dashboard/screens/provider_dashboard_screen.dart` |
| Edit | `lib/presentation/more/more_screen.dart` |
| Edit | `lib/data/repositories/organization_repository.dart` |
| **New** | `lib/data/repositories/staff_repository.dart` |
| Edit | `lib/data/models/organization_models_enhanced.dart` (add `OrgStatsModel`) |
| **New** | `lib/presentation/organization/screens/organization_profile_screen.dart` |
| **New** | `lib/presentation/staff/screens/staff_management_screen.dart` |
| Edit (rewrite) | `lib/presentation/providers/screens/provider_invitation_screen.dart` |
| No change | `lib/presentation/facilities/screens/facilities_list_screen.dart` |
| No change | `lib/presentation/facilities/screens/facility_form_screen.dart` |

---

## Out of Scope

- Staff invitation acceptance / registration flow (web-portal-only per existing architecture).
- Organization creation (super-admin only, handled via web admin panel).
- Billing/subscription admin views (already built and accessible to all staff).
