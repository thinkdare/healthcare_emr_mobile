import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_emr_mobile/core/sync/sync_diff_helper.dart';
import 'package:healthcare_emr_mobile/data/models/sync_models.dart';

void main() {
  group('SyncDiffHelper', () {
    test('returns server_wins when same field has different values on both sides',
        () {
      final diff = SyncDiffHelper.diff(
        clientData: {'dosage': '750mg', 'status': 'active'},
        serverData: {'dosage': '500mg', 'status': 'active'},
        resourceType: 'prescriptions',
      );
      expect(diff.strategy, 'server_wins');
      expect(diff.overlappingFields, contains('dosage'));
    });

    test('returns merged when client has exclusive field server does not have',
        () {
      final diff = SyncDiffHelper.diff(
        clientData: {
          'dosage': '750mg',
          'status': 'active',
          'notes': 'take with food'
        },
        serverData: {'dosage': '750mg', 'status': 'active'},
        resourceType: 'prescriptions',
      );
      expect(diff.strategy, 'merged');
      expect(diff.changedByClient, contains('notes'));
      expect(diff.overlappingFields, isEmpty);
    });

    test('returns server_wins when field differs on both client and server', () {
      final diff = SyncDiffHelper.diff(
        clientData: {'dosage': '750mg', 'status': 'active'},
        serverData: {'dosage': '600mg', 'status': 'active'},
        resourceType: 'prescriptions',
      );
      expect(diff.strategy, 'server_wins');
      expect(diff.overlappingFields, contains('dosage'));
    });

    test('narrative is not empty when fields differ', () {
      final diff = SyncDiffHelper.diff(
        clientData: {'dosage': '750mg', 'status': 'active'},
        serverData: {'dosage': '500mg', 'status': 'active'},
        resourceType: 'prescriptions',
      );
      expect(diff.narrative, isNotEmpty);
    });

    test('excludes internal fields from diff', () {
      final diff = SyncDiffHelper.diff(
        clientData: {
          'dosage': '750mg',
          'version': 3,
          'updated_at': '2026-05-16'
        },
        serverData: {
          'dosage': '750mg',
          'version': 5,
          'updated_at': '2026-05-17'
        },
        resourceType: 'prescriptions',
      );
      expect(diff.changedByClient, isEmpty);
      expect(diff.changedByServer, isEmpty);
      expect(diff.strategy, 'client_wins');
    });

    test('precomputes mergedData when client has exclusive fields', () {
      final diff = SyncDiffHelper.diff(
        clientData: {
          'dosage': '750mg',
          'status': 'active',
          'notes': 'take with food'
        },
        serverData: {'dosage': '750mg', 'status': 'active'},
        resourceType: 'prescriptions',
      );
      expect(diff.strategy, 'merged');
      expect(diff.mergedData, isNotNull);
      expect(diff.mergedData!['dosage'], '750mg');
      expect(diff.mergedData!['notes'], 'take with food');
    });
  });

  group('SyncDiffHelper.deleteConflictDiff', () {
    test('returns server_wins with delete narrative', () {
      final diff = SyncDiffHelper.deleteConflictDiff(
        serverData: {
          'dosage': '500mg',
          'status': 'active',
          'medication_name': 'Amoxicillin',
        },
        resourceType: 'prescriptions',
      );
      expect(diff.strategy, 'server_wins');
      expect(diff.narrative.toLowerCase(), contains('delet'));
      expect(diff.changedByClient, isEmpty);
      expect(diff.mergedData, isNull);
    });

    test('suggestion tells user to keep server version', () {
      final diff = SyncDiffHelper.deleteConflictDiff(
        serverData: {'status': 'active'},
        resourceType: 'appointments',
      );
      expect(diff.suggestion.toLowerCase(), contains('server'));
    });
  });

  group('SyncConflict.isDeleteConflict', () {
    test('returns true when clientData has no user-facing fields', () {
      final conflict = SyncConflict(
        id: 'c-1',
        resourceType: 'prescriptions',
        clientData: {'id': 'rx-1', 'deleted_at': '2026-06-01'},
        serverData: {'dosage': '500mg', 'status': 'active'},
        status: 'pending',
        createdAt: '2026-06-10T00:00:00Z',
      );
      expect(conflict.isDeleteConflict, isTrue);
    });

    test('returns false when clientData has user-facing fields', () {
      final conflict = SyncConflict(
        id: 'c-2',
        resourceType: 'prescriptions',
        clientData: {'id': 'rx-1', 'dosage': '750mg'},
        serverData: {'dosage': '500mg', 'status': 'active'},
        status: 'pending',
        createdAt: '2026-06-10T00:00:00Z',
      );
      expect(conflict.isDeleteConflict, isFalse);
    });

    test('returns false when serverData is empty', () {
      final conflict = SyncConflict(
        id: 'c-3',
        resourceType: 'prescriptions',
        clientData: {'id': 'rx-1'},
        serverData: {},
        status: 'pending',
        createdAt: '2026-06-10T00:00:00Z',
      );
      expect(conflict.isDeleteConflict, isFalse);
    });

    test(
        'returns true when serverData has deleted_at, even with a real client edit',
        () {
      // Server-deleted shape: client tried to update a soft-deleted
      // resource (SyncController::surfaceDeleteConflict()). clientData has
      // genuine user-facing fields here, which the old heuristic alone
      // would have misread as a normal (non-delete) conflict.
      final conflict = SyncConflict(
        id: 'c-4',
        resourceType: 'prescriptions',
        clientData: {'id': 'rx-1', 'dosage': '750mg'},
        serverData: {'dosage': '500mg', 'deleted_at': '2026-06-15T00:00:00Z'},
        status: 'pending',
        createdAt: '2026-06-10T00:00:00Z',
      );
      expect(conflict.isDeleteConflict, isTrue);
    });

    test('returns true when serverData is the hard-deleted marker', () {
      // Hard-deleted/missing shape: no row existed at all server-side.
      final conflict = SyncConflict(
        id: 'c-5',
        resourceType: 'prescriptions',
        clientData: {'id': 'rx-1', 'dosage': '750mg'},
        serverData: {'deleted': true, 'id': 'rx-1'},
        status: 'pending',
        createdAt: '2026-06-10T00:00:00Z',
      );
      expect(conflict.isDeleteConflict, isTrue);
    });
  });

  group('SyncDiffHelper.createConflictDiff', () {
    test('returns server_wins with a duplicate-patient narrative', () {
      final diff = SyncDiffHelper.createConflictDiff(
        serverData: {
          'reason': 'potential_duplicate_patient',
          'matches': [
            {
              'global_patient_id': 'gp-1',
              'confidence': 90,
              'match_reason': 'Name and date of birth exact match',
            },
          ],
        },
        resourceType: 'patients',
      );
      expect(diff.strategy, 'server_wins');
      expect(diff.narrative.toLowerCase(), contains('duplicate'));
      expect(diff.narrative, contains('90'));
      expect(diff.mergedData, isNull);
    });

    test('returns server_wins with a scheduling-conflict narrative', () {
      final diff = SyncDiffHelper.createConflictDiff(
        serverData: {'reason': 'scheduling_conflict', 'provider_id': 'doc-1'},
        resourceType: 'appointments',
      );
      expect(diff.strategy, 'server_wins');
      expect(diff.narrative.toLowerCase(), contains('overlap'));
    });
  });

  group('SyncConflict.isCreateConflict', () {
    test('returns true for a duplicate-patient conflict', () {
      final conflict = SyncConflict(
        id: 'c-6',
        resourceType: 'patients',
        clientData: {'first_name': 'Jane', 'last_name': 'Doe'},
        serverData: {'reason': 'potential_duplicate_patient', 'matches': []},
        status: 'pending',
        createdAt: '2026-06-10T00:00:00Z',
      );
      expect(conflict.isCreateConflict, isTrue);
      expect(conflict.isDeleteConflict, isFalse);
    });

    test('returns true for a scheduling conflict', () {
      final conflict = SyncConflict(
        id: 'c-7',
        resourceType: 'appointments',
        clientData: {'appointment_type': 'checkup'},
        serverData: {'reason': 'scheduling_conflict', 'provider_id': 'doc-1'},
        status: 'pending',
        createdAt: '2026-06-10T00:00:00Z',
      );
      expect(conflict.isCreateConflict, isTrue);
    });

    test('returns false for an ordinary update conflict', () {
      final conflict = SyncConflict(
        id: 'c-8',
        resourceType: 'prescriptions',
        clientData: {'dosage': '750mg'},
        serverData: {'dosage': '500mg', 'status': 'active'},
        status: 'pending',
        createdAt: '2026-06-10T00:00:00Z',
      );
      expect(conflict.isCreateConflict, isFalse);
    });
  });
}
