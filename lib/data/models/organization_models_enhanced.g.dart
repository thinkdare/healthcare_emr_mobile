// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'organization_models_enhanced.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OrganizationEnhancedModel _$OrganizationEnhancedModelFromJson(
  Map<String, dynamic> json,
) => OrganizationEnhancedModel(
  id: json['id'] as String,
  name: json['name'] as String,
  type: json['type'] as String,
  address: json['address'] as String,
  phone: json['phone'] as String?,
  email: json['email'] as String?,
  taxId: json['tax_id'] as String?,
  subscriptionStatus: json['subscription_status'] as String,
  trialEndsAt: json['trial_ends_at'] == null
      ? null
      : DateTime.parse(json['trial_ends_at'] as String),
  maxFacilities: (json['max_facilities'] as num).toInt(),
  maxProviders: (json['max_providers'] as num).toInt(),
  billingEmail: json['billing_email'] as String?,
  billingAddress: json['billing_address'] as String?,
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
  updatedAt: json['updated_at'] == null
      ? null
      : DateTime.parse(json['updated_at'] as String),
);

Map<String, dynamic> _$OrganizationEnhancedModelToJson(
  OrganizationEnhancedModel instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'type': instance.type,
  'address': instance.address,
  'phone': instance.phone,
  'email': instance.email,
  'tax_id': instance.taxId,
  'subscription_status': instance.subscriptionStatus,
  'trial_ends_at': instance.trialEndsAt?.toIso8601String(),
  'max_facilities': instance.maxFacilities,
  'max_providers': instance.maxProviders,
  'billing_email': instance.billingEmail,
  'billing_address': instance.billingAddress,
  'created_at': instance.createdAt?.toIso8601String(),
  'updated_at': instance.updatedAt?.toIso8601String(),
};

FacilityModel _$FacilityModelFromJson(Map<String, dynamic> json) =>
    FacilityModel(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      address: json['address'] as String,
      phone: json['phone'] as String?,
      operatingHours: json['operating_hours'] as Map<String, dynamic>?,
      supportsEmergencyAccess: json['supports_emergency_access'] as bool,
      isActive: json['is_active'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$FacilityModelToJson(FacilityModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'organization_id': instance.organizationId,
      'name': instance.name,
      'type': instance.type,
      'address': instance.address,
      'phone': instance.phone,
      'operating_hours': instance.operatingHours,
      'supports_emergency_access': instance.supportsEmergencyAccess,
      'is_active': instance.isActive,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
    };
