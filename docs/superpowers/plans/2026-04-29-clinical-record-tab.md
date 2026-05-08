# Clinical Record Tab — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add six new clinical resources (VitalSigns, Diagnoses, ProblemList, Procedures, Immunizations, DailyRosterEntry) to the Flutter mobile app, matching the backend APIs shipped in the last backend sprint, and rewire the RosterScreen to use the new dedicated roster endpoint.

**Architecture:** New models + repository methods are added to existing files following established patterns (hand-written `fromJson`, patient-scoped endpoints, same `{success, data}` envelope). A new "Clinical Record" tab (tab index 5) is added to `PatientDetailScreen` consolidating all five new clinical resources in collapsible sections. RosterScreen replaces its appointment-aggregation hack with direct calls to the new roster API.

**Tech Stack:** Flutter 3, Dart, Provider (ChangeNotifier), Dio, existing `ApiClient`, `clinical_models.dart` pattern (hand-written fromJson, no build_runner).

---

## File Map

| Action | File | What changes |
|---|---|---|
| **Create** | `lib/data/models/clinical_record_models.dart` | VitalSignModel, DiagnosisModel, ProblemListModel, ProcedureModel, ImmunizationModel, RosterEntryModel |
| **Modify** | `lib/data/models/clinical_models.dart` | Add `wardId` to Appointment, Prescription, LabResult; add `codingSystem` to Prescription |
| **Modify** | `lib/data/repositories/clinical_repository.dart` | Add list/create/delete methods for all 6 new resources |
| **Modify** | `lib/data/providers/clinical_provider.dart` | Add state + load/create/delete for all 6 resources; extend `loadAll` |
| **Create** | `lib/presentation/patients/widgets/clinical_record_tab.dart` | Read-only tab with 5 collapsible sections (one per resource) |
| **Create** | `lib/presentation/patients/widgets/clinical_record_forms.dart` | VitalSignForm, DiagnosisForm, ProblemForm, ProcedureForm, ImmunizationForm |
| **Modify** | `lib/presentation/patients/screens/patient_detail_screen.dart` | Add tab 5, update role-based tab index lists, wire FAB |
| **Modify** | `lib/presentation/roster/screens/roster_screen.dart` | Rewire to use `/patients/{id}/roster` instead of appointment aggregation |

---

## Task 1: New clinical record models

**Files:**
- Create: `lib/data/models/clinical_record_models.dart`

- [ ] **Step 1: Create the file with all six models**

