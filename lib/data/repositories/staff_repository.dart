import '../../core/api/api_client.dart';
import '../models/auth_models.dart';

// ── Invitation models ─────────────────────────────────────────────────────────

class InvitationDetails {
  final String token;
  final String email;
  final String facilityName;
  final String facilityId;
  final String staffType;
  final String? inviterName;
  final DateTime? expiresAt;

  const InvitationDetails({
    required this.token,
    required this.email,
    required this.facilityName,
    required this.facilityId,
    required this.staffType,
    this.inviterName,
    this.expiresAt,
  });

  factory InvitationDetails.fromJson(Map<String, dynamic> json) {
    final facility = json['facility'] as Map<String, dynamic>? ?? {};
    final inviter  = json['invited_by'] as Map<String, dynamic>?;
    return InvitationDetails(
      token:        json['token'] as String? ?? '',
      email:        json['email'] as String? ?? '',
      facilityName: (facility['name'] ?? json['facility_name']) as String? ?? '',
      facilityId:   (facility['id']   ?? json['facility_id'])   as String? ?? '',
      staffType:    json['staff_type'] as String? ?? '',
      inviterName:  inviter != null
          ? '${inviter['first_name'] ?? ''} ${inviter['last_name'] ?? ''}'.trim()
          : json['invited_by_name'] as String?,
      expiresAt: json['expires_at'] == null
          ? null
          : DateTime.tryParse(json['expires_at'] as String),
    );
  }

  String get staffTypeLabel {
    const labels = {
      'doctor': 'Doctor', 'nurse': 'Nurse', 'pharmacist': 'Pharmacist',
      'lab_tech': 'Lab Technician', 'radiologist': 'Radiologist',
      'physiotherapist': 'Physiotherapist', 'dentist': 'Dentist',
      'admin': 'Administrator', 'other': 'Healthcare Professional',
    };
    return labels[staffType] ?? staffType;
  }
}

class StaffRepository {
  final ApiClient apiClient;

  StaffRepository({required this.apiClient});

  /// Returns all staff members at the active facility (scoped by X-Tenant-ID header).
  Future<List<FacilityStaffMemberModel>> getStaffMemberships() async {
    final response = await apiClient.get(
      '/staff/memberships',
      queryParameters: {'per_page': 200},
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to load staff');
    }
    final data = response['data'];
    final raw = data is Map
        ? (data['data'] as List? ?? [])
        : (data as List? ?? []);
    return raw
        .map((e) => FacilityStaffMemberModel.fromJson(
            Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> updateMembership(
    String membershipId, {
    String? staffType,
    String? clinicalRankId,
    bool? isActive,
  }) async {
    final data = <String, dynamic>{
      'staff_type': ?staffType,
      'clinical_rank_id': ?clinicalRankId,
      'is_active': ?isActive,
    };
    final response = await apiClient.put(
      '/staff/memberships/$membershipId',
      data: data,
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to update membership');
    }
  }

  Future<void> deleteMembership(String membershipId, String reason) async {
    final response = await apiClient.delete(
      '/staff/memberships/$membershipId',
      data: {'reason': reason},
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to remove staff member');
    }
  }

  Future<List<ClinicalRankModel>> getClinicalRanks() async {
    final response = await apiClient.get('/clinical-ranks');
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to load clinical ranks');
    }
    final data = response['data'];
    final raw = data is Map
        ? (data['data'] as List? ?? [])
        : (data as List? ?? []);
    return raw
        .map((e) =>
            ClinicalRankModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  // ── Invitation flow ──────────────────────────────────────────────────────

  /// Validates a staff invitation token and returns invitation details.
  Future<InvitationDetails> validateInvitation(String token) async {
    final response = await apiClient.get(
      '/staff/invitation',
      queryParameters: {'token': token},
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Invalid or expired invitation');
    }
    return InvitationDetails.fromJson(
      Map<String, dynamic>.from(response['data'] as Map),
    );
  }

  /// Completes registration via an invitation token.
  /// Returns the auth token on success.
  Future<String> registerViaInvitation({
    required String token,
    required String firstName,
    required String lastName,
    required String password,
  }) async {
    final response = await apiClient.post(
      '/staff/register',
      data: {
        'token':                 token,
        'first_name':            firstName,
        'last_name':             lastName,
        'password':              password,
        'password_confirmation': password,
      },
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Registration failed');
    }
    final data = Map<String, dynamic>.from(response['data'] as Map);
    final authToken = (data['access_token'] ?? data['token']) as String?;
    if (authToken == null) throw Exception('No token returned from server');
    return authToken;
  }
}
