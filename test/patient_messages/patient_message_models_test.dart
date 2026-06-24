import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_emr_mobile/data/models/patient_message_models.dart';

void main() {
  group('PatientMessageModel', () {
    test('fromJson parses all fields', () {
      final message = PatientMessageModel.fromJson({
        'id': 'msg-1',
        'sender_type': 'patient',
        'sender_id': null,
        'recipient_type': 'provider',
        'subject': 'Question',
        'body': 'Is it safe to take with food?',
        'read_at': null,
        'created_at': '2026-06-01T10:00:00Z',
        'has_replies': false,
      });

      expect(message.id, 'msg-1');
      expect(message.body, 'Is it safe to take with food?');
      expect(message.isFromPatient, isTrue);
      expect(message.isUnread, isTrue);
    });

    test('isFromPatient is false for provider replies', () {
      final reply = PatientMessageModel.fromJson({
        'id': 'msg-2',
        'sender_type': 'provider',
        'sender_id': 'user-1',
        'recipient_type': 'patient',
        'subject': 'Re: Question',
        'body': 'Yes, that is safe.',
        'read_at': null,
        'created_at': '2026-06-01T11:00:00Z',
      });

      expect(reply.isFromPatient, isFalse);
      expect(reply.senderId, 'user-1');
    });

    test('isUnread is false when read_at is present', () {
      final message = PatientMessageModel.fromJson({
        'id': 'msg-3',
        'sender_type': 'patient',
        'recipient_type': 'provider',
        'read_at': '2026-06-01T12:00:00Z',
        'created_at': '2026-06-01T10:00:00Z',
      });

      expect(message.isUnread, isFalse);
    });

    test('hasReplies defaults to false when absent', () {
      final message = PatientMessageModel.fromJson({
        'id': 'msg-4',
        'sender_type': 'patient',
        'recipient_type': 'provider',
        'created_at': '2026-06-01T10:00:00Z',
      });

      expect(message.hasReplies, isFalse);
    });
  });
}