```dart
// lib/data/models/clinical_record_models.dart
//
// Models for the six clinical record resources added in the backend sprint:
//   VitalSign, Diagnosis, ProblemList, Procedure, Immunization, RosterEntry
//
// All are patient-scoped. Hand-written fromJson — no build_runner.

// ── VitalSign ─────────────────────────────────────────────────────────────────

class VitalSignModel {
  final String id;
  final String patientId;
  final String recordedById;
  final String? encounterId;
  final String? rosterEntryId;
  final String? wardId;
  final DateTime recordedAt;
  final int? bloodPressureSystolic;
  final int? bloodPressureDiastolic;
  final int? heartRate;
  final int? respiratoryRate;
  final double? temperature;
  final String? temperatureUnit; // 'C' | 'F'
  final double? oxygenSaturation;
  final double? weight;
  final String? weightUnit; // 'kg' | 'lbs'
  final double? height;
  final String? heightUnit; // 'cm' | 'in'
  final double? bmi;
  final String? notes;
  final int version;
  final DateTime? createdAt;

  const VitalSignModel({
    required this.id,
    required this.patientId,
    required this.recordedById,
    this.encounterId,
    this.rosterEntryId,
    this.wardId,
    required this.recordedAt,
    this.bloodPressureSystolic,
    this.bloodPressureDiastolic,
    this.heartRate,
    this.respiratoryRate,
    this.temperature,
    this.temperatureUnit,
    this.oxygenSaturation,
    this.weight,
    this.weightUnit,
    this.height,
    this.heightUnit,
    this.bmi,
    this.notes,
    required this.version,
    this.createdAt,
  });

  factory VitalSignModel.fromJson(Map<String, dynamic> json) {
    return VitalSignModel(
      id: json['id'] as String,
      patientId: json['patient_id'] as String,
      recordedById: json['recorded_by_id'] as String,
      encounterId: json['encounter_id'] as String?,
      rosterEntryId: json['roster_entry_id'] as String?,
      wardId: json['ward_id'] as String?,
      recordedAt: DateTime.parse(json['recorded_at'] as String),
      bloodPressureSystolic: (json['blood_pressure_systolic'] as num?)?.toInt(),
      bloodPressureDiastolic: (json['blood_pressure_diastolic'] as num?)?.toInt(),
      heartRate: (json['heart_rate'] as num?)?.toInt(),
      respiratoryRate: (json['respiratory_rate'] as num?)?.toInt(),
      temperature: (json['temperature'] as num?)?.toDouble(),
      temperatureUnit: json['temperature_unit'] as String?,
      oxygenSaturation: (json['oxygen_saturation'] as num?)?.toDouble(),
      weight: (json['weight'] as num?)?.toDouble(),
      weightUnit: json['weight_unit'] as String?,
      height: (json['height'] as num?)?.toDouble(),
      heightUnit: json['height_unit'] as String?,
      bmi: (json['bmi'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
      version: (json['version'] as num?)?.toInt() ?? 1,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  String get bpDisplay {
    if (bloodPressureSystolic == null || bloodPressureDiastolic == null) return '—';
    return '$bloodPressureSystolic/$bloodPressureDiastolic mmHg';
  }

  String get tempDisplay {
    if (temperature == null) return '—';
    final unit = temperatureUnit ?? 'C';
    return '${temperature!.toStringAsFixed(1)} °$unit';
  }

  String get spo2Display {
    if (oxygenSaturation == null) return '—';
    return '${oxygenSaturation!.toStringAsFixed(0)}%';
  }
}

// ── Diagnosis ─────────────────────────────────────────────────────────────────

class DiagnosisModel {
  final String id;
  final String patientId;
  final String diagnosedById;
  final String? encounterId;
  final String? wardId;
  final String? icdCode;
  final String? icdVersion; // '10' | '11'
  final String description;
  final String diagnosisType; // 'primary'|'secondary'|'differential'|'comorbidity'
  final String status;        // 'active'|'resolved'|'in_remission'|'ruled_out'
  final DateTime? onsetDate;
  final DateTime? resolvedDate;
  final String? notes;
  final int version;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const DiagnosisModel({
    required this.id,
    required this.patientId,
    required this.diagnosedById,
    this.encounterId,
    this.wardId,
    this.icdCode,
    this.icdVersion,
    required this.description,
    required this.diagnosisType,
    required this.status,
    this.onsetDate,
    this.resolvedDate,
    this.notes,
    required this.version,
    this.createdAt,
    this.updatedAt,
  });

  factory DiagnosisModel.fromJson(Map<String, dynamic> json) {
    DateTime? d(String k) {
      final v = json[k];
      return v == null ? null : DateTime.tryParse(v as String);
    }

    return DiagnosisModel(
      id: json['id'] as String,
      patientId: json['patient_id'] as String,
      diagnosedById: json['diagnosed_by_id'] as String,
      encounterId: json['encounter_id'] as String?,
      wardId: json['ward_id'] as String?,
      icdCode: json['icd_code'] as String?,
      icdVersion: json['icd_version'] as String?,
      description: json['description'] as String,
      diagnosisType: json['diagnosis_type'] as String? ?? 'primary',
      status: json['status'] as String? ?? 'active',
      onsetDate: d('onset_date'),
      resolvedDate: d('resolved_date'),
      notes: json['notes'] as String?,
      version: (json['version'] as num?)?.toInt() ?? 1,
      createdAt: d('created_at'),
      updatedAt: d('updated_at'),
    );
  }

  bool get isActive => status == 'active' || status == 'in_remission';
}

// ── ProblemList ───────────────────────────────────────────────────────────────

class ProblemListModel {
  final String id;
  final String patientId;
  final String recordedById;
  final String? icdCode;
  final String? snomedCode;
  final String codingSystem; // 'ICD10'|'ICD11'|'SNOMED'|'local'
  final String description;
  final String status;       // 'active'|'resolved'|'in_remission'|'chronic'
  final DateTime? onsetDate;
  final DateTime? resolvedDate;
  final String? notes;
  final int version;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ProblemListModel({
    required this.id,
    required this.patientId,
    required this.recordedById,
    this.icdCode,
    this.snomedCode,
    required this.codingSystem,
    required this.description,
    required this.status,
    this.onsetDate,
    this.resolvedDate,
    this.notes,
    required this.version,
    this.createdAt,
    this.updatedAt,
  });

  factory ProblemListModel.fromJson(Map<String, dynamic> json) {
    DateTime? d(String k) {
      final v = json[k];
      return v == null ? null : DateTime.tryParse(v as String);
    }

    return ProblemListModel(
      id: json['id'] as String,
      patientId: json['patient_id'] as String,
      recordedById: json['recorded_by_id'] as String,
      icdCode: json['icd_code'] as String?,
      snomedCode: json['snomed_code'] as String?,
      codingSystem: json['coding_system'] as String? ?? 'local',
      description: json['description'] as String,
      status: json['status'] as String? ?? 'active',
      onsetDate: d('onset_date'),
      resolvedDate: d('resolved_date'),
      notes: json['notes'] as String?,
      version: (json['version'] as num?)?.toInt() ?? 1,
      createdAt: d('created_at'),
      updatedAt: d('updated_at'),
    );
  }

  bool get isActive => status == 'active' || status == 'chronic';
}

// ── Procedure ─────────────────────────────────────────────────────────────────

class ProcedureModel {
  final String id;
  final String patientId;
  final String performedById;
  final String? encounterId;
  final String? wardId;
  final String? procedureCode;
  final String? procedureCodingSystem; // 'ICD10_PCS'|'CPT'|'SNOMED'|'local'
  final String description;
  final DateTime? performedAt;
  final int? durationMinutes;
  final String status;  // 'planned'|'in_progress'|'completed'|'cancelled'
  final String? notes;
  final int version;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ProcedureModel({
    required this.id,
    required this.patientId,
    required this.performedById,
    this.encounterId,
    this.wardId,
    this.procedureCode,
    this.procedureCodingSystem,
    required this.description,
    this.performedAt,
    this.durationMinutes,
    required this.status,
    this.notes,
    required this.version,
    this.createdAt,
    this.updatedAt,
  });

  factory ProcedureModel.fromJson(Map<String, dynamic> json) {
    DateTime? d(String k) {
      final v = json[k];
      return v == null ? null : DateTime.tryParse(v as String);
    }

    return ProcedureModel(
      id: json['id'] as String,
      patientId: json['patient_id'] as String,
      performedById: json['performed_by_id'] as String,
      encounterId: json['encounter_id'] as String?,
      wardId: json['ward_id'] as String?,
      procedureCode: json['procedure_code'] as String?,
      procedureCodingSystem: json['procedure_coding_system'] as String?,
      description: json['description'] as String,
      performedAt: d('performed_at'),
      durationMinutes: (json['duration_minutes'] as num?)?.toInt(),
      status: json['status'] as String? ?? 'planned',
      notes: json['notes'] as String?,
      version: (json['version'] as num?)?.toInt() ?? 1,
      createdAt: d('created_at'),
      updatedAt: d('updated_at'),
    );
  }

  bool get isCompleted => status == 'completed';
}

// ── Immunization ──────────────────────────────────────────────────────────────

class ImmunizationModel {
  final String id;
  final String patientId;
  final String administeredById;
  final String vaccineCode;    // CVX code
  final String vaccineName;
  final int doseNumber;
  final int? seriesTotal;
  final DateTime administeredAt;
  final String? lotNumber;
  // 'left_arm'|'right_arm'|'left_thigh'|'right_thigh'|'other'
  final String? site;
  // 'intramuscular'|'subcutaneous'|'intradermal'|'oral'|'nasal'
  final String route;
  final DateTime? expirationDate;
  final String? notes;
  final int version;
  final DateTime? createdAt;

  const ImmunizationModel({
    required this.id,
    required this.patientId,
    required this.administeredById,
    required this.vaccineCode,
    required this.vaccineName,
    required this.doseNumber,
    this.seriesTotal,
    required this.administeredAt,
    this.lotNumber,
    this.site,
    required this.route,
    this.expirationDate,
    this.notes,
    required this.version,
    this.createdAt,
  });

  factory ImmunizationModel.fromJson(Map<String, dynamic> json) {
    DateTime? d(String k) {
      final v = json[k];
      return v == null ? null : DateTime.tryParse(v as String);
    }

    return ImmunizationModel(
      id: json['id'] as String,
      patientId: json['patient_id'] as String,
      administeredById: json['administered_by_id'] as String,
      vaccineCode: json['vaccine_code'] as String,
      vaccineName: json['vaccine_name'] as String,
      doseNumber: (json['dose_number'] as num).toInt(),
      seriesTotal: (json['series_total'] as num?)?.toInt(),
      administeredAt: DateTime.parse(json['administered_at'] as String),
      lotNumber: json['lot_number'] as String?,
      site: json['site'] as String?,
      route: json['route'] as String,
      expirationDate: d('expiration_date'),
      notes: json['notes'] as String?,
      version: (json['version'] as num?)?.toInt() ?? 1,
      createdAt: d('created_at'),
    );
  }

  String get doseDisplay =>
      seriesTotal != null ? 'Dose $doseNumber of $seriesTotal' : 'Dose $doseNumber';
}

// ── RosterEntry ───────────────────────────────────────────────────────────────

class RosterEntryModel {
  final String id;
  final String patientId;
  final String wardId;
  final String addedById;
  final DateTime date;
  // 'scheduled'|'walk_in'|'emergency'|'transfer'
  final String entryType;
  final String? appointmentId;
  // 'critical'|'urgent'|'moderate'|'low'
  final String? triageSeverity;
  final String? chiefComplaint;
  // 'waiting'|'in_consultation'|'seen'|'admitted'|'referred'|'carried_over'
  final String status;
  final String? seenById;
  final DateTime? seenAt;
  final String? consultationNotes;
  final int carryOverCount;
  final DateTime originalRosterDate;
  final bool isCarriedOver;
  final bool isTerminal;
  final int version;
  final DateTime? createdAt;

  const RosterEntryModel({
    required this.id,
    required this.patientId,
    required this.wardId,
    required this.addedById,
    required this.date,
    required this.entryType,
    this.appointmentId,
    this.triageSeverity,
    this.chiefComplaint,
    required this.status,
    this.seenById,
    this.seenAt,
    this.consultationNotes,
    required this.carryOverCount,
    required this.originalRosterDate,
    required this.isCarriedOver,
    required this.isTerminal,
    required this.version,
    this.createdAt,
  });

  factory RosterEntryModel.fromJson(Map<String, dynamic> json) {
    DateTime? d(String k) {
      final v = json[k];
      return v == null ? null : DateTime.tryParse(v as String);
    }

    return RosterEntryModel(
      id: json['id'] as String,
      patientId: json['patient_id'] as String,
      wardId: json['ward_id'] as String,
      addedById: json['added_by_id'] as String,
      date: DateTime.parse(json['date'] as String),
      entryType: json['entry_type'] as String,
      appointmentId: json['appointment_id'] as String?,
      triageSeverity: json['triage_severity'] as String?,
      chiefComplaint: json['chief_complaint'] as String?,
      status: json['status'] as String? ?? 'waiting',
      seenById: json['seen_by_id'] as String?,
      seenAt: d('seen_at'),
      consultationNotes: json['consultation_notes'] as String?,
      carryOverCount: (json['carry_over_count'] as num?)?.toInt() ?? 0,
      originalRosterDate: DateTime.parse(json['original_roster_date'] as String),
      isCarriedOver: json['is_carried_over'] as bool? ?? false,
      isTerminal: json['is_terminal'] as bool? ?? false,
      version: (json['version'] as num?)?.toInt() ?? 1,
      createdAt: d('created_at'),
    );
  }

  bool get isWaiting => status == 'waiting';
  bool get isInConsultation => status == 'in_consultation';

  int get triagePriority => switch (triageSeverity) {
        'critical' => 0,
        'urgent'   => 1,
        'moderate' => 2,
        'low'      => 3,
        _          => 4,
      };
}
```

- [ ] **Step 2: Verify the file compiles** (no Flutter run needed — just check dart analyze)

