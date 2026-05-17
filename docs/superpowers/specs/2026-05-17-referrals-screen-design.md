# Referrals Screen — Design Spec

**Date:** 2026-05-17
**Scope:** Flutter mobile app (`healthcare_emr_mobile`)
**Backend:** `PatientReferralController` is complete — 9 endpoints, all routes registered. This spec covers mobile only.

---

## Problem

The backend cross-facility referral system (`/api/v1/referrals`) is fully implemented with status tracking, inter-facility messaging, and status history — but has no mobile surface. Clinicians have no way to send, receive, or act on referrals from the app.

---

## Decisions Made

| Question | Decision |
|---|---|
| Navigation placement | More screen tile with pending-action badge |
| List layout | Single unified list, status filter chips, SENT/RECEIVED role badge per card |
| Create referral entry point | Patient detail screen FAB picker ("Refer patient") |
| Architecture | Full provider pattern — ReferralRepository + ReferralProvider |
| Messaging | Inline at the bottom of ReferralDetailScreen (not a separate screen) |

---

## What This Is Not

Cross-facility referrals only — the backend explicitly rejects same-facility referrals (`SAME_FACILITY` error). Intra-facility consultation requests (same building, different doctor) are a separate deferred feature.

---

## Architecture

```
ReferralRepository
  - list({String? status, int page})
  - show(String id)
  - create(Map<String, dynamic> data)
  - accept(String id)
  - schedule(String id, String date, String? location)
  - complete(String id, String notes, String? recommendations)
  - cancel(String id, String reason)
  - getMessages(String id)
  - sendMessage(String id, String message)

ReferralProvider (ChangeNotifier)
  - referrals: List<ReferralModel>
  - activeFilter: ReferralFilter
  - isLoading: bool
  - isLoadingMore: bool
  - error: String?
  - pendingActionCount: int       ← badge in More screen
  - loadReferrals()
  - loadMore()
  - setFilter(ReferralFilter)
  - create(Map) → bool
  - accept(String id) → bool
  - schedule(String id, String date, String? location) → bool
  - complete(String id, String notes, String? recommendations) → bool
  - cancel(String id, String reason) → bool
  - getMessages(String id) → List<ReferralMessageModel>
  - sendMessage(String id, String message) → bool
```

`pendingActionCount` = count of referrals where the current user's facility is the `to_tenant` and status is `pending`. This is the number that needs immediate action from you. It drives the badge in the More screen tile.

---

## New Files

| File | Purpose |
|---|---|
| `lib/data/models/referral_models.dart` | `ReferralModel`, `ReferralMessageModel`, `ReferralStatusHistoryModel`, `ReferralFilter` enum |
| `lib/data/repositories/referral_repository.dart` | All 9 API calls |
| `lib/data/providers/referral_provider.dart` | List state, filter state, all write operations |
| `lib/presentation/referrals/screens/referrals_screen.dart` | Filter chips + unified list |
| `lib/presentation/referrals/screens/referral_detail_screen.dart` | Full detail with action bar and message thread |
| `lib/presentation/referrals/widgets/create_referral_sheet.dart` | DraggableScrollableSheet for creating a referral |
| `lib/presentation/referrals/widgets/referral_card.dart` | List item card |
| `lib/presentation/referrals/widgets/referral_message_thread.dart` | Chat-style inline message view |

## Modified Files

| File | Change |
|---|---|
| `lib/main.dart` | Add `ReferralRepository` + `ReferralProvider` to provider tree |
| `lib/presentation/more/more_screen.dart` | Add Referrals tile with `pendingActionCount` badge |
| `lib/presentation/patients/screens/patient_detail_screen.dart` | Add "Refer patient" to FAB picker; gate on `canReferPatient` |
| `lib/presentation/patients/widgets/clinical_forms.dart` | No change needed — `CreateReferralSheet` is a separate widget |

---

## Data Models

### ReferralFilter (enum)
```dart
enum ReferralFilter { all, pending, active, done }
```
`active` collapses `accepted` and `scheduled` statuses together — both mean "in progress."

