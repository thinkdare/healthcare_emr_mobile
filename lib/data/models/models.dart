import 'package:json_annotation/json_annotation.dart';

part 'models.g.dart';

// ─────────────────────────────────────────────────────────────────────────────
// UserModel
// ─────────────────────────────────────────────────────────────────────────────

@JsonSerializable()
class UserModel {
  final String id;
  final String email;

  /// Full name as stored on the User record.
  @JsonKey(name: 'full_name')
  final String name;

  @JsonKey(name: 'user_type')
  final String userType; // 'staff' | 'super_admin' | 'org_admin'

  @JsonKey(name: 'two_factor_enabled', defaultValue: false)
  final bool twoFactorEnabled;

  @JsonKey(name: 'created_at')
  final DateTime? createdAt;

  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.userType,
    this.twoFactorEnabled = false,
    this.createdAt,
    this.updatedAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);

  Map<String, dynamic> toJson() => _$UserModelToJson(this);

  String get initials {
    final parts = name.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isNotEmpty) return parts[0][0].toUpperCase();
    return 'U';
  }

  bool get isSuperAdmin => userType == 'super_admin';
  bool get isOrgAdmin => userType == 'org_admin';
  bool get isStaff => userType == 'staff';
}

// ─────────────────────────────────────────────────────────────────────────────
// OrganizationModel
// ─────────────────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────────────
// OrganizationLiteModel
// ─────────────────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────────────
// ApiResponse / ApiMeta — generic envelope wrappers
// ─────────────────────────────────────────────────────────────────────────────

@JsonSerializable(genericArgumentFactories: true)
class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? message;
  final ApiMeta? meta;

  ApiResponse({
    required this.success,
    this.data,
    this.message,
    this.meta,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Object? json) fromJsonT,
  ) =>
      _$ApiResponseFromJson(json, fromJsonT);

  Map<String, dynamic> toJson(Object? Function(T value) toJsonT) =>
      _$ApiResponseToJson(this, toJsonT);
}

@JsonSerializable()
class ApiMeta {
  final String? timestamp;
  final String? version;

  ApiMeta({this.timestamp, this.version});

  factory ApiMeta.fromJson(Map<String, dynamic> json) =>
      _$ApiMetaFromJson(json);

  Map<String, dynamic> toJson() => _$ApiMetaToJson(this);
}