```bash
cd /home/dh/Forge/sandbox/healthcare_emr_mobile
flutter analyze lib/data/models/clinical_record_models.dart
```
Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add lib/data/models/clinical_record_models.dart
git commit -m "feat(mobile): add VitalSign, Diagnosis, ProblemList, Procedure, Immunization, RosterEntry models"
```

---

## Task 2: Update existing clinical models with new backend fields

**Files:**
- Modify: `lib/data/models/clinical_models.dart`

The backend now returns `ward_id` on appointments, prescriptions, and lab results. Prescription also gets `coding_system`. Add these as nullable fields — they're optional and existing data won't have them.

- [ ] **Step 1: Add `wardId` to AppointmentModel**

In `clinical_models.dart`, inside `AppointmentModel`:

```dart
// Add to field declarations (after updatedAt):
final String? wardId;

// Add to constructor (after updatedAt):
this.wardId,

// Add to AppointmentModel.fromJson (after updatedAt parsing):
wardId: json['ward_id'] as String?,
```

- [ ] **Step 2: Add `wardId` and `codingSystem` to PrescriptionModel**

In `PrescriptionModel`:

```dart
// Add to field declarations (after drugInteractionsChecked):
final String? wardId;
final String? codingSystem;

// Add to constructor:
this.wardId,
this.codingSystem,

// Add to PrescriptionModel.fromJson (after drugInteractionsChecked):
wardId: json['ward_id'] as String?,
codingSystem: json['coding_system'] as String?,
```

- [ ] **Step 3: Add `wardId` to LabResultModel**

In `LabResultModel`:

```dart
// Add to field declarations (after requiresFollowup):
final String? wardId;

// Add to constructor:
this.wardId,

// Add to LabResultModel.fromJson (after requiresFollowup):
wardId: json['ward_id'] as String?,
```

- [ ] **Step 4: Verify no analysis errors**

```bash
flutter analyze lib/data/models/clinical_models.dart
```
Expected: no errors.

- [ ] **Step 5: Commit**

```bash
git add lib/data/models/clinical_models.dart
git commit -m "feat(mobile): add wardId and codingSystem fields to existing clinical models"
```

---

## Task 3: Extend ClinicalRepository with new resource methods

**Files:**
- Modify: `lib/data/repositories/clinical_repository.dart`

Add a clearly separated section for each new resource. Follow the exact same pattern as the existing methods: `GET` list (paginated, optional filters), `POST` create, `DELETE` delete. Roster also needs `PUT` update for status transitions.

- [ ] **Step 1: Add the import for the new models at the top of the file**

Add to the imports block (after `clinical_models.dart`):

```dart
import '../models/clinical_record_models.dart';
```

- [ ] **Step 2: Add VitalSign methods**

Append to the end of the `ClinicalRepository` class (before the closing `}`):

```dart
  // ── Vital Signs ───────────────────────────────────────────────────────────

  Future<List<VitalSignModel>> getVitalSigns(
    String patientId, {
    int page = 1,
  }) async {
    final response = await apiClient.get(
      '/patients/$patientId/vital-signs',
      queryParameters: {'page': page},
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to load vital signs');
    }
    final rawData = response['data'];
    final list = rawData is Map ? rawData['data'] as List? ?? [] : rawData as List? ?? [];
    return list
        .map((e) => VitalSignModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<VitalSignModel> createVitalSign(
      String patientId, Map<String, dynamic> data) async {
    final response =
        await apiClient.post('/patients/$patientId/vital-signs', data: data);
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to record vital signs');
    }
    return VitalSignModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map));
  }

  Future<void> deleteVitalSign(String patientId, String vitalSignId) async {
    final response =
        await apiClient.delete('/patients/$patientId/vital-signs/$vitalSignId');
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to delete vital sign');
    }
  }
```

- [ ] **Step 3: Add Diagnosis methods**

```dart
  // ── Diagnoses ─────────────────────────────────────────────────────────────

  Future<List<DiagnosisModel>> getDiagnoses(
    String patientId, {
    String? status,
    int page = 1,
  }) async {
    final response = await apiClient.get(
      '/patients/$patientId/diagnoses',
      queryParameters: {
        'page': page,
        if (status != null) 'status': status,
      },
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to load diagnoses');
    }
    final rawData = response['data'];
    final list = rawData is Map ? rawData['data'] as List? ?? [] : rawData as List? ?? [];
    return list
        .map((e) => DiagnosisModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<DiagnosisModel> createDiagnosis(
      String patientId, Map<String, dynamic> data) async {
    final response =
        await apiClient.post('/patients/$patientId/diagnoses', data: data);
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to record diagnosis');
    }
    return DiagnosisModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map));
  }

  Future<void> deleteDiagnosis(String patientId, String diagnosisId) async {
    final response =
        await apiClient.delete('/patients/$patientId/diagnoses/$diagnosisId');
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to delete diagnosis');
    }
  }
```

- [ ] **Step 4: Add ProblemList methods**

```dart
  // ── Problem List ──────────────────────────────────────────────────────────

  Future<List<ProblemListModel>> getProblems(
    String patientId, {
    String? status,
    int page = 1,
  }) async {
    final response = await apiClient.get(
      '/patients/$patientId/problems',
      queryParameters: {
        'page': page,
        if (status != null) 'status': status,
      },
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to load problem list');
    }
    final rawData = response['data'];
    final list = rawData is Map ? rawData['data'] as List? ?? [] : rawData as List? ?? [];
    return list
        .map((e) => ProblemListModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<ProblemListModel> createProblem(
      String patientId, Map<String, dynamic> data) async {
    final response =
        await apiClient.post('/patients/$patientId/problems', data: data);
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to record problem');
    }
    return ProblemListModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map));
  }

  Future<void> deleteProblem(String patientId, String problemId) async {
    final response =
        await apiClient.delete('/patients/$patientId/problems/$problemId');
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to delete problem');
    }
  }
```

- [ ] **Step 5: Add Procedure methods**

```dart
  // ── Procedures ────────────────────────────────────────────────────────────

  Future<List<ProcedureModel>> getProcedures(
    String patientId, {
    int page = 1,
  }) async {
    final response = await apiClient.get(
      '/patients/$patientId/procedures',
      queryParameters: {'page': page},
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to load procedures');
    }
    final rawData = response['data'];
    final list = rawData is Map ? rawData['data'] as List? ?? [] : rawData as List? ?? [];
    return list
        .map((e) => ProcedureModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<ProcedureModel> createProcedure(
      String patientId, Map<String, dynamic> data) async {
    final response =
        await apiClient.post('/patients/$patientId/procedures', data: data);
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to record procedure');
    }
    return ProcedureModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map));
  }

  Future<void> deleteProcedure(String patientId, String procedureId) async {
    final response =
        await apiClient.delete('/patients/$patientId/procedures/$procedureId');
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to delete procedure');
    }
  }
```

- [ ] **Step 6: Add Immunization methods**

```dart
  // ── Immunizations ─────────────────────────────────────────────────────────

  Future<List<ImmunizationModel>> getImmunizations(
    String patientId, {
    int page = 1,
  }) async {
    final response = await apiClient.get(
      '/patients/$patientId/immunizations',
      queryParameters: {'page': page},
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to load immunizations');
    }
    final rawData = response['data'];
    final list = rawData is Map ? rawData['data'] as List? ?? [] : rawData as List? ?? [];
    return list
        .map((e) => ImmunizationModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<ImmunizationModel> createImmunization(
      String patientId, Map<String, dynamic> data) async {
    final response =
        await apiClient.post('/patients/$patientId/immunizations', data: data);
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to record immunization');
    }
    return ImmunizationModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map));
  }

  Future<void> deleteImmunization(
      String patientId, String immunizationId) async {
    final response = await apiClient
        .delete('/patients/$patientId/immunizations/$immunizationId');
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to delete immunization');
    }
  }
```

- [ ] **Step 7: Add RosterEntry methods**

```dart
  // ── Daily Roster ──────────────────────────────────────────────────────────

  Future<List<RosterEntryModel>> getRosterEntries(
    String patientId, {
    String? date, // ISO date string 'YYYY-MM-DD'
    String? status,
    int page = 1,
  }) async {
    final response = await apiClient.get(
      '/patients/$patientId/roster',
      queryParameters: {
        'page': page,
        if (date != null) 'date': date,
        if (status != null) 'status': status,
      },
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to load roster entries');
    }
    final rawData = response['data'];
    final list = rawData is Map ? rawData['data'] as List? ?? [] : rawData as List? ?? [];
    return list
        .map((e) => RosterEntryModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<RosterEntryModel> createRosterEntry(
      String patientId, Map<String, dynamic> data) async {
    final response =
        await apiClient.post('/patients/$patientId/roster', data: data);
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to add patient to roster');
    }
    return RosterEntryModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map));
  }

  Future<RosterEntryModel> updateRosterEntry(
      String patientId, String entryId, Map<String, dynamic> data) async {
    final response = await apiClient.put(
      '/patients/$patientId/roster/$entryId',
      data: data,
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to update roster entry');
    }
    return RosterEntryModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map));
  }
