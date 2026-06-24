// lib/data/models/patient_consent_models.dart

class PatientConsentModel {
  final String id;
  final String consentType; // data_sharing | cross_facility_access | research | marketing | portal_access
  final String legalBasis;
  final bool given;
  final DateTime? givenAt;
  final DateTime? withdrawnAt;
  final String? notes;
  final DateTime recordedAt;

  const PatientConsentModel({
    required this.id,
    required this.consentType,
    required this.legalBasis,
    required this.given,
    this.givenAt,
    this.withdrawnAt,
    this.notes,
    required this.recordedAt,
  });

  String get consentTypeLabel => switch (consentType) {
        'data_sharing' => 'Data Sharing',
        'cross_facility_access' => 'Cross-Facility Access',
        'research' => 'Research',
        'marketing' => 'Marketing',
        'portal_access' => 'Portal Access',
        _ => consentType,
      };

  factory PatientConsentModel.fromJson(Map<String, dynamic> json) =>
      PatientConsentModel(
        id: json['id'] as String,
        consentType: json['consent_type'] as String,
        legalBasis: json['legal_basis'] as String,
        given: json['given'] as bool,
        givenAt: json['given_at'] != null ? DateTime.tryParse(json['given_at'] as String) : null,
        withdrawnAt:
            json['withdrawn_at'] != null ? DateTime.tryParse(json['withdrawn_at'] as String) : null,
        notes: json['notes'] as String?,
        recordedAt: DateTime.parse(json['recorded_at'] as String),
      );
}

class PatientConsentEventModel {
  final String id;
  final String action; // granted | updated | revoked
  final String consentType;
  final String legalBasis;
  final String documentVersion;
  final String actorType;
  final String? actorName;
  final String? notes;
  final DateTime occurredAt;

  const PatientConsentEventModel({
    required this.id,
    required this.action,
    required this.consentType,
    required this.legalBasis,
    required this.documentVersion,
    required this.actorType,
    this.actorName,
    this.notes,
    required this.occurredAt,
  });

  factory PatientConsentEventModel.fromJson(Map<String, dynamic> json) =>
      PatientConsentEventModel(
        id: json['id'] as String,
        action: json['action'] as String,
        consentType: json['consent_type'] as String,
        legalBasis: json['legal_basis'] as String,
        documentVersion: json['document_version'] as String,
        actorType: json['actor_type'] as String,
        actorName: json['actor_name'] as String?,
        notes: json['notes'] as String?,
        occurredAt: DateTime.parse(json['occurred_at'] as String),
      );
}

class NotificationPreferencesModel {
  final bool appointmentReminders;
  final bool sms;
  final bool email;
  final bool push;

  const NotificationPreferencesModel({
    this.appointmentReminders = true,
    this.sms = true,
    this.email = true,
    this.push = true,
  });

  factory NotificationPreferencesModel.fromJson(Map<String, dynamic>? json) =>
      NotificationPreferencesModel(
        appointmentReminders: (json?['appointment_reminders'] as bool?) ?? true,
        sms: (json?['sms'] as bool?) ?? true,
        email: (json?['email'] as bool?) ?? true,
        push: (json?['push'] as bool?) ?? true,
      );

  NotificationPreferencesModel copyWith({
    bool? appointmentReminders,
    bool? sms,
    bool? email,
    bool? push,
  }) =>
      NotificationPreferencesModel(
        appointmentReminders: appointmentReminders ?? this.appointmentReminders,
        sms: sms ?? this.sms,
        email: email ?? this.email,
        push: push ?? this.push,
      );
}
