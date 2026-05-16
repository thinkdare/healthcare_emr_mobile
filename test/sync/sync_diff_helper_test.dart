import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_emr_mobile/core/sync/sync_diff_helper.dart';

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
}
