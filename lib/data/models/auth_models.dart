/// Auth-specific models for the EMR backend API (Phase 8).
///
/// All serialisation is hand-written to avoid a build_runner dependency.
/// These models replace the old ProviderModel / LoginResponseModel which
/// were built against a single-tenant architecture that no longer exists.
library;

// ─────────────────────────────────────────────────────────────────────────────
// ClinicalRankModel
// ─────────────────────────────────────────────────────────────────────────────

class ClinicalRankModel {
  final String id;
  final String name;
  final int hierarchyLevel;
  final bool canPrescribe;
  final bool canOrderLabs;
  final bool canApproveAccessGrants;
  final bool canPerformEmergencyAccess;
  final String? organizationId;

  const ClinicalRankModel({
    required this.id,
    required this.name,
    required this.hierarchyLevel,
    required this.canPrescribe,
    required this.canOrderLabs,
    required this.canApproveAccessGrants,
    required this.canPerformEmergencyAccess,
    this.organizationId,
  });

  factory ClinicalRankModel.fromJson(Map<String, dynamic> json) =>
      ClinicalRankModel(
        id: json['id'] as String,
        name: json['name'] as String,
        hierarchyLevel: (json['hierarchy_level'] as num).toInt(),
        canPrescribe: json['can_prescribe'] as bool? ?? false,
        canOrderLabs: json['can_order_labs'] as bool? ?? false,
        canApproveAccessGrants:
            json['can_approve_access_grants'] as bool? ?? false,
        canPerformEmergencyAccess:
            json['can_perform_emergency_access'] as bool? ?? false,
        organizationId: json['organization_id'] as String?,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// StaffMembershipModel
// ─────────────────────────────────────────────────────────────────────────────

class StaffMembershipModel {
  final String id;
  final String staffType; // doctor | nurse | pharmacist | lab_tech | …
  final String? department;
  final bool isPrimary;
  final bool canEmergencyAccess;
  final bool canPrescribe;
  final bool canOrderLabs;
  final ClinicalRankModel? clinicalRank;

  const StaffMembershipModel({
    required this.id,
    required this.staffType,
    this.department,
    required this.isPrimary,
    required this.canEmergencyAccess,
    required this.canPrescribe,
    required this.canOrderLabs,
    this.clinicalRank,
  });

  /// Parses the membership payload returned by /auth/facilities and /auth/facility.
  /// Field names: membership_id, is_primary_affiliation, can_prescribe, can_order_labs.
  factory StaffMembershipModel.fromJson(Map<String, dynamic> json) =>
      StaffMembershipModel(
        id: (json['membership_id'] ?? json['id']) as String,
        staffType: json['staff_type'] as String,
        department: json['department'] is Map
            ? (json['department'] as Map<String, dynamic>)['name'] as String?
            : json['department'] as String?,
        isPrimary: json['is_primary_affiliation'] as bool? ?? json['is_primary'] as bool? ?? false,
        canEmergencyAccess: json['can_emergency_access'] as bool? ?? false,
        canPrescribe: json['can_prescribe'] as bool? ?? false,
        canOrderLabs: json['can_order_labs'] as bool? ?? false,
        clinicalRank: json['clinical_rank'] == null
            ? null
            : ClinicalRankModel.fromJson(
                json['clinical_rank'] as Map<String, dynamic>),
      );

  String get displayType {
    const labels = {
      'doctor': 'Doctor',
      'nurse': 'Nurse',
      'pharmacist': 'Pharmacist',
      'lab_tech': 'Lab Technician',
      'radiologist': 'Radiologist',
      'physiotherapist': 'Physiotherapist',
      'dentist': 'Dentist',
      'admin': 'Administrator',
      'other': 'Healthcare Professional',
    };
    return labels[staffType] ?? staffType;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AuthOrganizationLite — nested inside facility objects
// ─────────────────────────────────────────────────────────────────────────────

class AuthOrganizationLite {
  final String id;
  final String name;

  const AuthOrganizationLite({required this.id, required this.name});

  factory AuthOrganizationLite.fromJson(Map<String, dynamic> json) =>
      AuthOrganizationLite(
        id: json['id'] as String,
        name: json['name'] as String,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// AuthFacilityModel
//
// Used for both:
//   • /auth/check-email → facilities list (membership is null)
//   • /auth/facilities  → user's credentialed facilities (membership present)
//   • /auth/facility    → active facility after switch (membership present)
// ─────────────────────────────────────────────────────────────────────────────

class AuthFacilityModel {
  final String id;
  final String name;
  final String slug;
  final String? type;
  final String? address;
  final String? phone;
  final AuthOrganizationLite? organization;

  /// Present after login when fetching /auth/facilities or /auth/facility.
  /// Null in the check-email step.
  final StaffMembershipModel? membership;

  const AuthFacilityModel({
    required this.id,
    required this.name,
    required this.slug,
    this.type,
    this.address,
    this.phone,
    this.organization,
    this.membership,
  });

  /// For the check-email response: fields are id, name, slug (tenant fields directly).
  factory AuthFacilityModel.fromJson(Map<String, dynamic> json) =>
      AuthFacilityModel(
        id: json['id'] as String,
        name: json['name'] as String,
        slug: json['slug'] as String? ?? '',
        type: json['type'] as String?,
        address: json['address'] as String?,
        phone: json['phone'] as String?,
        organization: json['organization'] == null
            ? null
            : AuthOrganizationLite.fromJson(
                json['organization'] as Map<String, dynamic>),
        membership: json['membership'] == null
            ? null
            : StaffMembershipModel.fromJson(
                json['membership'] as Map<String, dynamic>),
      );

  /// For the /auth/facilities and /auth/facility responses where tenant fields
  /// are prefixed: tenant_id, tenant_name, tenant_slug, tenant_type.
  factory AuthFacilityModel.fromMembershipJson(Map<String, dynamic> json) =>
      AuthFacilityModel(
        id: json['tenant_id'] as String,
        name: json['tenant_name'] as String,
        slug: json['tenant_slug'] as String? ?? '',
        type: json['tenant_type'] as String?,
        organization: json['organization'] == null
            ? null
            : AuthOrganizationLite.fromJson(
                json['organization'] as Map<String, dynamic>),
        membership: StaffMembershipModel.fromJson(json),
      );

  String get displayType {
    const labels = {
      'hospital': 'Hospital',
      'clinic': 'Clinic',
      'pharmacy': 'Pharmacy',
      'laboratory': 'Laboratory',
      'diagnostic_center': 'Diagnostic Center',
      'other': 'Facility',
    };
    return labels[type] ?? (type ?? 'Facility');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CheckEmailResponse
// ─────────────────────────────────────────────────────────────────────────────

class CheckEmailResponse {
  final bool exists;
  final bool hasPassword;
  final String? userType;
  final List<AuthFacilityModel> facilities;

  const CheckEmailResponse({
    required this.exists,
    required this.hasPassword,
    this.userType,
    required this.facilities,
  });

  bool get isOrgAdmin => userType == 'org_admin';

  factory CheckEmailResponse.fromJson(Map<String, dynamic> json) =>
      CheckEmailResponse(
        exists: json['exists'] as bool? ?? false,
        hasPassword: json['has_password'] as bool? ?? true,
        userType: json['user_type'] as String?,
        facilities: (json['facilities'] as List? ?? [])
            .map((e) =>
                AuthFacilityModel.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// LoginResult — sealed-style: either a full token or a 2FA challenge
// ─────────────────────────────────────────────────────────────────────────────

sealed class LoginResult {}

class LoginSuccess extends LoginResult {
  final String token;
  final String tokenType;

  LoginSuccess({required this.token, required this.tokenType});
}

class LoginTwoFactorRequired extends LoginResult {
  final String challengeToken;

  LoginTwoFactorRequired({required this.challengeToken});
}

LoginResult loginResultFromJson(Map<String, dynamic> json) {
  if (json['two_factor_required'] == true) {
    return LoginTwoFactorRequired(
      challengeToken: json['challenge_token'] as String,
    );
  }
  return LoginSuccess(
    token: (json['access_token'] ?? json['token']) as String,
    tokenType: json['token_type'] as String? ?? 'Bearer',
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// FacilitySwitchResponse — result of POST /auth/facility
// ─────────────────────────────────────────────────────────────────────────────

class FacilitySwitchResponse {
  final String tenantId;
  final String tenantName;
  final StaffMembershipModel membership;

  const FacilitySwitchResponse({
    required this.tenantId,
    required this.tenantName,
    required this.membership,
  });

  factory FacilitySwitchResponse.fromJson(Map<String, dynamic> json) {
    final facility = json['active_facility'] as Map<String, dynamic>;
    return FacilitySwitchResponse(
      tenantId: json['tenant_id'] as String,
      tenantName: facility['tenant_name'] as String,
      membership: StaffMembershipModel.fromJson(facility),
    );
  }
}

// ─── FacilityStaffMemberModel ──────────────────────────────────────────────
// One entry from GET /staff/memberships — used by StaffManagementScreen.

class FacilityStaffMemberModel {
  final String membershipId;
  final String userId;
  final String firstName;
  final String lastName;
  final String email;
  final String staffType;
  final bool isActive;
  final ClinicalRankModel? clinicalRank;

  const FacilityStaffMemberModel({
    required this.membershipId,
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.staffType,
    required this.isActive,
    this.clinicalRank,
  });

  String get fullName => '$firstName $lastName'.trim();

  String get initials {
    final f = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';
    final l = lastName.isNotEmpty ? lastName[0].toUpperCase() : '';
    return '$f$l';
  }

  String get displayStaffType {
    const labels = {
      'doctor': 'Doctor',
      'nurse': 'Nurse',
      'pharmacist': 'Pharmacist',
      'lab_tech': 'Lab Technician',
      'radiologist': 'Radiologist',
      'physiotherapist': 'Physiotherapist',
      'dentist': 'Dentist',
      'admin': 'Administrator',
      'other': 'Healthcare Professional',
    };
    return labels[staffType] ?? staffType;
  }

  factory FacilityStaffMemberModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>? ?? {};
    return FacilityStaffMemberModel(
      membershipId: json['id'] as String,
      userId: (user['id'] ?? json['user_id']) as String,
      firstName: user['first_name'] as String? ?? '',
      lastName: user['last_name'] as String? ?? '',
      email: user['email'] as String? ?? '',
      staffType: json['staff_type'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? true,
      clinicalRank: json['clinical_rank'] == null
          ? null
          : ClinicalRankModel.fromJson(
              json['clinical_rank'] as Map<String, dynamic>),
    );
  }
}