### ReferralModel (key fields)
```dart
class ReferralModel {
  final String id;
  final String status;         // pending | accepted | scheduled | completed | cancelled
  final String specialty;
  final String urgency;        // routine | urgent | emergency
  final bool isUrgent;
  final bool isOverdue;
  final String? fromTenantId;
  final String fromTenantName;
  final String? toTenantId;
  final String toTenantName;
  final String referringProviderId;
  final String referringProviderName;
  final String? referredToProviderId;
  final String? referredToProviderName;
  final String? masterPatientId;
  final String? patientName;
  final String? patientDob;
  final String? reason;              // only in detail view
  final String? clinicalSummary;     // only in detail view
  final String? relevantHistory;     // only in detail view
  final String? currentMedications;  // only in detail view
  final String? diagnosticResults;   // only in detail view
  final String? consultationNotes;   // only in detail view
  final String? recommendations;     // only in detail view
  final String? appointmentDate;
  final String? appointmentLocation;
  final bool requiresFollowUp;
  final String? followUpDate;
  final String referredAt;
  final List<ReferralStatusHistoryModel> statusHistory;

  // Role flags — set by ReferralProvider when loading, not computed from model alone.
  // Provider reads AuthProvider.activeTenantId and tags each model on load.
  final bool isSent;       // current user's facility == fromTenantId
  final bool isReceived;   // current user's facility == toTenantId

  // Computed from model fields only
  bool get isOpen => !['completed', 'cancelled'].contains(status);
  bool get canAccept    => isReceived && status == 'pending';
  bool get canSchedule  => isReceived && status == 'accepted';
  bool get canComplete  => isReceived && status == 'scheduled';
  bool get canCancel    => isSent && ['pending', 'accepted', 'scheduled'].contains(status);
}
```

`isSent` / `isReceived` are computed by comparing `fromTenantId` against the active tenant stored in `AuthProvider`.

### ReferralMessageModel
```dart
class ReferralMessageModel {
  final String id;
  final String senderId;
  final String senderName;
  final String message;
  final String createdAt;
}
```

---

## ReferralsScreen

### Filter Chips
Horizontal scrolling row of chips: **All · Pending · Active · Done**

Tapping a chip calls `referralProvider.setFilter(filter)`. The backend supports a single `?status=` value, so compound filters (Active, Done) are applied client-side after fetching the full list:
- **All** → `GET /referrals` (no status param), display all
- **Pending** → display where `status == pending`
- **Active** → display where `status in [accepted, scheduled]`
- **Done** → display where `status in [completed, cancelled]`

`ReferralProvider` always fetches the full paginated list and stores it. `setFilter` changes the display predicate without a new API call, which also avoids the two-request problem for the Active/Done compound filters. Pull-to-refresh re-fetches from the API.

### ReferralCard

```
┌─────────────────────────────────────────────────────┐
│ [SENT] ●emergency    Adaobi Nwosu           Pending │
│ Cardiology · → Lagos General Hospital               │
│ Dr. Chukwudi Obi · 2 days ago          ⚠ Overdue   │
└─────────────────────────────────────────────────────┘
```

- **Role badge**: SENT (purple) or RECEIVED (teal)
- **Urgency dot**: grey = routine, amber = urgent, red = emergency
- **Patient name** (prominent)
- **Specialty · → or ← Facility name** (arrow direction shows flow)
- **Provider name · relative timestamp**
- **Overdue warning** if `isOverdue`
- **Status chip** right-aligned

Tap → opens `ReferralDetailScreen`.

### Empty States
- All: "No referrals yet. Refer a patient from their profile."
- Pending: "No pending referrals."
- Active: "No active referrals."
- Done: "No completed or cancelled referrals."

---

## ReferralDetailScreen

### Header Section
Patient name + DOB · specialty · urgency badge · `FromFacility → ToFacility` · referring provider · date referred.

### Clinical Content (collapsible sections)
- **Reason** (always expanded — required field)
- **Clinical summary** (collapsed by default)
- **Relevant history** (collapsed)
- **Current medications** (collapsed)
- **Diagnostic results** (collapsed)
- **Consultation notes** (collapsed; only shown when present — added on completion)
- **Recommendations** (collapsed; only shown when present)
- **Follow-up** (shown if `requiresFollowUp = true`)
- **Appointment** (shown if `appointmentDate` is set)

### Status Timeline
Compact vertical timeline of `statusHistory` entries: from_status → to_status, changed by, timestamp.

### Action Bar (bottom, role-dependent)

| Role | Status | Primary action | Secondary |
|---|---|---|---|
| Receiving | pending | **Accept** | Message |
| Receiving | accepted | **Schedule** | Message |
| Receiving | scheduled | **Mark complete** | Message |
| Receiving | completed / cancelled | *(none)* | *(disabled)* |
| Referring | pending | **Cancel** | Message |
| Referring | accepted | **Cancel** | Message |
| Referring | scheduled | **Cancel** | Message |
| Referring | completed / cancelled | *(none)* | — |

**Accept** — one-tap, no confirmation needed.

