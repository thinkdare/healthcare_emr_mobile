import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_emr_mobile/data/models/auth_models.dart';
import 'package:healthcare_emr_mobile/data/repositories/staff_repository.dart';

void main() {
  group('InvitationDetails', () {
    test('parses facility object shape', () {
      final details = InvitationDetails.fromJson({
        'token': 'abc123',
        'email': 'dr.smith@hospital.com',
        'facility': {'id': 'fac-1', 'name': 'City Hospital'},
        'staff_type': 'doctor',
        'invited_by': {'first_name': 'Jane', 'last_name': 'Doe'},
        'expires_at': '2026-12-31T23:59:59Z',
      });

      expect(details.token, 'abc123');
      expect(details.email, 'dr.smith@hospital.com');
      expect(details.facilityId, 'fac-1');
      expect(details.facilityName, 'City Hospital');
      expect(details.staffType, 'doctor');
      expect(details.staffTypeLabel, 'Doctor');
      expect(details.inviterName, 'Jane Doe');
      expect(details.expiresAt, isNotNull);
    });

    test('parses flat facility_name / facility_id shape', () {
      final details = InvitationDetails.fromJson({
        'token': 'tok-flat',
        'email': 'nurse@clinic.com',
        'facility_id': 'fac-2',
        'facility_name': 'Metro Clinic',
        'staff_type': 'nurse',
      });

      expect(details.facilityId, 'fac-2');
      expect(details.facilityName, 'Metro Clinic');
      expect(details.inviterName, isNull);
      expect(details.expiresAt, isNull);
    });

    test('staffTypeLabel falls back to raw value for unknown type', () {
      final details = InvitationDetails.fromJson({
        'token': 't',
        'email': 'x@y.com',
        'facility': {'id': 'f', 'name': 'F'},
        'staff_type': 'ultrasound_tech',
      });
      expect(details.staffTypeLabel, 'ultrasound_tech');
    });

    test('inviterName is empty string when names are blank', () {
      final details = InvitationDetails.fromJson({
        'token': 't',
        'email': 'x@y.com',
        'facility': {'id': 'f', 'name': 'F'},
        'staff_type': 'doctor',
        'invited_by': {'first_name': '', 'last_name': ''},
      });
      expect(details.inviterName, '');
    });
  });

  group('AuthFacilityModel', () {
    test('fromJson parses tenant fields', () {
      final facility = AuthFacilityModel.fromJson({
        'id': 'ten-1',
        'name': 'General Hospital',
        'slug': 'general-hospital',
        'type': 'hospital',
        'address': '1 Main St',
        'phone': '+2348000000000',
      });

      expect(facility.id, 'ten-1');
      expect(facility.name, 'General Hospital');
      expect(facility.displayType, 'Hospital');
      expect(facility.membership, isNull);
    });

    test('fromMembershipJson parses prefixed fields', () {
      final facility = AuthFacilityModel.fromMembershipJson({
        'tenant_id': 'ten-2',
        'tenant_name': 'City Clinic',
        'tenant_slug': 'city-clinic',
        'tenant_type': 'clinic',
        'membership_id': 'mem-1',
        'staff_type': 'nurse',
        'is_primary_affiliation': true,
        'can_prescribe': false,
        'can_order_labs': false,
        'can_emergency_access': false,
      });

      expect(facility.id, 'ten-2');
      expect(facility.name, 'City Clinic');
      expect(facility.membership, isNotNull);
      expect(facility.membership!.staffType, 'nurse');
      expect(facility.membership!.isPrimary, isTrue);
    });

    test('displayType falls back gracefully for unknown type', () {
      final facility = AuthFacilityModel.fromJson({
        'id': 'x',
        'name': 'X',
        'slug': 'x',
        'type': 'mobile_unit',
      });
      expect(facility.displayType, 'mobile_unit');
    });
  });

  group('StaffMembershipModel', () {
    test('parses canPrescribe and canOrderLabs', () {
      final membership = StaffMembershipModel.fromJson({
        'id': 'mem-3',
        'staff_type': 'doctor',
        'is_primary_affiliation': false,
        'can_prescribe': true,
        'can_order_labs': true,
        'can_emergency_access': false,
      });

      expect(membership.canPrescribe, isTrue);
      expect(membership.canOrderLabs, isTrue);
      expect(membership.canEmergencyAccess, isFalse);
      expect(membership.displayType, 'Doctor');
    });

    test('department is extracted from nested object', () {
      final membership = StaffMembershipModel.fromJson({
        'id': 'mem-4',
        'staff_type': 'nurse',
        'is_primary_affiliation': false,
        'can_prescribe': false,
        'can_order_labs': false,
        'can_emergency_access': false,
        'department': {'name': 'Paediatrics'},
      });

      expect(membership.department, 'Paediatrics');
    });
  });
}
