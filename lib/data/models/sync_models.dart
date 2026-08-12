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
}

class SyncChange {
  final String resourceType;
  final String? resourceId;
  final String operation; // 'create' | 'update' | 'delete'
  final Map<String, dynamic> payload;
  final int clientVersion;
  final String clientTimestamp;

  const SyncChange({
    required this.resourceType,
    this.resourceId,
    required this.operation,
    required this.payload,
    required this.clientVersion,
    required this.clientTimestamp,
  });

  Map<String, dynamic> toJson() => {
        'resource_type': resourceType,
        'resource_id': resourceId,
        'operation': operation,
        'payload': payload,
        'client_version': clientVersion,
        'client_timestamp': clientTimestamp,
      };
}

class SyncPushResult {
  final int queued;
  final int conflicts;
  final int applied;

  const SyncPushResult({
    required this.queued,
    required this.conflicts,
    required this.applied,
  });

  factory SyncPushResult.fromJson(Map<String, dynamic> json) => SyncPushResult(
        queued: (json['queued'] as num).toInt(),
        conflicts: (json['conflicts'] as num).toInt(),
        applied: (json['applied'] as num).toInt(),
      );
}