**Schedule** — opens a bottom sheet: date + time picker (required), location field (optional).

**Mark complete** — opens a bottom sheet: consultation notes text field (required, min 10 chars), recommendations (optional).

**Cancel** — opens a bottom sheet: reason text field (required, min 10 chars). Referring party only.

**Message** — scrolls to or expands the message thread below the clinical sections. Disabled on completed/cancelled referrals.

### ReferralMessageThread (inline)
Chat-style list of messages at the bottom of the detail screen. Current user's messages right-aligned (blue bubble), other party's left-aligned (grey). Send field fixed at bottom. Loads on screen open via `referralProvider.getMessages(id)`.

---

## CreateReferralSheet

Launched from the patient detail screen FAB picker: "Refer patient". Only shown if `auth.currentUser.isStaff` — gated same as prescriptions and lab orders.

`DraggableScrollableSheet` (initialChildSize 0.85, max 1.0).

**Fields (in order):**
1. **Destination facility** — searchable dropdown of tenants from `GET /tenants`. Excludes current facility.
2. **Specific provider** (optional) — shown only after facility is selected; fetches staff memberships at that facility. Dropdown of available providers.
3. **Specialty** — free-text field (e.g. "Cardiology", "Neurology")
4. **Urgency** — segmented control: Routine / Urgent / Emergency
5. **Reason** — multi-line text (required, min 10 chars, max 2000)
6. **Clinical summary** — multi-line text (optional, max 5000)
7. **Relevant history** — multi-line text (optional)
8. **Current medications** — multi-line text (optional)
9. **Diagnostic results** — multi-line text (optional)
10. **Requires follow-up** — toggle switch
11. **Follow-up date** — date picker (shown + required if toggle is on, must be after today)

**Submit** calls `referralProvider.create(data)`. On success, dismisses the sheet and shows `showAdaptiveToast('Referral sent')`. On error, shows toast with message.

**Patient consent check:** if the backend returns `PATIENT_CONSENT_REQUIRED`, show a specific error: "This patient has not enabled cross-facility data sharing. Ask them to update their portal privacy settings."

---

## Wiring into Patient Detail Screen

The FAB picker on `PatientDetailScreen` already handles multiple actions (book appointment, prescribe, order labs). Add "Refer patient" as a new option:

```dart
// In FAB picker action list:
if (auth.isStaff)
  _FabAction(
    icon: Icons.send,
    label: 'Refer patient',
    onTap: () => _openCreateReferral(context, patient),
  ),
```

`_openCreateReferral` opens `CreateReferralSheet` pre-filled with `masterPatientId` from the patient's central record.

**Note:** `masterPatientId` must be resolved from the patient's tenant record. `PatientModel` does not currently expose `masterPatientId` — this field needs to be added to `formatPatient()` in `PatientController` (backend, one-line change) and to `PatientModel.fromJson()`.

---

## Error Handling

| Error code | User-facing message |
|---|---|
| `PATIENT_CONSENT_REQUIRED` | "This patient has not enabled cross-facility data sharing." |
| `SAME_FACILITY` | "Cannot refer to your own facility." |
| `RECEIVING_PROVIDER_NOT_CREDENTIALED` | "That provider is not registered at the selected facility." |
| `INVALID_STATUS_TRANSITION` | "This action is no longer available — the referral status has changed." |
| `REFERRAL_CLOSED` | "Cannot send messages on a completed or cancelled referral." |
| Network error | `showAdaptiveToast` with generic retry message |

---

## Adaptive UI

Follows existing app conventions:
- iOS list tiles: `CupertinoListTile` style cards
- Filter chips: `CupertinoSlidingSegmentedControl` on iOS, `FilterChip` row on Android
- Action sheets (cancel, schedule, complete): `showAdaptiveActionSheet` / `ModalBottomSheet`
- Toasts: `showAdaptiveToast` from `platform.dart`
- Navigation: `CupertinoPageRoute` on iOS, `MaterialPageRoute` on Android

---

## Backend Note

One backend change required: `PatientController::formatPatient()` must include `master_patient_id` in the response. Currently it exposes `primary_provider_id` but not the MPI record ID. The `CreateReferralSheet` needs this to populate the `master_patient_id` field when creating a referral. This is a one-line addition to the Laravel controller and the `PatientModel.fromJson()` in Flutter.

---

## Out of Scope

- Push notifications for referral status changes (requires FCM/APNs — separate work item)
- Filtering referrals by patient or date range (nice-to-have, not in brief)
- Intra-facility consultation requests — separate spec and implementation
- Referral document attachments
