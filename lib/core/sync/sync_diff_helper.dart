// lib/core/sync/sync_diff_helper.dart
//
// Pure Dart — no Flutter imports. Diffs client_data vs server_data from a
// SyncConflict and produces a human-readable narrative + resolution suggestion.

class SyncDiff {
  final String narrative;
  final String suggestion;
  final String strategy; // 'merged' | 'server_wins' | 'client_wins'
  final Map<String, dynamic>? mergedData;
  final List<String> changedByClient;
  final List<String> changedByServer;
  final List<String> overlappingFields;

  const SyncDiff({
    required this.narrative,
    required this.suggestion,
    required this.strategy,
    this.mergedData,
    required this.changedByClient,
    required this.changedByServer,
    required this.overlappingFields,
  });
}

class SyncDiffHelper {
  // Internal versioning fields — never shown to the user.
  static const _excluded = {
    'id', 'version', 'created_at', 'updated_at', 'deleted_at',
    'user_id', 'membership_id', 'last_modified_by',
  };

  static SyncDiff diff({
    required Map<String, dynamic> clientData,
    required Map<String, dynamic> serverData,
    required String resourceType,
  }) {
    final allKeys = {...clientData.keys, ...serverData.keys}
        .where((k) => !_excluded.contains(k))
        .toSet();

    // Partition keys into three groups:
    //   clientOnly  — field present in client but not server (client added it)
    //   serverOnly  — field present in server but not client (server added it)
    //   trueOverlap — field present in both but with different values
    final clientOnly = <String>[];
    final serverOnly = <String>[];
    final trueOverlaps = <String>[];

    for (final key in allKeys) {
      final inClient = clientData.containsKey(key);
      final inServer = serverData.containsKey(key);
      final cv = clientData[key]?.toString();
      final sv = serverData[key]?.toString();

      if (inClient && !inServer) {
        clientOnly.add(key);
      } else if (!inClient && inServer) {
        serverOnly.add(key);
      } else if (cv != sv) {
        // Present in both, values differ — true conflict
        trueOverlaps.add(key);
      }
    }

    // Nothing differs at all (after excluding internals) — no-op conflict
    if (clientOnly.isEmpty && serverOnly.isEmpty && trueOverlaps.isEmpty) {
      return SyncDiff(
        narrative:
            'No user-facing fields differ — this conflict can be safely resolved.',
        suggestion: 'Keep your version',
        strategy: 'client_wins',
        changedByClient: [],
        changedByServer: [],
        overlappingFields: [],
      );
    }

    // Non-overlapping: client has unique fields and/or server has unique fields,
    // but neither side changed the SAME field. Safe to merge.
    if (trueOverlaps.isEmpty) {
      final merged = <String, dynamic>{...serverData};
      for (final k in clientOnly) {
        merged[k] = clientData[k];
      }
      return SyncDiff(
        narrative: _buildNarrative(
          clientChanged: clientOnly,
          serverChanged: serverOnly,
          overlapping: [],
        ),
        suggestion: 'Merge both changes',
        strategy: 'merged',
        mergedData: merged,
        changedByClient: clientOnly,
        changedByServer: serverOnly,
        overlappingFields: [],
      );
    }

    // True overlaps exist — the same field was changed on both sides.
    // Server wins: the server write is audited, timestamped, and more recent.
    return SyncDiff(
      narrative: _buildNarrative(
        clientChanged: [...clientOnly, ...trueOverlaps],
        serverChanged: [...serverOnly, ...trueOverlaps],
        overlapping: trueOverlaps,
      ),
      suggestion: 'Use server version (more recent)',
      strategy: 'server_wins',
      changedByClient: [...clientOnly, ...trueOverlaps],
      changedByServer: [...serverOnly, ...trueOverlaps],
      overlappingFields: trueOverlaps,
    );
  }

  static String _buildNarrative({
    required List<String> clientChanged,
    required List<String> serverChanged,
    required List<String> overlapping,
  }) {
    final parts = <String>[];
    final clientOnly = clientChanged
        .where((k) => !overlapping.contains(k))
        .map(_label)
        .join(', ');
    if (clientOnly.isNotEmpty) {
      parts.add('You added $clientOnly while offline.');
    }
    final serverOnly = serverChanged
        .where((k) => !overlapping.contains(k))
        .map(_label)
        .join(', ');
    if (serverOnly.isNotEmpty) {
      parts.add('The server added $serverOnly.');
    }
    if (overlapping.isNotEmpty) {
      final fields = overlapping.map(_label).join(', ');
      parts.add(
          'Both sides changed $fields — the server version will be used as it is more recent.');
    }
    return parts.isEmpty ? 'No user-facing fields differ.' : parts.join(' ');
  }

  static String _label(String field) => field.replaceAll('_', ' ');

  /// Produces a SyncDiff for delete-vs-update conflicts (client tried to
  /// delete a resource the server had since updated). Resolution options are
  /// binary: accept deletion (client_wins) or restore server version
  /// (server_wins). Merging is not applicable.
  static SyncDiff deleteConflictDiff({
    required Map<String, dynamic> serverData,
    required String resourceType,
  }) {
    final label = resourceType.replaceAll('_', ' ');
    return SyncDiff(
      narrative:
          'You deleted this $label while the server had updated it. '
          'The current server version is shown below.',
      suggestion: 'Keep server version (discard deletion)',
      strategy: 'server_wins',
      changedByClient: [],
      changedByServer: [],
      overlappingFields: [],
    );
  }
}
