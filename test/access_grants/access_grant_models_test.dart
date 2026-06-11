import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_emr_mobile/data/models/access_grant_models.dart';

void main() {
  group('AccessGrantModel', () {
    // A future date guaranteed to be in the future for all realistic test runs.
    const futureExpiresAt = '2099-12-31T23:59:59.000Z';
    // A past date guaranteed to be in the past.
    const pastExpiresAt = '2000-01-01T00:00:00.000Z';

    final baseJson = <String, dynamic>{
      'id': 'ag-1',
      'status': 'approved',
      'access_level': 'view_only',
      'accessible_data_types': ['lab_results', 'prescriptions', 'appointments'],
      'request_reason': 'Patient transferred for specialist review',
      'auto_approved': false,
      'approver_authority': 'medical_director',
      'requesting_tenant': {'id': 'tenant-a', 'name': 'Lagos General Hospital'},
      'granting_tenant': {'id': 'tenant-b', 'name': 'Abuja Specialist Clinic'},
      'requesting_provider_id': 'prov-1',
      'granted_at': '2026-06-01T10:00:00.000Z',
      'expires_at': futureExpiresAt,
      'revoked_at': null,
      'created_at': '2026-06-01T09:00:00.000Z',
    };

    // ── fromJson field parsing ──────────────────────────────────────────────

    test('fromJson parses all fields correctly', () {
      final model = AccessGrantModel.fromJson(Map<String, dynamic>.from(baseJson));

      expect(model.id, equals('ag-1'));
      expect(model.status, equals('approved'));
      expect(model.accessLevel, equals('view_only'));
      expect(model.accessibleDataTypes,
          equals(['lab_results', 'prescriptions', 'appointments']));
      expect(model.requestReason,
          equals('Patient transferred for specialist review'));
      expect(model.autoApproved, isFalse);
      expect(model.approverAuthority, equals('medical_director'));
      expect(model.requestingTenant,
          equals({'id': 'tenant-a', 'name': 'Lagos General Hospital'}));
      expect(model.grantingTenant,
          equals({'id': 'tenant-b', 'name': 'Abuja Specialist Clinic'}));
      expect(model.requestingProviderId, equals('prov-1'));
      expect(model.grantedAt, equals(DateTime.parse('2026-06-01T10:00:00.000Z')));
      expect(model.expiresAt, equals(DateTime.parse(futureExpiresAt)));
      expect(model.revokedAt, isNull);
      expect(model.createdAt, equals(DateTime.parse('2026-06-01T09:00:00.000Z')));
    });

    test('fromJson handles null optional fields gracefully', () {
      final minimalJson = <String, dynamic>{
        'id': 'ag-min',
        'status': 'pending',
        'access_level': 'view_only',
        'created_at': '2026-06-09T08:00:00.000Z',
      };

      final model = AccessGrantModel.fromJson(minimalJson);

      expect(model.accessibleDataTypes, isEmpty);      // default
      expect(model.requestReason, isNull);
      expect(model.autoApproved, isFalse);             // default
      expect(model.approverAuthority, isNull);
      expect(model.requestingTenant, isNull);
      expect(model.grantingTenant, isNull);
      expect(model.requestingProviderId, isNull);
      expect(model.grantedAt, isNull);
      expect(model.expiresAt, isNull);
      expect(model.revokedAt, isNull);
    });

    test('fromJson parses accessible_data_types list', () {
      final json = Map<String, dynamic>.from(baseJson)
        ..['accessible_data_types'] = ['vitals', 'diagnoses'];
      final model = AccessGrantModel.fromJson(json);
      expect(model.accessibleDataTypes, equals(['vitals', 'diagnoses']));
    });

    test('fromJson auto_approved defaults to false when absent', () {
      final json = Map<String, dynamic>.from(baseJson)..remove('auto_approved');
      final model = AccessGrantModel.fromJson(json);
      expect(model.autoApproved, isFalse);
    });

    test('fromJson parses auto_approved when true', () {
      final json = Map<String, dynamic>.from(baseJson)..['auto_approved'] = true;
      final model = AccessGrantModel.fromJson(json);
      expect(model.autoApproved, isTrue);
    });

    test('fromJson parses requestingTenant map with non-string values coerced', () {
      // The toStringMap helper coerces all values to String.
      final json = Map<String, dynamic>.from(baseJson)
        ..['requesting_tenant'] = {'id': 42, 'name': 'Numeric ID Facility'};
      final model = AccessGrantModel.fromJson(json);
      expect(model.requestingTenant, equals({'id': '42', 'name': 'Numeric ID Facility'}));
    });

    test('fromJson returns null for requestingTenant when value is null', () {
      final json = Map<String, dynamic>.from(baseJson)
        ..['requesting_tenant'] = null;
      final model = AccessGrantModel.fromJson(json);
      expect(model.requestingTenant, isNull);
    });

    // ── Status booleans ─────────────────────────────────────────────────────

    test('isPending is true when status is pending', () {
      final json = Map<String, dynamic>.from(baseJson)..['status'] = 'pending';
      final model = AccessGrantModel.fromJson(json);
      expect(model.isPending, isTrue);
      expect(model.isApproved, isFalse);
      expect(model.isDenied, isFalse);
      expect(model.isRevoked, isFalse);
    });

    test('isApproved is true when status is approved', () {
      final model = AccessGrantModel.fromJson(Map<String, dynamic>.from(baseJson));
      expect(model.isApproved, isTrue);
      expect(model.isPending, isFalse);
      expect(model.isDenied, isFalse);
      expect(model.isRevoked, isFalse);
    });

    test('isDenied is true when status is denied', () {
      final json = Map<String, dynamic>.from(baseJson)..['status'] = 'denied';
      final model = AccessGrantModel.fromJson(json);
      expect(model.isDenied, isTrue);
      expect(model.isPending, isFalse);
      expect(model.isApproved, isFalse);
      expect(model.isRevoked, isFalse);
    });

    test('isRevoked is true when status is revoked', () {
      final json = Map<String, dynamic>.from(baseJson)..['status'] = 'revoked';
      final model = AccessGrantModel.fromJson(json);
      expect(model.isRevoked, isTrue);
      expect(model.isPending, isFalse);
      expect(model.isApproved, isFalse);
      expect(model.isDenied, isFalse);
    });

    // ── isActive ────────────────────────────────────────────────────────────

    test('isActive is true when approved with a future expiresAt', () {
      // baseJson already has status=approved and expires_at in 2099.
      final model = AccessGrantModel.fromJson(Map<String, dynamic>.from(baseJson));
      expect(model.isActive, isTrue);
    });

    test('isActive is true when approved with no expiresAt (never expires)', () {
      final json = Map<String, dynamic>.from(baseJson)..['expires_at'] = null;
      final model = AccessGrantModel.fromJson(json);
      expect(model.isActive, isTrue);
    });

    test('isActive is false when approved but expiresAt is in the past', () {
      final json = Map<String, dynamic>.from(baseJson)
        ..['expires_at'] = pastExpiresAt;
      final model = AccessGrantModel.fromJson(json);
      expect(model.isActive, isFalse);
    });

    test('isActive is false when status is pending even with future expiresAt', () {
      final json = Map<String, dynamic>.from(baseJson)
        ..['status'] = 'pending'
        ..['expires_at'] = futureExpiresAt;
      final model = AccessGrantModel.fromJson(json);
      expect(model.isActive, isFalse);
    });

    test('isActive is false when status is denied', () {
      final json = Map<String, dynamic>.from(baseJson)
        ..['status'] = 'denied'
        ..['expires_at'] = futureExpiresAt;
      final model = AccessGrantModel.fromJson(json);
      expect(model.isActive, isFalse);
    });

    test('isActive is false when status is revoked', () {
      final json = Map<String, dynamic>.from(baseJson)
        ..['status'] = 'revoked'
        ..['expires_at'] = futureExpiresAt;
      final model = AccessGrantModel.fromJson(json);
      expect(model.isActive, isFalse);
    });

    // ── isExpired ───────────────────────────────────────────────────────────

    test('isExpired is true when approved and expiresAt is in the past', () {
      final json = Map<String, dynamic>.from(baseJson)
        ..['expires_at'] = pastExpiresAt;
      final model = AccessGrantModel.fromJson(json);
      expect(model.isExpired, isTrue);
    });

    test('isExpired is false when approved and expiresAt is in the future', () {
      final model = AccessGrantModel.fromJson(Map<String, dynamic>.from(baseJson));
      expect(model.isExpired, isFalse);
    });

    test('isExpired is false when approved but expiresAt is null', () {
      final json = Map<String, dynamic>.from(baseJson)..['expires_at'] = null;
      final model = AccessGrantModel.fromJson(json);
      expect(model.isExpired, isFalse);
    });

    test('isExpired is false when status is pending even with past expiresAt', () {
      final json = Map<String, dynamic>.from(baseJson)
        ..['status'] = 'pending'
        ..['expires_at'] = pastExpiresAt;
      final model = AccessGrantModel.fromJson(json);
      expect(model.isExpired, isFalse);
    });

    // ── Tenant name helpers ─────────────────────────────────────────────────

    test('requestingTenantName returns name from requestingTenant map', () {
      final model = AccessGrantModel.fromJson(Map<String, dynamic>.from(baseJson));
      expect(model.requestingTenantName, equals('Lagos General Hospital'));
    });

    test('requestingTenantName falls back to Unknown facility when requestingTenant is null', () {
      final json = Map<String, dynamic>.from(baseJson)
        ..['requesting_tenant'] = null;
      final model = AccessGrantModel.fromJson(json);
      expect(model.requestingTenantName, equals('Unknown facility'));
    });

    test('requestingTenantName falls back to Unknown facility when name key is absent', () {
      final json = Map<String, dynamic>.from(baseJson)
        ..['requesting_tenant'] = {'id': 'tenant-a'};
      final model = AccessGrantModel.fromJson(json);
      expect(model.requestingTenantName, equals('Unknown facility'));
    });

    test('grantingTenantName returns name from grantingTenant map', () {
      final model = AccessGrantModel.fromJson(Map<String, dynamic>.from(baseJson));
      expect(model.grantingTenantName, equals('Abuja Specialist Clinic'));
    });

    test('grantingTenantName falls back to Unknown facility when grantingTenant is null', () {
      final json = Map<String, dynamic>.from(baseJson)
        ..['granting_tenant'] = null;
      final model = AccessGrantModel.fromJson(json);
      expect(model.grantingTenantName, equals('Unknown facility'));
    });

    test('grantingTenantName falls back to Unknown facility when name key is absent', () {
      final json = Map<String, dynamic>.from(baseJson)
        ..['granting_tenant'] = {'id': 'tenant-b'};
      final model = AccessGrantModel.fromJson(json);
      expect(model.grantingTenantName, equals('Unknown facility'));
    });

    // ── accessLevelDisplay ──────────────────────────────────────────────────

    test('accessLevelDisplay returns View only for view_only', () {
      final model = AccessGrantModel.fromJson(Map<String, dynamic>.from(baseJson));
      expect(model.accessLevelDisplay, equals('View only'));
    });

    test('accessLevelDisplay returns View & update for view_and_update', () {
      final json = Map<String, dynamic>.from(baseJson)
        ..['access_level'] = 'view_and_update';
      final model = AccessGrantModel.fromJson(json);
      expect(model.accessLevelDisplay, equals('View & update'));
    });

    test('accessLevelDisplay returns Full access for full_access', () {
      final json = Map<String, dynamic>.from(baseJson)
        ..['access_level'] = 'full_access';
      final model = AccessGrantModel.fromJson(json);
      expect(model.accessLevelDisplay, equals('Full access'));
    });

    test('accessLevelDisplay returns raw accessLevel string for unknown value', () {
      final json = Map<String, dynamic>.from(baseJson)
        ..['access_level'] = 'custom_level';
      final model = AccessGrantModel.fromJson(json);
      expect(model.accessLevelDisplay, equals('custom_level'));
    });

    // ── DateTime parsing ────────────────────────────────────────────────────

    test('grantedAt is parsed from ISO string', () {
      final model = AccessGrantModel.fromJson(Map<String, dynamic>.from(baseJson));
      expect(model.grantedAt, equals(DateTime.parse('2026-06-01T10:00:00.000Z')));
    });

    test('createdAt is parsed from ISO string', () {
      final model = AccessGrantModel.fromJson(Map<String, dynamic>.from(baseJson));
      expect(model.createdAt, equals(DateTime.parse('2026-06-01T09:00:00.000Z')));
    });

    test('revokedAt is parsed when present', () {
      final json = Map<String, dynamic>.from(baseJson)
        ..['status'] = 'revoked'
        ..['revoked_at'] = '2026-06-05T14:00:00.000Z';
      final model = AccessGrantModel.fromJson(json);
      expect(model.revokedAt, equals(DateTime.parse('2026-06-05T14:00:00.000Z')));
    });

    test('revokedAt is null when not revoked', () {
      final model = AccessGrantModel.fromJson(Map<String, dynamic>.from(baseJson));
      expect(model.revokedAt, isNull);
    });
  });
}
