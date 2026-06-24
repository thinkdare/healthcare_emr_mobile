import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_emr_mobile/data/models/patient_consent_models.dart';

void main() {
  group('PatientConsentModel', () {
    test('fromJson parses all fields', () {
      final consent = PatientConsentModel.fromJson({
        'id': 'consent-1',
        'consent_type': 'data_sharing',
        'legal_basis': 'consent',
        'given': true,
        'given_at': '2026-06-01T10:00:00Z',
        'withdrawn_at': null,
        'notes': 'Discussed during intake',
        'recorded_at': '2026-06-01T10:00:00Z',
      });

      expect(consent.consentType, 'data_sharing');
      expect(consent.consentTypeLabel, 'Data Sharing');
      expect(consent.given, isTrue);
      expect(consent.withdrawnAt, isNull);
    });

    test('consentTypeLabel returns raw type for unknown values', () {
      final consent = PatientConsentModel.fromJson({
        'id': 'consent-2',
        'consent_type': 'unknown_type',
        'legal_basis': 'consent',
        'given': false,
        'recorded_at': '2026-06-01T10:00:00Z',
      });

      expect(consent.consentTypeLabel, 'unknown_type');
    });
  });

  group('PatientConsentEventModel', () {
    test('fromJson parses all fields', () {
      final event = PatientConsentEventModel.fromJson({
        'id': 'event-1',
        'action': 'granted',
        'consent_type': 'marketing',
        'legal_basis': 'consent',
        'document_version': 'v1',
        'actor_type': 'provider',
        'actor_name': 'Dr. Adeyemi',
        'notes': null,
        'occurred_at': '2026-06-01T10:00:00Z',
      });

      expect(event.action, 'granted');
      expect(event.actorName, 'Dr. Adeyemi');
    });
  });

  group('NotificationPreferencesModel', () {
    test('fromJson defaults all fields to true when json is null', () {
      final prefs = NotificationPreferencesModel.fromJson(null);

      expect(prefs.appointmentReminders, isTrue);
      expect(prefs.sms, isTrue);
      expect(prefs.email, isTrue);
      expect(prefs.push, isTrue);
    });

    test('fromJson parses explicit false values', () {
      final prefs = NotificationPreferencesModel.fromJson({
        'appointment_reminders': true,
        'sms': false,
        'email': false,
        'push': true,
      });

      expect(prefs.sms, isFalse);
      expect(prefs.email, isFalse);
      expect(prefs.push, isTrue);
    });

    test('copyWith overrides only the specified field', () {
      const prefs = NotificationPreferencesModel();
      final updated = prefs.copyWith(sms: false);

      expect(updated.sms, isFalse);
      expect(updated.email, isTrue);
      expect(updated.push, isTrue);
      expect(updated.appointmentReminders, isTrue);
    });
  });
}
