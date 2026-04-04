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
@JsonSerializable()
class FacilityModel {
  final String id;
  
  @JsonKey(name: 'organization_id')
  final String organizationId;
  
  final String name;
  final String type; // 'main_hospital', 'branch', 'pharmacy', 'lab'
  final String address;
  final String? phone;
  
  @JsonKey(name: 'operating_hours')
  final Map<String, dynamic>? operatingHours;
  
  @JsonKey(name: 'supports_emergency_access')
  final bool supportsEmergencyAccess;
  
  @JsonKey(name: 'is_active')
  final bool isActive;
  
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  FacilityModel({
    required this.id,
    required this.organizationId,
    required this.name,
    required this.type,
    required this.address,
    this.phone,
    this.operatingHours,
    required this.supportsEmergencyAccess,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FacilityModel.fromJson(Map<String, dynamic> json) =>
      _$FacilityModelFromJson(json);

  Map<String, dynamic> toJson() => _$FacilityModelToJson(this);
}