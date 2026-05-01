import 'package:json_annotation/json_annotation.dart';

part 'patient_models.g.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AllergyModel
// ─────────────────────────────────────────────────────────────────────────────

@JsonSerializable()
class AllergyModel {
  final String name;
  final String severity;

  @JsonKey(name: 'noted_date')
  final String? notedDate;

  const AllergyModel({
    required this.name,
    required this.severity,
    this.notedDate,
  });

  factory AllergyModel.fromJson(Map<String, dynamic> json) =>
      _$AllergyModelFromJson(json);

  Map<String, dynamic> toJson() => _$AllergyModelToJson(this);

  /// Colour-coded severity for UI display
  bool get isLifeThreatening => severity == 'life_threatening';
  bool get isSevere => severity == 'severe';
}

// ─────────────────────────────────────────────────────────────────────────────
// MedicationModel
// ─────────────────────────────────────────────────────────────────────────────

@JsonSerializable()
class MedicationModel {
  final String name;
  final String? dosage;
  final String? frequency;

  const MedicationModel({
    required this.name,
    this.dosage,
    this.frequency,
  });

  factory MedicationModel.fromJson(Map<String, dynamic> json) =>
      _$MedicationModelFromJson(json);

  Map<String, dynamic> toJson() => _$MedicationModelToJson(this);

