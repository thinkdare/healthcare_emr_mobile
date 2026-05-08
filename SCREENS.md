# Screen Walkthrough — Healthcare EMR Mobile

This document describes every screen in the app: what it does, what it shows, and where it can navigate to.

---

## Contents

1. [Root Routing (AuthWrapper)](#1-root-routing-authwrapper)
2. [Login Screen](#2-login-screen)
3. [Facility Picker Screen](#3-facility-picker-screen)
4. [Provider Dashboard Screen](#4-provider-dashboard-screen)
5. [Patient List Screen](#5-patient-list-screen)
6. [Patient Detail Screen](#6-patient-detail-screen)
7. [Patient Form Screen (Create / Edit)](#7-patient-form-screen-create--edit)
8. [Access Grants Screen](#8-access-grants-screen)
9. [Request Access Screen](#9-request-access-screen)
10. [Emergency Access Screen](#10-emergency-access-screen)
11. [Trigger Emergency Access Screen](#11-trigger-emergency-access-screen)
12. [Subscription Details Screen](#12-subscription-details-screen)
13. [Subscription Upgrade Screen](#13-subscription-upgrade-screen)
14. [Subscription Expired Screen](#14-subscription-expired-screen)
15. [Billing Invoices Screen](#15-billing-invoices-screen)
16. [Reports & Compliance Screen](#16-reports--compliance-screen)
17. [Staff Profile Screen](#17-staff-profile-screen)
18. [Facilities List Screen](#18-facilities-list-screen)
19. [Facility Form Screen (Create / Edit)](#19-facility-form-screen-create--edit)
20. [Provider Invitation Screen](#20-provider-invitation-screen)
21. [Registration / Onboarding Stubs](#21-registration--onboarding-stubs)

---

## 1. Root Routing (AuthWrapper)

**File:** `lib/main.dart`

The invisible root widget that decides the entry point on every app launch and session restore.

**Logic:**
- While `AuthProvider` is loading (restoring session from secure storage): shows a full-screen spinner.
- If `AuthProvider.isAuthenticated == true`: renders `ProviderDashboardScreen`.
- If not authenticated: renders `LoginScreen`.

There is no visible UI; it is purely a routing gate.

---

## 2. Login Screen

**File:** `lib/presentation/auth/screens/login_screen.dart`

The app's entry point for unauthenticated users. Implements a three-step flow on a single screen — the form evolves in place rather than navigating to separate screens.

**Step 1 — Email check**
- User enters their email address and taps **Next**.
- Calls `POST /auth/check-email`. If the email exists, the password field appears.
- If the account belongs to a single facility, the facility name is displayed as a read-only badge. If multiple facilities exist, a dropdown appears so the user can choose before logging in.
- Tapping the edit icon on the email field resets to Step 1.

**Step 2 — Password**
- User enters their password and taps **Login**.
- Calls `POST /auth/login`.
- **Forgot Password** shows a snackbar directing the user to their administrator (no self-service reset flow exists).

**Step 3 — Two-Factor Authentication (conditional)**
- Shown only when the login response has `requires_2fa: true`.
- User enters the 6-digit TOTP code or a `XXXXX-XXXXX` backup code.
- **Back to login** button resets all three steps.

**Navigation:**
| Trigger | Destination |
|---|---|
| Successful login, no facility selection needed | `ProviderDashboardScreen` (replaces stack) |
| Successful login, facility selection needed (`awaitingFacility` state) | `FacilityPickerScreen` (replaces stack) |
| Successful 2FA verification | Same as above, based on auth state |

---

## 3. Facility Picker Screen

**File:** `lib/presentation/auth/screens/facility_picker_screen.dart`

Shown after a successful login when the user is credentialed at more than one facility, or when a session is restored without a stored active tenant.

**What it shows:**
- A greeting card with the user's name, initials, and email.
- A scrollable list of facility cards. Each card shows the facility name, parent organisation, and the user's role at that facility (e.g. "Doctor").
- The selected facility card shows a spinner while the selection API call is in progress.

**Actions:**
- Tap any facility card → calls `POST /auth/facility` to set the active tenant.
- **Logout** button (app bar, top-right) → calls `POST /auth/logout`, clears the session, and navigates to the root route `/` (which resolves to `LoginScreen`).

**Navigation:**
| Trigger | Destination |
|---|---|
| Facility selected successfully | `ProviderDashboardScreen` (replaces stack) |
| Logout | `LoginScreen` (clears entire navigation stack) |

---

## 4. Provider Dashboard Screen

**File:** `lib/presentation/dashboard/screens/provider_dashboard_screen.dart`

The main hub of the app. Every authenticated session lands here. Pull-to-refresh reloads all summary data.

**What it shows:**
The body is a scrollable column of summary cards. Cards only render when there is data to show:

| Card | Content |
|---|---|
| Welcome Card | Gradient banner with the user's name, role, and active facility name |
| Subscription Card | Trial countdown or active status. Shows **Upgrade Plan** button when on trial |
| Patient Overview | Total patients, new patients (last 7 days). Appointments and prescriptions are listed as "coming soon" |
| Recent Patients | First 5 patients, with a **View All** link. Tapping a patient row navigates to `PatientListScreen` |
| Access Grants Card | Visible only when there are pending approvals or outgoing requests. Shows a yellow pending-count badge |
| Emergency Access Card | Visible only when events exist. Shows a red unreviewed-count badge |
| Staff Profile Card | Current role, clinical rank, and capability chips (Prescribe, Order Labs, Emergency Access) |
| Active Facility Card | Name, organisation, type, address, and phone |

**App bar:**
- Logout icon → shows a confirmation dialog. On confirm, clears the SQLite patient cache and token, then navigates to `LoginScreen`.

**Side drawer:**
| Menu item | Destination |
|---|---|
| Home | Closes the drawer (stays on Dashboard) |
| Patients | `PatientListScreen` |
| Access Grants (with pending badge) | `AccessGrantsScreen` |
| Emergency Access | `EmergencyAccessScreen` |
| Subscription | `SubscriptionDetailsScreen` |
| Reports & Compliance | `ReportingScreen` |
| My Profile | `StaffProfileScreen` |
| Logout | Confirmation dialog → `LoginScreen` |

**Floating Action Button:** `Patients` → `PatientListScreen`

**In-card navigation:**
| Interaction | Destination |
|---|---|
| Tap "Total Patients" stat tile | `PatientListScreen` |
| Tap "View All" in Recent Patients | `PatientListScreen` |
| Tap Access Grants card | `AccessGrantsScreen` |
| Tap Emergency Access card | `EmergencyAccessScreen` |
| Tap "Upgrade Plan" button | `SubscriptionUpgradeScreen` |

---

## 5. Patient List Screen

**File:** `lib/presentation/patients/screens/patient_list_screen.dart`

A paginated, searchable list of patients visible to the authenticated provider.

**What it shows:**
- `PatientCard` rows with name, gender, age, blood type, and a red "Allergy" badge if the patient has critical allergies.
- An offline/cache banner when data is being served from SQLite rather than the API.
- An error banner (dismissible) if the last load failed.
- Infinite scrolling: loads the next page when the user scrolls within 200 px of the bottom.
- Pull-to-refresh clears the search and forces a fresh API load.

**Search:**
- Toggled by the search icon in the app bar. Hides/shows an inline search text field.
- Searches by name, email, or phone number (minimum 2 characters enforced by the API).
- Results replace the list in real-time as the user types.

**Navigation:**
| Trigger | Destination |
|---|---|
| Tap any `PatientCard` | `PatientDetailScreen` (with that patient) |
| FAB (person_add) | `PatientFormScreen` (create mode) |
| Back button / system back | `ProviderDashboardScreen` |

---

## 6. Patient Detail Screen

**File:** `lib/presentation/patients/screens/patient_detail_screen.dart`

Full record view for a single patient. Uses a `TabBar` with five tabs.

**App bar:**
- Title shows the patient's full name.
- Edit icon → `PatientFormScreen` (edit mode). On return, if a `PatientModel` is returned, the screen updates in place and syncs the `PatientProvider`.
- Refresh icon → reloads all clinical data from the API.

**Tabs:**

### Overview tab
Scrollable cards showing:
- Patient summary (name, age, gender, blood type)
- Allergies (with CRITICAL badge if any are life-threatening/severe)
- Current medications
- Chronic conditions (chip list)
- Emergency contact
- Insurance details

No navigation from this tab.

### Appointments tab
List of `AppointmentCard` widgets. Each card shows appointment type, date/time, reason, and a status badge (colour-coded by status). Pull-to-refresh reloads appointments.

FAB: **Book Appointment** → opens `AppointmentForm` as a modal bottom sheet.

### Prescriptions tab
List of `PrescriptionCard` widgets showing medication name, dosage, frequency, route, refills remaining, and status. Pull-to-refresh reloads prescriptions.

FAB: **New Prescription** → opens `PrescriptionForm` as a modal bottom sheet. Only visible if `auth.canPrescribe` is true; otherwise shows a snackbar.

### Lab Results tab
List of `LabResultCard` widgets showing test name, type, priority badge, status, results (if recorded), and abnormal-flag chips. Pull-to-refresh reloads results.

FAB: **Order Lab Test** → opens `LabOrderForm` as a modal bottom sheet. Only visible if `auth.canOrderLabs` is true; otherwise shows a snackbar.

### Documents tab
List of `DocumentCard` widgets. Each card shows file name, document type, size, and a confidential lock icon where applicable.

FAB: **Upload Document** → opens `DocumentUploadForm` as a modal bottom sheet.

Tapping the download icon on a document card fetches a download URL and opens it via `url_launcher` in an external app.

**Navigation:**
| Trigger | Destination |
|---|---|
| Edit icon (app bar) | `PatientFormScreen` (edit mode) |
| Back | `PatientListScreen` |
| FAB on Appointments tab | `AppointmentForm` modal bottom sheet |
| FAB on Prescriptions tab | `PrescriptionForm` modal bottom sheet |
| FAB on Lab Results tab | `LabOrderForm` modal bottom sheet |
| FAB on Documents tab | `DocumentUploadForm` modal bottom sheet |
| Document download icon | External app (via `url_launcher`) |

---

## 7. Patient Form Screen (Create / Edit)

**File:** `lib/presentation/patients/screens/patient_form_screen.dart`

Dual-purpose form: renders as **New Patient** when no patient is passed in, or **Edit Patient** when an existing `PatientModel` is provided.

**Sections:**
1. Basic Information — first name, last name, date of birth (date picker), gender, blood type
2. Contact Information — phone, email, address
3. Emergency Contact — name and phone
4. Allergies — dynamic list of `{allergen, severity}` rows; severity dropdown
5. Current Medications — dynamic list of `{name, dosage}` rows
6. Chronic Conditions — dynamic list of free-text condition strings
7. Insurance — provider name and policy number

**Save button** is in the app bar (top-right). On success, pops and returns the saved `PatientModel` to the caller.

**Navigation:**
| Trigger | Destination |
|---|---|
| Save (success) | Pops back to caller (`PatientListScreen` or `PatientDetailScreen`) with the new/updated `PatientModel` |
| Back / Cancel | Pops with no result |

---

## 8. Access Grants Screen

**File:** `lib/presentation/access_grants/screens/access_grants_screen.dart`

Manages cross-facility patient access grants. Uses a `TabBar` with two tabs.

**Pending Approval tab**
Shows grants where the caller's facility is the granting party. Each card shows the requesting facility, access level, data types, reason, and expiry. Two action buttons per card:
- **Deny** → `showDialog` confirmation with a required reason field (min 10 chars). Calls `POST /access-grants/{id}/deny`.
- **Approve** → `showDialog` confirmation with an optional notes field. Calls `POST /access-grants/{id}/approve`.

**My Requests tab**
Shows grants the caller has requested (outgoing). Each card shows the granting facility, access level, status, and timestamps. For pending or active grants, a **Cancel Request** / **Revoke Access** button appears → `showDialog` with a required reason field.

**Navigation:**
| Trigger | Destination |
|---|---|
| FAB "Request Access" | `RequestAccessScreen` |
| Back | `ProviderDashboardScreen` |

---

## 9. Request Access Screen

**File:** `lib/presentation/access_grants/screens/request_access_screen.dart`

Form to request cross-facility access to a patient at another facility.

**Fields:**
- **Global Patient ID** — UUID text field. Locked if a `prefillGlobalPatientId` was passed by the caller.
- **Access Level** — dropdown: View only / View & update / Full access.
- **Data Types** — multi-select filter chips (Demographics, Medications, Allergies, Lab Results, Prescriptions, Appointments, Medical History). All selected by default.
- **Reason** — multi-line text (min 20 chars).
- **Access Expires** — optional date picker (between tomorrow and 365 days). Can be cleared.

**Submit** button is in the app bar. On success, shows a snackbar ("auto-approved" or "awaiting approval") and pops returning `true`.

**Navigation:**
| Trigger | Destination |
|---|---|
| Submit (success) | Pops back to `AccessGrantsScreen` with `true` |
| Back / Cancel | Pops with no result |

---

## 10. Emergency Access Screen

**File:** `lib/presentation/emergency_access/screens/emergency_access_screen.dart`

Audit log of all emergency (break-glass) access events. Supports infinite scrolling and pull-to-refresh.

**What it shows:**
Each `EmergencyLogCard` displays:
- Emergency type chip (Life Threatening, Unconscious, Cannot Consent, Critical Care)
- Review status chip (Reviewed / Escalated / Pending Review)
- Patient name, provider name, facility, and access timestamp
- Escalation warnings when applicable

**Review action:** For events where the current user is the notified primary provider (`log.notifiedProviderId == currentUser.id`) and the event is unreviewed, a **Review This Event** button appears on the card → opens a `showDialog` with a required review notes field (min 10 chars). Calls `POST /emergency-access/{id}/review`.

**Navigation:**
| Trigger | Destination |
|---|---|
| FAB "Break Glass" (visible only if `auth.canEmergencyAccess`) | `TriggerEmergencyAccessScreen` |
| Back | `ProviderDashboardScreen` |

---

## 11. Trigger Emergency Access Screen

**File:** `lib/presentation/emergency_access/screens/trigger_emergency_access_screen.dart`

Break-glass form. Immediately grants access to a patient record and creates an immutable audit log. The screen has a red-tinted background and app bar to signal the severity of the action.

**Fields:**
- **Patient UUID** — UUID text field. Locked if `prefillPatientId` was passed by the caller.
- **Emergency Type** — dropdown: Life Threatening / Unconscious Patient / Unable to Consent / Critical Care.
- **Emergency Details** — multi-line justification (min 20 chars).

**Submit** in the app bar first shows a `showDialog` confirmation warning the user this action is permanent and immutable. On confirm, calls `POST /emergency-access`. On success, pops returning `true`.

**Navigation:**
| Trigger | Destination |
|---|---|
| Submit (success) | Pops back to `EmergencyAccessScreen` with `true` |
| Back / Cancel | Pops with no result |

---

## 12. Subscription Details Screen

**File:** `lib/presentation/subscription/screens/subscription_details_screen.dart`

Shows the organisation's current subscription plan and billing history.

**What it shows:**
- **Status card** — large icon and label (Free Trial / Active / Payment Past Due / Cancelled). For trials, shows days remaining and end date.
- **Plan details card** — plan name, billing cycle, amount, currency, and current billing period.
- **Recent Invoices** — up to 5 invoices with number, date, status (paid/pending), and total amount.
- If the subscription is active and not pending cancellation: a **Cancel Subscription** button → `showDialog` confirmation → calls `DELETE /billing/organizations/{orgId}/subscriptions/{subId}`.
- If cancellation is pending: an informational banner.

**Navigation:**
| Trigger | Destination |
|---|---|
| Back | `ProviderDashboardScreen` (via drawer) |

---

## 13. Subscription Upgrade Screen

**File:** `lib/presentation/subscription/screens/subscription_upgrade_screen.dart`

Plan selection screen. Fetches and displays all available billing plans.

**What it shows:**
- If on a trial: a banner showing remaining trial days.
- A `PlanCard` for each available plan, showing name, description, price (in NGN), limit chips, and feature list. The currently active plan is highlighted and its button is disabled.

**Actions:**
- Tapping **Select Plan** on any non-current plan either calls `POST /billing/organizations/{orgId}/subscriptions/{subId}/change-plan` (if a subscription exists) or `POST /billing/organizations/{orgId}/subscriptions/trial` (if no subscription). On success, pops.

**Navigation:**
| Trigger | Destination |
|---|---|
| Plan selected (success) | Pops back to caller |
| Back | `ProviderDashboardScreen` or `SubscriptionDetailsScreen` |

---

## 14. Subscription Expired Screen

**File:** `lib/presentation/subscription/screens/subscription_expired_screen.dart`

A blocking screen shown when the organisation's subscription has expired. There is no app bar or drawer — the user cannot navigate past this screen without acting.

**What it shows:**
- If the subscription was a trial: an **Upgrade Now** button.
- If the subscription has expired (not trial): an informational banner and a **Logout** button.
- A support contact footer (`support@emrsystem.com`).

**Navigation:**
| Trigger | Destination |
|---|---|
| "Upgrade Now" (trial expired) | Navigates to `/subscription/upgrade` (named route) |
| "Logout" (subscription expired) | Navigates to `/auth/logout` (named route) |

---

## 15. Billing Invoices Screen

**File:** `lib/presentation/subscription/screens/billing_invoices_screen.dart`

Full invoice history for the organisation.

**What it shows:**
- On wide screens (web, `width > 600`): three summary stat cards at the top (Total Paid, Paid Count, Pending Count), then a list.
- On narrow screens (mobile): just the invoice list.
- Each invoice card shows number, date, amount, and a colour-coded status badge.
- Overdue invoices show a red "Due: {date}" banner.

**Invoice detail:** Tapping any invoice card opens a `showModalBottomSheet` (draggable, 50–95% height) with full invoice details. Unpaid invoices show a **Pay Now** button (stubbed, shows "coming soon" snackbar) and a **Download PDF** button (stubbed).

**Navigation:**
| Trigger | Destination |
|---|---|
| Back | Caller screen |

---

## 16. Reports & Compliance Screen

**File:** `lib/presentation/reporting/screens/reporting_screen.dart`

Reporting dashboard for admins. Three tabs.

### Organisation tab
A 2×2 stats grid (Total Facilities, Staff Members, Total Patients, Active Subscriptions) and a per-facility breakdown card for each facility. Stats include a "generated at" timestamp (nightly compute job). Pull-to-refresh reloads org stats.

### Facility tab
Two 2×2 stats grids:
- Patient Activity: Total Patients, New (30 days), Appointments, Prescriptions
- Clinical Activity: Lab Orders, Documents, Emergency Events, Access Grants
- Compliance: Audit Events, Unreviewed Emergency (highlighted in warning colour if > 0)

Pull-to-refresh reloads facility stats.

### Audit Log tab
Paginated compliance audit log with infinite scroll.

- Filter bar showing total event count and a **Filter** button (with a blue badge when filters are active).
- **Filter** → `showModalBottomSheet` with dropdowns for: Action (viewed, created, updated, etc.), Access Authority (primary provider, cross-facility grant, emergency, etc.), Emergency Events (all / emergency only / non-emergency only). Clear and Apply buttons.
- Each `AuditEntryCard` shows an action icon, action label, resource type, authority basis, and timestamp. Emergency entries are highlighted with a red border and "EMERGENCY" chip.

**Navigation:**
| Trigger | Destination |
|---|---|
| Back | `ProviderDashboardScreen` (via drawer) |

---

## 17. Staff Profile Screen

**File:** `lib/presentation/profile/screens/staff_profile_screen.dart`

The authenticated user's personal account screen. Three tabs.

### Profile tab
Read-only view of:
- Avatar (initials), name, email.
- Account card: account type, 2FA enabled/disabled status.
- Staff Membership card: role, primary affiliation, clinical rank, hierarchy level.
- Clinical Capabilities card: permission flags for prescribing, lab ordering, access grant approval, emergency access.
- Active Facility card: name, organisation, type, address, phone.

### Security tab
- **Change Password** form: current password, new password, confirm password. Calls `PUT /auth/password`. On success clears the form; on failure shows the error.
- **Active Sessions** section: single "Sign out of this device" button that calls `Navigator.of(context).pop()` (returns to Dashboard). Full device sign-out is handled from the Dashboard logout action.

### 2FA tab
Behaves differently based on 2FA state:

**2FA disabled:**
- Status card showing a warning icon and "2FA is disabled" message.
- **Set up 2FA** button → calls `POST /auth/2fa/setup`, then renders an inline setup flow:
  1. Instruction to open an authenticator app.
  2. Secret key displayed in a monospace box with a copy-to-clipboard button.
  3. A 6-digit code input field and **Enable 2FA** button → calls `POST /auth/2fa/enable`.
  4. On success, transitions to the Backup Codes view (see below).

**2FA enabled:**
- Status card showing "2FA is enabled".
- **Disable 2FA** button → `showDialog` with password confirmation → calls `DELETE /auth/2fa`.
- Backup Codes card showing remaining code count and a **Regenerate backup codes** button → `showDialog` confirmation → calls `POST /auth/2fa/backup-codes`.

**Backup Codes view** (shown after enabling or regenerating):
- Success banner.
- 2-column grid of backup codes (monospace).
- **Copy all** button copies all codes to clipboard.
- **Done** button dismisses the backup codes view and returns to the status view.

**Navigation:**
| Trigger | Destination |
|---|---|
| Back | `ProviderDashboardScreen` (via drawer) |
| "Sign out of this device" (Security tab) | Pops to caller |

---

## 18. Facilities List Screen

**File:** `lib/presentation/facilities/screens/facilities_list_screen.dart`

Admin screen listing all facilities within the organisation. Adapts its layout for wide screens.

**What it shows:**
- On wide screens (`width > 600`): a responsive grid (max 400 px per cell).
- On narrow screens: a vertical list.
- Each facility card shows name, type, address, phone, an Active/Inactive badge, and an Emergency badge if the facility supports emergency access.
- Each card has a `PopupMenuButton` (three-dot menu) with **Edit** and **Delete** options.

**Actions:**
- Tap a facility card → navigates to `/facilities/edit` (named route) with the facility as arguments.
- **Edit** (popup menu) → same as above.
- **Delete** (popup menu) → `showDialog` confirmation → calls the delete API and refreshes the list.
- FAB "Add Facility" → navigates to `/facilities/add` (named route).

**Navigation:**
| Trigger | Destination |
|---|---|
| Tap facility card or "Edit" in menu | `FacilityFormScreen` (edit mode) via named route `/facilities/edit` |
| FAB "Add Facility" or empty-state "Add Facility" button | `FacilityFormScreen` (create mode) via named route `/facilities/add` |
| Back | Caller screen |

---

## 19. Facility Form Screen (Create / Edit)

**File:** `lib/presentation/facilities/screens/facility_form_screen.dart`

Dual-purpose form used by `FacilitiesListScreen`. Renders as **Add Facility** or **Edit Facility** based on whether a `FacilityModel` is passed in.

**Fields:**
- Facility name (required)
- Type dropdown (Main Hospital, Branch, Pharmacy, Laboratory, Diagnostic Center)
- Address (required)
- Phone (optional)
- "Supports Emergency Access" toggle

On success, pops returning `true` so `FacilitiesListScreen` can refresh.

**Navigation:**
| Trigger | Destination |
|---|---|
| Save (success) | Pops back to `FacilitiesListScreen` with `true` |
| Back / Cancel | Pops with no result |

---

## 20. Provider Invitation Screen

**File:** `lib/presentation/providers/screens/provider_invitation_screen.dart`

Admin form to send a staff invitation email via `POST /staff/invite`.

**Fields:**
- First name, last name (required)
- Email (required)
- Phone (optional)
- License number (optional)
- Specialization (optional)
- Provider type dropdown (Doctor, Nurse, Pharmacist, Lab Technician, Admin, Other)
- Facility selector (currently a placeholder — populated from API in full implementation)
- "Can perform emergency access" toggle

On success, shows a snackbar "Invitation sent successfully" and clears the form. The API integration is stubbed with a simulated 2-second delay.

**Navigation:**
| Trigger | Destination |
|---|---|
| Back | Caller screen |

---

## 21. Registration / Onboarding Stubs

These screens exist in the codebase but are not yet integrated into the main navigation flow. Organization registration and pricing configuration are web-portal-only.

### Pricing Screen
**File:** `lib/presentation/registration/screens/pricing_screen.dart`

Read-only display of available billing plans loaded from `GET /billing/plans`. Each plan shows name, description, price, limits, and features. Does not trigger any actions (no sign-up flow from mobile).

### Organization Registration Screen
**File:** `lib/presentation/registration/screens/organization_registration_screen.dart`

Stub screen. Displays a message directing the user to the web portal. Accepts `numFacilities`, `numProviders`, and `billingCycle` constructor parameters but does not use them.

### Trial Welcome Screen
**File:** `lib/presentation/registration/screens/trial_welcome_screen.dart`

Post-registration confirmation stub. Shows a success message and a **Go to Login** button.

**Navigation:**
| Trigger | Destination |
|---|---|
| "Go to Login" | `LoginScreen` (clears entire stack via `pushNamedAndRemoveUntil('/', ...)`) |

### Quote Calculator Screen
**File:** `lib/presentation/registration/screens/quote_calculator_screen.dart`

Stub screen. Displays a message that pricing configuration is web-only. Accepts an optional `initialTier` parameter.

---

## Navigation Map Summary

```
LoginScreen
  └─ (success, single facility) → ProviderDashboardScreen
  └─ (success, multi-facility)  → FacilityPickerScreen
       └─ (facility selected)   → ProviderDashboardScreen
       └─ Logout                → LoginScreen

ProviderDashboardScreen  (drawer + FAB + card taps)
  ├─ Drawer: Patients            → PatientListScreen
  ├─ Drawer: Access Grants       → AccessGrantsScreen
  ├─ Drawer: Emergency Access    → EmergencyAccessScreen
  ├─ Drawer: Subscription        → SubscriptionDetailsScreen
  ├─ Drawer: Reports             → ReportingScreen
  ├─ Drawer: My Profile          → StaffProfileScreen
  ├─ Drawer / AppBar: Logout     → LoginScreen
  ├─ FAB / stat tile / View All  → PatientListScreen
  ├─ Access Grants card          → AccessGrantsScreen
  ├─ Emergency Access card       → EmergencyAccessScreen
  └─ Upgrade Plan button         → SubscriptionUpgradeScreen

PatientListScreen
  ├─ Tap PatientCard             → PatientDetailScreen
  └─ FAB                         → PatientFormScreen (create)

PatientDetailScreen
  ├─ Edit icon                   → PatientFormScreen (edit)
  ├─ Appointments FAB            → AppointmentForm (bottom sheet)
  ├─ Prescriptions FAB           → PrescriptionForm (bottom sheet)
  ├─ Lab Results FAB             → LabOrderForm (bottom sheet)
  ├─ Documents FAB               → DocumentUploadForm (bottom sheet)
  └─ Document download           → External app (url_launcher)

AccessGrantsScreen
  └─ FAB                         → RequestAccessScreen

EmergencyAccessScreen
  └─ FAB "Break Glass"           → TriggerEmergencyAccessScreen

SubscriptionDetailsScreen
  (no outbound navigation)

SubscriptionUpgradeScreen
  (pops on plan selection)

SubscriptionExpiredScreen
  ├─ Upgrade Now                 → /subscription/upgrade (named route)
  └─ Logout                      → /auth/logout (named route)

BillingInvoicesScreen
  └─ Tap invoice card            → Invoice detail (bottom sheet)

ReportingScreen
  └─ Audit Log filter            → Filter sheet (bottom sheet)

StaffProfileScreen
  └─ 2FA setup / backup codes    → Inline flow (no navigation)

FacilitiesListScreen
  ├─ Tap card / Edit menu        → FacilityFormScreen (edit) via /facilities/edit
  └─ FAB "Add Facility"          → FacilityFormScreen (create) via /facilities/add

TrialWelcomeScreen
  └─ Go to Login                 → LoginScreen (clears stack)
```
