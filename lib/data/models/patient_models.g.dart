// GENERATED CODE - DO NOT MODIFY BY HAND
// Run: flutter pub run build_runner build --delete-conflicting-outputs

part of 'patient_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AllergyModel
// ─────────────────────────────────────────────────────────────────────────────

AllergyModel _$AllergyModelFromJson(Map<String, dynamic> json) => AllergyModel(
      name: json['name'] as String,
      severity: json['severity'] as String,
      notedDate: json['noted_date'] as String?,
    );

Map<String, dynamic> _$AllergyModelToJson(AllergyModel instance) =>
    <String, dynamic>{
      'name': instance.name,
      'severity': instance.severity,
      'noted_date': instance.notedDate,
    };

// ─────────────────────────────────────────────────────────────────────────────
// MedicationModel
// ─────────────────────────────────────────────────────────────────────────────

MedicationModel _$MedicationModelFromJson(Map<String, dynamic> json) =>
    MedicationModel(
      name: json['name'] as String,
      dosage: json['dosage'] as String?,
      frequency: json['frequency'] as String?,
    );

Map<String, dynamic> _$MedicationModelToJson(MedicationModel instance) =>
    <String, dynamic>{
      'name': instance.name,
      'dosage': instance.dosage,
      'frequency': instance.frequency,
    };

// ─────────────────────────────────────────────────────────────────────────────
// PatientProviderLite
// ─────────────────────────────────────────────────────────────────────────────

PatientProviderLite _$PatientProviderLiteFromJson(Map<String, dynamic> json) =>
    PatientProviderLite(
      id: json['id'] as String,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      providerType: json['provider_type'] as String,
    );

Map<String, dynamic> _$PatientProviderLiteToJson(
        PatientProviderLite instance) =>
    <String, dynamic>{
      'id': instance.id,
      'first_name': instance.firstName,
      'last_name': instance.lastName,
      'provider_type': instance.providerType,
    };

// ─────────────────────────────────────────────────────────────────────────────
// PatientFacilityLite
// ─────────────────────────────────────────────────────────────────────────────

PatientFacilityLite _$PatientFacilityLiteFromJson(
        Map<String, dynamic> json) =>
    PatientFacilityLite(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String?,
    );

Map<String, dynamic> _$PatientFacilityLiteToJson(
        PatientFacilityLite instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'type': instance.type,
    };

// ─────────────────────────────────────────────────────────────────────────────
// PatientModel
// ─────────────────────────────────────────────────────────────────────────────

PatientModel _$PatientModelFromJson(Map<String, dynamic> json) => PatientModel(
      id: json['id'] as String,
      primaryProviderId: json['primary_provider_id'] as String,
      currentFacilityId: json['current_facility_id'] as String?,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      dateOfBirth: json['date_of_birth'] as String,
      gender: json['gender'] as String,
      bloodType: json['blood_type'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      address: json['address'] as String?,
      emergencyContactName: json['emergency_contact_name'] as String,
      emergencyContactPhone: json['emergency_contact_phone'] as String,
      allergies: (json['allergies'] as List<dynamic>?)
              ?.map((e) =>
                  AllergyModel.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
      currentMedications: (json['current_medications'] as List<dynamic>?)
              ?.map((e) =>
                  MedicationModel.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
      chronicConditions: (json['chronic_conditions'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      insuranceProvider: json['insurance_provider'] as String?,
      insuranceNumber: json['insurance_number'] as String?,
      patientPortalEnabled: json['patient_portal_enabled'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      lastSyncedAt: json['last_synced_at'] == null
          ? null
          : DateTime.parse(json['last_synced_at'] as String),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
      primaryProvider: json['primary_provider'] == null
          ? null
          : PatientProviderLite.fromJson(
              Map<String, dynamic>.from(json['primary_provider'] as Map)),
      currentFacility: json['current_facility'] == null
          ? null
          : PatientFacilityLite.fromJson(
              Map<String, dynamic>.from(json['current_facility'] as Map)),
    );

Map<String, dynamic> _$PatientModelToJson(PatientModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'primary_provider_id': instance.primaryProviderId,
      'current_facility_id': instance.currentFacilityId,
      'first_name': instance.firstName,
      'last_name': instance.lastName,
      'date_of_birth': instance.dateOfBirth,
      'gender': instance.gender,
      'blood_type': instance.bloodType,
      'phone': instance.phone,
      'email': instance.email,
      'address': instance.address,
      'emergency_contact_name': instance.emergencyContactName,
      'emergency_contact_phone': instance.emergencyContactPhone,
      'allergies': instance.allergies.map((e) => e.toJson()).toList(),
      'current_medications':
          instance.currentMedications.map((e) => e.toJson()).toList(),
      'chronic_conditions': instance.chronicConditions,
      'insurance_provider': instance.insuranceProvider,
      'insurance_number': instance.insuranceNumber,
      'patient_portal_enabled': instance.patientPortalEnabled,
      'is_active': instance.isActive,
      'last_synced_at': instance.lastSyncedAt?.toIso8601String(),
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
      'primary_provider': instance.primaryProvider?.toJson(),
      'current_facility': instance.currentFacility?.toJson(),
    };

// ─────────────────────────────────────────────────────────────────────────────
// PaginatedPatientResponse
// ─────────────────────────────────────────────────────────────────────────────

PaginatedPatientResponse _$PaginatedPatientResponseFromJson(
        Map<String, dynamic> json) =>
    PaginatedPatientResponse(
      data: (json['data'] as List<dynamic>)
          .map((e) =>
              PatientModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      currentPage: (json['current_page'] as num).toInt(),
      perPage: (json['per_page'] as num).toInt(),
      total: (json['total'] as num).toInt(),
      lastPage: (json['last_page'] as num).toInt(),
    );

Map<String, dynamic> _$PaginatedPatientResponseToJson(
        PaginatedPatientResponse instance) =>
    <String, dynamic>{
      'data': instance.data.map((e) => e.toJson()).toList(),
      'current_page': instance.currentPage,
      'per_page': instance.perPage,
      'total': instance.total,
      'last_page': instance.lastPage,
    };