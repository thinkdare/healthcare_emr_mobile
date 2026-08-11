/// An intra-facility patient transfer request (IntraPatientTransferController).
/// Handing a patient off to another provider at the same facility —
/// distinct from a cross-facility PatientReferral.
class IntraTransferModel {
  final String id;
  final String status; // 'pending' | 'accepted' | 'declined'
  final String patientId;
  final String? patientName;
  final String? patientMrn;
  final String fromProviderId;
  final String toProviderId;
  final String? handoverNotes;
  final String? declineReason;
  final DateTime? requestedAt;
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
    this.requestedAt,
    this.respondedAt,
    required this.isIncoming,
  });

  factory IntraTransferModel.fromJson(Map<String, dynamic> json) =>
      IntraTransferModel(
        id: json['id'] as String,
        status: json['status'] as String? ?? 'pending',
        patientId: json['patient_id'] as String,
        patientName: json['patient_name'] as String?,
        patientMrn: json['patient_mrn'] as String?,
        fromProviderId: json['from_provider_id'] as String,
        toProviderId: json['to_provider_id'] as String,
        handoverNotes: json['handover_notes'] as String?,
        declineReason: json['decline_reason'] as String?,
        requestedAt: json['requested_at'] == null
            ? null
            : DateTime.tryParse(json['requested_at'] as String),
        respondedAt: json['responded_at'] == null
            ? null
            : DateTime.tryParse(json['responded_at'] as String),
        isIncoming: json['is_incoming'] as bool? ?? false,
      );
}