```

- [ ] **Step 8: Verify**

```bash
flutter analyze lib/data/repositories/clinical_repository.dart
```
Expected: no errors.

- [ ] **Step 9: Commit**

```bash
git add lib/data/repositories/clinical_repository.dart
git commit -m "feat(mobile): add repository methods for vital signs, diagnoses, problems, procedures, immunizations, roster"
```

---

## Task 4: Extend ClinicalProvider with new state and methods

**Files:**
- Modify: `lib/data/providers/clinical_provider.dart`

- [ ] **Step 1: Add import and state fields**

Add import at the top:
```dart
import '../models/clinical_record_models.dart';
```

Inside `ClinicalProvider`, after `List<MedicalDocumentModel> _documents = [];`, add:
```dart
  List<VitalSignModel> _vitalSigns = [];
  List<DiagnosisModel> _diagnoses = [];
  List<ProblemListModel> _problems = [];
  List<ProcedureModel> _procedures = [];
  List<ImmunizationModel> _immunizations = [];
```

- [ ] **Step 2: Add getters**

After `List<MedicalDocumentModel> get documents => _documents;`, add:
```dart
  List<VitalSignModel> get vitalSigns => _vitalSigns;
  List<DiagnosisModel> get diagnoses => _diagnoses;
  List<ProblemListModel> get problems => _problems;
  List<ProcedureModel> get procedures => _procedures;
  List<ImmunizationModel> get immunizations => _immunizations;

  List<DiagnosisModel> get activeDiagnoses =>
      _diagnoses.where((d) => d.isActive).toList();

  List<ProblemListModel> get activeProblems =>
      _problems.where((p) => p.isActive).toList();
