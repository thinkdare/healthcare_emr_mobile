import 'package:json_annotation/json_annotation.dart';

part 'models.g.dart';

// User Model
@JsonSerializable()
class UserModel {
  final String id;
  final String email;
  
  @JsonKey(name: 'user_type')
  final String userType;
  
  @JsonKey(name: 'userable_type')
  final String userableType;
  
  @JsonKey(name: 'userable_id')
  final String userableId;
  
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  UserModel({
    required this.id,
    required this.email,
    required this.userType,
    required this.userableType,
    required this.userableId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);

  Map<String, dynamic> toJson() => _$UserModelToJson(this);
}

// Organization Model - COMPLETE VERSION
@JsonSerializable()
class OrganizationModel {
  final String id;
  final String name;
  final String type;
  final String address;
  final String? phone;
  final String? email;
  
  @JsonKey(name: 'tax_id')
  final String? taxId;
  
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  OrganizationModel({
    required this.id,
    required this.name,
    required this.type,
    required this.address,
    this.phone,
    this.email,
    this.taxId,
    this.createdAt,
    this.updatedAt,
  });

  factory OrganizationModel.fromJson(Map<String, dynamic> json) =>
      _$OrganizationModelFromJson(json);

  Map<String, dynamic> toJson() => _$OrganizationModelToJson(this);
}

// Organization Lite Model (for simpler responses)
@JsonSerializable()
class OrganizationLiteModel {
  final String id;
  final String name;
  final String? type;
  final String? address;

  OrganizationLiteModel({
    required this.id,
    required this.name,
    this.type,
    this.address,
  });

  factory OrganizationLiteModel.fromJson(Map<String, dynamic> json) =>
      _$OrganizationLiteModelFromJson(json);

  Map<String, dynamic> toJson() => _$OrganizationLiteModelToJson(this);
}

// Provider Model
@JsonSerializable()
class ProviderModel {
  final String id;
  
  @JsonKey(name: 'organization_id')
  final String organizationId;
  
  @JsonKey(name: 'first_name')
  final String firstName;
  
  @JsonKey(name: 'last_name')
  final String lastName;
  
  final String phone;
  
  @JsonKey(name: 'provider_type')
  final String providerType;
  
  final String? specialization;
  
  @JsonKey(name: 'license_number')
  final String licenseNumber;
  
  @JsonKey(name: 'can_emergency_access')
  final bool canEmergencyAccess;
  
  @JsonKey(name: 'is_active')
  final bool isActive;
  
  final OrganizationModel? organization;
  
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  ProviderModel({
    required this.id,
    required this.organizationId,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.providerType,
    this.specialization,
    required this.licenseNumber,
    required this.canEmergencyAccess,
    required this.isActive,
    this.organization,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProviderModel.fromJson(Map<String, dynamic> json) =>
      _$ProviderModelFromJson(json);

  Map<String, dynamic> toJson() => _$ProviderModelToJson(this);
  
  String get fullName => '$firstName $lastName';
}

// Login Response Model
@JsonSerializable()
class LoginResponseModel {
  final UserModel user;
  final ProviderModel provider;
  final String token;
  
  @JsonKey(name: 'token_type')
  final String tokenType;

  LoginResponseModel({
    required this.user,
    required this.provider,
    required this.token,
    required this.tokenType,
  });

  factory LoginResponseModel.fromJson(Map<String, dynamic> json) =>
      _$LoginResponseModelFromJson(json);

  Map<String, dynamic> toJson() => _$LoginResponseModelToJson(this);
}

// API Response Model (Generic)
@JsonSerializable(genericArgumentFactories: true)
class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? message;
  final ApiMeta meta;

  ApiResponse({
    required this.success,
    this.data,
    this.message,
    required this.meta,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Object? json) fromJsonT,
  ) =>
      _$ApiResponseFromJson(json, fromJsonT);

  Map<String, dynamic> toJson(Object? Function(T value) toJsonT) =>
      _$ApiResponseToJson(this, toJsonT);
}

// API Meta Model
@JsonSerializable()
class ApiMeta {
  final String timestamp;
  final String version;

  ApiMeta({
    required this.timestamp,
    required this.version,
  });

  factory ApiMeta.fromJson(Map<String, dynamic> json) =>
      _$ApiMetaFromJson(json);

  Map<String, dynamic> toJson() => _$ApiMetaToJson(this);
}