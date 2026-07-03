import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_emr_mobile/data/models/organization_models_enhanced.dart';

void main() {
  group('FacilityModel', () {
    test('fromJson parses the flat TenantController response shape', () {
      final facility = FacilityModel.fromJson({
        'id': 'tenant-1',
        'name': 'Lagos General Hospital',
        'slug': 'lagos-general-hospital',
        'type': 'hospital',
        'country': 'NG',
        'state_province': 'Lagos',
        'address': '1 Hospital Road',
        'phone': '+2348012345678',
        'email': 'info@lagosgeneral.com',
        'supports_emergency_access': true,
        'is_active': true,
        'organization': {'id': 'org-1', 'name': 'Lagos Health Group'},
        'created_at': '2026-01-01T10:00:00Z',
      });

      expect(facility.id, 'tenant-1');
      expect(facility.type, 'hospital');
      expect(facility.country, 'NG');
      expect(facility.organizationId, 'org-1');
      expect(facility.organizationName, 'Lagos Health Group');
      expect(facility.supportsEmergencyAccess, isTrue);
    });

    test('fromJson handles a null organization gracefully', () {
      final facility = FacilityModel.fromJson({
        'id': 'tenant-2',
        'name': 'Standalone Clinic',
        'slug': 'standalone-clinic',
        'type': 'clinic',
        'country': 'NG',
        'supports_emergency_access': false,
        'is_active': true,
        'organization': null,
        'created_at': '2026-01-01T10:00:00Z',
      });

      expect(facility.organizationId, isNull);
      expect(facility.organizationName, isNull);
    });

    test('fromJson parses detailed-only fields when present', () {
      final facility = FacilityModel.fromJson({
        'id': 'tenant-3',
        'name': 'Detailed Clinic',
        'slug': 'detailed-clinic',
        'type': 'clinic',
        'country': 'NG',
        'supports_emergency_access': false,
        'is_active': true,
        'created_at': '2026-01-01T10:00:00Z',
        'operating_hours': {'mon': '8-17'},
        'settings': {'timezone': 'Africa/Lagos'},
        'is_open_now': true,
      });

      expect(facility.operatingHours, {'mon': '8-17'});
      expect(facility.settings, {'timezone': 'Africa/Lagos'});
      expect(facility.isOpenNow, isTrue);
    });

    test('fromJson defaults missing optional flags', () {
      final facility = FacilityModel.fromJson({
        'id': 'tenant-4',
        'name': 'Minimal Tenant',
        'type': 'pharmacy',
        'created_at': '2026-01-01T10:00:00Z',
      });

      expect(facility.supportsEmergencyAccess, isFalse);
      expect(facility.isActive, isTrue);
      expect(facility.slug, '');
      expect(facility.country, '');
    });

    test('fromJson round-trips the diagnostic_center facility type', () {
      final facility = FacilityModel.fromJson({
        'id': 'tenant-5',
        'name': 'City Diagnostics',
        'slug': 'city-diagnostics',
        'type': 'diagnostic_center',
        'country': 'NG',
        'supports_emergency_access': false,
        'is_active': true,
        'organization': null,
        'created_at': '2026-01-01T10:00:00Z',
      });

      expect(facility.type, 'diagnostic_center');
    });
  });
}
