import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_emr_mobile/data/models/referral_models.dart';

void main() {
  group('ReferralFilter', () {
    test('matches returns true for pending referral on pending filter', () {
      expect(ReferralFilter.pending.matches('pending'), isTrue);
    });

    test('active filter matches accepted and scheduled', () {
      expect(ReferralFilter.active.matches('accepted'), isTrue);
      expect(ReferralFilter.active.matches('scheduled'), isTrue);
      expect(ReferralFilter.active.matches('pending'), isFalse);
    });

    test('done filter matches completed and cancelled', () {
      expect(ReferralFilter.done.matches('completed'), isTrue);
      expect(ReferralFilter.done.matches('cancelled'), isTrue);
      expect(ReferralFilter.done.matches('pending'), isFalse);
    });

    test('all filter matches any status', () {
      for (final s in ['pending', 'accepted', 'scheduled', 'completed', 'cancelled']) {
        expect(ReferralFilter.all.matches(s), isTrue);
      }
    });
  });

  group('ReferralModel', () {
    final baseJson = {
      'id': 'ref-1',
      'status': 'pending',
      'specialty': 'Cardiology',
      'urgency': 'urgent',
      'is_urgent': true,
      'is_overdue': false,
      'from_tenant': {'id': 'tenant-a', 'name': 'Lagos General'},
      'to_tenant': {'id': 'tenant-b', 'name': 'Abuja Specialist'},
      'referring_provider_id': 'user-1',
      'referring_provider': 'Dr. Adeyemi',
      'referred_to_provider_id': null,
      'referred_to_provider': null,
      'requires_follow_up': false,
      'referred_at': '2026-05-17T10:00:00.000Z',
      'created_at': '2026-05-17T10:00:00.000Z',
    };

    test('fromJson parses all required fields', () {
      final model = ReferralModel.fromJson(
        Map<String, dynamic>.from(baseJson),
        currentTenantId: 'tenant-a',
      );
      expect(model.id, 'ref-1');
      expect(model.status, 'pending');
      expect(model.specialty, 'Cardiology');
      expect(model.fromTenantName, 'Lagos General');
      expect(model.toTenantName, 'Abuja Specialist');
    });

    test('isSent true when currentTenantId matches fromTenantId', () {
      final model = ReferralModel.fromJson(
        Map<String, dynamic>.from(baseJson),
        currentTenantId: 'tenant-a',
      );
      expect(model.isSent, isTrue);
      expect(model.isReceived, isFalse);
    });

    test('isReceived true when currentTenantId matches toTenantId', () {
      final model = ReferralModel.fromJson(
        Map<String, dynamic>.from(baseJson),
        currentTenantId: 'tenant-b',
      );
      expect(model.isReceived, isTrue);
      expect(model.isSent, isFalse);
    });

    test('canAccept true only for receiving party with pending status', () {
      final model = ReferralModel.fromJson(
        Map<String, dynamic>.from(baseJson),
        currentTenantId: 'tenant-b',
      );
      expect(model.canAccept, isTrue);
      expect(model.canCancel, isFalse);
    });

    test('canCancel true only for sending party with open status', () {
      final model = ReferralModel.fromJson(
        Map<String, dynamic>.from(baseJson),
        currentTenantId: 'tenant-a',
      );
      expect(model.canCancel, isTrue);
      expect(model.canAccept, isFalse);
    });

    test('isOpen false for completed referral', () {
      final json = Map<String, dynamic>.from(baseJson)
        ..['status'] = 'completed';
      final model = ReferralModel.fromJson(json, currentTenantId: 'tenant-a');
      expect(model.isOpen, isFalse);
      expect(model.canCancel, isFalse);
    });
  });
}
