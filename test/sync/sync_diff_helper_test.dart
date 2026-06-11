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
  });
}
