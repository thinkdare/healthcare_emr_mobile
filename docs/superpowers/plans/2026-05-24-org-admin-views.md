# Org Admin Views Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a gated Admin section to the EMR mobile app navigation with four screens — Organization Profile (view/edit), Staff Management (list/edit/remove), Invite Staff (rewritten), and Facilities (wiring existing screen) — visible only to org-admin users.

**Architecture:** `AuthProvider.isOrgAdmin` (checking `UserModel.userType == 'org_admin'`) gates all admin UI. New screens are `StatefulWidget`s with constructor-injected repositories; no new root-level providers. The drawer and iOS More tab each get an injected Admin section. All five build steps produce independently working, committable increments.

**Tech Stack:** Flutter, Provider, Dio (`ApiClient`), `@JsonSerializable` (code-gen via `build_runner`), `flutter_test`

---

## Task 1 — Auth gate: add `isOrgAdmin` to `AuthProvider` and fix existing usages

**Files:**
- Modify: `lib/data/providers/auth_provider.dart` (after line 73)
- Modify: `lib/presentation/dashboard/screens/provider_dashboard_screen.dart` (lines 219, 263, 289)
- Test: `test/auth/auth_provider_test.dart` (new file)

- [ ] **Step 1: Create test directory and write the failing test**

```dart
// test/auth/auth_provider_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_emr_mobile/data/models/models.dart';

void main() {
  group('UserModel.isOrgAdmin', () {
    test('returns true when userType is org_admin', () {
      final user = UserModel(
        id: 'u1',
        email: 'admin@test.com',
        userType: 'org_admin',
        twoFactorEnabled: false,
      );
      expect(user.isOrgAdmin, isTrue);
    });

    test('returns false when userType is staff', () {
      final user = UserModel(
        id: 'u2',
        email: 'staff@test.com',
        userType: 'staff',
        twoFactorEnabled: false,
      );
      expect(user.isOrgAdmin, isFalse);
    });
  });
}
```

- [ ] **Step 2: Run test — expect it to pass (UserModel.isOrgAdmin already exists)**

```bash
cd /path/to/healthcare_emr_mobile
flutter test test/auth/auth_provider_test.dart
```

Expected: PASS — `UserModel.isOrgAdmin` is already defined in `lib/data/models/models.dart:53`.

- [ ] **Step 3: Add `isOrgAdmin` getter to `AuthProvider`**

In `lib/data/providers/auth_provider.dart`, after the `staffType` getter (line 73), add:

```dart
  bool get isOrgAdmin => _currentUser?.isOrgAdmin ?? false;
```

- [ ] **Step 4: Update the three existing `auth.staffType == 'admin'` usages in the dashboard**

In `lib/presentation/dashboard/screens/provider_dashboard_screen.dart`:

**Line 219 (body Consumer):** Change:
```dart
final isAdmin = auth.staffType == 'admin';
```
To:
```dart
final isOrgAdmin = auth.isOrgAdmin;
```
Then update its usages on lines 221 and 237:
```dart
// line 221
final showGrants = isOrgAdmin || isDoctor ||
    (auth.activeMembership?.clinicalRank?.canApproveAccessGrants ?? false);
// line 237
if (isOrgAdmin) ...[
```

**Line 263 (FAB Consumer):** No change needed — FAB uses `auth.staffType == 'doctor'` / `'nurse'` only.

**Line 289 (_buildDrawer Consumer):** Change:
```dart
final isAdmin = auth.staffType == 'admin';
// ...
final showAdminItems = isAdmin;
```
To:
```dart
final isOrgAdmin = auth.isOrgAdmin;
// ...
// delete: final showAdminItems = isAdmin;
```
Then update all uses of `showAdminItems` and `isAdmin` in `_buildDrawer` to use `isOrgAdmin`.

- [ ] **Step 5: Run tests**

```bash
flutter test test/auth/auth_provider_test.dart
flutter analyze
```

Expected: all PASS, no analysis errors.

- [ ] **Step 6: Commit**

```bash
git add lib/data/providers/auth_provider.dart \
        lib/presentation/dashboard/screens/provider_dashboard_screen.dart \
        test/auth/auth_provider_test.dart
git commit -m "feat: add isOrgAdmin auth gate, replace staffType admin checks"
```

---

## Task 2 — Models: `OrgStatsModel`, `UpdateOrganizationRequest`, `FacilityStaffMemberModel`

**Files:**
- Modify: `lib/data/models/organization_models_enhanced.dart`
- Modify: `lib/data/models/auth_models.dart`
- Generated: `lib/data/models/organization_models_enhanced.g.dart` (via build_runner)
- Test: `test/organization/org_models_test.dart` (new file)

- [ ] **Step 1: Write failing model tests**

```dart
// test/organization/org_models_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_emr_mobile/data/models/organization_models_enhanced.dart';
import 'package:healthcare_emr_mobile/data/models/auth_models.dart';

void main() {
  group('OrgStatsModel.fromJson', () {
    test('parses all fields', () {
      final json = {
        'total_facilities': 3,
        'total_staff': 24,
        'total_patients': 1240,
        'active_subscriptions': 1,
      };
      final stats = OrgStatsModel.fromJson(json);
      expect(stats.totalFacilities, 3);
      expect(stats.totalStaff, 24);
      expect(stats.totalPatients, 1240);
      expect(stats.activeSubscriptions, 1);
    });
  });

  group('UpdateOrganizationRequest.toJson', () {
    test('omits null fields', () {
      final req = UpdateOrganizationRequest(name: 'New Name', address: null);
      final json = req.toJson();
      expect(json.containsKey('name'), isTrue);
      expect(json.containsKey('address'), isFalse);
    });

    test('includes all provided fields', () {
      final req = UpdateOrganizationRequest(
        name: 'CityHealth', type: 'hospital_group',
        address: '123 Main', phone: '+234800',
        email: 'a@b.com', taxId: 'TIN-123',
        billingEmail: 'billing@b.com', billingAddress: '123 Main',
      );
      final json = req.toJson();
      expect(json['name'], 'CityHealth');
      expect(json['type'], 'hospital_group');
      expect(json['tax_id'], 'TIN-123');
      expect(json['billing_email'], 'billing@b.com');
    });
  });

  group('FacilityStaffMemberModel.fromJson', () {
    test('parses user fields and capabilities', () {
      final json = {
        'id': 'mem-1',
        'staff_type': 'doctor',
        'is_active': true,
        'clinical_rank': {
          'id': 'rank-1',
          'name': 'Consultant',
          'hierarchy_level': 800,
          'can_prescribe': true,
          'can_order_labs': true,
          'can_approve_access_grants': true,
          'can_perform_emergency_access': true,
        },
        'user': {
          'id': 'user-1',
          'first_name': 'Jane',
          'last_name': 'Smith',
          'email': 'jane@clinic.com',
        },
      };
      final member = FacilityStaffMemberModel.fromJson(json);
      expect(member.membershipId, 'mem-1');
      expect(member.staffType, 'doctor');
      expect(member.isActive, isTrue);
      expect(member.fullName, 'Jane Smith');
      expect(member.email, 'jane@clinic.com');
      expect(member.clinicalRank?.canPrescribe, isTrue);
    });

    test('handles missing clinical_rank', () {
      final json = {
        'id': 'mem-2',
        'staff_type': 'admin',
        'is_active': true,
        'user': {'id': 'u2', 'first_name': 'Bob', 'last_name': 'Jones', 'email': 'bob@c.com'},
      };
      final member = FacilityStaffMemberModel.fromJson(json);
      expect(member.clinicalRank, isNull);
      expect(member.initials, 'BJ');
    });
  });
}
```

