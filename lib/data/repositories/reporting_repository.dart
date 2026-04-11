import '../../core/api/api_client.dart';

class AuditLogEntry {
  final String id;
  final String? patientId;
  final String? userId;
  final String action;
  final String? resourceType;
  final String? accessAuthority;
  final bool wasEmergency;
  final bool wasOffline;
  final String? ipAddress;
  final String? activeFacilitySlug;
  final DateTime? accessedAt;

  const AuditLogEntry({
    required this.id,
    this.patientId,
    this.userId,
    required this.action,
    this.resourceType,
    this.accessAuthority,
    required this.wasEmergency,
    required this.wasOffline,
    this.ipAddress,
    this.activeFacilitySlug,
    this.accessedAt,
  });

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) => AuditLogEntry(
        id: json['id'] as String,
        patientId: json['patient_id'] as String?,
        userId: json['user_id'] as String?,
        action: json['action'] as String? ?? '',
        resourceType: json['resource_type'] as String?,
        accessAuthority: json['access_authority'] as String?,
        wasEmergency: json['was_emergency'] as bool? ?? false,
        wasOffline: json['was_offline'] as bool? ?? false,
        ipAddress: json['ip_address'] as String?,
        activeFacilitySlug: json['active_facility_slug'] as String?,
        accessedAt: json['accessed_at'] == null
            ? null
            : DateTime.tryParse(json['accessed_at'] as String),
      );

  String get actionDisplay => switch (action) {
        'viewed'           => 'Viewed',
        'created'          => 'Created',
        'updated'          => 'Updated',
        'deleted'          => 'Deleted',
        'emergency_access' => 'Emergency Access',
        'access_denied'    => 'Access Denied',
        _                  => action,
      };

  String get authorityDisplay => switch (accessAuthority) {
        'primary_provider'    => 'Primary Provider',
        'intra_tenant_grant'  => 'Intra-facility Grant',
        'cross_tenant_grant'  => 'Cross-facility Grant',
        'emergency'           => 'Emergency',
        'denied'              => 'Denied',
        _                     => accessAuthority ?? '—',
      };
}

class ReportingRepository {
  final ApiClient apiClient;

  ReportingRepository({required this.apiClient});

  // ── Org dashboard ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> orgDashboard(String orgId) async {
    final response = await apiClient
        .get('/reporting/organizations/$orgId/dashboard');
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to load org dashboard');
    }
    final data = Map<String, dynamic>.from(response['data'] as Map);
    return data['stats'] as Map<String, dynamic>?;
  }

  // ── Tenant dashboard ──────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> tenantDashboard(String tenantId) async {
    final response =
        await apiClient.get('/reporting/tenants/$tenantId/dashboard');
    if (response['success'] != true) {
      throw Exception(
          response['message'] ?? 'Failed to load facility dashboard');
    }
    final data = Map<String, dynamic>.from(response['data'] as Map);
    return data['stats'] as Map<String, dynamic>?;
  }

  // ── Audit log ─────────────────────────────────────────────────────────────

  Future<({List<AuditLogEntry> items, bool hasMore, int total})> auditLog(
    String tenantId, {
    int page = 1,
    String? action,
    String? accessAuthority,
    String? from,
    String? to,
    bool? wasEmergency,
  }) async {
    final params = <String, dynamic>{'page': page, 'per_page': 30};
    if (action != null) params['action'] = action;
    if (accessAuthority != null) params['access_authority'] = accessAuthority;
    if (from != null) params['from'] = from;
    if (to != null) params['to'] = to;
    if (wasEmergency != null) params['was_emergency'] = wasEmergency ? 1 : 0;

    final response = await apiClient.get(
      '/reporting/tenants/$tenantId/compliance/audit-log',
      queryParameters: params,
    );

    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to load audit log');
    }

    final list = (response['data'] as List? ?? [])
        .map((e) => AuditLogEntry.fromJson(e as Map<String, dynamic>))
        .toList();

    final meta = response['meta'] as Map? ?? {};
    final pagination = meta['pagination'] as Map? ?? {};
    final total = (pagination['total'] as num?)?.toInt() ?? list.length;
    final lastPage = (pagination['last_page'] as num?)?.toInt() ?? 1;
    final hasMore = page < lastPage;

    return (items: list, hasMore: hasMore, total: total);
  }

  // ── Audit summary ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> auditSummary(
      String tenantId, String from, String to) async {
    final response = await apiClient.get(
      '/reporting/tenants/$tenantId/compliance/audit-summary',
      queryParameters: {'from': from, 'to': to},
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to load audit summary');
    }
    return Map<String, dynamic>.from(response['data'] as Map);
  }
}
