/// AccessGrantModel
///
/// Represents a cross-facility patient access grant (central DB).
/// Returned by GET/POST /api/v1/access-grants.
class AccessGrantModel {
  final String id;
  final String status; // pending | approved | denied | revoked
  final String accessLevel; // view_only | view_and_update | full_access
  final List<String> accessibleDataTypes;
  final String? requestReason;
  final bool autoApproved;
  final String? approverAuthority;
  final Map<String, String>? requestingTenant; // {id, name}
  final Map<String, String>? grantingTenant;   // {id, name}
  final String? requestingProviderId;
  final DateTime? grantedAt;
  final DateTime? expiresAt;
  final DateTime? revokedAt;
  final DateTime createdAt;

  const AccessGrantModel({
    required this.id,
    required this.status,
    required this.accessLevel,
    required this.accessibleDataTypes,
    this.requestReason,
    this.autoApproved = false,
    this.approverAuthority,
    this.requestingTenant,
    this.grantingTenant,
    this.requestingProviderId,
    this.grantedAt,
    this.expiresAt,
    this.revokedAt,
    required this.createdAt,
  });

  bool get isPending  => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isDenied   => status == 'denied';
  bool get isRevoked  => status == 'revoked';

  bool get isActive =>
      isApproved &&
      (expiresAt == null || expiresAt!.isAfter(DateTime.now()));

  bool get isExpired =>
      isApproved && expiresAt != null && expiresAt!.isBefore(DateTime.now());

  String get requestingTenantName =>
      requestingTenant?['name'] ?? 'Unknown facility';

  String get grantingTenantName =>
      grantingTenant?['name'] ?? 'Unknown facility';

  String get accessLevelDisplay => switch (accessLevel) {
        'view_only'        => 'View only',
        'view_and_update'  => 'View & update',
        'full_access'      => 'Full access',
        _                  => accessLevel,
      };

  factory AccessGrantModel.fromJson(Map<String, dynamic> json) {
    Map<String, String>? toStringMap(dynamic v) {
      if (v == null) return null;
      if (v is Map) {
        return v.map((k, val) => MapEntry(k.toString(), val.toString()));
      }
      return null;
    }

    return AccessGrantModel(
      id:                    json['id'] as String,
      status:                json['status'] as String,
      accessLevel:           json['access_level'] as String,
      accessibleDataTypes:   (json['accessible_data_types'] as List?)
                                 ?.map((e) => e.toString())
                                 .toList() ??
                             [],
      requestReason:         json['request_reason'] as String?,
      autoApproved:          (json['auto_approved'] as bool?) ?? false,
      approverAuthority:     json['approver_authority'] as String?,
      requestingTenant:      toStringMap(json['requesting_tenant']),
      grantingTenant:        toStringMap(json['granting_tenant']),
      requestingProviderId:  json['requesting_provider_id'] as String?,
      grantedAt:             json['granted_at'] != null
                                 ? DateTime.tryParse(json['granted_at'] as String)
                                 : null,
      expiresAt:             json['expires_at'] != null
                                 ? DateTime.tryParse(json['expires_at'] as String)
                                 : null,
      revokedAt:             json['revoked_at'] != null
                                 ? DateTime.tryParse(json['revoked_at'] as String)
                                 : null,
      createdAt:             DateTime.parse(json['created_at'] as String),
    );
  }
}