- [ ] **Step 2: Run tests — expect them to fail (models don't exist yet)**

```bash
flutter test test/organization/org_models_test.dart
```

Expected: FAIL — `OrgStatsModel`, `UpdateOrganizationRequest`, `FacilityStaffMemberModel` not defined.

- [ ] **Step 3: Add `OrgStatsModel` and `UpdateOrganizationRequest` to `organization_models_enhanced.dart`**

Append to the end of `lib/data/models/organization_models_enhanced.dart`:

```dart
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
```

- [ ] **Step 4: Run build_runner to regenerate `organization_models_enhanced.g.dart`**

```bash
dart run build_runner build --delete-conflicting-outputs
```

Expected: `organization_models_enhanced.g.dart` regenerated with no errors.

- [ ] **Step 5: Add `FacilityStaffMemberModel` to `auth_models.dart`**

Append to the end of `lib/data/models/auth_models.dart`:

```dart
// ─────────────────────────────────────────────────────────────────────────────
// FacilityStaffMemberModel — one entry from GET /staff/memberships list
// Used by StaffManagementScreen to show and edit facility staff.
// ─────────────────────────────────────────────────────────────────────────────

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
      'doctor': 'Doctor', 'nurse': 'Nurse', 'pharmacist': 'Pharmacist',
      'lab_tech': 'Lab Technician', 'radiologist': 'Radiologist',
      'physiotherapist': 'Physiotherapist', 'dentist': 'Dentist',
      'admin': 'Administrator', 'other': 'Healthcare Professional',
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
```

- [ ] **Step 6: Run tests — expect them to pass**

```bash
flutter test test/organization/org_models_test.dart
```

Expected: all PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/data/models/organization_models_enhanced.dart \
        lib/data/models/organization_models_enhanced.g.dart \
        lib/data/models/auth_models.dart \
        test/organization/org_models_test.dart
git commit -m "feat: add OrgStatsModel, UpdateOrganizationRequest, FacilityStaffMemberModel"
```

---

## Task 3 — Repository additions: `OrganizationRepository` + new `StaffRepository`

**Files:**
- Modify: `lib/data/repositories/organization_repository.dart`
- Create: `lib/data/repositories/staff_repository.dart`
- Test: `test/organization/organization_repository_test.dart` (new file)

- [ ] **Step 1: Write failing repository tests**

```dart
// test/organization/organization_repository_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_emr_mobile/core/api/api_client.dart';
import 'package:healthcare_emr_mobile/data/repositories/organization_repository.dart';
import 'package:healthcare_emr_mobile/data/models/organization_models_enhanced.dart';

// Minimal fake ApiClient — only implements the methods used by OrganizationRepository.
class _FakeApiClient implements ApiClient {
  final Map<String, dynamic> Function(String path) getHandler;
  _FakeApiClient({required this.getHandler});

  @override
  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? queryParameters}) async =>
      getHandler(path);

  @override
  Future<Map<String, dynamic>> put(String path, {dynamic data}) async => {
    'success': true,
    'data': {'id': 'org-1', 'name': 'Updated', 'type': 'hospital', 'address': 'X',
              'subscription_status': 'active', 'max_facilities': 5, 'max_providers': 50}
  };

  // Unimplemented methods — tests only touch get/put.
  @override dynamic noSuchMethod(Invocation i) => throw UnimplementedError(i.memberName.toString());
}

void main() {
  group('OrganizationRepository.getOrgStats', () {
    test('returns OrgStatsModel on success', () async {
      final fake = _FakeApiClient(getHandler: (_) => {
        'success': true,
        'data': {'total_facilities': 3, 'total_staff': 12, 'total_patients': 500, 'active_subscriptions': 1},
      });
      final repo = OrganizationRepository(apiClient: fake as ApiClient);
      final stats = await repo.getOrgStats('org-1');
      expect(stats.totalFacilities, 3);
      expect(stats.totalPatients, 500);
    });

    test('throws on API failure', () async {
      final fake = _FakeApiClient(getHandler: (_) => {'success': false, 'message': 'Not found'});
      final repo = OrganizationRepository(apiClient: fake as ApiClient);
      expect(() => repo.getOrgStats('org-1'), throwsException);
    });
  });

  group('OrganizationRepository.updateOrganization', () {
    test('sends request and returns updated model', () async {
      final fake = _FakeApiClient(getHandler: (_) => {'success': true, 'data': {}});
      final repo = OrganizationRepository(apiClient: fake as ApiClient);
      final req = UpdateOrganizationRequest(name: 'Updated', type: 'hospital');
      final result = await repo.updateOrganization('org-1', req);
      expect(result.name, 'Updated');
    });
  });
}
```

- [ ] **Step 2: Run tests — expect FAIL (methods not defined)**

```bash
flutter test test/organization/organization_repository_test.dart
```

Expected: FAIL — `getOrgStats`, `updateOrganization` not defined on `OrganizationRepository`.

- [ ] **Step 3: Add three new methods to `OrganizationRepository`**

Append to `lib/data/repositories/organization_repository.dart` (inside the class, after `checkEmail`):

```dart
  Future<OrganizationEnhancedModel> getOrganization(String id) async {
    final response = await apiClient.get('/organizations/$id');
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to load organization');
    }
    return OrganizationEnhancedModel.fromJson(
      Map<String, dynamic>.from(response['data'] as Map),
    );
  }

  Future<OrgStatsModel> getOrgStats(String id) async {
    final response = await apiClient.get('/organizations/$id/stats');
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to load org stats');
    }
    return OrgStatsModel.fromJson(
      Map<String, dynamic>.from(response['data'] as Map),
    );
  }

  Future<OrganizationEnhancedModel> updateOrganization(
    String id,
    UpdateOrganizationRequest request,
  ) async {
    final response = await apiClient.put(
      '/organizations/$id',
      data: request.toJson(),
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to update organization');
    }
    return OrganizationEnhancedModel.fromJson(
      Map<String, dynamic>.from(response['data'] as Map),
    );
  }
