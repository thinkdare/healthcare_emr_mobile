// lib/data/models/referral_models.dart

enum ReferralFilter {
  all,
  pending,
  active, // accepted + scheduled
  done;   // completed + cancelled

  bool matches(String status) => switch (this) {
        ReferralFilter.all     => true,
        ReferralFilter.pending => status == 'pending',
        ReferralFilter.active  => status == 'accepted' || status == 'scheduled',
        ReferralFilter.done    => status == 'completed' || status == 'cancelled',
      };

  String get label => switch (this) {
        ReferralFilter.all     => 'All',
        ReferralFilter.pending => 'Pending',
        ReferralFilter.active  => 'Active',
        ReferralFilter.done    => 'Done',
      };
}

class ReferralStatusHistoryModel {
  final String? from;
  final String to;
  final String? changedBy;
  final String? reason;
  final String at;

  const ReferralStatusHistoryModel({
    this.from,
    required this.to,
    this.changedBy,
    this.reason,
    required this.at,
  });

  factory ReferralStatusHistoryModel.fromJson(Map<String, dynamic> json) =>
      ReferralStatusHistoryModel(
        from:      json['from'] as String?,
        to:        json['to'] as String,
        changedBy: json['changed_by'] as String?,
        reason:    json['reason'] as String?,
        at:        json['at'] as String,
      );
}

class ReferralMessageModel {
  final String id;
  final String senderId;
  final String senderName;
  final String message;
  final String createdAt;

  const ReferralMessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.message,
    required this.createdAt,
  });

  factory ReferralMessageModel.fromJson(Map<String, dynamic> json) =>
      ReferralMessageModel(
        id:         json['id'] as String,
        senderId:   json['sender_id'] as String,
        senderName: json['sender'] as String? ?? 'Unknown',
        message:    json['message'] as String,
        createdAt:  json['created_at'] as String,
      );
}

class ReferralModel {
  final String id;
  final String status;
  final String specialty;
  final String urgency;
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
  final String? patientGender;
  final String? reason;
  final String? clinicalSummary;
  final String? relevantHistory;
  final String? currentMedications;
  final String? diagnosticResults;
  final String? consultationNotes;
  final String? recommendations;
  final String? appointmentDate;
  final String? appointmentLocation;
  final bool requiresFollowUp;
  final String? followUpDate;
  final String referredAt;
  final String? acceptedAt;
  final String? scheduledAt;
  final String? completedAt;
  final String? cancelledAt;
  final List<ReferralStatusHistoryModel> statusHistory;

  // Role flags — set at parse time from currentTenantId
  final bool isSent;
  final bool isReceived;

  const ReferralModel({
    required this.id,
    required this.status,
    required this.specialty,
    required this.urgency,
    required this.isUrgent,
    required this.isOverdue,
    this.fromTenantId,
    required this.fromTenantName,
    this.toTenantId,
    required this.toTenantName,
    required this.referringProviderId,
    required this.referringProviderName,
    this.referredToProviderId,
    this.referredToProviderName,
    this.masterPatientId,
    this.patientName,
    this.patientDob,
    this.patientGender,
    this.reason,
    this.clinicalSummary,
    this.relevantHistory,
    this.currentMedications,
    this.diagnosticResults,
    this.consultationNotes,
    this.recommendations,
    this.appointmentDate,
    this.appointmentLocation,
    required this.requiresFollowUp,
    this.followUpDate,
    required this.referredAt,
    this.acceptedAt,
    this.scheduledAt,
    this.completedAt,
    this.cancelledAt,
    required this.isSent,
    required this.isReceived,
    this.statusHistory = const [],
  });

  bool get isOpen      => !['completed', 'cancelled'].contains(status);
  bool get canAccept   => isReceived && status == 'pending';
  bool get canSchedule => isReceived && status == 'accepted';
  bool get canComplete => isReceived && status == 'scheduled';
  bool get canCancel   =>
      isSent && ['pending', 'accepted', 'scheduled'].contains(status);

  factory ReferralModel.fromJson(
    Map<String, dynamic> json, {
    required String currentTenantId,
  }) {
    final fromTenant = json['from_tenant'] as Map?;
    final toTenant   = json['to_tenant']   as Map?;
    final fromId     = fromTenant?['id'] as String?;
    final toId       = toTenant?['id']   as String?;
    final patient    = json['master_patient'] as Map?;

    List<ReferralStatusHistoryModel> history = [];
    final rawHistory = json['status_history'];
    if (rawHistory is List) {
      history = rawHistory
          .map((e) => ReferralStatusHistoryModel.fromJson(
                Map<String, dynamic>.from(e as Map),
              ))
          .toList();
    }

    return ReferralModel(
      id:                     json['id'] as String,
      status:                 json['status'] as String,
      specialty:              json['specialty'] as String,
      urgency:                json['urgency'] as String,
      isUrgent:               (json['is_urgent'] as bool?) ?? false,
      isOverdue:              (json['is_overdue'] as bool?) ?? false,
      fromTenantId:           fromId,
      fromTenantName:         fromTenant?['name'] as String? ?? '',
      toTenantId:             toId,
      toTenantName:           toTenant?['name'] as String? ?? '',
      referringProviderId:    json['referring_provider_id'] as String,
      referringProviderName:  json['referring_provider'] as String? ?? '',
      referredToProviderId:   json['referred_to_provider_id'] as String?,
      referredToProviderName: json['referred_to_provider'] as String?,
      masterPatientId:        patient?['id'] as String?,
      patientName:            patient?['name'] as String?,
      patientDob:             patient?['date_of_birth'] as String?,
      patientGender:          patient?['gender'] as String?,
      reason:                 json['reason'] as String?,
      clinicalSummary:        json['clinical_summary'] as String?,
      relevantHistory:        json['relevant_history'] as String?,
      currentMedications:     json['current_medications'] as String?,
      diagnosticResults:      json['diagnostic_results'] as String?,
      consultationNotes:      json['consultation_notes'] as String?,
      recommendations:        json['recommendations'] as String?,
      appointmentDate:        json['appointment_date'] as String?,
      appointmentLocation:    json['appointment_location'] as String?,
      requiresFollowUp:       (json['requires_follow_up'] as bool?) ?? false,
      followUpDate:           json['follow_up_date'] as String?,
      referredAt:             json['referred_at'] as String,
      acceptedAt:             json['accepted_at'] as String?,
      scheduledAt:            json['scheduled_at'] as String?,
      completedAt:            json['completed_at'] as String?,
      cancelledAt:            json['cancelled_at'] as String?,
      isSent:                 fromId == currentTenantId,
      isReceived:             toId == currentTenantId,
      statusHistory:          history,
    );
  }
}
