# Healthcare EMR — API Reference

> Derived from `API_HANDOVER.md` (backend v2, authoritative source).  
> Use this document when building the iOS, Android, or web clients.

---

## Contents

1. [Conventions](#1-conventions)
2. [Authentication](#2-authentication)
3. [Two-Factor Authentication (2FA)](#3-two-factor-authentication-2fa)
4. [Staff Registration & Invitation](#4-staff-registration--invitation)
5. [Organizations](#5-organizations)
6. [Tenants (Facilities)](#6-tenants-facilities)
7. [Staff Memberships & Clinical Ranks](#7-staff-memberships--clinical-ranks)
8. [Patients](#8-patients)
9. [Appointments](#9-appointments)
10. [Prescriptions](#10-prescriptions)
11. [Lab Results](#11-lab-results)
12. [Medical Documents](#12-medical-documents)
13. [Access Grants (Cross-Facility)](#13-access-grants-cross-facility)
14. [Emergency Access](#14-emergency-access)
15. [Referrals](#15-referrals)
16. [Patient Portal](#16-patient-portal)
17. [Billing](#17-billing)
18. [Offline Sync](#18-offline-sync)
19. [Reporting & Compliance](#19-reporting--compliance)
20. [Utilities](#20-utilities)
21. [Error Code Reference](#21-error-code-reference)
22. [Enum Reference](#22-enum-reference)

---

## 1. Conventions

### Base URL

```
http://localhost/api/v1          ← iOS simulator, desktop, web
http://10.0.2.2/api/v1           ← Android emulator (AVD, standard)
http://10.0.3.2/api/v1           ← Android emulator (Genymotion)
```

> Backend runs on **port 80** via Nginx. Do not use port 8000.

### Required Headers

| Header | When Required | Value |
|---|---|---|
| `Authorization` | All authenticated routes | `Bearer {token}` |
| `X-Tenant-ID` | All clinical routes (patients, appointments, prescriptions, labs, documents, access grants, emergency access, sync) | UUID of the active facility |
| `Content-Type` | POST / PUT requests | `application/json` |
| `Accept` | All requests | `application/json` |

### Response Envelope

Every response uses this shape:

```json
{
  "success": true,
  "message": "Human-readable description.",
  "data": { ... },
  "meta": {
    "timestamp": "2026-04-16T09:00:00+00:00",
    "version": "v1"
  }
}
```

Paginated responses nest results under `data.items` with a `data.pagination` object:

```json
{
  "data": {
    "items": [ ... ],
    "pagination": {
      "current_page": 1,
      "per_page": 20,
      "total": 142,
      "last_page": 8
    }
  }
}
```

### Error Response

```json
{
  "success": false,
  "message": "You do not have access to this patient record.",
  "error_code": "ACCESS_DENIED",
  "data": null,
  "meta": { "timestamp": "...", "version": "v1" }
}
```

### HTTP Status Codes

| Code | Meaning |
|---|---|
| `200` | OK |
| `201` | Created |
| `401` | Unauthenticated |
| `403` | Forbidden (authenticated but not permitted) |
| `404` | Resource not found |
| `409` | Version conflict (optimistic locking) |
| `422` | Validation error |
| `429` | Rate limit exceeded |

### Optimistic Locking

Patient records, appointments, prescriptions, and lab results carry a `version` integer. Include the `version` from your last-fetched record when submitting an update. If the server version has changed (edited by another session), the API returns `409 VERSION_CONFLICT`. Omitting `version` skips the check.

---

## 2. Authentication

### `POST /auth/login`

Rate limited: 5 requests/minute per IP. No auth required.

**Request:**
```json
{
  "email": "dr.amaka@lagosgeneral.ng",
  "password": "s3cur3P@ssword"
}
```

**Response `200`:**
```json
{
  "data": {
    "token": "1|abc123...",
    "token_type": "Bearer",
    "requires_2fa": false,
    "user": {
      "id": "uuid",
      "email": "dr.amaka@lagosgeneral.ng",
      "first_name": "Amaka",
      "last_name": "Eze",
      "user_type": "staff",
      "two_factor_enabled": false
    }
  }
}
```

If `requires_2fa` is `true`, the returned token has **ability `two-factor` only**. The client must call `POST /auth/2fa/verify` before the token grants full access.

---

### `POST /auth/check-email`

Pre-login lookup. Use this to discover which facilities an email is credentialed at before showing the password prompt.

**Request:** `{ "email": "dr.amaka@lagosgeneral.ng" }`

**Response `200`:**
```json
{
  "data": {
    "exists": true,
    "has_password": true,
    "facilities": [
      {
        "id": "uuid-tenant",
        "name": "Lagos General Hospital",
        "slug": "lagos-general",
        "type": "hospital",
        "address": "Marina, Lagos Island",
        "phone": "+234 1 234 5678",
        "organization": { "id": "uuid-org", "name": "Lagos Health Network" }
      }
    ]
  }
}
```

---

### `GET /auth/me`

Returns the authenticated user's profile and all facilities they are credentialed at.

**Response `200` — key fields in `data`:**

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | |
| `email` | string | |
| `first_name`, `last_name` | string | |
| `user_type` | string | `staff` or `patient` |
| `two_factor_enabled` | boolean | |
| `preferences` | object | `currency`, `theme` |
| `available_facilities` | array | See facility object below |

Facility object inside `available_facilities`:

| Field | Type |
|---|---|
| `membership_id` | UUID |
| `tenant_id` | UUID — use as `X-Tenant-ID` |
| `tenant_name` | string |
| `tenant_type` | string |
| `staff_type` | string |
| `clinical_rank` | `{ id, name, code }` |
| `is_primary` | boolean |

---

### `POST /auth/facility`

Switches the active facility. Returns the permissions the user has at that facility.

**Request:** `{ "tenant_id": "uuid-tenant" }`

**Response `200` — key fields:**

| Field | Type |
|---|---|
| `tenant_id` | UUID — store and send as `X-Tenant-ID` |
| `tenant_name` | string |
| `staff_type` | string |
| `clinical_rank` | string |
| `can_prescribe` | boolean |
| `can_order_labs` | boolean |
| `can_emergency_access` | boolean |

---

### `GET /auth/facilities`

Lists all active facility memberships with full detail (department, rank, permissions).

---

### `POST /auth/logout`

Revokes the current token only.

### `POST /auth/logout-all`

Revokes all tokens — signs out from every device.

### `POST /auth/refresh`

Exchanges a refresh token (ability: `refresh`) for a new session token.

**Response `200`:** `{ "data": { "token": "2|xyz789...", "token_type": "Bearer" } }`

---

### `PUT /auth/password`

```json
{
  "current_password": "oldPassword1!",
  "password": "newPassword2!",
  "password_confirmation": "newPassword2!"
}
```

All tokens are revoked on success. User must log in again.

---

### `PUT /auth/preferences`

All fields optional:
```json
{ "currency": "NGN", "theme": "dark", "locale": "en-NG" }
```
`currency` must be one of the values returned by `GET /currencies`.

---

## 3. Two-Factor Authentication (2FA)

All 2FA routes require `Authorization` (Sanctum).

### Setup flow (new device or first enable)

1. `POST /auth/2fa/setup` → returns `{ secret, otpauth_url }`. Display QR code.
2. User scans QR in authenticator app, enters first code.
3. `POST /auth/2fa/enable` with `{ "code": "123456" }` → returns one-time backup codes. **Show immediately; cannot be retrieved again.**

### Login flow (2FA already enabled)

1. `POST /auth/login` returns `requires_2fa: true` and a restricted token.
2. `POST /auth/2fa/verify` with `{ "code": "123456" }` (TOTP or `XXXXX-XXXXX` backup code) → returns full session token.

### Other endpoints

| Method | Path | Description |
|---|---|---|
| `DELETE` | `/auth/2fa` | Disable 2FA. Requires `{ "code": "123456" }` |
| `GET` | `/auth/2fa/backup-codes` | Returns `{ "remaining": 6 }` — count only, not the codes |
| `POST` | `/auth/2fa/backup-codes` | Regenerates all backup codes. Previous codes immediately invalidated. Requires `{ "code": "123456" }` |

---

## 4. Staff Registration & Invitation

Staff are **never** self-registered — all accounts start from an invitation.

### `POST /staff/invite`

Auth: `Authorization` + `X-Tenant-ID`. Admin / super admin only.

```json
{
  "email": "nurse.fatima@lagosgeneral.ng",
  "first_name": "Fatima",
  "last_name": "Bello",
  "staff_type": "nurse",
  "clinical_rank_id": "uuid-rank",
  "department": "Cardiology"
}
```

`staff_type` values: `doctor`, `nurse`, `pharmacist`, `lab_technician`, `admin`, `other`.

**Response `201`:** `{ "invitation_id", "email", "expires_at" }`

---

### `GET /staff/invitation?token={token}`

Validates an invitation token. Use before showing the registration form.

**Response `200` — key fields:** `email`, `first_name`, `last_name`, `facility`, `staff_type`, `department`, `clinical_rank`, `expires_at`.

---

### `POST /staff/register`

Accept an invitation and create the account.

```json
{
  "token": "abc123-invitation-token",
  "first_name": "Fatima",
  "last_name": "Bello",
  "password": "securePass1!",
  "password_confirmation": "securePass1!",
  "phone": "+234 803 123 4567",
  "license_number": "MDCN-12345"
}
```

**Response `201`:** Same shape as `POST /auth/login` — includes a full session token.

---

## 5. Organizations

Top-level entity that owns multiple facilities. Accessible to org admins and super admins.

### `GET /organizations`

Lists all organizations the caller can see.

### `POST /organizations`

```json
{
  "name": "Abuja Medical Group",
  "slug": "abuja-medical",
  "contact_email": "admin@abujamed.ng",
  "contact_phone": "+234 9 876 5432",
  "address": "Central Business District, Abuja"
}
```

### `GET /organizations/{id}/stats`

Returns `{ tenant_count, active_tenant_count, staff_count, subscription_status }`.

---

## 6. Tenants (Facilities)

Each tenant is an individual facility with its own isolated PostgreSQL database.

### `POST /tenants`

```json
{
  "organization_id": "uuid-org",
  "name": "Lagos General Hospital",
  "slug": "lagos-general",
  "type": "hospital",
  "address": "Marina, Lagos Island, Lagos",
  "phone": "+234 1 234 5678",
  "email": "info@lagosgeneral.ng"
}
```

`type` values: `hospital`, `clinic`, `pharmacy`, `laboratory`, `diagnostic_center`, `dental`, `mental_health`, `physiotherapy`, `other`.

**Response `201`:** Full tenant object including `database_name`, `is_active`, `provisioned_at`.

### `GET /tenants/{id}/staff`

Lists all staff members at this facility.

---

## 7. Staff Memberships & Clinical Ranks

### Staff Memberships

| Method | Path | Description |
|---|---|---|
| `GET` | `/staff/memberships` | List memberships for the caller |
| `PUT` | `/staff/memberships/{id}` | Update `department`, `clinical_rank_id`, `is_active` |
| `DELETE` | `/staff/memberships/{id}` | Soft-deactivate (does not delete the user account) |
| `POST` | `/staff/memberships/{id}/primary` | Mark as primary facility affiliation |

### Clinical Ranks

### `GET /clinical-ranks`

Returns all ranks with their permission flags.

**Response item shape:**
```json
{
  "id": "uuid-rank",
  "name": "Consultant",
  "code": "CONSULTANT",
  "hierarchy_level": 5,
  "can_prescribe": true,
  "can_order_labs": true,
  "can_approve_access_grants": true,
  "can_perform_emergency_access": true,
  "description": "..."
}
```

### `POST /clinical-ranks`

```json
{
  "name": "House Officer",
  "code": "HO",
  "hierarchy_level": 2,
  "can_prescribe": false,
  "can_order_labs": true,
  "can_approve_access_grants": false,
  "can_perform_emergency_access": false,
  "description": "Junior doctor in residency training."
}
```

---

## 8. Patients

**Middleware:** `auth:sanctum` + `X-Tenant-ID` + `audit.patient`  
Every access is written to the compliance audit log.

### `GET /patients`

Returns patients visible to the caller (own patients + grant-accessible). Super admins see all.

**Query params:** `search` (min 2 chars, `SEARCH_TOO_SHORT` if shorter), `per_page` (default 20).

**Response item shape (list):**

| Field | Type |
|---|---|
| `id` | UUID |
| `mrn` | string (e.g. `LGOS-2026-00042`) |
| `full_name`, `first_name`, `last_name` | string |
| `gender` | enum |
| `blood_type` | enum |
| `is_active` | boolean |
| `primary_provider_id` | UUID |
| `version` | integer |

---

### `POST /patients`

**Key fields:**

| Field | Type | Notes |
|---|---|---|
| `first_name`, `last_name` | string | Required |
| `date_of_birth` | date (`YYYY-MM-DD`) | Required |
| `gender` | enum | Required |
| `blood_type` | enum | Optional |
| `phone`, `email`, `address` | string | Optional |
| `emergency_contact_name`, `emergency_contact_phone` | string | Optional |
| `allergies` | array of `{ name, severity }` | Optional |
| `current_medications` | array of `{ name, dosage }` | Optional |
| `chronic_conditions` | array of strings | Optional |
| `insurance_provider`, `insurance_number` | string | Optional |
| `medical_history` | string | Optional |

**Response `201`:** Full detail view including `global_patient_id`, `created_at`, `updated_at`.

---

### `GET /patients/{id}`

Full detail view. Returns `403 ACCESS_DENIED` if the caller lacks an active grant.

### `PUT /patients/{id}`

Same body as `POST`. All fields optional. Include `version` for optimistic locking.

### `DELETE /patients/{id}`

Soft-deactivates (`is_active = false`). Only the primary provider or super admin.

### `GET /patients/{id}/audit-log`

Compliance audit trail. Only the primary provider or super admin.

**Response item shape:**

| Field | Values |
|---|---|
| `action` | `viewed`, `updated`, etc. |
| `access_authority` | `primary_provider`, `intra_grant`, `cross_grant`, `emergency`, `system`, `denied` |
| `was_emergency` | boolean |
| `was_offline` | boolean |

---

## 9. Appointments

Base path: `/patients/{patientId}/appointments`

### `POST /patients/{patientId}/appointments`

```json
{
  "appointment_date": "2026-04-20T10:00:00+01:00",
  "duration_minutes": 30,
  "appointment_type": "followup",
  "reason": "3-month diabetes review",
  "notes": "Patient to bring blood glucose diary.",
  "provider_id": "uuid-provider"
}
```

`provider_id` defaults to the requesting user if omitted.  
Returns `422 SCHEDULING_CONFLICT` if the provider has an overlapping appointment.

`appointment_type` values: `checkup`, `followup`, `emergency`, `consultation`, `procedure`, `vaccination`.

**Response `201` key fields:** `id`, `status` (`scheduled`), `version: 1`.

---

### `PUT /patients/{patientId}/appointments/{id}`

All fields optional. Include `version` for optimistic locking.

`status` values on update: `confirmed`, `checked_in`, `in_progress`, `no_show`.  
Setting `checked_in` automatically records `checked_in_at`.

---

### `POST /patients/{patientId}/appointments/{id}/cancel`

```json
{ "cancellation_reason": "Patient called to reschedule." }
```

### `POST /patients/{patientId}/appointments/{id}/complete`

```json
{ "notes": "Reviewed blood sugar trends. Continue metformin." }
```

---

## 10. Prescriptions

Base path: `/patients/{patientId}/prescriptions`

Requires `can_prescribe = true` on the clinical rank to create.

### `POST /patients/{patientId}/prescriptions`

```json
{
  "medication_name": "Amlodipine",
  "medication_code": "AML-5",
  "dosage": "5mg",
  "frequency": "Once daily",
  "route": "oral",
  "duration_days": 30,
  "quantity": 30,
  "refills_allowed": 2,
  "prescribed_date": "2026-04-16",
  "start_date": "2026-04-17",
  "expires_date": "2026-07-16",
  "special_instructions": "Take in the morning with water. Avoid grapefruit."
}
```

`route` values: `oral`, `topical`, `injection`, `intravenous`, `inhalation`, `sublingual`, `rectal`, `other`.

**Status lifecycle:** `pending` → `partially_filled` → `filled` | `discontinued` | `expired`

---

### State-transition endpoints

| Method | Path | Who | Notes |
|---|---|---|---|
| `POST` | `…/{id}/fill` | Pharmacist | Body: `{ "quantity_dispensed": 30 }`. Partial fill → `partially_filled`. |
| `POST` | `…/{id}/refill` | `can_prescribe` staff | Decrements `refills_remaining`; resets status to `pending`. Errors: `NO_REFILLS`. |
| `POST` | `…/{id}/discontinue` | Prescriber / primary provider / super admin | Body: `{ "discontinuation_reason": "..." }` |

---

## 11. Lab Results

Base path: `/patients/{patientId}/lab-results`

Requires `can_order_labs = true` on the clinical rank to order.

### `POST /patients/{patientId}/lab-results`

```json
{
  "test_name": "HbA1c",
  "test_code": "HBA1C",
  "test_type": "blood",
  "priority": "routine",
  "ordered_date": "2026-04-16",
  "notes": "Patient fasted for 8 hours."
}
```

`test_type` values: `blood`, `urine`, `stool`, `imaging`, `biopsy`, `culture`, `other`.  
`priority` values: `routine`, `urgent`, `stat`.

**Status lifecycle:** `pending` → `in_progress` → `completed` | `cancelled`

---

### State-transition endpoints

| Method | Path | Who | Key body fields |
|---|---|---|---|
| `POST` | `…/{id}/record` | Lab technician | `results`, `interpretation`, `abnormal_flags`, `requires_followup`, `sample_collected_at` |
| `POST` | `…/{id}/review` | Ordering / primary provider | `interpretation`, `requires_followup` |
| `POST` | `…/{id}/cancel` | Ordering / primary provider / super admin | No body |

---

## 12. Medical Documents

Base path: `/patients/{patientId}/documents`

### `POST /patients/{patientId}/documents`

Upload a document. Use **multipart form** upload:

| Field | Type | Notes |
|---|---|---|
| `file` | binary | PDF, image, DOCX, etc. |
| `document_type` | enum | `discharge_summary`, `referral_letter`, `lab_report`, `imaging`, `consent`, `other` |
| `title` | string | Required |
| `notes` | string | Optional |

**Response `201` key fields:** `id`, `document_type`, `title`, `file_name`, `mime_type`, `file_size_bytes`.

### `DELETE /patients/{patientId}/documents/{id}`

Soft-deletes. Only the uploader, primary provider, or super admin.

---

## 13. Access Grants (Cross-Facility)

Allows a provider at one facility to access a patient registered at another. Both facilities use `X-Tenant-ID`.

### `POST /access-grants`

```json
{
  "global_patient_id": "uuid-global-patient",
  "access_level": "view_only",
  "data_types": ["demographics", "medications", "lab_results"],
  "reason": "Patient transferred. Need to review previous medication history.",
  "expires_at": "2026-05-16"
}
```

`access_level` values: `view_only`, `view_and_update`, `full_access`.  
`data_types` values: `demographics`, `medications`, `allergies`, `lab_results`, `prescriptions`, `appointments`, `medical_history`.

**Status lifecycle:** `pending` → `approved` | `denied` | `revoked` | `expired`

---

### `GET /access-grants`

Returns:
- `pending_my_approval` — grants where the caller's facility is the granting party
- `my_requests` — grants the caller requested

### State-transition endpoints

| Method | Path | Who | Key body fields |
|---|---|---|---|
| `POST` | `…/{id}/approve` | Granting facility staff | `notes` (optional) |
| `POST` | `…/{id}/deny` | Granting facility staff | `reason` (min 10 chars) |
| `POST` | `…/{id}/revoke` | Either party | `reason` (min 10 chars) |

### `GET /access-grants/{id}/audit`

Full lifecycle audit trail for a grant. Returns array of action events with `performed_by`, `authority_basis`, `notes`, `performed_at`.

---

## 14. Emergency Access

Break-glass access. Provider immediately accesses any patient record. The event is immutable and notifies the patient's primary provider.

**Requires:** `can_emergency_access = true` on **both** the membership flag and the clinical rank.

### `POST /emergency-access`

```json
{
  "master_patient_id": "uuid-global-patient",
  "emergency_type": "unconscious",
  "emergency_details": "Patient arrived unconscious via ambulance. Needs allergy history to avoid contraindications.",
  "data_accessed": ["allergies", "medications", "medical_history"]
}
```

`emergency_type` values: `life_threatening`, `unconscious`, `unable_to_consent`, `critical_care`.

**Response `201` key fields:** `id`, `patient_name`, `provider_name`, `facility_name`, `notified_provider_id`, `notification_status`, `reviewed_by_primary`, `needs_escalation`.

---

### `POST /emergency-access/{id}/review`

Primary provider or super admin reviews the event (prevents escalation).

```json
{ "review_notes": "Access was appropriate. Care was necessary." }
```

---

## 15. Referrals

Patient must have `allow_cross_tenant_access = true` (consent given) before a referral can be created.

### `POST /referrals`

```json
{
  "master_patient_id": "uuid-global-patient",
  "to_tenant_id": "uuid-receiving-facility",
  "referred_to_provider_id": "uuid-specialist",
  "specialty": "Cardiology",
  "urgency": "urgent",
  "reason": "Chest pain with ST-segment changes. Refer for urgent cardiology assessment.",
  "clinical_summary": "54-year-old male with T2DM and hypertension...",
  "relevant_history": "Previous CABG in 2019.",
  "current_medications": "Metformin 500mg BD, Amlodipine 5mg OD",
  "diagnostic_results": "ECG: ST depression in V4-V6.",
  "requires_follow_up": true,
  "follow_up_date": "2026-05-16"
}
```

`urgency` values: `routine`, `urgent`, `emergency`.

**Status lifecycle:** `pending` → `accepted` → `scheduled` → `completed` | `cancelled`

> Returns `422 SAME_FACILITY` if `to_tenant_id` matches the caller's facility.  
> Returns `422 PATIENT_CONSENT_REQUIRED` if cross-facility access is not enabled on the patient.

---

### State-transition endpoints

| Method | Path | Who | Key body fields |
|---|---|---|---|
| `POST` | `…/{id}/accept` | Receiving facility | No body |
| `POST` | `…/{id}/schedule` | Receiving facility | `appointment_date`, `appointment_location` |
| `POST` | `…/{id}/complete` | Receiving facility | `consultation_notes`, `recommendations` |
| `POST` | `…/{id}/cancel` | Referring facility | `reason` |

### Referral Messaging

| Method | Path | Description |
|---|---|---|
| `GET` | `/referrals/{id}/messages` | List messages on an open referral |
| `POST` | `/referrals/{id}/messages` | Send `{ "message": "..." }` |

Messaging is only available while the referral is open (`REFERRAL_CLOSED` if completed/cancelled).

---

## 16. Patient Portal

Read-only self-service portal for patients. Auth uses email + date of birth. **No `X-Tenant-ID` required.**

### `POST /portal/login`

```json
{
  "email": "chidi.okeke@gmail.com",
  "date_of_birth": "1985-03-12"
}
```

**Response `200`:** `{ token, patient: { id, full_name, primary_facility } }`

---

### Portal endpoints (all require portal token)

| Method | Path | Description |
|---|---|---|
| `GET` | `/portal/invitation/{token}` | Accept portal invite (activates access) |
| `GET` | `/portal/me` | Patient's own profile |
| `GET` | `/portal/appointments` | Upcoming appointments (read-only) |
| `GET` | `/portal/prescriptions` | Active prescriptions (read-only) |
| `GET` | `/portal/lab-results` | Completed + reviewed results (read-only) |
| `POST` | `/portal/appointment-requests` | Request an appointment (`preferred_date`, `preferred_time`, `reason`, `notes`) |
| `GET` | `/portal/messages` | Inbox |
| `POST` | `/portal/messages` | Send message: `{ subject, message }` |

### `POST /patients/{patientId}/portal-invite`

Clinician sends portal activation link to a patient.

```json
{
  "master_patient_id": "uuid-global-patient",
  "email": "chidi.okeke@gmail.com"
}
```

### Provider reply to patient message

`POST /patients/{patientId}/messages/{id}/reply`  
Body: `{ "message": "..." }`

---

## 17. Billing

### `GET /billing/plans` *(public — no auth)*

Returns available plans. Prices are in **minor currency units** (kobo for NGN, cents for USD/CAD, euro cents for EUR).

**Plan object key fields:** `id`, `name`, `slug`, `billing_cycle`, `prices` (`{ usd, eur, cad, ngn }`), `limits` (`max_facilities`, `max_staff`, `max_patients`), `features`.

---

### Subscription endpoints

| Method | Path | Description |
|---|---|---|
| `POST` | `/billing/organizations/{orgId}/subscriptions/trial` | Start trial: `{ plan_id, trial_days }` |
| `POST` | `/billing/organizations/{orgId}/subscriptions/{subId}/change-plan` | Switch plan: `{ plan_id }` |
| `DELETE` | `/billing/organizations/{orgId}/subscriptions/{subId}` | Cancel. Add `?immediately=true` for immediate cancellation; otherwise cancels at period end. |

**Subscription status values:** `trialing`, `active`, `past_due`, `cancelled`, `expired`

---

### Invoices & Payments

| Method | Path | Description |
|---|---|---|
| `GET` | `/billing/organizations/{orgId}/invoices/{id}` | Full invoice with items and payments |
| `POST` | `/billing/organizations/{orgId}/invoices/{id}/payments` | Record manual payment |

**Payment request:**
```json
{
  "amount": 12000000,
  "method": "bank_transfer",
  "reference": "TRF-2026041600123"
}
```

`method` values: `card`, `bank_transfer`, `ussd`, `mobile_money`, `paypal_wallet`, `other`.

---

## 18. Offline Sync

Requires `Authorization` + `X-Tenant-ID`.

### `POST /sync/register`

Call once per device after first login.

```json
{
  "device_id": "uuid-device",
  "device_type": "android",
  "app_version": "1.4.2"
}
```

`device_type` values: `android`, `ios` (inferred — use platform string).

### `POST /sync/push`

Push batched offline changes:

```json
{
  "records": [
    {
      "resource_type": "patient",
      "resource_id": "uuid-patient",
      "version": 3,
      "action": "update",
      "payload": { "medical_history": "Updated offline..." },
      "modified_at": "2026-04-15T22:30:00+01:00"
    }
  ]
}
```

**Response `200`:** `{ accepted, conflicts, rejected }`

### `GET /sync/pull?since={ISO timestamp}`

Pulls records changed since the given timestamp.

### `GET /sync/conflicts`

Lists unresolved conflicts.

### `POST /sync/conflicts/{id}/resolve`

`{ "resolution": "use_server" }` or `{ "resolution": "use_client" }`

---

## 19. Reporting & Compliance

Auth: Super admin or org admin only.

| Method | Path | Description |
|---|---|---|
| `GET` | `/reporting/organizations/{orgId}/dashboard` | Org-level stats: facilities, staff, patients, subscription status |
| `GET` | `/reporting/tenants/{tenantId}/dashboard` | Facility-level stats: patients, appointments, prescriptions, staff |
| `GET` | `/reporting/tenants/{tenantId}/compliance/audit-log` | Full audit log. Query params: `from`, `to` (ISO date), `user_id`, `action`, `per_page` |
| `GET` | `/reporting/tenants/{tenantId}/compliance/audit-summary` | Aggregated stats: access by authority type, emergency frequency, top users |
| `GET` | `/reporting/tenants/{tenantId}/compliance/emergency-access` | All emergency access events with review status |

All tenant-scoped reporting routes require `X-Tenant-ID`.

---

## 20. Utilities

### `GET /health` *(public)*

Ping the API. Returns `{ status: "ok", version: "2.0", timestamp }`.

### `GET /currencies` *(public)*

Returns supported currencies and live exchange rates relative to NGN base.

**Response `200`:**
```json
{
  "data": {
    "supported": ["NGN", "USD", "EUR", "CAD"],
    "base": "NGN",
    "rates": { "USD": 0.00062, "EUR": 0.00057, "CAD": 0.00086 },
    "last_updated": "2026-04-16T08:00:00+00:00"
  }
}
```

---

## 21. Error Code Reference

| `error_code` | HTTP | Trigger |
|---|---|---|
| `INVALID_CREDENTIALS` | 401 | Wrong email/password or portal login mismatch |
| `TWO_FACTOR_REQUIRED` | 401 | Account has 2FA enabled; restricted challenge token issued |
| `INVALID_CODE` | 422 | Incorrect TOTP or backup code |
| `WRONG_PASSWORD` | 422 | `current_password` mismatch on change-password |
| `ACCESS_DENIED` | 403 | No active grant for this patient |
| `INSUFFICIENT_RANK` | 403 | Clinical rank does not permit the action |
| `EMERGENCY_ACCESS_NOT_PERMITTED` | 403 | Membership flag or rank does not allow break-glass |
| `NOT_STAFF` | 403 | Endpoint is staff-only |
| `DUPLICATE_MEMBERSHIP` | 422 | User already has a membership at this facility |
| `INVALID_INVITATION` | 404/422 | Token not found, expired, or already used |
| `VERSION_CONFLICT` | 409 | Optimistic lock failure — refresh the record and retry |
| `SCHEDULING_CONFLICT` | 422 | Overlapping appointment for the same provider |
| `PRESCRIPTION_EXPIRED` | 422 | Attempting to fill a prescription past its expiry date |
| `NO_REFILLS` | 422 | `refills_remaining = 0` |
| `INVALID_STATUS` | 422 | Action not valid for current status (e.g. filling a discontinued prescription) |
| `INVALID_STATUS_TRANSITION` | 422 | Workflow violation (e.g. referral status) |
| `PATIENT_CONSENT_REQUIRED` | 422 | Patient has not enabled cross-facility access |
| `SAME_FACILITY` | 422 | Cannot refer a patient to the same facility |
| `ALREADY_REVIEWED` | 422 | Emergency access event or lab result already reviewed |
| `ALREADY_PAID` | 422 | Invoice already fully paid |
| `ALREADY_SUBSCRIBED` | 422 | Organization already has an active subscription |
| `NO_SUBSCRIPTION` | 404 | No active subscription found |
| `SEARCH_TOO_SHORT` | 422 | Patient search term under 2 characters |
| `NOT_ENABLED` | 422 | 2FA is not enabled on this account |
| `REFERRAL_CLOSED` | 422 | Cannot message on a completed or cancelled referral |

---

## 22. Enum Reference

### Gender
`male`, `female`, `other`, `prefer_not_to_say`

### Blood Type
`A+`, `A-`, `B+`, `B-`, `AB+`, `AB-`, `O+`, `O-`

### Allergy Severity
`mild`, `moderate`, `severe`, `life_threatening`

### Facility (Tenant) Type
`hospital`, `clinic`, `pharmacy`, `laboratory`, `diagnostic_center`, `dental`, `mental_health`, `physiotherapy`, `other`

### Staff Type
`doctor`, `nurse`, `pharmacist`, `lab_technician`, `admin`, `other`

### Appointment Type
`checkup`, `followup`, `emergency`, `consultation`, `procedure`, `vaccination`

### Appointment Status (update)
`confirmed`, `checked_in`, `in_progress`, `no_show`

### Prescription Route
`oral`, `topical`, `injection`, `intravenous`, `inhalation`, `sublingual`, `rectal`, `other`

### Prescription Status Lifecycle
`pending` → `partially_filled` → `filled` | `discontinued` | `expired`

### Lab Test Type
`blood`, `urine`, `stool`, `imaging`, `biopsy`, `culture`, `other`

### Lab Priority
`routine`, `urgent`, `stat`

### Lab Status Lifecycle
`pending` → `in_progress` → `completed` | `cancelled`

### Medical Document Type
`discharge_summary`, `referral_letter`, `lab_report`, `imaging`, `consent`, `other`

### Access Grant Level
`view_only`, `view_and_update`, `full_access`

### Access Grant Data Types
`demographics`, `medications`, `allergies`, `lab_results`, `prescriptions`, `appointments`, `medical_history`

### Access Grant Status Lifecycle
`pending` → `approved` | `denied` | `revoked` | `expired`

### Emergency Type
`life_threatening`, `unconscious`, `unable_to_consent`, `critical_care`

### Referral Urgency
`routine`, `urgent`, `emergency`

### Referral Status Lifecycle
`pending` → `accepted` → `scheduled` → `completed` | `cancelled`

### Subscription Status
`trialing`, `active`, `past_due`, `cancelled`, `expired`

### Payment Method
`card`, `bank_transfer`, `ussd`, `mobile_money`, `paypal_wallet`, `other`

### Sync Conflict Resolution
`use_server`, `use_client`

### Patient Audit — Access Authority
`primary_provider`, `intra_grant`, `cross_grant`, `emergency`, `system`, `denied`