```

Also add the missing import at the top of the file:

```dart
import '../models/organization_models_enhanced.dart';
```

- [ ] **Step 4: Run tests — expect PASS**

```bash
flutter test test/organization/organization_repository_test.dart
```

Expected: all PASS.

- [ ] **Step 5: Create `StaffRepository`**

```dart
// lib/data/repositories/staff_repository.dart
import '../../../core/api/api_client.dart';
import '../models/auth_models.dart';

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
      if (staffType != null) 'staff_type': staffType,
      if (clinicalRankId != null) 'clinical_rank_id': clinicalRankId,
      if (isActive != null) 'is_active': isActive,
    };
    final response = await apiClient.put('/staff/memberships/$membershipId', data: data);
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
        .map((e) => ClinicalRankModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}
```

- [ ] **Step 6: Run analyze**

```bash
flutter analyze lib/data/repositories/
```

Expected: no errors.

- [ ] **Step 7: Commit**

```bash
git add lib/data/repositories/organization_repository.dart \
        lib/data/repositories/staff_repository.dart \
        test/organization/organization_repository_test.dart
git commit -m "feat: add org and staff repository methods"
```

---

## Task 4 — Navigation: admin section in drawer and More tab, Facilities wired

**Files:**
- Modify: `lib/presentation/dashboard/screens/provider_dashboard_screen.dart`
- Modify: `lib/presentation/more/more_screen.dart`

This task restructures the drawer's current `if (showAdminItems)` block (which hides Subscription and Reports from non-admins) and adds the four admin entries. Subscription and Reports become always-visible in Account for all staff.

- [ ] **Step 1: Update `_buildDrawer` in `provider_dashboard_screen.dart`**

Add imports at the top of the file:

```dart
import '../../facilities/screens/facilities_list_screen.dart';
```

Replace the current `if (showAdminItems) ...[Subscription, Reports]` block and surrounding Account items with:

```dart
              // ── Admin section (org admins only) ────────────────────────
              if (isOrgAdmin) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text('ADMIN',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: Colors.orange.shade700)),
                ),
                ListTile(
                  leading: Icon(Icons.business, color: Colors.orange.shade700),
                  title: const Text('Organization'),
                  onTap: () {
                    Navigator.of(context).pop();
                    // OrganizationProfileScreen added in Task 7
                  },
                ),
                ListTile(
                  leading: Icon(Icons.local_hospital_outlined,
                      color: Colors.orange.shade700),
                  title: const Text('Facilities'),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const FacilitiesListScreen()));
                  },
                ),
                ListTile(
                  leading: Icon(Icons.group_outlined,
                      color: Colors.orange.shade700),
                  title: const Text('Staff'),
                  onTap: () {
                    Navigator.of(context).pop();
                    // StaffManagementScreen added in Task 8
                  },
                ),
                ListTile(
                  leading: Icon(Icons.mail_outline,
                      color: Colors.orange.shade700),
                  title: const Text('Invite Staff'),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const ProviderInvitationScreen()));
                  },
                ),
              ],
              // ── Account section (all staff) ────────────────────────────
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text('ACCOUNT',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: Colors.grey.shade600)),
              ),
              ListTile(
                leading: const Icon(Icons.subscriptions),
                title: const Text('Subscription'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const SubscriptionDetailsScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.analytics_outlined),
                title: const Text('Reports & Compliance'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const ReportingScreen()));
                },
              ),
```

Also add the missing import for `ProviderInvitationScreen`:

```dart
import '../../providers/screens/provider_invitation_screen.dart';
```

- [ ] **Step 2: Update `MoreScreen` with admin section**

In `lib/presentation/more/more_screen.dart`, add these imports:

```dart
import '../facilities/screens/facilities_list_screen.dart';
import '../providers/screens/provider_invitation_screen.dart';
```

Insert a new `CupertinoListSection.insetGrouped` block for Admin, between the existing Clinical and Account sections:

```dart
            if (auth.isOrgAdmin)
              CupertinoListSection.insetGrouped(
                header: Text('Admin',
                    style: TextStyle(
                        color: CupertinoColors.systemOrange.resolveFrom(context))),
                children: [
                  CupertinoListTile(
                    leading: const Icon(CupertinoIcons.building_2_fill,
                        color: CupertinoColors.systemOrange),
                    title: const Text('Organization'),
                    trailing: const CupertinoListTileChevron(),
                    onTap: () {}, // OrganizationProfileScreen added in Task 7
                  ),
                  CupertinoListTile(
                    leading: const Icon(CupertinoIcons.house_fill,
                        color: CupertinoColors.systemOrange),
                    title: const Text('Facilities'),
                    trailing: const CupertinoListTileChevron(),
                    onTap: () => _push(context, const FacilitiesListScreen()),
                  ),
                  CupertinoListTile(
                    leading: const Icon(CupertinoIcons.group,
                        color: CupertinoColors.systemOrange),
                    title: const Text('Staff'),
                    trailing: const CupertinoListTileChevron(),
                    onTap: () {}, // StaffManagementScreen added in Task 8
                  ),
                  CupertinoListTile(
                    leading: const Icon(CupertinoIcons.mail,
                        color: CupertinoColors.systemOrange),
                    title: const Text('Invite Staff'),
                    trailing: const CupertinoListTileChevron(),
                    onTap: () => _push(context, const ProviderInvitationScreen()),
                  ),
                ],
              ),
