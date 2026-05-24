import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_emr_mobile/data/models/organization_models_enhanced.dart';
import 'package:healthcare_emr_mobile/data/models/auth_models.dart';

void main() {
  group('OrgStatsModel.fromJson', () {
    test('parses all fields', () {
      final json = {
        'total_facilities': 3,
        'total_staff': 24,
        'total_patients': 1240,
        'active_subscriptions': 1,
      };
      final stats = OrgStatsModel.fromJson(json);
      expect(stats.totalFacilities, 3);
      expect(stats.totalStaff, 24);
      expect(stats.totalPatients, 1240);
      expect(stats.activeSubscriptions, 1);
    });
  });

  group('UpdateOrganizationRequest.toJson', () {
    test('omits null fields', () {
      final req = UpdateOrganizationRequest(name: 'New Name', address: null);
      final json = req.toJson();
      expect(json.containsKey('name'), isTrue);
      expect(json.containsKey('address'), isFalse);
    });

    test('includes all provided fields', () {
      final req = UpdateOrganizationRequest(
        name: 'CityHealth',
        type: 'hospital_group',
        address: '123 Main',
        phone: '+234800',
        email: 'a@b.com',
        taxId: 'TIN-123',
        billingEmail: 'billing@b.com',
        billingAddress: '123 Main',
      );
      final json = req.toJson();
      expect(json['name'], 'CityHealth');
      expect(json['type'], 'hospital_group');
      expect(json['tax_id'], 'TIN-123');
      expect(json['billing_email'], 'billing@b.com');
    });
  });

  group('FacilityStaffMemberModel.fromJson', () {
    test('parses user fields and capabilities', () {
      final json = {
        'id': 'mem-1',
        'staff_type': 'doctor',
        'is_active': true,
        'clinical_rank': {
          'id': 'rank-1',
          'name': 'Consultant',
          'hierarchy_level': 800,
          'can_prescribe': true,
          'can_order_labs': true,
          'can_approve_access_grants': true,
          'can_perform_emergency_access': true,
        },
        'user': {
          'id': 'user-1',
          'first_name': 'Jane',
          'last_name': 'Smith',
          'email': 'jane@clinic.com',
        },
      };
      final member = FacilityStaffMemberModel.fromJson(json);
      expect(member.membershipId, 'mem-1');
      expect(member.staffType, 'doctor');
      expect(member.isActive, isTrue);
      expect(member.fullName, 'Jane Smith');
      expect(member.email, 'jane@clinic.com');
      expect(member.clinicalRank?.canPrescribe, isTrue);
    });

    test('handles missing clinical_rank', () {
      final json = {
        'id': 'mem-2',
        'staff_type': 'admin',
        'is_active': true,
        'user': {
          'id': 'u2',
          'first_name': 'Bob',
          'last_name': 'Jones',
          'email': 'bob@c.com',
        },
      };
      final member = FacilityStaffMemberModel.fromJson(json);
      expect(member.clinicalRank, isNull);
      expect(member.initials, 'BJ');
    });
  });
}