  String get displayDose {
    final parts = [if (dosage != null) dosage!, if (frequency != null) frequency!];
    return parts.isNotEmpty ? parts.join(' — ') : name;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PatientProviderLite  (nested inside PatientModel)
// ─────────────────────────────────────────────────────────────────────────────

@JsonSerializable()
class PatientProviderLite {
  final String id;

  @JsonKey(name: 'first_name')
  final String firstName;

  @JsonKey(name: 'last_name')
  final String lastName;

  @JsonKey(name: 'provider_type')
  final String providerType;

  const PatientProviderLite({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.providerType,
  });

  factory PatientProviderLite.fromJson(Map<String, dynamic> json) =>
      _$PatientProviderLiteFromJson(json);

  Map<String, dynamic> toJson() => _$PatientProviderLiteToJson(this);

  String get fullName => '$firstName $lastName';
}

// ─────────────────────────────────────────────────────────────────────────────
// PatientFacilityLite  (nested inside PatientModel)
// ─────────────────────────────────────────────────────────────────────────────

@JsonSerializable()
class PatientFacilityLite {
  final String id;
  final String name;
  final String? type;

  const PatientFacilityLite({
    required this.id,
    required this.name,
    this.type,
  });

  factory PatientFacilityLite.fromJson(Map<String, dynamic> json) =>
      _$PatientFacilityLiteFromJson(json);

  Map<String, dynamic> toJson() => _$PatientFacilityLiteToJson(this);
}

// ─────────────────────────────────────────────────────────────────────────────
// PatientModel
// ─────────────────────────────────────────────────────────────────────────────

@JsonSerializable(explicitToJson: true)
class PatientModel {
  final String id;

  /// Medical Record Number assigned by the facility (e.g. LGOS-2026-00042).
  final String? mrn;

  @JsonKey(name: 'primary_provider_id')
  final String primaryProviderId;

  @JsonKey(name: 'current_facility_id')
  final String? currentFacilityId;

  @JsonKey(name: 'first_name')
  final String firstName;

  @JsonKey(name: 'last_name')
  final String lastName;

  @JsonKey(name: 'date_of_birth')
  final String dateOfBirth;

  final String gender;

  @JsonKey(name: 'blood_type')
  final String? bloodType;

  final String? phone;
  final String? email;
  final String? address;

  @JsonKey(name: 'emergency_contact_name')
  final String emergencyContactName;

  @JsonKey(name: 'emergency_contact_phone')
  final String emergencyContactPhone;

  final List<AllergyModel> allergies;

  @JsonKey(name: 'current_medications')
  final List<MedicationModel> currentMedications;

  @JsonKey(name: 'chronic_conditions')
  final List<String> chronicConditions;

  @JsonKey(name: 'insurance_provider')
  final String? insuranceProvider;

  @JsonKey(name: 'insurance_number')
  final String? insuranceNumber;

  @JsonKey(name: 'medical_history')
  final String? medicalHistory;

  /// Only present in detail view — used for cross-facility access grant requests.
  @JsonKey(name: 'global_patient_id')
  final String? globalPatientId;

  @JsonKey(name: 'patient_portal_enabled')
  final bool patientPortalEnabled;

  @JsonKey(name: 'is_active')
  final bool isActive;

  @JsonKey(name: 'last_synced_at')
  final DateTime? lastSyncedAt;

  @JsonKey(name: 'created_at')
  final DateTime? createdAt;

  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  // Eager-loaded relationships (nullable — not always present)
  @JsonKey(name: 'primary_provider')
  final PatientProviderLite? primaryProvider;

  @JsonKey(name: 'current_facility')
  final PatientFacilityLite? currentFacility;

  const PatientModel({
    required this.id,
    this.mrn,
    required this.primaryProviderId,
    this.currentFacilityId,
    required this.firstName,
    required this.lastName,
    required this.dateOfBirth,
    required this.gender,
    this.bloodType,
    this.phone,
    this.email,
    this.address,
    required this.emergencyContactName,
    required this.emergencyContactPhone,
    this.allergies = const [],
    this.currentMedications = const [],
    this.chronicConditions = const [],
    this.insuranceProvider,
    this.insuranceNumber,
    this.medicalHistory,
    this.globalPatientId,
    this.patientPortalEnabled = false,
    this.isActive = true,
    this.lastSyncedAt,
    this.createdAt,
    this.updatedAt,
    this.primaryProvider,
    this.currentFacility,
  });

  factory PatientModel.fromJson(Map<String, dynamic> json) =>
      _$PatientModelFromJson(json);

  Map<String, dynamic> toJson() => _$PatientModelToJson(this);

  // ── Computed helpers ────────────────────────────────────────────────────────

  String get fullName => '$firstName $lastName';

  /// Best attempt at age from ISO date string
  int? get age {
    try {
      final dob = DateTime.parse(dateOfBirth);
      final now = DateTime.now();
      int years = now.year - dob.year;
      if (now.month < dob.month ||
          (now.month == dob.month && now.day < dob.day)) {
        years--;
      }
      return years;
    } catch (_) {
      return null;
    }
  }

  String get ageDisplay => age != null ? '$age yrs' : '—';

  bool get hasAllergies => allergies.isNotEmpty;
  bool get hasCriticalAllergies =>
      allergies.any((a) => a.isLifeThreatening || a.isSevere);
}

// ─────────────────────────────────────────────────────────────────────────────
// PaginatedPatientResponse  (wraps the Laravel paginator envelope)
// ─────────────────────────────────────────────────────────────────────────────

@JsonSerializable(explicitToJson: true)
class PaginatedPatientResponse {
  final List<PatientModel> data;

  @JsonKey(name: 'current_page')
  final int currentPage;

  @JsonKey(name: 'per_page')
  final int perPage;

  final int total;

  @JsonKey(name: 'last_page')
  final int lastPage;

  const PaginatedPatientResponse({
    required this.data,
    required this.currentPage,
    required this.perPage,
    required this.total,
    required this.lastPage,
  });

  factory PaginatedPatientResponse.fromJson(Map<String, dynamic> json) =>
      _$PaginatedPatientResponseFromJson(json);

  Map<String, dynamic> toJson() => _$PaginatedPatientResponseToJson(this);

  bool get hasMore => currentPage < lastPage;
}

// ─────────────────────────────────────────────────────────────────────────────
// DashboardStatsModel
// ─────────────────────────────────────────────────────────────────────────────

/// Holds the data that drives the Quick Stats section on the dashboard.
/// This is a client-side aggregation — not a dedicated API endpoint.
/// The stats are derived from cached data when offline, or fetched on demand.
class DashboardStatsModel {
  final int totalPatients;
  final int activePatients;
  final int recentPatients; // created in last 7 days

  // Phase 5 will populate these — kept as 0 for now
  final int pendingAppointments;
  final int activePrescriptions;

  final DateTime? lastRefreshed;
  final bool isFromCache;

  const DashboardStatsModel({
    this.totalPatients = 0,
    this.activePatients = 0,
    this.recentPatients = 0,
    this.pendingAppointments = 0,
    this.activePrescriptions = 0,
    this.lastRefreshed,
    this.isFromCache = false,
  });

  DashboardStatsModel copyWith({
    int? totalPatients,
    int? activePatients,
    int? recentPatients,
    int? pendingAppointments,
    int? activePrescriptions,
    DateTime? lastRefreshed,
    bool? isFromCache,
  }) {
    return DashboardStatsModel(
      totalPatients: totalPatients ?? this.totalPatients,
      activePatients: activePatients ?? this.activePatients,
      recentPatients: recentPatients ?? this.recentPatients,
      pendingAppointments: pendingAppointments ?? this.pendingAppointments,
      activePrescriptions: activePrescriptions ?? this.activePrescriptions,
      lastRefreshed: lastRefreshed ?? this.lastRefreshed,
      isFromCache: isFromCache ?? this.isFromCache,
    );
  }
}