```

- [ ] **Step 3: Run analyze and smoke-test**

```bash
flutter analyze
flutter run  # verify drawer renders admin section for org_admin user
```

Expected: no errors, admin section visible only for org_admin users.

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/dashboard/screens/provider_dashboard_screen.dart \
        lib/presentation/more/more_screen.dart
git commit -m "feat: add admin nav section with facilities wiring"
```

---

## Task 5 — Rewrite `ProviderInvitationScreen`

> ⚠️ **Merge gate:** This screen's PR cannot merge beyond local dev until the backend adds an admin check to `StaffRegistrationController::invite()`. File a backend ticket and link it to this PR before merging to staging.

**Files:**
- Rewrite: `lib/presentation/providers/screens/provider_invitation_screen.dart`

- [ ] **Step 1: Replace the file entirely**

```dart
// lib/presentation/providers/screens/provider_invitation_screen.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/api/api_client.dart';
import '../../../core/platform.dart';
import '../../../config/theme.dart';
import '../../../data/models/auth_models.dart';
import '../../../data/repositories/staff_repository.dart';
import '../../../data/providers/auth_provider.dart';

class ProviderInvitationScreen extends StatefulWidget {
  const ProviderInvitationScreen({super.key});

  @override
  State<ProviderInvitationScreen> createState() =>
      _ProviderInvitationScreenState();
}

class _ProviderInvitationScreenState extends State<ProviderInvitationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  late final StaffRepository _repo;

  static const _staffTypes = [
    ('doctor', 'Doctor'), ('nurse', 'Nurse'), ('pharmacist', 'Pharmacist'),
    ('lab_tech', 'Lab Technician'), ('radiologist', 'Radiologist'),
    ('physiotherapist', 'Physiotherapist'), ('dentist', 'Dentist'),
    ('admin', 'Administrator'), ('other', 'Other'),
  ];

  String _selectedStaffType = 'doctor';
  String? _selectedRankId;
  List<ClinicalRankModel> _ranks = [];
  bool _ranksLoading = true;
  bool _submitting = false;
  String? _rankError;

  @override
  void initState() {
    super.initState();
    _repo = StaffRepository(apiClient: context.read<ApiClient>());
    _loadRanks();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadRanks() async {
    try {
      final ranks = await _repo.getClinicalRanks();
      if (mounted) setState(() { _ranks = ranks; _ranksLoading = false; });
    } catch (e) {
      if (mounted) {
        setState(() { _ranksLoading = false; _rankError = e.toString(); });
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRankId == null) {
      showAdaptiveToast(context, 'Please select a clinical rank', type: ToastType.error);
      return;
    }
    setState(() => _submitting = true);
    try {
      await context.read<ApiClient>().post('/staff/invite', data: {
        'email': _emailController.text.trim(),
        'staff_type': _selectedStaffType,
        'clinical_rank_id': _selectedRankId,
      });
      if (mounted) {
        showAdaptiveToast(
          context,
          'Invitation sent to ${_emailController.text.trim()}',
          type: ToastType.success,
        );
        _emailController.clear();
        setState(() { _selectedStaffType = 'doctor'; _selectedRankId = null; });
      }
    } catch (e) {
      if (mounted) {
        showAdaptiveToast(context, e.toString(), type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final facilityName = context.read<AuthProvider>().facilityName;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invite Staff'),
        actions: [
          if (_submitting)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            )
          else
            TextButton(
              onPressed: _submit,
              child: const Text('Send', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Facility banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
              ),
              child: Row(children: [
                Icon(Icons.local_hospital_outlined,
                    size: 18, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Inviting to: $facilityName',
                    style: TextStyle(
                        color: AppTheme.primaryColor, fontWeight: FontWeight.w600),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 20),

            // Email
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email address *',
                hintText: 'staff@clinic.com',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Email is required';
                if (!v.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Staff type
            DropdownButtonFormField<String>(
              value: _selectedStaffType,
              decoration: const InputDecoration(labelText: 'Staff type *'),
              items: _staffTypes
                  .map((t) => DropdownMenuItem(value: t.$1, child: Text(t.$2)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedStaffType = v!),
            ),
            const SizedBox(height: 20),

            // Clinical rank selector
            Text('Clinical rank *',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            if (_ranksLoading)
              const Center(child: CircularProgressIndicator())
            else if (_rankError != null)
              Text('Failed to load ranks: $_rankError',
                  style: const TextStyle(color: Colors.red))
            else
              ..._ranks.map((rank) => _RankCard(
                rank: rank,
                selected: _selectedRankId == rank.id,
                onTap: () => setState(() => _selectedRankId = rank.id),
              )),
          ],
        ),
      ),
    );
  }
}

class _RankCard extends StatelessWidget {
  final ClinicalRankModel rank;
  final bool selected;
  final VoidCallback onTap;

  const _RankCard({required this.rank, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryColor.withOpacity(0.06) : Colors.white,
          border: Border.all(
            color: selected ? AppTheme.primaryColor : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(rank.name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Text('Level ${rank.hierarchyLevel}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  ]),
                  const SizedBox(height: 6),
                  Wrap(spacing: 4, runSpacing: 4, children: [
                    if (rank.canPrescribe) _CapChip('Can Prescribe', Colors.purple),
                    if (rank.canOrderLabs) _CapChip('Can Order Labs', Colors.orange),
                    if (rank.canPerformEmergencyAccess)
                      _CapChip('Emergency Access', Colors.red),
                  ]),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle, color: AppTheme.primaryColor, size: 20),
          ],
        ),
      ),
    );
  }
}

class _CapChip extends StatelessWidget {
  final String label;
  final Color color;
  const _CapChip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: color)),
    );
  }
}
```

- [ ] **Step 2: Run analyze**

```bash
flutter analyze lib/presentation/providers/
```

Expected: no errors.

- [ ] **Step 3: Smoke-test manually**

