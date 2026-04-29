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
    DateTime? d(String k) {
      final v = json[k];
      return v == null ? null : DateTime.tryParse(v as String);
    }

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
      createdAt: d('created_at'),
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
      doseNumber: (json['dose_number'] as num?)?.toInt() ?? 1,
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
