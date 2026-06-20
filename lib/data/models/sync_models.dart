// lib/data/models/sync_models.dart

enum SyncStatus { idle, syncing, synced, offline, error }

class SyncConflict {
  final String id;
  final String resourceType;
  final String? resourceId;
  final Map<String, dynamic> clientData;
  final Map<String, dynamic> serverData;
  final Map<String, dynamic>? mergedData;
  final String? resolutionStrategy;
  final String status; // 'pending' | 'resolved'
  final String? resolutionNotes;
  final String? resolvedAt;
  final String createdAt;

  const SyncConflict({
    required this.id,
    required this.resourceType,
    this.resourceId,
    required this.clientData,
    required this.serverData,
    this.mergedData,
    this.resolutionStrategy,
    required this.status,
    this.resolutionNotes,
    this.resolvedAt,
    required this.createdAt,
  });

  factory SyncConflict.fromJson(Map<String, dynamic> json) => SyncConflict(
        id: json['id'] as String,
        resourceType: json['resource_type'] as String,
        resourceId: json['resource_id'] as String?,
        clientData: Map<String, dynamic>.from(json['client_data'] as Map),
        serverData: Map<String, dynamic>.from(json['server_data'] as Map),
        mergedData: json['merged_data'] != null
            ? Map<String, dynamic>.from(json['merged_data'] as Map)
            : null,
        resolutionStrategy: json['resolution_strategy'] as String?,
        status: json['status'] as String,
        resolutionNotes: json['resolution_notes'] as String?,
        resolvedAt: json['resolved_at'] as String?,
        createdAt: json['created_at'] as String,
      );

  bool get isPending => status == 'pending';

  /// True for either shape of delete conflict:
  ///  - server-deleted: the server has deleted (or never had) the resource
  ///    the client tried to edit. serverData carries an explicit signal —
  ///    either `deleted_at` set (soft-deleted, fields still present) or
  ///    `deleted: true` with no other fields (hard-deleted/missing — see
  ///    SyncController::surfaceDeleteConflict() server-side).
  ///  - client-deleted: the client operation was itself a delete and the
  ///    server had since updated the record. Inferred from the payload: a
  ///    delete operation sends no user-facing fields, so clientData has
  ///    nothing beyond internal fields.
  bool get isDeleteConflict {
    if (serverData['deleted'] == true) return true;

    final deletedAt = serverData['deleted_at'];
    if (deletedAt != null && deletedAt != '') return true;

    const internal = {
      'id', 'version', 'created_at', 'updated_at', 'deleted_at',
      'user_id', 'membership_id', 'last_modified_by',
    };
    final meaningful =
        clientData.keys.where((k) => !internal.contains(k)).toList();
    return meaningful.isEmpty && serverData.isNotEmpty;
  }

  /// True when this conflict came from an offline *create* being withheld
  /// rather than applied — a potential duplicate patient or an appointment
  /// scheduling conflict detected during push() (see
  /// SyncController::surfaceCreateConflict() server-side). serverData here
  /// is conflict metadata (`reason`, `matches`/`provider_id`), not a record
  /// snapshot, so it must not be run through the normal field-by-field diff.
  static const _createConflictReasons = {
    'potential_duplicate_patient',
    'scheduling_conflict',
  };

  bool get isCreateConflict => _createConflictReasons.contains(serverData['reason']);
}

class SyncChange {
  /// The local pending_sync row id this change came from. Stable across
  /// retries of the same logical change (never regenerated), which is what
  /// lets the server recognize a retried request and avoid reprocessing an
  /// already-applied write — see SyncController::push() server-side.
  final String id;
  final String resourceType;
  final String? resourceId;
  final String operation; // 'create' | 'update' | 'delete'
  final Map<String, dynamic> payload;
  final int clientVersion;
  final String clientTimestamp;

  const SyncChange({
    required this.id,
    required this.resourceType,
    this.resourceId,
    required this.operation,
    required this.payload,
    required this.clientVersion,
    required this.clientTimestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'resource_type': resourceType,
        'resource_id': resourceId,
        'operation': operation,
        'payload': payload,
        'client_version': clientVersion,
        'client_timestamp': clientTimestamp,
      };
}

/// Per-change outcome from a push, keyed by the same id sent in SyncChange.
/// 'completed' and 'conflict' are durably resolved server-side (the second
/// is tracked via SyncConflict) and safe to drop from the local queue.
/// 'forbidden' and 'rejected' are NOT safe to drop — the server doesn't
/// cache those verdicts (the access situation can change), so leaving them
/// queued lets them retry on the next push for free.
class SyncItemResult {
  final String id;
  final String outcome;

  const SyncItemResult({required this.id, required this.outcome});

  factory SyncItemResult.fromJson(Map<String, dynamic> json) => SyncItemResult(
        id: json['id'] as String,
        outcome: json['outcome'] as String,
      );

  bool get isResolved => outcome == 'completed' || outcome == 'conflict';
}

class SyncPushResult {
  final int queued;
  final int conflicts;
  final int applied;
  final List<SyncItemResult> items;

  const SyncPushResult({
    required this.queued,
    required this.conflicts,
    required this.applied,
    this.items = const [],
  });

  factory SyncPushResult.fromJson(Map<String, dynamic> json) => SyncPushResult(
        queued: (json['queued'] as num).toInt(),
        conflicts: (json['conflicts'] as num).toInt(),
        applied: (json['applied'] as num).toInt(),
        items: (json['items'] as List? ?? [])
            .map((e) => SyncItemResult.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}
