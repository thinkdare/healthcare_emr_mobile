// lib/data/models/patient_message_models.dart

class PatientMessageModel {
  final String id;
  final String senderType; // patient | provider
  final String? senderId;
  final String recipientType; // patient | provider
  final String? subject;
  final String? body;
  final DateTime? readAt;
  final DateTime createdAt;
  final bool hasReplies;

  const PatientMessageModel({
    required this.id,
    required this.senderType,
    this.senderId,
    required this.recipientType,
    this.subject,
    this.body,
    this.readAt,
    required this.createdAt,
    this.hasReplies = false,
  });

  bool get isFromPatient => senderType == 'patient';
  bool get isUnread => readAt == null;

  factory PatientMessageModel.fromJson(Map<String, dynamic> json) =>
      PatientMessageModel(
        id: json['id'] as String,
        senderType: json['sender_type'] as String,
        senderId: json['sender_id'] as String?,
        recipientType: json['recipient_type'] as String,
        subject: json['subject'] as String?,
        body: json['body'] as String?,
        readAt: json['read_at'] != null ? DateTime.tryParse(json['read_at'] as String) : null,
        createdAt: DateTime.parse(json['created_at'] as String),
        hasReplies: (json['has_replies'] as bool?) ?? false,
      );
}