Run app as an org_admin user, tap "Invite Staff" from drawer. Verify:
- Facility banner shows correct facility name
- Email and staff type fields present
- Clinical ranks load from API and render as selectable cards
- Submitting calls `POST /staff/invite` (check network tab or server logs)

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/providers/screens/provider_invitation_screen.dart
git commit -m "feat: rewrite invite staff screen to match POST /staff/invite API"
```

---

## Task 6 — New `OrganizationProfileScreen`

> Backend 403 enforcement confirmed ✓.

**Files:**
- Create: `lib/presentation/organization/screens/organization_profile_screen.dart`
- Modify: `lib/presentation/dashboard/screens/provider_dashboard_screen.dart` (wire nav entry)
- Modify: `lib/presentation/more/more_screen.dart` (wire nav entry)

- [ ] **Step 1: Create directory and screen file**

```dart
// lib/presentation/organization/screens/organization_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/api/api_client.dart';
import '../../../config/theme.dart';
import '../../../data/models/organization_models_enhanced.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/repositories/organization_repository.dart';

class OrganizationProfileScreen extends StatefulWidget {
  final OrganizationRepository repository;
  const OrganizationProfileScreen({required this.repository, super.key});

  @override
  State<OrganizationProfileScreen> createState() =>
      _OrganizationProfileScreenState();
}

class _OrganizationProfileScreenState extends State<OrganizationProfileScreen> {
  OrganizationEnhancedModel? _org;
  OrgStatsModel? _stats;
  bool _loading = true;
  bool _statsError = false;
  String? _loadError;
  bool _isEditing = false;
  bool _saving = false;

  // Edit controllers
  late final TextEditingController _nameCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _taxIdCtrl;
  late final TextEditingController _billingEmailCtrl;
  late final TextEditingController _billingAddressCtrl;
  String? _selectedType;
  final _formKey = GlobalKey<FormState>();

  static const _orgTypes = [
    ('hospital', 'Hospital'), ('clinic', 'Clinic'), ('pharmacy', 'Pharmacy'),
    ('laboratory', 'Laboratory'), ('diagnostic_center', 'Diagnostic Center'),
    ('hospital_group', 'Hospital Group'), ('other', 'Other'),
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _addressCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _taxIdCtrl = TextEditingController();
    _billingEmailCtrl = TextEditingController();
    _billingAddressCtrl = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _addressCtrl, _phoneCtrl, _emailCtrl,
                     _taxIdCtrl, _billingEmailCtrl, _billingAddressCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final orgId = context.read<AuthProvider>().organizationId;
    if (orgId == null) {
      setState(() { _loading = false; _loadError = 'No organisation found'; });
      return;
    }

    setState(() { _loading = true; _loadError = null; _statsError = false; });

    final results = await Future.wait([
      widget.repository.getOrganization(orgId).then((v) => (org: v, err: null))
          .catchError((e) => (org: null, err: e.toString())),
      widget.repository.getOrgStats(orgId).then((v) => (stats: v, err: null))
          .catchError((e) => (stats: null, err: e.toString())),
    ]);

    final orgResult = results[0] as ({OrganizationEnhancedModel? org, String? err});
    final statsResult = results[1] as ({OrgStatsModel? stats, String? err});

    if (!mounted) return;

    if (orgResult.org == null) {
      setState(() { _loading = false; _loadError = orgResult.err; });
      return;
    }

    _populateControllers(orgResult.org!);
    setState(() {
      _org = orgResult.org;
      _stats = statsResult.stats;
      _statsError = statsResult.stats == null;
      _loading = false;
    });
  }

  void _populateControllers(OrganizationEnhancedModel org) {
    _nameCtrl.text = org.name;
    _addressCtrl.text = org.address;
    _phoneCtrl.text = org.phone ?? '';
    _emailCtrl.text = org.email ?? '';
    _taxIdCtrl.text = org.taxId ?? '';
    _billingEmailCtrl.text = org.billingEmail ?? '';
    _billingAddressCtrl.text = org.billingAddress ?? '';
    _selectedType = org.type;
  }

