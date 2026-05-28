// lib/data/models/intra_grant_models.dart

class IntraAccessGrantModel {
  final String id;
  final String status; // pending|accepted|declined|completed|cancelled
  final String patientId;
  final String? patientName;
  final String? patientMrn;
  final String grantedById;
  final String grantedToId;
  final String accessLevel;
  final String question;
  final String? response;
  final DateTime? respondedAt;
  final DateTime? expiresAt;
  final DateTime createdAt;
  final bool isIncoming;

  final String? rosterEntryId;

  const IntraAccessGrantModel({
    required this.id,
    required this.status,
    required this.patientId,
    this.patientName,
    this.patientMrn,
    required this.grantedById,
    required this.grantedToId,
    required this.accessLevel,
    required this.question,
    this.response,
    this.respondedAt,
    this.expiresAt,
    required this.createdAt,
    required this.isIncoming,
    this.rosterEntryId,
  });

  bool get isPending    => status == 'pending';
  bool get isAccepted   => status == 'accepted';
  bool get isDeclined   => status == 'declined';
  bool get isCompleted  => status == 'completed';
  bool get isCancelled  => status == 'cancelled';
  bool get isClosed     => const ['declined', 'completed', 'cancelled'].contains(status);
  bool get hasResponse  => response != null && response!.isNotEmpty;

  String get statusLabel => switch (status) {
    'pending'   => 'Pending',
    'accepted'  => 'In review',
    'declined'  => 'Declined',
    'completed' => 'Completed',
    'cancelled' => 'Cancelled',
    _           => status,
  };

  factory IntraAccessGrantModel.fromJson(Map<String, dynamic> json) {
    return IntraAccessGrantModel(
      id:           json['id'] as String,
      status:       json['status'] as String,
      patientId:    json['patient_id'] as String,
      patientName:  json['patient_name'] as String?,
      patientMrn:   json['patient_mrn'] as String?,
      grantedById:  json['granted_by_id'] as String,
      grantedToId:  json['granted_to_id'] as String,
      accessLevel:  json['access_level'] as String? ?? 'view_only',
      question:     json['question'] as String? ?? '',
      response:     json['response'] as String?,
      respondedAt:  json['responded_at'] != null
                        ? DateTime.tryParse(json['responded_at'] as String)
                        : null,
      expiresAt:    json['expires_at'] != null
                        ? DateTime.tryParse(json['expires_at'] as String)
                        : null,
      createdAt:      DateTime.parse(json['created_at'] as String),
      isIncoming:     (json['is_incoming'] as bool?) ?? false,
      rosterEntryId:  json['roster_entry_id'] as String?,
    );
  }
}

// ── ConsultationMessage ───────────────────────────────────────────────────────

class ConsultationMessageModel {
  final String id;
  final String authorId;
  final String body;
  final DateTime sentAt;
  final bool isOwn;

  const ConsultationMessageModel({
    required this.id,
    required this.authorId,
    required this.body,
    required this.sentAt,
    required this.isOwn,
  });

  factory ConsultationMessageModel.fromJson(Map<String, dynamic> json) {
    return ConsultationMessageModel(
      id:       json['id'] as String,
      authorId: json['author_id'] as String,
      body:     json['body'] as String,
      sentAt:   DateTime.parse(json['sent_at'] as String),
      isOwn:    (json['is_own'] as bool?) ?? false,
    );
  }
}

// ── IntraPatientTransfer ──────────────────────────────────────────────────────

class IntraTransferModel {
  final String id;
  final String status; // pending|accepted|declined
  final String patientId;
  final String? patientName;
  final String? patientMrn;
  final String fromProviderId;
  final String toProviderId;
  final String? handoverNotes;
  final String? declineReason;
  final DateTime requestedAt;
  final DateTime? respondedAt;
  final bool isIncoming;

  const IntraTransferModel({
    required this.id,
    required this.status,
    required this.patientId,
    this.patientName,
    this.patientMrn,
    required this.fromProviderId,
    required this.toProviderId,
    this.handoverNotes,
    this.declineReason,
    required this.requestedAt,
    this.respondedAt,
    required this.isIncoming,
  });

  bool get isPending  => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isDeclined => status == 'declined';

  factory IntraTransferModel.fromJson(Map<String, dynamic> json) {
    return IntraTransferModel(
      id:               json['id'] as String,
      status:           json['status'] as String,
      patientId:        json['patient_id'] as String,
      patientName:      json['patient_name'] as String?,
      patientMrn:       json['patient_mrn'] as String?,
      fromProviderId:   json['from_provider_id'] as String,
      toProviderId:     json['to_provider_id'] as String,
      handoverNotes:    json['handover_notes'] as String?,
      declineReason:    json['decline_reason'] as String?,
      requestedAt:      DateTime.parse(json['requested_at'] as String),
      respondedAt:      json['responded_at'] != null
                            ? DateTime.tryParse(json['responded_at'] as String)
                            : null,
      isIncoming:       (json['is_incoming'] as bool?) ?? false,
    );
  }
}

class ClinicalNoteModel {
  final String id;
  final String patientId;
  final String noteType;
  final String? title;
  final String body;
  final String authoredById;
  final String authoredByName;
  final String? sourceType;
  final String? sourceId;
  final DateTime authoredAt;

  const ClinicalNoteModel({
    required this.id,
    required this.patientId,
    required this.noteType,
    this.title,
    required this.body,
    required this.authoredById,
    required this.authoredByName,
    this.sourceType,
    this.sourceId,
    required this.authoredAt,
  });

  bool get isConsultationResponse => noteType == 'consultation_response';
  bool get isConsultationDeclined => noteType == 'consultation_declined';
  bool get isConsultation => isConsultationResponse || isConsultationDeclined;

  String get displayTitle {
    if (title != null && title!.isNotEmpty) return title!;
    return switch (noteType) {
      'consultation_response' => 'Consultation response',
      'consultation_declined' => 'Consultation declined',
      _                       => 'Clinical note',
    };
  }

  factory ClinicalNoteModel.fromJson(Map<String, dynamic> json) {
    return ClinicalNoteModel(
      id:              json['id'] as String,
      patientId:       json['patient_id'] as String? ?? '',
      noteType:        json['note_type'] as String,
      title:           json['title'] as String?,
      body:            json['body'] as String,
      authoredById:    json['authored_by_id'] as String,
      authoredByName:  json['authored_by_name'] as String,
      sourceType:      json['source_type'] as String?,
      sourceId:        json['source_id'] as String?,
      authoredAt:      DateTime.parse(json['authored_at'] as String),
    );
  }
}
