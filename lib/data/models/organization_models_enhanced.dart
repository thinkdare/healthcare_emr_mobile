import 'package:json_annotation/json_annotation.dart';

part 'organization_models_enhanced.g.dart';

// Enhanced Organization Model with Subscription Fields
@JsonSerializable()
class OrganizationEnhancedModel {
  final String id;
  final String name;
  final String type;
  final String address;
  final String? phone;
  final String? email;
  
  @JsonKey(name: 'tax_id')
  final String? taxId;
  
  // Subscription fields
  @JsonKey(name: 'subscription_status')
  final String subscriptionStatus; // 'trial', 'active', 'suspended', 'cancelled'
  
  @JsonKey(name: 'trial_ends_at')
  final DateTime? trialEndsAt;
  
  @JsonKey(name: 'max_facilities')
  final int maxFacilities;
  
  @JsonKey(name: 'max_providers')
  final int maxProviders;
  
  @JsonKey(name: 'billing_email')
  final String? billingEmail;
  
  @JsonKey(name: 'billing_address')
  final String? billingAddress;
  
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  OrganizationEnhancedModel({
    required this.id,
    required this.name,
    required this.type,
    required this.address,
    this.phone,
    this.email,
    this.taxId,
    required this.subscriptionStatus,
    this.trialEndsAt,
    required this.maxFacilities,
    required this.maxProviders,
    this.billingEmail,
    this.billingAddress,
    this.createdAt,
    this.updatedAt,
  });

  factory OrganizationEnhancedModel.fromJson(Map<String, dynamic> json) =>
      _$OrganizationEnhancedModelFromJson(json);

  Map<String, dynamic> toJson() => _$OrganizationEnhancedModelToJson(this);
  
  bool get isActive => subscriptionStatus == 'active' || subscriptionStatus == 'trial';
  bool get onTrial => subscriptionStatus == 'trial';
  
  int? get trialDaysRemaining {
    if (trialEndsAt == null) return null;
    return trialEndsAt!.difference(DateTime.now()).inDays;
  }
}

// Facility Model
/// Manually maintained (not codegen) — mirrors TenantController::formatTenant()'s
/// exact response shape, which nests organization as {id, name} rather than a
/// flat organization_id, and has no updated_at field.
class FacilityModel {
  final String id;
  final String name;
  final String slug;
  final String type; // hospital | clinic | pharmacy | lab
  final String country;
  final String? stateProvince;
  final String? address;
  final String? phone;
  final String? email;
  final bool supportsEmergencyAccess;
  final bool isActive;
  final String? organizationId;
  final String? organizationName;
  final DateTime createdAt;

  // Only present when fetched via show() (detailed: true)
  final Map<String, dynamic>? operatingHours;
  final Map<String, dynamic>? settings;
  final bool? isOpenNow;

  FacilityModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.type,
    required this.country,
    this.stateProvince,
    this.address,
    this.phone,
    this.email,
    required this.supportsEmergencyAccess,
    required this.isActive,
    this.organizationId,
    this.organizationName,
    required this.createdAt,
    this.operatingHours,
    this.settings,
    this.isOpenNow,
  });

  factory FacilityModel.fromJson(Map<String, dynamic> json) {
    final org = json['organization'] as Map?;
    return FacilityModel(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String? ?? '',
      type: json['type'] as String,
      country: json['country'] as String? ?? '',
      stateProvince: json['state_province'] as String?,
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      supportsEmergencyAccess: (json['supports_emergency_access'] as bool?) ?? false,
      isActive: (json['is_active'] as bool?) ?? true,
      organizationId: org?['id'] as String?,
      organizationName: org?['name'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      operatingHours: json['operating_hours'] != null
          ? Map<String, dynamic>.from(json['operating_hours'] as Map)
          : null,
      settings: json['settings'] != null
          ? Map<String, dynamic>.from(json['settings'] as Map)
          : null,
      isOpenNow: json['is_open_now'] as bool?,
    );
  }
}

// ─── OrgStatsModel ─────────────────────────────────────────────────────────

@JsonSerializable()
class OrgStatsModel {
  @JsonKey(name: 'total_facilities') final int totalFacilities;
  @JsonKey(name: 'total_staff')      final int totalStaff;
  @JsonKey(name: 'total_patients')   final int totalPatients;
  @JsonKey(name: 'active_subscriptions') final int activeSubscriptions;

  const OrgStatsModel({
    required this.totalFacilities,
    required this.totalStaff,
    required this.totalPatients,
    required this.activeSubscriptions,
  });

  factory OrgStatsModel.fromJson(Map<String, dynamic> json) =>
      _$OrgStatsModelFromJson(json);

  Map<String, dynamic> toJson() => _$OrgStatsModelToJson(this);
}

// ─── UpdateOrganizationRequest ─────────────────────────────────────────────

@JsonSerializable(includeIfNull: false)
class UpdateOrganizationRequest {
  final String? name;
  final String? type;
  final String? address;
  final String? phone;
  final String? email;

  @JsonKey(name: 'tax_id')
  final String? taxId;

  @JsonKey(name: 'billing_email')
  final String? billingEmail;

  @JsonKey(name: 'billing_address')
  final String? billingAddress;

  const UpdateOrganizationRequest({
    this.name,
    this.type,
    this.address,
    this.phone,
    this.email,
    this.taxId,
    this.billingEmail,
    this.billingAddress,
  });

  factory UpdateOrganizationRequest.fromJson(Map<String, dynamic> json) =>
      _$UpdateOrganizationRequestFromJson(json);

  Map<String, dynamic> toJson() => _$UpdateOrganizationRequestToJson(this);
}