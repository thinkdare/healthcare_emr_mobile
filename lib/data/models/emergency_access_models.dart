class EmergencyAccessModel {
  final String id;
  final String masterPatientId;
  final String? patientName;
  final String? providerId;
  final String? providerName;
  final String? facilityId;
  final String? facilityName;
  final String emergencyType;
  final String? notifiedProviderId;
  final String notificationStatus;
  final bool reviewedByPrimary;
  final DateTime? reviewedAt;
  final bool escalatedToSupervisor;
  final DateTime? escalatedAt;
  final bool needsEscalation;
  final DateTime accessedAt;
  // Detailed view only
  final String? emergencyDetails;
  final List<String>? dataAccessed;
  final String? reviewNotes;

  const EmergencyAccessModel({
    required this.id,
    required this.masterPatientId,
    this.patientName,
    this.providerId,
    this.providerName,
    this.facilityId,
    this.facilityName,
    required this.emergencyType,
    this.notifiedProviderId,
    required this.notificationStatus,
    required this.reviewedByPrimary,
    this.reviewedAt,
    required this.escalatedToSupervisor,
    this.escalatedAt,
    required this.needsEscalation,
    required this.accessedAt,
    this.emergencyDetails,
    this.dataAccessed,
    this.reviewNotes,
  });

  String get emergencyTypeDisplay => switch (emergencyType) {
        'life_threatening'  => 'Life Threatening',
        'unconscious'       => 'Unconscious Patient',
        'unable_to_consent' => 'Unable to Consent',
        'critical_care'     => 'Critical Care',
        _                   => emergencyType,
      };

  bool get needsReview => !reviewedByPrimary;

  factory EmergencyAccessModel.fromJson(Map<String, dynamic> json) =>
      EmergencyAccessModel(
        id:                    json['id'] as String,
        masterPatientId:       json['master_patient_id'] as String,
        patientName:           json['patient_name'] as String?,
        providerId:            json['provider_id'] as String?,
        providerName:          json['provider_name'] as String?,
        facilityId:            json['facility_id'] as String?,
        facilityName:          json['facility_name'] as String?,
        emergencyType:         json['emergency_type'] as String,
        notifiedProviderId:    json['notified_provider_id'] as String?,
        notificationStatus:    json['notification_status'] as String? ?? 'pending',
        reviewedByPrimary:     json['reviewed_by_primary'] as bool? ?? false,
        reviewedAt:            json['reviewed_at'] != null
                                   ? DateTime.parse(json['reviewed_at'] as String)
                                   : null,
        escalatedToSupervisor: json['escalated_to_supervisor'] as bool? ?? false,
        escalatedAt:           json['escalated_at'] != null
                                   ? DateTime.parse(json['escalated_at'] as String)
                                   : null,
        needsEscalation:       json['needs_escalation'] as bool? ?? false,
        accessedAt:            DateTime.parse(json['accessed_at'] as String),
        emergencyDetails:      json['emergency_details'] as String?,
        dataAccessed:          (json['data_accessed'] as List?)
                                   ?.map((e) => e.toString())
                                   .toList(),
        reviewNotes:           json['review_notes'] as String?,
      );
}