```

- [ ] **Step 3: Extend `loadAll` to include new resources**

Replace the existing `loadAll` method body with:
```dart
  Future<void> loadAll(String patientId) async {
    _patientId = patientId;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        repository.getAppointments(patientId),
        repository.getPrescriptions(patientId),
        repository.getLabResults(patientId),
        repository.getDocuments(patientId),
        repository.getVitalSigns(patientId),
        repository.getDiagnoses(patientId),
        repository.getProblems(patientId),
        repository.getProcedures(patientId),
        repository.getImmunizations(patientId),
      ]);
      _appointments  = results[0] as List<AppointmentModel>;
      _prescriptions = results[1] as List<PrescriptionModel>;
      _labResults    = results[2] as List<LabResultModel>;
      _documents     = results[3] as List<MedicalDocumentModel>;
      _vitalSigns    = results[4] as List<VitalSignModel>;
      _diagnoses     = results[5] as List<DiagnosisModel>;
      _problems      = results[6] as List<ProblemListModel>;
      _procedures    = results[7] as List<ProcedureModel>;
      _immunizations = results[8] as List<ImmunizationModel>;
      _error = null;
    } catch (e) {
      _error = _friendlyError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
```

- [ ] **Step 4: Add individual loaders**

After `loadDocuments()`, add:
```dart
  Future<void> loadVitalSigns() async {
    if (_patientId == null) return;
    try {
      _vitalSigns = await repository.getVitalSigns(_patientId!);
      notifyListeners();
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
    }
  }

  Future<void> loadDiagnoses({String? status}) async {
    if (_patientId == null) return;
    try {
      _diagnoses = await repository.getDiagnoses(_patientId!, status: status);
      notifyListeners();
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
    }
  }

  Future<void> loadProblems({String? status}) async {
    if (_patientId == null) return;
    try {
      _problems = await repository.getProblems(_patientId!, status: status);
      notifyListeners();
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
    }
  }

  Future<void> loadProcedures() async {
    if (_patientId == null) return;
    try {
      _procedures = await repository.getProcedures(_patientId!);
      notifyListeners();
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
    }
  }

  Future<void> loadImmunizations() async {
    if (_patientId == null) return;
    try {
      _immunizations = await repository.getImmunizations(_patientId!);
      notifyListeners();
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
    }
  }
```

- [ ] **Step 5: Add write operations**

After `deleteDocument()`, add:
```dart
  Future<VitalSignModel?> createVitalSign(Map<String, dynamic> data) async {
    if (_patientId == null) return null;
    try {
      final v = await repository.createVitalSign(_patientId!, data);
      _vitalSigns = [v, ..._vitalSigns];
      notifyListeners();
      return v;
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
      return null;
    }
  }

  Future<bool> deleteVitalSign(String vitalSignId) async {
    if (_patientId == null) return false;
    try {
      await repository.deleteVitalSign(_patientId!, vitalSignId);
      _vitalSigns = _vitalSigns.where((v) => v.id != vitalSignId).toList();
      notifyListeners();
      return true;
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  Future<DiagnosisModel?> createDiagnosis(Map<String, dynamic> data) async {
    if (_patientId == null) return null;
    try {
      final d = await repository.createDiagnosis(_patientId!, data);
      _diagnoses = [d, ..._diagnoses];
      notifyListeners();
      return d;
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
      return null;
    }
  }

  Future<bool> deleteDiagnosis(String diagnosisId) async {
    if (_patientId == null) return false;
    try {
      await repository.deleteDiagnosis(_patientId!, diagnosisId);
      _diagnoses = _diagnoses.where((d) => d.id != diagnosisId).toList();
      notifyListeners();
      return true;
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  Future<ProblemListModel?> createProblem(Map<String, dynamic> data) async {
    if (_patientId == null) return null;
    try {
      final p = await repository.createProblem(_patientId!, data);
      _problems = [p, ..._problems];
      notifyListeners();
      return p;
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
      return null;
    }
  }

  Future<bool> deleteProblem(String problemId) async {
    if (_patientId == null) return false;
    try {
      await repository.deleteProblem(_patientId!, problemId);
      _problems = _problems.where((p) => p.id != problemId).toList();
      notifyListeners();
      return true;
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  Future<ProcedureModel?> createProcedure(Map<String, dynamic> data) async {
    if (_patientId == null) return null;
    try {
      final p = await repository.createProcedure(_patientId!, data);
      _procedures = [p, ..._procedures];
      notifyListeners();
      return p;
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
      return null;
    }
  }

  Future<bool> deleteProcedure(String procedureId) async {
    if (_patientId == null) return false;
    try {
      await repository.deleteProcedure(_patientId!, procedureId);
      _procedures = _procedures.where((p) => p.id != procedureId).toList();
      notifyListeners();
      return true;
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  Future<ImmunizationModel?> createImmunization(
      Map<String, dynamic> data) async {
    if (_patientId == null) return null;
    try {
      final i = await repository.createImmunization(_patientId!, data);
      _immunizations = [i, ..._immunizations];
      notifyListeners();
      return i;
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
      return null;
    }
  }

  Future<bool> deleteImmunization(String immunizationId) async {
    if (_patientId == null) return false;
    try {
      await repository.deleteImmunization(_patientId!, immunizationId);
      _immunizations =
          _immunizations.where((i) => i.id != immunizationId).toList();
      notifyListeners();
      return true;
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
      return false;
    }
  }
```

- [ ] **Step 6: Extend `clear()` to reset new lists**

In the `clear()` method, after `_documents = [];`, add:
```dart
    _vitalSigns    = [];
    _diagnoses     = [];
    _problems      = [];
    _procedures    = [];
    _immunizations = [];
```

- [ ] **Step 7: Verify**

```bash
flutter analyze lib/data/providers/clinical_provider.dart
```
Expected: no errors.

- [ ] **Step 8: Commit**

```bash
git add lib/data/providers/clinical_provider.dart
git commit -m "feat(mobile): extend ClinicalProvider with state and methods for 5 new clinical resources"
```

---

## Task 5: Create Clinical Record forms

**Files:**
- Create: `lib/presentation/patients/widgets/clinical_record_forms.dart`

Five modal bottom sheet forms — one per new resource. Each follows the same pattern as the existing forms in `clinical_forms.dart`: `StatefulWidget`, a form key, `_saving` flag, `Navigator.pop(true)` on success.

- [ ] **Step 1: Create the file**

```dart
// lib/presentation/patients/widgets/clinical_record_forms.dart
//
// Write forms for the five new clinical record resources, shown as modal
// bottom sheets from the Clinical Record tab FAB.
//
// VitalSignForm    — records a set of vital signs
// DiagnosisForm    — records a new diagnosis
// ProblemForm      — adds an entry to the problem list
// ProcedureForm    — records a procedure
// ImmunizationForm — records a vaccine administration
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/theme.dart';
import '../../../data/providers/clinical_provider.dart';

// ── Shared helpers ────────────────────────────────────────────────────────────

Widget _sheet({required String title, required Widget child}) {
  return Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(title,
            style:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        child,
      ],
    ),
  );
}

InputDecoration _field(String label, {String? hint}) => InputDecoration(
      labelText: label,
      hintText: hint,
      border: const OutlineInputBorder(),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );

// ── VitalSignForm ─────────────────────────────────────────────────────────────

class VitalSignForm extends StatefulWidget {
  const VitalSignForm({super.key});

  @override
  State<VitalSignForm> createState() => _VitalSignFormState();
}

class _VitalSignFormState extends State<VitalSignForm> {
  final _formKey = GlobalKey<FormState>();
  final _bpSysCtrl  = TextEditingController();
  final _bpDiaCtrl  = TextEditingController();
  final _hrCtrl     = TextEditingController();
  final _rrCtrl     = TextEditingController();
  final _tempCtrl   = TextEditingController();
  final _spo2Ctrl   = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _notesCtrl  = TextEditingController();
  String _tempUnit   = 'C';
  String _weightUnit = 'kg';
  String _heightUnit = 'cm';
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [
      _bpSysCtrl, _bpDiaCtrl, _hrCtrl, _rrCtrl, _tempCtrl,
      _spo2Ctrl, _weightCtrl, _heightCtrl, _notesCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    int? _int(TextEditingController c) =>
        c.text.trim().isEmpty ? null : int.tryParse(c.text.trim());
    double? _dbl(TextEditingController c) =>
        c.text.trim().isEmpty ? null : double.tryParse(c.text.trim());

    final data = {
      'recorded_at': DateTime.now().toIso8601String(),
      if (_bpSysCtrl.text.trim().isNotEmpty)
        'blood_pressure_systolic': _int(_bpSysCtrl),
      if (_bpDiaCtrl.text.trim().isNotEmpty)
        'blood_pressure_diastolic': _int(_bpDiaCtrl),
      if (_hrCtrl.text.trim().isNotEmpty) 'heart_rate': _int(_hrCtrl),
      if (_rrCtrl.text.trim().isNotEmpty) 'respiratory_rate': _int(_rrCtrl),
      if (_tempCtrl.text.trim().isNotEmpty) ...{
        'temperature': _dbl(_tempCtrl),
        'temperature_unit': _tempUnit,
      },
      if (_spo2Ctrl.text.trim().isNotEmpty)
        'oxygen_saturation': _dbl(_spo2Ctrl),
      if (_weightCtrl.text.trim().isNotEmpty) ...{
        'weight': _dbl(_weightCtrl),
        'weight_unit': _weightUnit,
      },
      if (_heightCtrl.text.trim().isNotEmpty) ...{
        'height': _dbl(_heightCtrl),
        'height_unit': _heightUnit,
      },
      if (_notesCtrl.text.trim().isNotEmpty) 'notes': _notesCtrl.text.trim(),
    };

    final result =
        await context.read<ClinicalProvider>().createVitalSign(data);
    if (!mounted) return;
    setState(() => _saving = false);
    if (result != null) Navigator.pop(context, true);
  }

  Widget _unitToggle(String current, List<String> options, ValueChanged<String> onChanged) {
    return ToggleButtons(
      isSelected: options.map((o) => o == current).toList(),
      onPressed: (i) => onChanged(options[i]),
      constraints: const BoxConstraints(minWidth: 40, minHeight: 36),
      children: options.map((o) => Text(o, style: const TextStyle(fontSize: 12))).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _sheet(
        title: 'Record Vital Signs',
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _bpSysCtrl,
                    decoration: _field('Systolic BP', hint: 'mmHg'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _bpDiaCtrl,
                    decoration: _field('Diastolic BP', hint: 'mmHg'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _hrCtrl,
                    decoration: _field('Heart Rate', hint: 'bpm'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _rrCtrl,
                    decoration: _field('Resp. Rate', hint: '/min'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _tempCtrl,
                    decoration: _field('Temperature'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 8),
                _unitToggle(_tempUnit, ['C', 'F'],
                    (v) => setState(() => _tempUnit = v)),
              ]),
              const SizedBox(height: 12),
              TextFormField(
                controller: _spo2Ctrl,
                decoration: _field('Oxygen Saturation', hint: '%'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _weightCtrl,
                    decoration: _field('Weight'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 8),
                _unitToggle(_weightUnit, ['kg', 'lbs'],
                    (v) => setState(() => _weightUnit = v)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _heightCtrl,
                    decoration: _field('Height'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 8),
                _unitToggle(_heightUnit, ['cm', 'in'],
                    (v) => setState(() => _heightUnit = v)),
              ]),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesCtrl,
                decoration: _field('Notes'),
                maxLines: 2,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save Vitals'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── DiagnosisForm ─────────────────────────────────────────────────────────────

class DiagnosisForm extends StatefulWidget {
  const DiagnosisForm({super.key});

  @override
  State<DiagnosisForm> createState() => _DiagnosisFormState();
}

class _DiagnosisFormState extends State<DiagnosisForm> {
  final _formKey     = GlobalKey<FormState>();
  final _descCtrl    = TextEditingController();
  final _icdCtrl     = TextEditingController();
  final _notesCtrl   = TextEditingController();
  String _type   = 'primary';
  String _status = 'active';
  bool _saving   = false;

  static const _types = [
    ('primary', 'Primary'),
    ('secondary', 'Secondary'),
    ('differential', 'Differential'),
    ('comorbidity', 'Comorbidity'),
  ];

  static const _statuses = [
    ('active', 'Active'),
    ('in_remission', 'In Remission'),
    ('resolved', 'Resolved'),
    ('ruled_out', 'Ruled Out'),
  ];

  @override
  void dispose() {
    _descCtrl.dispose();
    _icdCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final data = {
      'description': _descCtrl.text.trim(),
      'diagnosis_type': _type,
      'status': _status,
      if (_icdCtrl.text.trim().isNotEmpty) 'icd_code': _icdCtrl.text.trim(),
      if (_notesCtrl.text.trim().isNotEmpty) 'notes': _notesCtrl.text.trim(),
    };

    final result =
        await context.read<ClinicalProvider>().createDiagnosis(data);
    if (!mounted) return;
    setState(() => _saving = false);
    if (result != null) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _sheet(
        title: 'Record Diagnosis',
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _descCtrl,
                decoration: _field('Description *'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _icdCtrl,
                decoration: _field('ICD Code', hint: 'e.g. E11.9'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _type,
                decoration: _field('Diagnosis Type'),
                items: _types
                    .map((t) => DropdownMenuItem(
                        value: t.$1, child: Text(t.$2)))
                    .toList(),
                onChanged: (v) => setState(() => _type = v!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _status,
                decoration: _field('Status'),
                items: _statuses
                    .map((s) => DropdownMenuItem(
                        value: s.$1, child: Text(s.$2)))
                    .toList(),
                onChanged: (v) => setState(() => _status = v!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesCtrl,
                decoration: _field('Notes'),
                maxLines: 3,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save Diagnosis'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── ProblemForm ───────────────────────────────────────────────────────────────

class ProblemForm extends StatefulWidget {
  const ProblemForm({super.key});

  @override
  State<ProblemForm> createState() => _ProblemFormState();
}

class _ProblemFormState extends State<ProblemForm> {
  final _formKey   = GlobalKey<FormState>();
  final _descCtrl  = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _status = 'active';
  bool _saving   = false;

  static const _statuses = [
    ('active', 'Active'),
    ('chronic', 'Chronic'),
    ('in_remission', 'In Remission'),
    ('resolved', 'Resolved'),
  ];

  @override
  void dispose() {
    _descCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final data = {
      'description': _descCtrl.text.trim(),
      'status': _status,
      if (_notesCtrl.text.trim().isNotEmpty) 'notes': _notesCtrl.text.trim(),
    };

    final result = await context.read<ClinicalProvider>().createProblem(data);
    if (!mounted) return;
    setState(() => _saving = false);
    if (result != null) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _sheet(
        title: 'Add to Problem List',
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _descCtrl,
                decoration: _field('Problem Description *'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _status,
                decoration: _field('Status'),
                items: _statuses
                    .map((s) => DropdownMenuItem(
                        value: s.$1, child: Text(s.$2)))
                    .toList(),
                onChanged: (v) => setState(() => _status = v!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesCtrl,
                decoration: _field('Notes'),
                maxLines: 2,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Add Problem'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── ProcedureForm ─────────────────────────────────────────────────────────────

class ProcedureForm extends StatefulWidget {
  const ProcedureForm({super.key});

  @override
  State<ProcedureForm> createState() => _ProcedureFormState();
}

class _ProcedureFormState extends State<ProcedureForm> {
  final _formKey      = GlobalKey<FormState>();
  final _descCtrl     = TextEditingController();
  final _durationCtrl = TextEditingController();
  final _notesCtrl    = TextEditingController();
  String _status = 'planned';
  bool _saving   = false;

  static const _statuses = [
    ('planned', 'Planned'),
    ('in_progress', 'In Progress'),
    ('completed', 'Completed'),
    ('cancelled', 'Cancelled'),
  ];

  @override
  void dispose() {
    _descCtrl.dispose();
    _durationCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final data = {
      'description': _descCtrl.text.trim(),
      'status': _status,
      'performed_at': DateTime.now().toIso8601String(),
      if (_durationCtrl.text.trim().isNotEmpty)
        'duration_minutes': int.tryParse(_durationCtrl.text.trim()),
      if (_notesCtrl.text.trim().isNotEmpty) 'notes': _notesCtrl.text.trim(),
    };

    final result =
        await context.read<ClinicalProvider>().createProcedure(data);
    if (!mounted) return;
    setState(() => _saving = false);
    if (result != null) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _sheet(
        title: 'Record Procedure',
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _descCtrl,
                decoration: _field('Description *'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _status,
                decoration: _field('Status'),
                items: _statuses
                    .map((s) => DropdownMenuItem(
                        value: s.$1, child: Text(s.$2)))
                    .toList(),
                onChanged: (v) => setState(() => _status = v!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _durationCtrl,
                decoration: _field('Duration (minutes)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesCtrl,
                decoration: _field('Notes'),
                maxLines: 3,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save Procedure'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── ImmunizationForm ──────────────────────────────────────────────────────────

class ImmunizationForm extends StatefulWidget {
  const ImmunizationForm({super.key});

  @override
  State<ImmunizationForm> createState() => _ImmunizationFormState();
}

class _ImmunizationFormState extends State<ImmunizationForm> {
  final _formKey      = GlobalKey<FormState>();
  final _nameCtrl     = TextEditingController();
  final _codeCtrl     = TextEditingController();
  final _doseCtrl     = TextEditingController(text: '1');
  final _lotCtrl      = TextEditingController();
  final _notesCtrl    = TextEditingController();
  String _route = 'intramuscular';
  bool _saving  = false;

  static const _routes = [
    ('intramuscular', 'Intramuscular'),
    ('subcutaneous', 'Subcutaneous'),
    ('intradermal', 'Intradermal'),
    ('oral', 'Oral'),
    ('nasal', 'Nasal'),
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _doseCtrl.dispose();
    _lotCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final data = {
      'vaccine_name': _nameCtrl.text.trim(),
      'vaccine_code': _codeCtrl.text.trim(),
      'dose_number': int.tryParse(_doseCtrl.text.trim()) ?? 1,
      'route': _route,
      'administered_at': DateTime.now().toIso8601String(),
      if (_lotCtrl.text.trim().isNotEmpty) 'lot_number': _lotCtrl.text.trim(),
      if (_notesCtrl.text.trim().isNotEmpty) 'notes': _notesCtrl.text.trim(),
    };

    final result =
        await context.read<ClinicalProvider>().createImmunization(data);
    if (!mounted) return;
    setState(() => _saving = false);
    if (result != null) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _sheet(
        title: 'Record Immunization',
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: _field('Vaccine Name *'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _codeCtrl,
                decoration: _field('CVX Code *', hint: 'e.g. 140'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _doseCtrl,
                    decoration: _field('Dose #'),
                    keyboardType: TextInputType.number,
                    validator: (v) =>
                        (v == null || int.tryParse(v) == null)
                            ? 'Enter a number'
                            : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _lotCtrl,
                    decoration: _field('Lot Number'),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _route,
                decoration: _field('Route'),
                items: _routes
                    .map((r) => DropdownMenuItem(
                        value: r.$1, child: Text(r.$2)))
                    .toList(),
                onChanged: (v) => setState(() => _route = v!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesCtrl,
                decoration: _field('Notes'),
                maxLines: 2,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Record Vaccination'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Analyze**

```bash
flutter analyze lib/presentation/patients/widgets/clinical_record_forms.dart
```
Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/patients/widgets/clinical_record_forms.dart
git commit -m "feat(mobile): add VitalSign, Diagnosis, Problem, Procedure, Immunization forms"
```

---

## Task 6: Create Clinical Record tab widget

**Files:**
- Create: `lib/presentation/patients/widgets/clinical_record_tab.dart`

Read-only tab with five `ExpansionTile` sections. Each section has an add button that opens the corresponding form as a bottom sheet, and a delete icon on each record. Ordered: VitalSigns → Diagnoses → ProblemList → Procedures → Immunizations.

- [ ] **Step 1: Create the file**

```dart
// lib/presentation/patients/widgets/clinical_record_tab.dart
//
// ClinicalRecordTab — Patient detail tab 5.
//
// Shows five collapsible sections, one per new clinical resource.
// Tap the section header's "+" icon to open the write form.
// Long-press a record to delete it (with confirmation dialog).
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../data/models/clinical_record_models.dart';
import '../../../data/providers/clinical_provider.dart';
import 'clinical_record_forms.dart';

class ClinicalRecordTab extends StatelessWidget {
  const ClinicalRecordTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ClinicalProvider>(
      builder: (context, clinical, _) {
        if (clinical.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (clinical.error != null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(clinical.error!,
                    style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 12),
                ElevatedButton(
                    onPressed: () => clinical.loadAll(clinical.patientId!),
                    child: const Text('Retry')),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () => clinical.loadAll(clinical.patientId!),
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              _VitalSignsSection(clinical.vitalSigns),
              _DiagnosesSection(clinical.diagnoses),
              _ProblemsSection(clinical.problems),
              _ProceduresSection(clinical.procedures),
              _ImmunizationsSection(clinical.immunizations),
            ],
          ),
        );
      },
    );
  }
}

// ── Shared section scaffold ────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final int count;
  final Widget form;
  final List<Widget> children;

  const _Section({
    required this.title,
    required this.count,
    required this.form,
    required this.children,
  });

  Future<void> _openForm(BuildContext context) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => form,
    );
    if (created == true && context.mounted) {
      context.read<ClinicalProvider>().loadAll(
            context.read<ClinicalProvider>().patientId!,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ExpansionTile(
        title: Text('$title ($count)',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => _openForm(context),
              tooltip: 'Add',
            ),
            const Icon(Icons.expand_more),
          ],
        ),
        children: children.isEmpty
            ? [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('None recorded',
                      style: TextStyle(color: Colors.grey[600])),
                )
              ]
            : children,
      ),
    );
  }
}

Future<void> _confirmDelete(
    BuildContext context, String label, VoidCallback onConfirm) {
  return showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete Record'),
      content: Text('Delete this $label? This cannot be undone.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            onConfirm();
          },
          child:
              const Text('Delete', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
}

// ── Vital Signs Section ────────────────────────────────────────────────────────

class _VitalSignsSection extends StatelessWidget {
  final List<VitalSignModel> items;
  const _VitalSignsSection(this.items);

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Vital Signs',
      count: items.length,
      form: const VitalSignForm(),
      children: items.map((v) => _VitalSignTile(v)).toList(),
    );
  }
}

class _VitalSignTile extends StatelessWidget {
  final VitalSignModel v;
  const _VitalSignTile(this.v);

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('dd MMM yyyy HH:mm').format(v.recordedAt.toLocal());
    return ListTile(
      dense: true,
      title: Text(date,
          style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Wrap(
        spacing: 12,
        children: [
          if (v.bloodPressureSystolic != null)
            Text('BP: ${v.bpDisplay}'),
          if (v.heartRate != null)
            Text('HR: ${v.heartRate} bpm'),
          if (v.oxygenSaturation != null)
            Text('SpO₂: ${v.spo2Display}'),
          if (v.temperature != null)
            Text('Temp: ${v.tempDisplay}'),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, color: Colors.red),
        onPressed: () => _confirmDelete(context, 'vital sign reading', () {
          context.read<ClinicalProvider>().deleteVitalSign(v.id);
        }),
      ),
    );
  }
}

// ── Diagnoses Section ─────────────────────────────────────────────────────────

class _DiagnosesSection extends StatelessWidget {
  final List<DiagnosisModel> items;
  const _DiagnosesSection(this.items);

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Diagnoses',
      count: items.length,
      form: const DiagnosisForm(),
      children: items.map((d) => _DiagnosisTile(d)).toList(),
    );
  }
}

class _DiagnosisTile extends StatelessWidget {
  final DiagnosisModel d;
  const _DiagnosisTile(this.d);

  Color get _statusColor => switch (d.status) {
        'active'      => Colors.red,
        'in_remission'=> Colors.orange,
        'resolved'    => Colors.green,
        _             => Colors.grey,
      };

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      title: Text(d.description,
          style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: _statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(d.status,
              style: TextStyle(
                  color: _statusColor, fontSize: 11)),
        ),
        if (d.icdCode != null) ...[
          const SizedBox(width: 8),
          Text(d.icdCode!,
              style:
                  const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ]),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, color: Colors.red),
        onPressed: () => _confirmDelete(context, 'diagnosis', () {
          context.read<ClinicalProvider>().deleteDiagnosis(d.id);
        }),
      ),
    );
  }
}

// ── Problem List Section ──────────────────────────────────────────────────────

class _ProblemsSection extends StatelessWidget {
  final List<ProblemListModel> items;
  const _ProblemsSection(this.items);

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Problem List',
      count: items.length,
      form: const ProblemForm(),
      children: items.map((p) => _ProblemTile(p)).toList(),
    );
  }
}

class _ProblemTile extends StatelessWidget {
  final ProblemListModel p;
  const _ProblemTile(this.p);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      title: Text(p.description,
          style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(p.status,
          style: TextStyle(
              color: p.isActive ? Colors.orange : Colors.green,
              fontSize: 11)),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, color: Colors.red),
        onPressed: () => _confirmDelete(context, 'problem', () {
          context.read<ClinicalProvider>().deleteProblem(p.id);
        }),
      ),
    );
  }
}

// ── Procedures Section ────────────────────────────────────────────────────────

class _ProceduresSection extends StatelessWidget {
  final List<ProcedureModel> items;
  const _ProceduresSection(this.items);

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Procedures',
      count: items.length,
      form: const ProcedureForm(),
      children: items.map((p) => _ProcedureTile(p)).toList(),
    );
  }
}

class _ProcedureTile extends StatelessWidget {
  final ProcedureModel p;
  const _ProcedureTile(this.p);

  @override
  Widget build(BuildContext context) {
    final date = p.performedAt != null
        ? DateFormat('dd MMM yyyy').format(p.performedAt!.toLocal())
        : 'Date unknown';
    return ListTile(
      dense: true,
      title: Text(p.description,
          style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text('$date · ${p.status}',
          style: const TextStyle(fontSize: 11)),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, color: Colors.red),
        onPressed: () => _confirmDelete(context, 'procedure', () {
          context.read<ClinicalProvider>().deleteProcedure(p.id);
        }),
      ),
    );
  }
}

// ── Immunizations Section ─────────────────────────────────────────────────────

class _ImmunizationsSection extends StatelessWidget {
  final List<ImmunizationModel> items;
  const _ImmunizationsSection(this.items);

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Immunizations',
      count: items.length,
      form: const ImmunizationForm(),
      children: items.map((i) => _ImmunizationTile(i)).toList(),
    );
  }
}

class _ImmunizationTile extends StatelessWidget {
  final ImmunizationModel i;
  const _ImmunizationTile(this.i);

  @override
  Widget build(BuildContext context) {
    final date =
        DateFormat('dd MMM yyyy').format(i.administeredAt.toLocal());
    return ListTile(
      dense: true,
      title: Text(i.vaccineName,
          style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(
          '$date · ${i.doseDisplay} · ${i.route}',
          style: const TextStyle(fontSize: 11)),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, color: Colors.red),
        onPressed: () => _confirmDelete(context, 'immunization record', () {
          context.read<ClinicalProvider>().deleteImmunization(i.id);
        }),
      ),
    );
  }
}
```

- [ ] **Step 2: Check for `intl` package — it's needed for DateFormat**

```bash
grep 'intl' /home/dh/Forge/sandbox/healthcare_emr_mobile/pubspec.yaml
```
If `intl` is not listed, add it to `pubspec.yaml` dependencies:
```yaml
  intl: ^0.19.0
```
Then run:
```bash
cd /home/dh/Forge/sandbox/healthcare_emr_mobile && flutter pub get
```

- [ ] **Step 3: Analyze**

```bash
flutter analyze lib/presentation/patients/widgets/clinical_record_tab.dart
```
Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/patients/widgets/clinical_record_tab.dart lib/presentation/patients/widgets/clinical_record_forms.dart pubspec.yaml pubspec.lock
git commit -m "feat(mobile): add ClinicalRecordTab with 5 collapsible sections and write forms"
```

---

## Task 7: Wire Clinical Record tab into PatientDetailScreen

**Files:**
- Modify: `lib/presentation/patients/screens/patient_detail_screen.dart`

Add a 6th tab (index 5) visible to doctors and nurses. Update the FAB switch to open the correct form for the new tab.

- [ ] **Step 1: Add the import for new widgets**

At the top of `patient_detail_screen.dart`, add:
```dart
import '../widgets/clinical_record_tab.dart';
import '../widgets/clinical_record_forms.dart';
```

- [ ] **Step 2: Update role-based tab index lists**

Replace the four const lists at the top of the file:
```dart
// 0=Overview 1=Appointments 2=Prescriptions 3=Lab Results 4=Documents 5=Clinical Record
const _nurseTabIndices      = [0, 1, 5];
const _pharmacistTabIndices = [0, 2];
const _labTechTabIndices    = [0, 3];
const _doctorTabIndices     = [0, 1, 2, 3, 4, 5];
```

- [ ] **Step 3: Add "Clinical Record" to `_allTabs`**

Find where the TabBar `tabs:` list is defined (it contains the current 5 tabs). Add as the sixth element:
```dart
const Tab(text: 'Clinical Record'),
```

Find where the `TabBarView children:` list is defined. Add as the sixth element:
```dart
const ClinicalRecordTab(),
```

- [ ] **Step 4: Update the FAB switch in `_openClinicalForm()`**

In the `switch (_currentTab)` block, add a case for tab 5 before the `default:`:
```dart
      case 5: // Clinical Record — FAB cycles through forms
        // Show a bottom sheet with sub-options for each resource type
        await _showClinicalRecordFormPicker(context);
        return;
```

Then add the helper method to `_PatientDetailScreenState`:
```dart
  Future<void> _showClinicalRecordFormPicker(BuildContext context) async {
    final choice = await showModalBottomSheet<Type>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.monitor_heart),
              title: const Text('Vital Signs'),
              onTap: () => Navigator.pop(ctx, VitalSignForm),
            ),
            ListTile(
              leading: const Icon(Icons.medical_information),
              title: const Text('Diagnosis'),
              onTap: () => Navigator.pop(ctx, DiagnosisForm),
            ),
            ListTile(
              leading: const Icon(Icons.list_alt),
              title: const Text('Problem'),
              onTap: () => Navigator.pop(ctx, ProblemForm),
            ),
            ListTile(
              leading: const Icon(Icons.local_hospital),
              title: const Text('Procedure'),
              onTap: () => Navigator.pop(ctx, ProcedureForm),
            ),
            ListTile(
              leading: const Icon(Icons.vaccines),
              title: const Text('Immunization'),
              onTap: () => Navigator.pop(ctx, ImmunizationForm),
            ),
          ],
        ),
      ),
    );

    if (choice == null || !mounted) return;

    Widget form = switch (choice) {
      _ when choice == VitalSignForm    => const VitalSignForm(),
      _ when choice == DiagnosisForm    => const DiagnosisForm(),
      _ when choice == ProblemForm      => const ProblemForm(),
      _ when choice == ProcedureForm    => const ProcedureForm(),
      _ when choice == ImmunizationForm => const ImmunizationForm(),
      _                                 => const VitalSignForm(),
    };

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => form,
    );

    if (created == true && mounted) {
      context.read<ClinicalProvider>().loadAll(
            context.read<ClinicalProvider>().patientId!,
          );
    }
  }
```

- [ ] **Step 5: Analyze**

```bash
flutter analyze lib/presentation/patients/screens/patient_detail_screen.dart
```
Expected: no errors.

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/patients/screens/patient_detail_screen.dart
git commit -m "feat(mobile): add Clinical Record tab (tab 5) to PatientDetailScreen for doctors and nurses"
```

---

## Task 8: Rewire RosterScreen to use the dedicated roster API

**Files:**
- Modify: `lib/presentation/roster/screens/roster_screen.dart`

Replace the N+1 appointment-aggregation hack with N+1 calls to the new `/patients/{id}/roster` endpoint. Show `RosterEntryModel` data (triage severity, status, chief complaint) instead of appointment data. Allow updating status (waiting → in_consultation → seen).

- [ ] **Step 1: Add the import for the new model and provider**

At the top of `roster_screen.dart`, replace or add:
```dart
import '../../../data/models/clinical_record_models.dart';
```
(Keep existing imports for `PatientModel`, `PatientProvider`, `AuthProvider`, `ClinicalProvider`.)

- [ ] **Step 2: Replace the screen state fields**

Replace `_todayAppts` and `_rosterPatients` with:
```dart
  // patientId → today's roster entries
  final Map<String, List<RosterEntryModel>> _rosterMap = {};
  List<PatientModel> _rosterPatients = [];
```

- [ ] **Step 3: Replace the `_load()` method body**

Replace the existing `_load()` implementation with:
```dart
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final auth          = context.read<AuthProvider>();
      final patientProv   = context.read<PatientProvider>();
      final clinicalRepo  = context.read<ClinicalProvider>().repository;

      await patientProv.loadPatients(
          providerId: auth.currentUserId, forceRefresh: true);

      final patients = patientProv.patients;
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);

      final Map<String, List<RosterEntryModel>> rosterMap = {};

      await Future.wait(patients.map((p) async {
        try {
          final entries = await clinicalRepo.getRosterEntries(
            p.id,
            date: todayStr,
          );
          if (entries.isNotEmpty) {
            rosterMap[p.id] = entries;
          }
        } catch (_) {
          // Skip patients we can't load roster for
        }
      }));

      final rostered = patients
          .where((p) => rosterMap.containsKey(p.id))
          .toList()
        ..sort((a, b) {
          final aEntries = rosterMap[a.id]!;
          final bEntries = rosterMap[b.id]!;
          // Sort by highest triage priority (lowest number = most urgent)
          final aPrio = aEntries
              .map((e) => e.triagePriority)
              .reduce((min, x) => x < min ? x : min);
          final bPrio = bEntries
              .map((e) => e.triagePriority)
              .reduce((min, x) => x < min ? x : min);
          return aPrio.compareTo(bPrio);
        });

      setState(() {
        _rosterMap = {};
        _rosterMap.addAll(rosterMap);
        _rosterPatients = rostered;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load roster: $e';
        _loading = false;
      });
    }
  }
```

- [ ] **Step 4: Replace roster card UI to show RosterEntryModel data**

Find the existing patient card builder (the widget built per patient in the list). Replace the body to show triage severity + chief complaint + status, and add a status-update button:

In the `ListView.builder` or equivalent in the `build()` method, replace the patient card content with:
```dart
// Per patient card in the list:
final entries = _rosterMap[patient.id] ?? [];
final entry   = entries.first; // show the primary (first) entry

Color triageColor = switch (entry.triageSeverity) {
  'critical' => Colors.red,
  'urgent'   => Colors.orange,
  'moderate' => Colors.blue,
  'low'      => Colors.green,
  _          => Colors.grey,
};

return Card(
  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
  child: ListTile(
    leading: CircleAvatar(
      backgroundColor: triageColor.withOpacity(0.15),
      child: Icon(Icons.person, color: triageColor),
    ),
    title: Text(
      '${patient.firstName} ${patient.lastName}',
      style: const TextStyle(fontWeight: FontWeight.w600),
    ),
    subtitle: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (entry.chiefComplaint != null)
          Text(entry.chiefComplaint!,
              style: const TextStyle(fontSize: 12)),
        Row(children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: triageColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              entry.triageSeverity ?? 'unset',
              style: TextStyle(color: triageColor, fontSize: 11),
            ),
          ),
          const SizedBox(width: 8),
          Text(entry.status,
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ]),
      ],
    ),
    trailing: entry.isTerminal
        ? const Icon(Icons.check_circle, color: Colors.green)
        : entry.isWaiting
            ? ElevatedButton(
                onPressed: () =>
                    _startConsultation(patient, entry),
                child: const Text('Start'),
              )
            : const Icon(Icons.access_time, color: Colors.orange),
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PatientDetailScreen(patient: patient),
      ),
    ),
  ),
);
```

- [ ] **Step 5: Add `_startConsultation` helper**

Add to `_RosterScreenState`:
```dart
  Future<void> _startConsultation(
      PatientModel patient, RosterEntryModel entry) async {
    final repo = context.read<ClinicalProvider>().repository;
    try {
      await repo.updateRosterEntry(
        patient.id,
        entry.id,
        {'status': 'in_consultation', 'version': entry.version},
      );
      await _load(); // Refresh to show updated status
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e')),
        );
      }
    }
  }
```

- [ ] **Step 6: Fix state field type conflict**

Since `_rosterMap` is now declared as `final Map<...> _rosterMap = {}` but is reassigned in `_load()`, change the declaration to non-final:
```dart
  Map<String, List<RosterEntryModel>> _rosterMap = {};
```

- [ ] **Step 7: Analyze**

```bash
flutter analyze lib/presentation/roster/screens/roster_screen.dart
```
Expected: no errors. Fix any residual references to `AppointmentModel` fields (replace with `RosterEntryModel` equivalents).

- [ ] **Step 8: Commit**

```bash
git add lib/presentation/roster/screens/roster_screen.dart
git commit -m "feat(mobile): rewire RosterScreen to use dedicated roster API with triage severity and status updates"
```

---

## Self-Review

### Spec coverage

| Requirement | Task |
|---|---|
| VitalSignModel with all backend fields | Task 1 |
| DiagnosisModel | Task 1 |
| ProblemListModel | Task 1 |
| ProcedureModel | Task 1 |
| ImmunizationModel | Task 1 |
| RosterEntryModel | Task 1 |
| ward_id on Appointment, Prescription, LabResult | Task 2 |
| coding_system on Prescription | Task 2 |
| Repository: list + create + delete for all 6 | Task 3 |
| Repository: update for RosterEntry | Task 3 |
| Provider state + loaders for all 5 new resources | Task 4 |
| Provider: extend `loadAll` | Task 4 |
| Provider: extend `clear()` | Task 4 |
| VitalSignForm | Task 5 |
| DiagnosisForm | Task 5 |
| ProblemForm | Task 5 |
| ProcedureForm | Task 5 |
| ImmunizationForm | Task 5 |
| ClinicalRecordTab with 5 sections | Task 6 |
| Delete confirmation in each section | Task 6 |
| Tab 5 added to PatientDetailScreen | Task 7 |
| Nurse role sees tab 5 | Task 7 |
| Doctor role sees tab 5 | Task 7 |
| FAB on tab 5 opens resource picker | Task 7 |
| RosterScreen rewired to roster API | Task 8 |
| RosterScreen sorts by triage severity | Task 8 |
| RosterScreen start-consultation action | Task 8 |

### Type consistency check

- `VitalSignModel` uses `recordedById` consistently (matches backend `recorded_by_id`) ✓
- `DiagnosisModel.diagnosedById` matches backend `diagnosed_by_id` ✓
- `RosterEntryModel.triagePriority` getter used in sort in Task 8 ✓
- All `fromJson` keys match backend `format()` output ✓
- `ClinicalProvider` method names (`createVitalSign`, `deleteVitalSign`, etc.) match usage in forms and tab ✓
- `ClinicalRepository` method names match `ClinicalProvider` calls ✓