  void _cancelEdit() {
    _populateControllers(_org!);
    setState(() => _isEditing = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final updated = await widget.repository.updateOrganization(
        _org!.id,
        UpdateOrganizationRequest(
          name: _nameCtrl.text.trim(),
          type: _selectedType,
          address: _addressCtrl.text.trim(),
          phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
          taxId: _taxIdCtrl.text.trim().isEmpty ? null : _taxIdCtrl.text.trim(),
          billingEmail: _billingEmailCtrl.text.trim().isEmpty ? null : _billingEmailCtrl.text.trim(),
          billingAddress: _billingAddressCtrl.text.trim().isEmpty ? null : _billingAddressCtrl.text.trim(),
        ),
      );
      if (mounted) setState(() { _org = updated; _isEditing = false; });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Organization'),
        actions: [
          if (_loading || _org == null) const SizedBox.shrink()
          else if (_isEditing) ...[
            TextButton(
              onPressed: _cancelEdit,
              child: const Text('Cancel', style: TextStyle(color: Colors.white)),
            ),
            if (_saving)
              const Padding(padding: EdgeInsets.all(14),
                  child: SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
            else
              TextButton(
                onPressed: _save,
                child: const Text('Save',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
          ] else
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => setState(() => _isEditing = true),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? _ErrorView(message: _loadError!, onRetry: _load)
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final org = _org!;
    return Form(
      key: _formKey,
      child: ListView(
        children: [
          _StatsHeader(org: org, stats: _stats, statsError: _statsError),
          const SizedBox(height: 8),
          _SectionCard(
            title: 'Organization Details',
            editing: _isEditing,
            children: [
              _FieldRow(label: 'Name', controller: _nameCtrl,
                  editing: _isEditing, required: true),
              if (_isEditing) _TypeDropdown(
                value: _selectedType,
                types: _orgTypes,
                onChanged: (v) => setState(() => _selectedType = v),
              ) else _ReadRow(label: 'Type',
                  value: _orgTypes.firstWhere((t) => t.$1 == org.type,
                      orElse: () => (org.type, org.type)).$2),
              _FieldRow(label: 'Address', controller: _addressCtrl,
                  editing: _isEditing, required: true),
              _FieldRow(label: 'Phone', controller: _phoneCtrl,
                  editing: _isEditing),
              _FieldRow(label: 'Email', controller: _emailCtrl,
                  editing: _isEditing),
              _FieldRow(label: 'Tax ID', controller: _taxIdCtrl,
                  editing: _isEditing),
            ],
          ),
          _SectionCard(
            title: 'Billing',
            editing: _isEditing,
            children: [
              _FieldRow(label: 'Billing Email', controller: _billingEmailCtrl,
                  editing: _isEditing),
              _FieldRow(label: 'Billing Address', controller: _billingAddressCtrl,
                  editing: _isEditing),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────

class _StatsHeader extends StatelessWidget {
  final OrganizationEnhancedModel org;
  final OrgStatsModel? stats;
  final bool statsError;
  const _StatsHeader({required this.org, this.stats, required this.statsError});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(org.name,
              style: const TextStyle(color: Colors.white, fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(org.type,
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 16),
          Row(children: [
            _StatTile(
              label: 'Facilities',
              value: statsError ? '—' : '${stats?.totalFacilities ?? '—'}',
            ),
            const SizedBox(width: 8),
            _StatTile(
              label: 'Staff',
              value: statsError ? '—' : '${stats?.totalStaff ?? '—'}',
            ),
            const SizedBox(width: 8),
            _StatTile(
              label: 'Patients',
              value: statsError ? '—' : '${stats?.totalPatients ?? '—'}',
              warning: statsError,
            ),
          ]),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final bool warning;
  const _StatTile({required this.label, required this.value, this.warning = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(value, style: const TextStyle(color: Colors.white,
                fontSize: 18, fontWeight: FontWeight.bold)),
            if (warning) const SizedBox(width: 4),
            if (warning) const Icon(Icons.warning_amber, size: 14,
                color: Colors.white70),
          ]),
          Text(label, style: const TextStyle(color: Colors.white70,
              fontSize: 11)),
        ]),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final bool editing;
  const _SectionCard({required this.title, required this.children, required this.editing});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            decoration: BoxDecoration(
              color: editing
                  ? AppTheme.primaryColor.withOpacity(0.08)
                  : Colors.grey.shade50,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Text(title.toUpperCase(),
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: editing ? AppTheme.primaryColor : Colors.grey.shade600)),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool editing;
  final bool required;
  const _FieldRow({required this.label, required this.controller,
      required this.editing, this.required = false});

  @override
  Widget build(BuildContext context) {
    if (!editing) {
      return _ReadRow(label: label, value: controller.text);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          isDense: true,
        ),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? '$label is required' : null
            : null,
      ),
    );
  }
}

class _ReadRow extends StatelessWidget {
  final String label;
  final String value;
  const _ReadRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        const SizedBox(height: 2),
        Text(value.isEmpty ? '—' : value,
            style: const TextStyle(fontSize: 14)),
        const Divider(height: 14),
      ]),
    );
  }
}

class _TypeDropdown extends StatelessWidget {
  final String? value;
  final List<(String, String)> types;
  final ValueChanged<String?> onChanged;
  const _TypeDropdown({this.value, required this.types, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: const InputDecoration(labelText: 'Type *', isDense: true),
        items: types.map((t) => DropdownMenuItem(value: t.$1, child: Text(t.$2))).toList(),
        onChanged: onChanged,
        validator: (v) => v == null ? 'Type is required' : null,
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline, size: 48, color: Colors.red),
      const SizedBox(height: 12),
      Text(message, textAlign: TextAlign.center),
      const SizedBox(height: 16),
      ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
    ]));
  }
}
```

- [ ] **Step 2: Wire into drawer and More tab**

In `lib/presentation/dashboard/screens/provider_dashboard_screen.dart`, add import:

```dart
import '../../organization/screens/organization_profile_screen.dart';
```

Replace the placeholder `onTap: () {}` on the Organization drawer entry with:

```dart
onTap: () {
  Navigator.of(context).pop();
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => OrganizationProfileScreen(
      repository: OrganizationRepository(apiClient: context.read<ApiClient>()),
    ),
  ));
},
```

In `lib/presentation/more/more_screen.dart`, add import:

```dart
import '../organization/screens/organization_profile_screen.dart';
import '../../data/repositories/organization_repository.dart';
```

Replace the Organization `onTap: () {}` with:

```dart
onTap: () => _push(context, OrganizationProfileScreen(
  repository: OrganizationRepository(apiClient: context.read<ApiClient>()),
)),
```

- [ ] **Step 3: Run analyze**

```bash
flutter analyze lib/presentation/organization/
```

Expected: no errors.

- [ ] **Step 4: Smoke-test**

Run as org_admin, open Organization from drawer. Verify:
- Stats header shows Facilities / Staff / Patients counts (or `—` on stats failure)
- Details and Billing cards show correct read-only data
- Edit mode enables all fields; Cancel reverts to original values
- Save calls `PUT /organizations/{id}` and updates the view

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/organization/ \
        lib/presentation/dashboard/screens/provider_dashboard_screen.dart \
        lib/presentation/more/more_screen.dart
git commit -m "feat: add organization profile screen with inline edit"
```

---

## Task 7 — New `StaffManagementScreen`

**Files:**
- Create: `lib/presentation/staff/screens/staff_management_screen.dart`
- Modify: `lib/presentation/dashboard/screens/provider_dashboard_screen.dart` (wire)
- Modify: `lib/presentation/more/more_screen.dart` (wire)

- [ ] **Step 1: Create the screen**

```dart
// lib/presentation/staff/screens/staff_management_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/api/api_client.dart';
import '../../../config/theme.dart';
import '../../../data/models/auth_models.dart';
import '../../../data/repositories/staff_repository.dart';

class StaffManagementScreen extends StatefulWidget {
  final StaffRepository repository;
  const StaffManagementScreen({required this.repository, super.key});

  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  List<FacilityStaffMemberModel> _allStaff = [];
  List<ClinicalRankModel> _ranks = [];
  bool _loading = true;
  String? _error;
  String _searchQuery = '';
  String _typeFilter = 'all';
  String _statusFilter = 'active';
  bool _searchVisible = false;
  final _searchCtrl = TextEditingController();

  static const _staffTypeFilters = [
    ('all', 'All'), ('doctor', 'Doctor'), ('nurse', 'Nurse'),
    ('pharmacist', 'Pharmacist'), ('lab_tech', 'Lab Tech'),
    ('radiologist', 'Radiologist'), ('admin', 'Admin'), ('other', 'Other'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        widget.repository.getStaffMemberships(),
        widget.repository.getClinicalRanks(),
      ]);
      if (mounted) {
        setState(() {
          _allStaff = results[0] as List<FacilityStaffMemberModel>;
          _ranks = results[1] as List<ClinicalRankModel>;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  List<FacilityStaffMemberModel> get _filtered {
    return _allStaff.where((m) {
      if (_typeFilter != 'all' && m.staffType != _typeFilter) return false;
      if (_statusFilter == 'active' && !m.isActive) return false;
      if (_statusFilter == 'inactive' && m.isActive) return false;
      if (_searchQuery.length >= 2) {
        final q = _searchQuery.toLowerCase();
        if (!m.fullName.toLowerCase().contains(q) &&
            !m.email.toLowerCase().contains(q)) return false;
      }
      return true;
    }).toList();
  }

  void _openEditSheet(FacilityStaffMemberModel member) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _EditSheet(
        member: member,
        ranks: _ranks,
        repository: widget.repository,
        onSaved: (updated) {
          setState(() {
            final idx = _allStaff.indexWhere((m) => m.membershipId == updated.membershipId);
            if (idx >= 0) _allStaff[idx] = updated;
          });
        },
        onRemoved: (membershipId) {
          setState(() => _allStaff.removeWhere((m) => m.membershipId == membershipId));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: _searchVisible
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Search staff…',
                  hintStyle: TextStyle(color: Colors.white60),
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              )
            : const Text('Staff'),
        actions: [
          IconButton(
            icon: Icon(_searchVisible ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              _searchVisible = !_searchVisible;
              if (!_searchVisible) { _searchQuery = ''; _searchCtrl.clear(); }
            }),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(_error!),
                  const SizedBox(height: 12),
                  ElevatedButton(onPressed: _load, child: const Text('Retry')),
                ]))
              : Column(
                  children: [
                    // Type filter chips
                    SizedBox(
                      height: 44,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        children: _staffTypeFilters.map((f) {
                          final selected = _typeFilter == f.$1;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: FilterChip(
                              label: Text(f.$2),
                              selected: selected,
                              onSelected: (_) => setState(() => _typeFilter = f.$1),
                              selectedColor: AppTheme.primaryColor.withOpacity(0.2),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    // Status filter
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      child: Row(children: [
                        for (final s in [('active', 'Active'), ('inactive', 'Inactive'), ('all', 'All')])
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(s.$2),
                              selected: _statusFilter == s.$1,
                              onSelected: (_) => setState(() => _statusFilter = s.$1),
                              selectedColor: s.$1 == 'active'
                                  ? Colors.green.withOpacity(0.2)
                                  : s.$1 == 'inactive'
                                      ? Colors.red.withOpacity(0.2)
                                      : AppTheme.primaryColor.withOpacity(0.2),
                            ),
                          ),
                        const Spacer(),
                        Text('${filtered.length} members',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      ]),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _load,
                        child: filtered.isEmpty
                            ? const Center(child: Text('No staff found'))
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                itemCount: filtered.length,
                                itemBuilder: (_, i) => _StaffCard(
                                  member: filtered[i],
                                  onTap: () => _openEditSheet(filtered[i]),
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

// ── Staff card ──────────────────────────────────────────────────────────────

class _StaffCard extends StatelessWidget {
  final FacilityStaffMemberModel member;
  final VoidCallback onTap;
  const _StaffCard({required this.member, required this.onTap});

  Color get _avatarColor {
    const colors = {
      'doctor': Color(0xFF1565C0), 'nurse': Color(0xFF00695C),
      'pharmacist': Color(0xFF6A1B9A), 'lab_tech': Color(0xFFE65100),
      'admin': Color(0xFF37474F),
    };
    return colors[member.staffType] ?? const Color(0xFF546E7A);
  }

  @override
  Widget build(BuildContext context) {
    final rank = member.clinicalRank;
    return Opacity(
      opacity: member.isActive ? 1 : 0.6,
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          contentPadding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          leading: CircleAvatar(
            backgroundColor: _avatarColor,
            child: Text(member.initials,
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.bold)),
          ),
          title: Text(member.fullName,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('${member.displayStaffType} · ',
                  style: const TextStyle(fontSize: 12)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: member.isActive
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(member.isActive ? 'Active' : 'Inactive',
                    style: TextStyle(
                        fontSize: 10,
                        color: member.isActive ? Colors.green.shade700 : Colors.red.shade700)),
              ),
            ]),
            if (rank != null) ...[
              const SizedBox(height: 4),
              Wrap(spacing: 4, runSpacing: 2, children: [
                if (rank.canPrescribe)
                  _Chip('Rx', Colors.purple),
                if (rank.canOrderLabs)
                  _Chip('Labs', Colors.orange),
                if (rank.canPerformEmergencyAccess)
                  _Chip('Emergency', Colors.red),
              ]),
            ],
          ]),
          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
          onTap: onTap,
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, color: color)),
    );
  }
}

// ── Edit bottom sheet ───────────────────────────────────────────────────────

class _EditSheet extends StatefulWidget {
  final FacilityStaffMemberModel member;
  final List<ClinicalRankModel> ranks;
  final StaffRepository repository;
  final void Function(FacilityStaffMemberModel) onSaved;
  final void Function(String) onRemoved;

  const _EditSheet({
    required this.member,
    required this.ranks,
    required this.repository,
    required this.onSaved,
    required this.onRemoved,
  });

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late String _staffType;
  late String? _rankId;
  late bool _isActive;
  bool _saving = false;
  bool _removing = false;

  static const _staffTypes = [
    ('doctor', 'Doctor'), ('nurse', 'Nurse'), ('pharmacist', 'Pharmacist'),
    ('lab_tech', 'Lab Technician'), ('radiologist', 'Radiologist'),
    ('physiotherapist', 'Physiotherapist'), ('dentist', 'Dentist'),
    ('admin', 'Administrator'), ('other', 'Other'),
  ];

  @override
  void initState() {
    super.initState();
    _staffType = widget.member.staffType;
    _rankId = widget.member.clinicalRank?.id;
    _isActive = widget.member.isActive;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.repository.updateMembership(
        widget.member.membershipId,
        staffType: _staffType,
        clinicalRankId: _rankId,
        isActive: _isActive,
      );
      if (mounted) {
        final rank = widget.ranks.firstWhere(
            (r) => r.id == _rankId,
            orElse: () => widget.member.clinicalRank!);
        // Construct updated model from edited state for optimistic UI update.
        final updated = FacilityStaffMemberModel(
          membershipId: widget.member.membershipId,
          userId: widget.member.userId,
          firstName: widget.member.firstName,
          lastName: widget.member.lastName,
          email: widget.member.email,
          staffType: _staffType,
          isActive: _isActive,
          clinicalRank: _rankId != null ? rank : null,
        );
        widget.onSaved(updated);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _remove() async {
    final reasonCtrl = TextEditingController();
    String? reasonError;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Remove from Facility'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Remove ${widget.member.fullName} from this facility?'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Reason (required, min 10 chars)',
                errorText: reasonError,
              ),
            ),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () {
                final reason = reasonCtrl.text.trim();
                if (reason.length < 10) {
                  setS(() => reasonError = 'Reason must be at least 10 characters');
                  return;
                }
                Navigator.of(ctx).pop(true);
              },
              child: const Text('Remove'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    setState(() => _removing = true);
    try {
      await widget.repository.deleteMembership(
          widget.member.membershipId, reasonCtrl.text.trim());
      if (mounted) {
        widget.onRemoved(widget.member.membershipId);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _removing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, ctrl) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(children: [
          Container(width: 40, height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2))),
          Expanded(
            child: ListView(controller: ctrl, padding: const EdgeInsets.all(16), children: [
              // Header
              Row(children: [
                CircleAvatar(
                  backgroundColor: AppTheme.primaryColor,
                  child: Text(widget.member.initials,
                      style: const TextStyle(color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.member.fullName,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  Text(widget.member.email,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ]),
              ]),
              const Divider(height: 24),

              // Staff type
              DropdownButtonFormField<String>(
                value: _staffType,
                decoration: const InputDecoration(labelText: 'Staff Type'),
                items: _staffTypes
                    .map((t) => DropdownMenuItem(value: t.$1, child: Text(t.$2)))
                    .toList(),
                onChanged: (v) => setState(() => _staffType = v!),
              ),
              const SizedBox(height: 16),

              // Clinical rank
              const Text('Clinical Rank',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                      color: Colors.grey)),
              const SizedBox(height: 8),
              ...widget.ranks.map((rank) => GestureDetector(
                onTap: () => setState(() => _rankId = rank.id),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _rankId == rank.id
                        ? AppTheme.primaryColor.withOpacity(0.06) : Colors.white,
                    border: Border.all(
                      color: _rankId == rank.id
                          ? AppTheme.primaryColor : Colors.grey.shade300,
                      width: _rankId == rank.id ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(rank.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text('Level ${rank.hierarchyLevel}',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                      const SizedBox(height: 4),
                      Wrap(spacing: 4, children: [
                        if (rank.canPrescribe) _Chip2('Rx', Colors.purple),
                        if (rank.canOrderLabs) _Chip2('Labs', Colors.orange),
                        if (rank.canPerformEmergencyAccess) _Chip2('Emergency', Colors.red),
                      ]),
                    ])),
                    if (_rankId == rank.id)
                      Icon(Icons.check_circle, color: AppTheme.primaryColor),
                  ]),
                ),
              )),
              const SizedBox(height: 16),

              // Active toggle
              SwitchListTile(
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
                title: const Text('Active'),
                subtitle: const Text('Inactive staff can no longer log in'),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 16),

              // Save
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: _saving
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save Changes',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 8),

              // Remove
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _removing ? null : _remove,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _removing
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red))
                      : const Text('Remove from Facility'),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Chip2 extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip2(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(fontSize: 10, color: color)),
    );
  }
}
```

- [ ] **Step 2: Wire into drawer and More tab**

In `lib/presentation/dashboard/screens/provider_dashboard_screen.dart`, add import:

```dart
import '../../staff/screens/staff_management_screen.dart';
import '../../../data/repositories/staff_repository.dart';
```

Replace the Staff placeholder `onTap: () {}` with:

```dart
onTap: () {
  Navigator.of(context).pop();
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => StaffManagementScreen(
      repository: StaffRepository(apiClient: context.read<ApiClient>()),
    ),
  ));
},
```

In `lib/presentation/more/more_screen.dart`, add imports:

```dart
import '../staff/screens/staff_management_screen.dart';
import '../../data/repositories/staff_repository.dart';
```

Replace Staff `onTap: () {}` with:

```dart
onTap: () => _push(context, StaffManagementScreen(
  repository: StaffRepository(apiClient: context.read<ApiClient>()),
)),
```

- [ ] **Step 3: Run analyze**

```bash
flutter analyze lib/presentation/staff/
```

Expected: no errors.

- [ ] **Step 4: Smoke-test**

Run as org_admin, open Staff from drawer. Verify:
- Staff list loads (scoped to active facility via X-Tenant-ID)
- Type filter chips and Active/Inactive filter work client-side
- Tapping a staff card opens the edit sheet
- Save changes calls `PUT /staff/memberships/{id}`
- Remove from Facility requires a 10+ char reason; shows inline error if too short; calls `DELETE /staff/memberships/{id}` on confirm

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/staff/ \
        lib/presentation/dashboard/screens/provider_dashboard_screen.dart \
        lib/presentation/more/more_screen.dart \
        lib/data/repositories/staff_repository.dart
git commit -m "feat: add staff management screen with edit/remove bottom sheet"
```

---

## Self-Review Checklist

- [x] **Spec coverage** — All five deliverables implemented: auth gate (Task 1), navigation (Task 4), org profile (Task 6), invite staff (Task 5), staff management (Task 7), facilities wiring (Task 4). Repositories in Task 3.
- [x] **No placeholders** — Every step has actual code or exact shell commands.
- [x] **Type consistency** — `FacilityStaffMemberModel` defined in Task 2, used in Tasks 3 and 7. `OrgStatsModel`/`UpdateOrganizationRequest` defined in Task 2, used in Tasks 3 and 6. `StaffRepository` created in Task 3, constructor-injected in Tasks 5 and 7. `ClinicalRankModel` used throughout — already defined in `auth_models.dart`.
- [x] **API assumptions addressed** — `GET /staff/memberships` confirmed working via existing `FacilityRepository.listStaffAtCurrentTenant()`.
- [x] **Merge gate** — Task 5 (Invite Staff) carries explicit merge blocker comment referencing backend ticket requirement.
- [x] **Error degradation** — Org Profile parallel API failure handled: stats error degrades to `—` placeholders, org load error blocks screen.
- [x] **Reason field validation** — Delete membership dialog validates min 10 chars client-side before calling API.
- [x] **DI seam** — All new screens accept constructor-injected repositories; no `context.read` inside `StatefulWidget` constructors.
