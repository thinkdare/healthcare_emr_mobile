# API Contract — Healthcare EMR Mobile ↔ Backend

> Generated from the live backend (Phase 8 complete, 409 tests passing).  
> Use this as the single source of truth when building or updating the Flutter app.

---

## Table of Contents

1. [Base URL & Headers](#1-base-url--headers)
2. [Response Envelope](#2-response-envelope)
3. [Breaking Changes vs. Current Flutter Code](#3-breaking-changes-vs-current-flutter-code)
4. [Authentication Flow](#4-authentication-flow)
5. [Two-Factor Authentication](#5-two-factor-authentication)
6. [Facility Selection](#6-facility-selection)
7. [Organizations & Tenants](#7-organizations--tenants)
8. [Staff Management](#8-staff-management)
9. [Patients](#9-patients)
10. [Appointments](#10-appointments)
11. [Prescriptions](#11-prescriptions)
12. [Lab Results](#12-lab-results)
13. [Medical Documents](#13-medical-documents)
14. [Access Grants & Emergency Access](#14-access-grants--emergency-access)
15. [Patient Referrals](#15-patient-referrals)
16. [Patient Portal](#16-patient-portal)
17. [Patient Messaging](#17-patient-messaging)
18. [Offline Sync](#18-offline-sync)
19. [Billing](#19-billing)
20. [Reporting](#20-reporting)
21. [Utilities](#21-utilities)
22. [Error Codes Reference](#22-error-codes-reference)
23. [Data Type Reference](#23-data-type-reference)

---

## 1. Base URL & Headers

```
Base URL:  http://10.0.2.2/api/v1      (Android emulator → localhost)
           http://localhost/api/v1       (iOS simulator / desktop)
```

> The backend runs on **port 80** via Nginx. The current Flutter `app_config.dart` points to port 8001 — **fix this**.

### Required headers (all requests)

```
Content-Type: application/json
Accept:       application/json
```

### Required headers (authenticated requests)

```
Authorization: Bearer <token>
```

### Required headers (clinical routes — any `/patients/*`, `/appointments`, `/prescriptions`, etc.)

```
Authorization: Bearer <token>
X-Tenant-ID:   <facility_uuid>
```

The `X-Tenant-ID` value is the `id` of the facility the staff member selected after login. This must be injected by the `ApiClient` interceptor from secure storage, just like the `Authorization` header. Store both `auth_token` and `active_tenant_id` in `FlutterSecureStorage`.

---

## 2. Response Envelope

Every response shares this structure:

```json
{
  "success": true,
  "message": "Human-readable status",
  "data": { ... }
}
```

Paginated responses wrap the list in `data` and add a `meta.pagination` object:

```json
{
  "success": true,
  "message": "Patients retrieved.",
  "data": [ ... ],
  "meta": {
    "pagination": {
      "current_page": 1,
      "per_page": 20,
      "total": 87,
      "last_page": 5,
      "from": 1,
      "to": 20,
      "has_more": true
    }
  }
}
```

Error response:

```json
{
  "success": false,
  "message": "You do not have access to this patient record.",
  "error": { "code": "FORBIDDEN" }
}
```

Validation error (422):

```json
{
  "success": false,
  "message": "Validation failed.",
  "errors": {
    "email": ["The email field is required."],
    "date_of_birth": ["The date of birth must be a date before today."]
  }
}
```

---

## 3. Breaking Changes vs. Current Flutter Code

These are issues in the **existing** Flutter project that must be fixed before the app will work with the current backend.

| # | File | Current (broken) | Correct |
|---|---|---|---|
| 1 | `app_config.dart` | Port `8001` | Port `80` |
| 2 | `auth_repository.dart` | `GET /auth/user` | `GET /auth/me` |
| 3 | `patient_repository.dart` | `GET /patients/search?q=` | `GET /patients?search=` |
| 4 | `patient_repository.dart` | `PATCH /patients/{id}` | `PUT /patients/{id}` |
| 5 | `auth_repository.dart` | Login sends `organization_id` | Login sends only `email` + `password` (org is selected post-login as a facility) |
| 6 | `models.dart` `LoginResponseModel` | Expects `user` + `provider` in `data` | `data` contains `user` + `token` + `token_type`; no `provider` key |
| 7 | `models.dart` `UserModel` | Has `userable_type` / `userable_id` | User has no polymorphic relation; staff details come from memberships |
| 8 | `models.dart` `ProviderModel` | Has `organization_id`, `license_number`, `provider_type` | These fields don't exist — use `StaffMembershipModel` instead |
| 9 | `api_client.dart` | Only injects `Authorization` header | Must also inject `X-Tenant-ID` header for clinical routes |
| 10 | `auth_repository.dart` `getCurrentUser` | Reads `data['userable']` as provider | `data` is flat — no `userable` key |

---

## 4. Authentication Flow

### POST /v1/auth/check-email

Pre-login step: look up which facilities a user belongs to.

**Request:**
```json
{ "email": "doctor@clinic.com" }
```

**Response `data`:**
```json
{
  "exists": true,
  "has_password": true,
  "facilities": [
    {
      "id": "uuid",
      "name": "City General Hospital",
      "slug": "city-general",
      "type": "hospital",
      "organization": { "id": "uuid", "name": "CityHealth Group" }
    }
  ]
}
```

If `exists` is `false`, the user has no account. If `facilities` is empty, the user exists but has no active memberships.

---

### POST /v1/auth/login

**Request:**
```json
{
  "email": "doctor@clinic.com",
  "password": "secret"
}
```

**Response `data` — normal login (no 2FA):**
```json
{
  "token": "1|abcdef...",
  "token_type": "Bearer",
  "user": {
    "id": "uuid",
    "email": "doctor@clinic.com",
    "user_type": "staff",
    "two_factor_enabled": false,
    "created_at": "2026-01-01T00:00:00Z",
    "updated_at": "2026-01-01T00:00:00Z"
  }
}
```

**Response `data` — when 2FA is enabled:**
```json
{
  "two_factor_required": true,
  "challenge_token": "2|xxxxxx...",
  "token_type": "Bearer"
}
```

The `challenge_token` has ability `two-factor` and expires in 10 minutes. Use it as the `Authorization` header when calling `POST /auth/2fa/verify`. See [Section 5](#5-two-factor-authentication).

**After a successful login (no 2FA) or after 2FA verify:**
1. Store `token` in `FlutterSecureStorage` as `auth_token`.
2. Call `GET /auth/facilities` to show the facility picker.
3. After the user picks a facility, store the facility `id` as `active_tenant_id`.
4. All subsequent clinical API calls must include `X-Tenant-ID: <active_tenant_id>`.

---

### GET /v1/auth/me

Returns the current user's profile.

**Response `data`:**
```json
{
  "id": "uuid",
  "email": "doctor@clinic.com",
  "user_type": "staff",
  "two_factor_enabled": true,
  "preferences": { "theme": "light", "notifications": true },
  "created_at": "2026-01-01T00:00:00Z",
  "updated_at": "2026-01-01T00:00:00Z"
}
```

---

### POST /v1/auth/logout

No request body. Revokes the current token server-side. Always clear local storage regardless of response.

---

### POST /v1/auth/logout-all

No request body. Revokes **all** tokens for this user (use for "sign out everywhere").

---

### POST /v1/auth/refresh

Rotates the token. Requires a token with `refresh` ability (issued alongside the main token).

**Response `data`:** Same shape as login `data`.

---

### PUT /v1/auth/password

**Request:**
```json
{
  "current_password": "old",
  "password": "newpassword",
  "password_confirmation": "newpassword"
}
```

---

### PUT /v1/auth/preferences

**Request:** any key-value pairs to store as preferences:
```json
{ "theme": "dark", "notifications": true }
```

---

## 5. Two-Factor Authentication

### POST /v1/auth/2fa/setup

Initiates TOTP setup. Returns a secret and QR code URI.

**Response `data`:**
```json
{
  "secret": "BASE32SECRET",
  "qr_uri": "otpauth://totp/EMR:doctor@clinic.com?secret=BASE32SECRET&issuer=EMR",
  "manual_entry_key": "BASE 32SE CRET"
}
```

Show the `qr_uri` as a QR code (use `qr_flutter` package) and the `manual_entry_key` as a fallback.

---

### POST /v1/auth/2fa/enable

Confirms setup with the first TOTP code.

**Request:**
```json
{ "code": "123456" }
```

**Response `data`:**
```json
{
  "enabled": true,
  "backup_codes": [
    "XXXX-XXXX", "XXXX-XXXX", "XXXX-XXXX", "XXXX-XXXX",
    "XXXX-XXXX", "XXXX-XXXX", "XXXX-XXXX", "XXXX-XXXX"
  ]
}
```

Store or display backup codes — they are shown **only once**.

---

### POST /v1/auth/2fa/verify

Exchange a 2FA challenge token for a full session token.

**Authorization header:** `Bearer <challenge_token>` (the short-lived one from login)

**Request:**
```json
{ "code": "123456" }
```

Accepts both a 6-digit TOTP code or an `XXXX-XXXX` backup code.

**Response `data`:** Same shape as normal login `data` (full `token` + `user`).

---

### DELETE /v1/auth/2fa

Disables 2FA. **Request:**
```json
{ "code": "123456" }
```

---

### GET /v1/auth/2fa/backup-codes

**Response `data`:**
```json
{ "remaining_count": 6 }
```

---

### POST /v1/auth/2fa/backup-codes

Regenerates all 8 backup codes (old ones are invalidated).

**Request:**
```json
{ "code": "123456" }
```

**Response `data`:**
```json
{
  "backup_codes": ["XXXX-XXXX", ...]
}
```

---

## 6. Facility Selection

### GET /v1/auth/facilities

Returns facilities the current user has an active membership at.

**Response `data`:** array of facility objects:
```json
[
  {
    "id": "uuid",
    "name": "City General Hospital",
    "slug": "city-general",
    "type": "hospital",
    "address": "123 Main St",
    "phone": "+234...",
    "organization": {
      "id": "uuid",
      "name": "CityHealth Group"
    },
    "membership": {
      "id": "uuid",
      "staff_type": "doctor",
      "is_primary": true,
      "clinical_rank": {
        "id": "uuid",
        "name": "Consultant",
        "hierarchy_level": 800,
        "can_prescribe": true,
        "can_order_labs": true,
        "can_approve_access_grants": true,
        "can_perform_emergency_access": true
      }
    }
  }
]
```

After the user selects a facility, call `POST /auth/facility` to set it as active server-side, then store the facility `id` as `active_tenant_id` locally.

---

### POST /v1/auth/facility

Switch active facility context server-side.

**Request:**
```json
{ "tenant_id": "uuid" }
```

**Response `data`:**
```json
{
  "tenant_id": "uuid",
  "tenant_name": "City General Hospital",
  "membership": { ... same membership shape as above ... }
}
```

Store the returned `membership` — it tells you what the user can do in this facility (capabilities from `clinical_rank`, `staff_type`, `can_emergency_access`).

---

## 7. Organizations & Tenants

### GET /v1/organizations

**Query params:** `?search=name&page=1&per_page=20`

**Response:** paginated list. Each item:
```json
{
  "id": "uuid",
  "name": "CityHealth Group",
  "type": "hospital_group",
  "address": "...",
  "phone": "...",
  "email": "...",
  "tax_id": "...",
  "is_active": true,
  "facilities_count": 3,
  "created_at": "2026-01-01T00:00:00Z"
}
```

### POST /v1/organizations

**Request:**
```json
{
  "name": "New Clinic Group",
  "type": "clinic",
  "address": "123 Street",
  "phone": "+2348000000000",
  "email": "admin@newclinic.com",
  "tax_id": "optional"
}
```

Valid `type` values: `hospital`, `clinic`, `pharmacy`, `laboratory`, `diagnostic_center`, `hospital_group`, `other`

### GET/PUT/DELETE /v1/organizations/{id}

PUT uses same fields as POST (all optional on update).

### GET /v1/organizations/{id}/stats

Returns counts: `total_facilities`, `total_staff`, `total_patients`, `active_subscriptions`.

---

### GET /v1/tenants

Returns facilities. Each item:
```json
{
  "id": "uuid",
  "name": "City General Hospital",
  "slug": "city-general",
  "type": "hospital",
  "address": "...",
  "phone": "...",
  "email": "...",
  "organization_id": "uuid",
  "is_active": true,
  "db_provisioned": true,
  "created_at": "2026-01-01T00:00:00Z"
}
```

### POST /v1/tenants

**Request:**
```json
{
  "name": "New Branch",
  "type": "clinic",
  "address": "...",
  "phone": "...",
  "email": "...",
  "organization_id": "uuid"
}
```

Valid `type`: `hospital`, `clinic`, `pharmacy`, `laboratory`, `diagnostic_center`, `other`

---

## 8. Staff Management

### GET /v1/staff/invitation?token={token}

Validates an invitation link before showing the registration form.

**Response `data`:**
```json
{
  "valid": true,
  "token": "abc123",
  "email": "newdoctor@clinic.com",
  "tenant": { "id": "uuid", "name": "City General Hospital" },
  "invited_as": "doctor",
  "expires_at": "2026-05-01T00:00:00Z"
}
```

---

### POST /v1/staff/register

Complete registration via an invitation token.

**Request:**
```json
{
  "token": "abc123",
  "name": "Dr. Jane Smith",
  "password": "SecurePass123!",
  "password_confirmation": "SecurePass123!"
}
```

**Response `data`:** Same shape as login `data` (token + user).

---

### POST /v1/staff/invite *(requires X-Tenant-ID)*

Invite a new staff member to the active facility.

**Request:**
```json
{
  "email": "newstaff@clinic.com",
  "staff_type": "nurse",
  "clinical_rank_id": "uuid"
}
```

Valid `staff_type`: `doctor`, `nurse`, `pharmacist`, `lab_tech`, `radiologist`, `physiotherapist`, `dentist`, `admin`, `other`

---

### GET /v1/staff/memberships

List the current user's memberships across all facilities.

**Response `data`:** array — same membership shape shown in Section 6.

---

### GET/PUT/DELETE /v1/staff/memberships/{id}

PUT request fields: `staff_type`, `clinical_rank_id`, `is_active`

---

### GET /v1/clinical-ranks

**Response `data`:** array:
```json
[
  {
    "id": "uuid",
    "name": "Consultant",
    "hierarchy_level": 800,
    "can_prescribe": true,
    "can_order_labs": true,
    "can_approve_access_grants": true,
    "can_perform_emergency_access": true,
    "organization_id": null
  }
]
```

`organization_id` is `null` for system-default ranks.

---

## 9. Patients

> All patient endpoints require `X-Tenant-ID` header.

### GET /v1/patients

**Query params:**

| Param | Type | Notes |
|---|---|---|
| `search` | string | Searches by name, email, or phone. Min 2 chars. |
| `page` | int | Default 1 |
| `per_page` | int | Default 20 |
| `fields` | string | Sparse fieldsets: `id,mrn,full_name,gender` |

**Response:** paginated. Each patient (list view):
```json
{
  "id": "uuid",
  "mrn": "CITY-2026-00042",
  "full_name": "John Doe",
  "first_name": "John",
  "last_name": "Doe",
  "gender": "male",
  "blood_type": "O+",
  "is_active": true,
  "primary_provider_id": "uuid",
  "version": 3
}
```

---

### POST /v1/patients

**Request:**
```json
{
  "first_name": "John",
  "last_name": "Doe",
  "date_of_birth": "1990-05-15",
  "gender": "male",
  "blood_type": "O+",
  "phone": "+2348012345678",
  "email": "john@example.com",
  "address": "123 Lagos Street",
  "emergency_contact_name": "Jane Doe",
  "emergency_contact_phone": "+2348098765432",
  "allergies": [
    { "name": "Penicillin", "severity": "severe" }
  ],
  "current_medications": [
    { "name": "Metformin", "dosage": "500mg" }
  ],
  "chronic_conditions": ["Type 2 Diabetes", "Hypertension"],
  "insurance_provider": "NHIS",
  "insurance_number": "NH-12345",
  "medical_history": "Previous appendectomy in 2015."
}
```

**Required fields:** `first_name`, `last_name`, `date_of_birth`, `gender`

Valid `gender`: `male`, `female`, `other`, `prefer_not_to_say`

Valid `blood_type`: `A+`, `A-`, `B+`, `B-`, `AB+`, `AB-`, `O+`, `O-`

Valid `allergies[].severity`: `mild`, `moderate`, `severe`, `life_threatening`

**Response `data`:** full patient detail (see GET /{id}).

---

### GET /v1/patients/{id}

**Query params:** `?fields=id,mrn,full_name` (optional sparse fieldsets)

**Response `data`:**
```json
{
  "id": "uuid",
  "mrn": "CITY-2026-00042",
  "full_name": "John Doe",
  "first_name": "John",
  "last_name": "Doe",
  "date_of_birth": "1990-05-15",
  "gender": "male",
  "blood_type": "O+",
  "phone": "+2348012345678",
  "email": "john@example.com",
  "address": "123 Lagos Street",
  "emergency_contact_name": "Jane Doe",
  "emergency_contact_phone": "+2348098765432",
  "allergies": [
    { "name": "Penicillin", "severity": "severe" }
  ],
  "current_medications": [
    { "name": "Metformin", "dosage": "500mg" }
  ],
  "chronic_conditions": ["Type 2 Diabetes"],
  "insurance_provider": "NHIS",
  "insurance_number": "NH-12345",
  "medical_history": "...",
  "patient_portal_enabled": false,
  "global_patient_id": "uuid",
  "is_active": true,
  "primary_provider_id": "uuid",
  "version": 3,
  "last_synced_at": null,
  "created_at": "2026-01-01T00:00:00Z",
  "updated_at": "2026-01-15T00:00:00Z"
}
```

---

### PUT /v1/patients/{id}

Same fields as POST (all optional). Include `version` for optimistic locking conflict detection.

**Request:**
```json
{
  "phone": "+2348099999999",
  "version": 3
}
```

**409 response** when `version` doesn't match server:
```json
{
  "success": false,
  "message": "Record has been modified by another session. Refresh and retry.",
  "error": { "code": "VERSION_CONFLICT" }
}
```

---

### DELETE /v1/patients/{id}

Soft-deactivates. Only the primary provider or super admin can call this.

---

### GET /v1/patients/{id}/audit-log

**Query params:** `?page=1&per_page=50`

**Response:** paginated. Each entry:
```json
{
  "id": "uuid",
  "action": "viewed",
  "resource_type": "full_record",
  "access_authority": "primary_provider",
  "user_id": "uuid",
  "facility_context": "city-general",
  "was_emergency": false,
  "was_offline": false,
  "ip_address": "192.168.1.1",
  "accessed_at": "2026-04-10T14:22:00Z"
}
```

---

## 10. Appointments

> All require `X-Tenant-ID`.

### GET /v1/patients/{patientId}/appointments

**Query params:** `?status=scheduled&page=1&per_page=20`

Valid `status`: `scheduled`, `completed`, `cancelled`, `no_show`

**Response:** paginated. Each item:
```json
{
  "id": "uuid",
  "patient_id": "uuid",
  "provider_id": "uuid",
  "scheduled_at": "2026-04-15T09:00:00Z",
  "duration_minutes": 30,
  "appointment_type": "consultation",
  "status": "scheduled",
  "notes": "Follow-up for hypertension",
  "completed_at": null,
  "cancelled_at": null,
  "cancellation_reason": null,
  "version": 1,
  "created_at": "2026-04-10T00:00:00Z"
}
```

---

### POST /v1/patients/{patientId}/appointments

**Request:**
```json
{
  "scheduled_at": "2026-04-15T09:00:00Z",
  "duration_minutes": 30,
  "appointment_type": "consultation",
  "notes": "Follow-up"
}
```

Valid `appointment_type`: `consultation`, `follow_up`, `procedure`, `lab_visit`, `emergency`, `other`

Returns `409 SCHEDULING_CONFLICT` if the provider already has an appointment in that time slot.

---

### PUT /v1/patients/{patientId}/appointments/{id}

Same fields as POST (all optional) + `version`.

---

### POST /v1/patients/{patientId}/appointments/{id}/cancel

**Request:**
```json
{ "reason": "Patient requested cancellation" }
```

---

### POST /v1/patients/{patientId}/appointments/{id}/complete

No request body. Marks appointment as complete and sets `completed_at`.

---

## 11. Prescriptions

> All require `X-Tenant-ID`. Creating a prescription requires `can_prescribe` on the staff member's clinical rank.

### GET /v1/patients/{patientId}/prescriptions

**Query params:** `?status=active&page=1&per_page=20`

Valid `status`: `active`, `filled`, `refilled`, `discontinued`, `expired`

**Response:** paginated. Each item:
```json
{
  "id": "uuid",
  "patient_id": "uuid",
  "prescribed_by_id": "uuid",
  "medication_name": "Metformin",
  "dosage": "500mg",
  "frequency": "twice daily",
  "route": "oral",
  "duration_days": 30,
  "quantity": 60,
  "refills_remaining": 2,
  "instructions": "Take with food",
  "status": "active",
  "prescribed_at": "2026-04-01T00:00:00Z",
  "filled_at": null,
  "discontinued_at": null,
  "discontinuation_reason": null,
  "version": 1
}
```

---

### POST /v1/patients/{patientId}/prescriptions

**Request:**
```json
{
  "medication_name": "Metformin",
  "dosage": "500mg",
  "frequency": "twice daily",
  "route": "oral",
  "duration_days": 30,
  "quantity": 60,
  "refills_remaining": 2,
  "instructions": "Take with food"
}
```

Valid `route`: `oral`, `intravenous`, `intramuscular`, `topical`, `inhalation`, `sublingual`, `other`

---

### POST /v1/patients/{patientId}/prescriptions/{id}/fill

No body. Sets `status = filled`.

### POST /v1/patients/{patientId}/prescriptions/{id}/refill

No body. Decrements `refills_remaining`, sets `status = refilled`.

### POST /v1/patients/{patientId}/prescriptions/{id}/discontinue

**Request:**
```json
{ "reason": "Side effects reported" }
```

---

## 12. Lab Results

> Requires `X-Tenant-ID`. Creating requires `can_order_labs` on rank.

### GET /v1/patients/{patientId}/lab-results

**Query params:** `?status=pending&page=1`

Valid `status`: `ordered`, `sample_collected`, `processing`, `completed`, `reviewed`, `cancelled`

**Response:** paginated. Each item:
```json
{
  "id": "uuid",
  "patient_id": "uuid",
  "ordered_by_id": "uuid",
  "test_name": "Full Blood Count",
  "test_code": "FBC",
  "urgency": "routine",
  "status": "ordered",
  "ordered_at": "2026-04-01T00:00:00Z",
  "sample_collected_at": null,
  "result_value": null,
  "result_unit": null,
  "reference_range": null,
  "is_abnormal": null,
  "notes": null,
  "reviewed_by_id": null,
  "reviewed_at": null,
  "version": 1
}
```

---

### POST /v1/patients/{patientId}/lab-results

**Request:**
```json
{
  "test_name": "Full Blood Count",
  "test_code": "FBC",
  "urgency": "routine",
  "notes": "Fasting sample required"
}
```

Valid `urgency`: `routine`, `urgent`, `stat`

---

### POST /v1/patients/{patientId}/lab-results/{id}/record

Record the actual result.

**Request:**
```json
{
  "result_value": "13.5",
  "result_unit": "g/dL",
  "reference_range": "12.0–16.0",
  "is_abnormal": false,
  "notes": "Within normal range"
}
```

---

### POST /v1/patients/{patientId}/lab-results/{id}/review

Clinician signs off on the result.

**Request:**
```json
{ "notes": "Reviewed — no action needed" }
```

---

## 13. Medical Documents

> Requires `X-Tenant-ID`. Upload is multipart/form-data.

### GET /v1/patients/{patientId}/documents

**Response:** paginated. Each item:
```json
{
  "id": "uuid",
  "patient_id": "uuid",
  "uploaded_by_id": "uuid",
  "document_type": "lab_report",
  "title": "MRI Scan 2026-04-01",
  "file_name": "mri_scan.pdf",
  "mime_type": "application/pdf",
  "file_size_bytes": 204800,
  "is_confidential": false,
  "uploaded_at": "2026-04-01T12:00:00Z"
}
```

---

### POST /v1/patients/{patientId}/documents

**Content-Type:** `multipart/form-data`

**Form fields:**

| Field | Type | Required | Notes |
|---|---|---|---|
| `file` | file | Yes | Max 50 MB |
| `document_type` | string | Yes | See valid values below |
| `title` | string | Yes | Max 255 chars |
| `is_confidential` | bool | No | Default false |

Valid `document_type`: `lab_report`, `imaging`, `referral_letter`, `discharge_summary`, `consent_form`, `prescription`, `insurance`, `other`

---

### GET /v1/patients/{patientId}/documents/{id}

Returns the document record **plus** a time-limited signed URL:
```json
{
  "id": "uuid",
  "title": "MRI Scan",
  "download_url": "https://...",
  "url_expires_at": "2026-04-10T15:30:00Z"
}
```

The `download_url` expires after 5 minutes. Open it in an in-app WebView or download directly.

---

### DELETE /v1/patients/{patientId}/documents/{id}

Only the uploader, primary provider, or super admin can delete.

---

## 14. Access Grants & Emergency Access

> Requires `X-Tenant-ID`.

### POST /v1/access-grants

Request access to a patient at another facility.

**Request:**
```json
{
  "patient_global_id": "uuid",
  "target_tenant_id": "uuid",
  "access_level": "view_only",
  "reason": "Specialist consultation",
  "expires_at": "2026-05-01T00:00:00Z"
}
```

Valid `access_level`: `view_only`, `read_write`, `full`

---

### POST /v1/access-grants/{id}/approve

No body. Approves a pending grant.

### POST /v1/access-grants/{id}/deny

**Request:** `{ "reason": "Not clinically justified" }`

### POST /v1/access-grants/{id}/revoke

**Request:** `{ "reason": "Treatment concluded" }`

---

### POST /v1/emergency-access

Trigger break-glass access.

**Request:**
```json
{
  "master_patient_id": "uuid",
  "emergency_type": "life_threatening",
  "justification": "Patient unconscious, need history for treatment"
}
```

Valid `emergency_type`: `life_threatening`, `unconscious`, `unable_to_consent`, `critical_care`, `other`

**Rate limit:** 3 requests per 15 minutes per user.

---

### POST /v1/emergency-access/{id}/review

Primary provider acknowledges and reviews the break-glass access.

**Request:**
```json
{
  "review_notes": "Access was appropriate given the emergency",
  "access_was_appropriate": true
}
```

---

## 15. Patient Referrals

> Requires `X-Tenant-ID`.

### POST /v1/referrals

**Request:**
```json
{
  "patient_global_id": "uuid",
  "target_tenant_id": "uuid",
  "referral_reason": "Specialist cardiology consultation",
  "urgency": "urgent",
  "clinical_notes": "Patient has new-onset chest pain...",
  "requested_appointment_date": "2026-04-20"
}
```

Valid `urgency`: `routine`, `urgent`, `emergency`

---

### GET /v1/referrals/{id}

**Response `data`:**
```json
{
  "id": "uuid",
  "status": "pending",
  "patient_global_id": "uuid",
  "source_tenant_id": "uuid",
  "target_tenant_id": "uuid",
  "referral_reason": "...",
  "urgency": "urgent",
  "clinical_notes": "...",
  "requested_appointment_date": "2026-04-20",
  "status_history": [
    { "status": "pending", "changed_at": "2026-04-10T10:00:00Z", "by_user_id": "uuid" }
  ],
  "created_at": "2026-04-10T10:00:00Z"
}
```

Valid `status`: `pending`, `accepted`, `scheduled`, `completed`, `cancelled`

---

### POST /v1/referrals/{id}/accept / schedule / complete / cancel

All accept an optional `{ "notes": "..." }` body.

`schedule` additionally accepts `{ "scheduled_at": "2026-04-20T09:00:00Z" }`.

---

## 16. Patient Portal

> These endpoints have a different auth model — portal tokens are scoped to a single patient.

### POST /v1/portal/login

Passwordless — patient logs in with email and date of birth.

**Request:**
```json
{
  "email": "patient@example.com",
  "date_of_birth": "1990-05-15"
}
```

**Response `data`:**
```json
{
  "token": "3|portaltoken...",
  "token_type": "Bearer",
  "patient": {
    "id": "uuid",
    "full_name": "John Doe",
    "email": "patient@example.com"
  }
}
```

---

### GET /v1/portal/invitation/{token}

Accept a portal invitation. No auth required.

**Response `data`:** confirmation message + patient info.

---

### GET /v1/portal/me

Returns the logged-in patient's own record (same shape as `GET /patients/{id}` detail view).

### GET /v1/portal/appointments

Returns the patient's upcoming/past appointments.

### GET /v1/portal/prescriptions

Returns active prescriptions.

### GET /v1/portal/lab-results

Returns reviewed lab results only.

### POST /v1/portal/appointment-requests

**Request:**
```json
{
  "preferred_date": "2026-04-20",
  "preferred_time": "morning",
  "reason": "Routine check-up"
}
```

---

## 17. Patient Messaging

### Provider side (requires `X-Tenant-ID`)

**GET /v1/patients/{patientId}/messages** — provider inbox for this patient

**POST /v1/patients/{patientId}/messages/{id}/reply**

```json
{ "body": "Your results look normal. No action required." }
```

### Portal side (portal token)

**GET /v1/portal/messages** — patient's message inbox

**POST /v1/portal/messages** — send new message to provider

```json
{
  "subject": "Question about my medication",
  "body": "Is it safe to take ibuprofen with my current medications?"
}
```

**GET /v1/portal/messages/{id}** — read a message (marks it as read)

---

## 18. Offline Sync

> Requires `X-Tenant-ID`.

The sync system lets the app work offline and reconcile changes later.

### POST /v1/sync/register

Register this device for sync.

**Request:**
```json
{
  "device_id": "unique-device-uuid",
  "device_name": "iPhone 15 Pro",
  "platform": "ios",
  "app_version": "1.0.0"
}
```

---

### POST /v1/sync/push

Push locally-made changes to the server.

**Request:**
```json
{
  "device_id": "uuid",
  "changes": [
    {
      "resource_type": "patient",
      "resource_id": "patient-uuid",
      "action": "update",
      "payload": { "phone": "+2348099999999" },
      "client_version": 3,
      "changed_at": "2026-04-10T08:00:00Z"
    }
  ]
}
```

Valid `resource_type`: `patient`, `appointment`, `prescription`, `lab_result`

Valid `action`: `create`, `update`, `delete`

**Response `data`:**
```json
{
  "accepted": ["patient-uuid"],
  "conflicts": [
    {
      "resource_id": "other-uuid",
      "conflict_id": "conflict-uuid",
      "server_version": 5,
      "client_version": 3
    }
  ]
}
```

---

### GET /v1/sync/pull

Fetch server changes since last sync.

**Query params:** `?since=2026-04-09T00:00:00Z&device_id=uuid`

**Response `data`:**
```json
{
  "changes": [
    {
      "resource_type": "patient",
      "resource_id": "uuid",
      "action": "update",
      "payload": { ... },
      "server_version": 5,
      "changed_at": "2026-04-10T09:00:00Z"
    }
  ],
  "server_time": "2026-04-10T10:00:00Z"
}
```

---

### GET /v1/sync/conflicts

**Response:** paginated list of unresolved conflicts.

---

### POST /v1/sync/conflicts/{id}/resolve

**Request:**
```json
{
  "resolution": "client_wins",
  "merged_payload": null
}
```

Valid `resolution`: `client_wins`, `server_wins`, `merged`, `manual`

If `resolution` is `merged`, provide `merged_payload` with the reconciled data.

---

## 19. Billing

### Public (no auth)

**GET /v1/billing/plans** — list all subscription plans

**GET /v1/billing/plans/{id}** — plan detail

Each plan:
```json
{
  "id": "uuid",
  "name": "Professional",
  "slug": "professional",
  "price_usd": 199.00,
  "billing_period": "monthly",
  "max_facilities": 5,
  "max_staff_per_facility": 50,
  "features": ["2FA", "Offline Sync", "Patient Portal", "..."],
  "is_active": true
}
```

---

### Authenticated billing (requires auth)

**GET /v1/billing/organizations/{orgId}/subscription**

```json
{
  "id": "uuid",
  "plan": { "name": "Professional", "slug": "professional" },
  "status": "active",
  "trial_ends_at": null,
  "current_period_end": "2026-05-01T00:00:00Z",
  "currency": "USD",
  "amount": 199.00
}
```

**POST /v1/billing/organizations/{orgId}/subscriptions/trial**

```json
{ "plan_id": "uuid", "currency": "NGN" }
```

**POST /v1/billing/organizations/{orgId}/subscriptions/{subId}/activate**

```json
{ "payment_method": "card", "payment_reference": "ref_abc123" }
```

**POST /v1/billing/organizations/{orgId}/subscriptions/{subId}/change-plan**

```json
{ "plan_id": "new-plan-uuid" }
```

**POST /v1/billing/organizations/{orgId}/invoices/{id}/payments**

```json
{
  "amount": 199.00,
  "currency": "USD",
  "payment_method": "card",
  "reference": "txn_abc123",
  "notes": "Monthly payment"
}
```

Valid `payment_method`: `card`, `bank_transfer`, `ussd`, `mobile_money`, `paypal_wallet`, `other`

---

## 20. Reporting

> Super admin and org admin only. Clinical staff receive 403.

### GET /v1/reporting/organizations/{orgId}/dashboard

Aggregate stats across all facilities in the org. Served from Redis cache (nightly).

**Response `data`:**
```json
{
  "total_facilities": 3,
  "total_staff": 47,
  "total_patients": 1204,
  "total_appointments_this_month": 342,
  "active_subscriptions": 2
}
```

---

### GET /v1/reporting/tenants/{tenantId}/compliance/audit-log *(requires X-Tenant-ID)*

**Query params:**

| Param | Type | Notes |
|---|---|---|
| `action` | string | Filter by action type |
| `user_id` | uuid | Filter by who accessed |
| `patient_id` | uuid | Filter by patient |
| `from` | date | e.g. `2026-04-01` |
| `to` | date | e.g. `2026-04-30` |
| `emergency_only` | bool | Only break-glass accesses |
| `page` | int | |
| `per_page` | int | Max 100 |

**Response:** paginated audit log entries (same shape as patient audit log in Section 9).

---

### GET /v1/reporting/tenants/{tenantId}/compliance/audit-summary *(requires X-Tenant-ID)*

**Query params:** `?from=2026-04-01&to=2026-04-30`

**Response `data`:**
```json
{
  "by_action": { "viewed": 420, "updated": 38, "created": 12 },
  "by_authority": { "primary_provider": 380, "intra_grant": 62, "emergency": 8 }
}
```

---

## 21. Utilities

### GET /v1/health

No auth. Returns `{ "status": "ok", "version": "2.0" }`.

### GET /v1/currencies

No auth. Returns supported currencies and exchange rates:

```json
{
  "supported": ["USD", "EUR", "NGN", "CAD"],
  "base": "USD",
  "rates": { "EUR": 0.92, "NGN": 1580.0, "CAD": 1.37 },
  "last_updated": "2026-04-10T00:00:00Z"
}
```

---

## 22. Error Codes Reference

| Code | HTTP | Meaning |
|---|---|---|
| `NOT_FOUND` | 404 | Resource does not exist |
| `FORBIDDEN` | 403 | Authenticated but not authorised |
| `UNAUTHORIZED` | 401 | Token missing or invalid |
| `VERSION_CONFLICT` | 409 | Optimistic lock failed — refresh and retry |
| `SCHEDULING_CONFLICT` | 409 | Appointment time slot already booked |
| `SEARCH_TOO_SHORT` | 422 | Search term must be ≥ 2 characters |
| `VALIDATION_ERROR` | 422 | Field validation failed (see `errors` key) |
| `TWO_FACTOR_REQUIRED` | 200 | Login succeeded but 2FA verification needed |
| `RATE_LIMITED` | 429 | Too many requests |

---

## 23. Data Type Reference

### Enumerations

```
gender:              male | female | other | prefer_not_to_say
blood_type:          A+ | A- | B+ | B- | AB+ | AB- | O+ | O-
allergy_severity:    mild | moderate | severe | life_threatening
staff_type:          doctor | nurse | pharmacist | lab_tech | radiologist
                     physiotherapist | dentist | admin | other
appointment_type:    consultation | follow_up | procedure | lab_visit | emergency | other
appointment_status:  scheduled | completed | cancelled | no_show
prescription_status: active | filled | refilled | discontinued | expired
prescription_route:  oral | intravenous | intramuscular | topical
                     inhalation | sublingual | other
lab_urgency:         routine | urgent | stat
lab_status:          ordered | sample_collected | processing
                     completed | reviewed | cancelled
doc_type:            lab_report | imaging | referral_letter | discharge_summary
                     consent_form | prescription | insurance | other
access_level:        view_only | read_write | full
emergency_type:      life_threatening | unconscious | unable_to_consent
                     critical_care | other
referral_urgency:    routine | urgent | emergency
referral_status:     pending | accepted | scheduled | completed | cancelled
payment_method:      card | bank_transfer | ussd | mobile_money | paypal_wallet | other
sync_action:         create | update | delete
sync_resolution:     client_wins | server_wins | merged | manual
org_type:            hospital | clinic | pharmacy | laboratory
                     diagnostic_center | hospital_group | other
```

### Date / Time

All timestamps are ISO 8601 UTC: `2026-04-10T14:22:00Z`

All date-only fields (e.g. `date_of_birth`, `requested_appointment_date`) use `YYYY-MM-DD`.

### IDs

All IDs are UUID v4 strings.

### Pagination defaults

`page=1`, `per_page=20`. Max `per_page` is 100 for most endpoints.
