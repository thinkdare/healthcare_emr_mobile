# Referrals Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a full cross-facility referrals feature — list screen, detail screen, inline messaging, and a create-referral sheet launched from the patient detail screen.

**Architecture:** `ReferralRepository` wraps 9 backend endpoints. `ReferralProvider` (ChangeNotifier) manages a single fetched list filtered client-side by `ReferralFilter`. `ReferralDetailScreen` shows clinical content, status timeline, role-based actions, and an inline message thread. `CreateReferralSheet` is launched from the patient detail app bar.

**Tech Stack:** Flutter, provider, Dio (via ApiClient), existing `AuthProvider.activeTenantId` for role computation, existing `showAdaptiveToast`/`showAdaptiveActionSheet` from `platform.dart`.

**Spec:** `docs/superpowers/specs/2026-05-17-referrals-screen-design.md`

**Pre-flight note:** `PatientModel.globalPatientId` (JSON key `global_patient_id`) is already returned by the backend and populated in the model. No backend changes are required — use `patient.globalPatientId` as `master_patient_id` when creating a referral.

---

## File Map

| Action | Path | Responsibility |
|---|---|---|
| Create | `lib/data/models/referral_models.dart` | ReferralModel, ReferralMessageModel, ReferralStatusHistoryModel, ReferralFilter enum |
| Create | `lib/data/repositories/referral_repository.dart` | All 9 API endpoints |
| Create | `lib/data/providers/referral_provider.dart` | Fetched list, client-side filter, write ops, pendingActionCount |
| Create | `lib/presentation/referrals/screens/referrals_screen.dart` | Filter chips + card list |
| Create | `lib/presentation/referrals/screens/referral_detail_screen.dart` | Header, clinical sections, status timeline, action bar |
| Create | `lib/presentation/referrals/widgets/referral_card.dart` | Single list item |
| Create | `lib/presentation/referrals/widgets/referral_message_thread.dart` | Inline chat view |
| Create | `lib/presentation/referrals/widgets/create_referral_sheet.dart` | DraggableScrollableSheet for creating a referral |
| Create | `test/referrals/referral_model_test.dart` | Unit tests for model parsing and computed properties |
| Modify | `lib/main.dart` | Add ReferralRepository + ReferralProvider to provider tree |
| Modify | `lib/presentation/more/more_screen.dart` | Add Referrals tile with pendingActionCount badge |
| Modify | `lib/presentation/patients/screens/patient_detail_screen.dart` | Add "Refer" icon button to app bar, gated on auth.isStaff |

---

## Task 1: Referral data models + unit tests

**Files:**
- Create: `lib/data/models/referral_models.dart`
- Create: `test/referrals/referral_model_test.dart`

- [ ] **Step 1: Write the failing tests**

```bash
mkdir -p /home/dh/Forge/sandbox/healthcare_emr_mobile/test/referrals
```

Create `test/referrals/referral_model_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_emr_mobile/data/models/referral_models.dart';

void main() {
  group('ReferralFilter', () {
    test('matches returns true for pending referral on pending filter', () {
      expect(
        ReferralFilter.pending.matches('pending'),
        isTrue,
      );
    });

    test('active filter matches accepted and scheduled', () {
      expect(ReferralFilter.active.matches('accepted'), isTrue);
      expect(ReferralFilter.active.matches('scheduled'), isTrue);
      expect(ReferralFilter.active.matches('pending'), isFalse);
    });

    test('done filter matches completed and cancelled', () {
      expect(ReferralFilter.done.matches('completed'), isTrue);
      expect(ReferralFilter.done.matches('cancelled'), isTrue);
      expect(ReferralFilter.done.matches('pending'), isFalse);
    });

    test('all filter matches any status', () {
      for (final s in ['pending', 'accepted', 'scheduled', 'completed', 'cancelled']) {
        expect(ReferralFilter.all.matches(s), isTrue);
      }
    });
  });

  group('ReferralModel', () {
    final baseJson = {
      'id': 'ref-1',
      'status': 'pending',
      'specialty': 'Cardiology',
      'urgency': 'urgent',
      'is_urgent': true,
      'is_overdue': false,
      'from_tenant': {'id': 'tenant-a', 'name': 'Lagos General'},
      'to_tenant': {'id': 'tenant-b', 'name': 'Abuja Specialist'},
      'referring_provider_id': 'user-1',
      'referring_provider': 'Dr. Adeyemi',
      'referred_to_provider_id': null,
      'referred_to_provider': null,
      'requires_follow_up': false,
      'referred_at': '2026-05-17T10:00:00.000Z',
      'created_at': '2026-05-17T10:00:00.000Z',
    };

    test('fromJson parses all required fields', () {
      final model = ReferralModel.fromJson(
        Map<String, dynamic>.from(baseJson),
        currentTenantId: 'tenant-a',
      );
      expect(model.id, 'ref-1');
      expect(model.status, 'pending');
      expect(model.specialty, 'Cardiology');
      expect(model.fromTenantName, 'Lagos General');
      expect(model.toTenantName, 'Abuja Specialist');
    });

    test('isSent true when currentTenantId matches fromTenantId', () {
      final model = ReferralModel.fromJson(
        Map<String, dynamic>.from(baseJson),
        currentTenantId: 'tenant-a',
      );
      expect(model.isSent, isTrue);
      expect(model.isReceived, isFalse);
    });

    test('isReceived true when currentTenantId matches toTenantId', () {
      final model = ReferralModel.fromJson(
        Map<String, dynamic>.from(baseJson),
        currentTenantId: 'tenant-b',
      );
      expect(model.isReceived, isTrue);
      expect(model.isSent, isFalse);
    });

    test('canAccept true only for receiving party with pending status', () {
      final model = ReferralModel.fromJson(
        Map<String, dynamic>.from(baseJson),
        currentTenantId: 'tenant-b',
      );
      expect(model.canAccept, isTrue);
      expect(model.canCancel, isFalse);
    });

    test('canCancel true only for sending party with open status', () {
      final model = ReferralModel.fromJson(
        Map<String, dynamic>.from(baseJson),
        currentTenantId: 'tenant-a',
      );
      expect(model.canCancel, isTrue);
      expect(model.canAccept, isFalse);
    });

    test('isOpen false for completed referral', () {
      final json = Map<String, dynamic>.from(baseJson)
        ..['status'] = 'completed';
      final model = ReferralModel.fromJson(json, currentTenantId: 'tenant-a');
      expect(model.isOpen, isFalse);
      expect(model.canCancel, isFalse);
    });
  });
}
```

- [ ] **Step 2: Run tests — verify they fail**

```bash
cd /home/dh/Forge/sandbox/healthcare_emr_mobile
flutter test test/referrals/referral_model_test.dart 2>&1 | tail -5
```

Expected: FAIL — `Target of URI doesn't exist: 'package:healthcare_emr_mobile/data/models/referral_models.dart'`

- [ ] **Step 3: Create the models**

Create `lib/data/models/referral_models.dart`:

```dart
// lib/data/models/referral_models.dart

enum ReferralFilter {
  all,
  pending,
  active, // accepted + scheduled
  done;   // completed + cancelled

  bool matches(String status) => switch (this) {
        ReferralFilter.all     => true,
        ReferralFilter.pending => status == 'pending',
        ReferralFilter.active  => status == 'accepted' || status == 'scheduled',
        ReferralFilter.done    => status == 'completed' || status == 'cancelled',
      };

  String get label => switch (this) {
        ReferralFilter.all     => 'All',
        ReferralFilter.pending => 'Pending',
        ReferralFilter.active  => 'Active',
        ReferralFilter.done    => 'Done',
      };
}

class ReferralStatusHistoryModel {
  final String? from;
  final String to;
  final String? changedBy;
  final String? reason;
  final String at;

  const ReferralStatusHistoryModel({
    this.from,
    required this.to,
    this.changedBy,
    this.reason,
    required this.at,
  });

  factory ReferralStatusHistoryModel.fromJson(Map<String, dynamic> json) =>
      ReferralStatusHistoryModel(
        from:      json['from'] as String?,
        to:        json['to'] as String,
        changedBy: json['changed_by'] as String?,
        reason:    json['reason'] as String?,
        at:        json['at'] as String,
      );
}

class ReferralMessageModel {
  final String id;
  final String senderId;
  final String senderName;
  final String message;
  final String createdAt;

  const ReferralMessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.message,
    required this.createdAt,
  });

  factory ReferralMessageModel.fromJson(Map<String, dynamic> json) =>
      ReferralMessageModel(
        id:        json['id'] as String,
        senderId:  json['sender_id'] as String,
        senderName: json['sender'] as String? ?? 'Unknown',
        message:   json['message'] as String,
        createdAt: json['created_at'] as String,
      );
}

class ReferralModel {
  final String id;
  final String status;
  final String specialty;
  final String urgency;
  final bool isUrgent;
  final bool isOverdue;
  final String? fromTenantId;
  final String fromTenantName;
  final String? toTenantId;
  final String toTenantName;
  final String referringProviderId;
  final String referringProviderName;
  final String? referredToProviderId;
  final String? referredToProviderName;
  final String? masterPatientId;
  final String? patientName;
  final String? patientDob;
  final String? patientGender;
  final String? reason;
  final String? clinicalSummary;
  final String? relevantHistory;
  final String? currentMedications;
  final String? diagnosticResults;
  final String? consultationNotes;
  final String? recommendations;
  final String? appointmentDate;
  final String? appointmentLocation;
  final bool requiresFollowUp;
  final String? followUpDate;
  final String referredAt;
  final String? acceptedAt;
  final String? scheduledAt;
  final String? completedAt;
  final String? cancelledAt;
  final List<ReferralStatusHistoryModel> statusHistory;

  // Role flags set at parse time from currentTenantId
  final bool isSent;
  final bool isReceived;

  const ReferralModel({
    required this.id,
    required this.status,
    required this.specialty,
    required this.urgency,
    required this.isUrgent,
    required this.isOverdue,
    this.fromTenantId,
    required this.fromTenantName,
    this.toTenantId,
    required this.toTenantName,
    required this.referringProviderId,
    required this.referringProviderName,
    this.referredToProviderId,
    this.referredToProviderName,
    this.masterPatientId,
    this.patientName,
    this.patientDob,
    this.patientGender,
    this.reason,
    this.clinicalSummary,
    this.relevantHistory,
    this.currentMedications,
    this.diagnosticResults,
    this.consultationNotes,
    this.recommendations,
    this.appointmentDate,
    this.appointmentLocation,
    required this.requiresFollowUp,
    this.followUpDate,
    required this.referredAt,
    this.acceptedAt,
    this.scheduledAt,
    this.completedAt,
    this.cancelledAt,
    required this.isSent,
    required this.isReceived,
    this.statusHistory = const [],
  });

  // Computed from model fields
  bool get isOpen    => !['completed', 'cancelled'].contains(status);
  bool get canAccept  => isReceived && status == 'pending';
  bool get canSchedule => isReceived && status == 'accepted';
  bool get canComplete => isReceived && status == 'scheduled';
  bool get canCancel   => isSent &&
      ['pending', 'accepted', 'scheduled'].contains(status);

  factory ReferralModel.fromJson(
    Map<String, dynamic> json, {
    required String currentTenantId,
  }) {
    final fromTenant = json['from_tenant'] as Map?;
    final toTenant   = json['to_tenant']   as Map?;
    final fromId = fromTenant?['id'] as String?;
    final toId   = toTenant?['id']   as String?;
    final patient = json['master_patient'] as Map?;

    List<ReferralStatusHistoryModel> history = [];
    final rawHistory = json['status_history'];
    if (rawHistory is List) {
      history = rawHistory
          .map((e) => ReferralStatusHistoryModel.fromJson(
                Map<String, dynamic>.from(e as Map),
              ))
          .toList();
    }

    return ReferralModel(
      id:                     json['id'] as String,
      status:                 json['status'] as String,
      specialty:              json['specialty'] as String,
      urgency:                json['urgency'] as String,
      isUrgent:               (json['is_urgent'] as bool?) ?? false,
      isOverdue:              (json['is_overdue'] as bool?) ?? false,
      fromTenantId:           fromId,
      fromTenantName:         fromTenant?['name'] as String? ?? '',
      toTenantId:             toId,
      toTenantName:           toTenant?['name'] as String? ?? '',
      referringProviderId:    json['referring_provider_id'] as String,
      referringProviderName:  json['referring_provider'] as String? ?? '',
      referredToProviderId:   json['referred_to_provider_id'] as String?,
      referredToProviderName: json['referred_to_provider'] as String?,
      masterPatientId:        patient?['id'] as String?,
      patientName:            patient?['name'] as String?,
      patientDob:             patient?['date_of_birth'] as String?,
      patientGender:          patient?['gender'] as String?,
      reason:                 json['reason'] as String?,
      clinicalSummary:        json['clinical_summary'] as String?,
      relevantHistory:        json['relevant_history'] as String?,
      currentMedications:     json['current_medications'] as String?,
      diagnosticResults:      json['diagnostic_results'] as String?,
      consultationNotes:      json['consultation_notes'] as String?,
      recommendations:        json['recommendations'] as String?,
      appointmentDate:        json['appointment_date'] as String?,
      appointmentLocation:    json['appointment_location'] as String?,
      requiresFollowUp:       (json['requires_follow_up'] as bool?) ?? false,
      followUpDate:           json['follow_up_date'] as String?,
      referredAt:             json['referred_at'] as String,
      acceptedAt:             json['accepted_at'] as String?,
      scheduledAt:            json['scheduled_at'] as String?,
      completedAt:            json['completed_at'] as String?,
      cancelledAt:            json['cancelled_at'] as String?,
      isSent:                 fromId == currentTenantId,
      isReceived:             toId == currentTenantId,
      statusHistory:          history,
    );
  }
}
```

- [ ] **Step 4: Run tests — verify they pass**

```bash
flutter test test/referrals/referral_model_test.dart 2>&1
```

Expected: `All tests passed!` (10 tests)

- [ ] **Step 5: Verify no analyzer issues**

```bash
flutter analyze lib/data/models/referral_models.dart 2>&1 | tail -3
```

Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/data/models/referral_models.dart test/referrals/referral_model_test.dart
git commit -m "feat: add referral data models with unit tests"
```

---

## Task 2: ReferralRepository

**Files:**
- Create: `lib/data/repositories/referral_repository.dart`

- [ ] **Step 1: Create the repository**

```dart
// lib/data/repositories/referral_repository.dart

import '../../core/api/api_client.dart';
import '../models/referral_models.dart';

class ReferralRepository {
  final ApiClient apiClient;
  final String Function() getTenantId;

  ReferralRepository({
    required this.apiClient,
    required this.getTenantId,
  });

  List<ReferralModel> _parse(List raw) => raw
      .map((e) => ReferralModel.fromJson(
            Map<String, dynamic>.from(e as Map),
            currentTenantId: getTenantId(),
          ))
      .toList();

  // ── GET /api/v1/referrals ─────────────────────────────────────────────────

  Future<List<ReferralModel>> list({int page = 1}) async {
    final response = await apiClient.get(
      '/referrals',
      queryParameters: {'page': page, 'per_page': 50},
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to load referrals');
    }
    // Response may be paginated — handle both shapes
    final data = response['data'];
    final raw = data is Map ? (data['data'] as List? ?? []) : (data as List? ?? []);
    return _parse(raw);
  }

  // ── GET /api/v1/referrals/{id} ────────────────────────────────────────────

  Future<ReferralModel> show(String id) async {
    final response = await apiClient.get('/referrals/$id');
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to load referral');
    }
    return ReferralModel.fromJson(
      Map<String, dynamic>.from(response['data'] as Map),
      currentTenantId: getTenantId(),
    );
  }

  // ── POST /api/v1/referrals ────────────────────────────────────────────────

  Future<ReferralModel> create(Map<String, dynamic> data) async {
    final response = await apiClient.post('/referrals', data: data);
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to create referral');
    }
    return ReferralModel.fromJson(
      Map<String, dynamic>.from(response['data'] as Map),
      currentTenantId: getTenantId(),
    );
  }

  // ── POST /api/v1/referrals/{id}/accept ───────────────────────────────────

  Future<ReferralModel> accept(String id) async {
    final response = await apiClient.post('/referrals/$id/accept');
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to accept referral');
    }
    return ReferralModel.fromJson(
      Map<String, dynamic>.from(response['data'] as Map),
      currentTenantId: getTenantId(),
    );
  }

  // ── POST /api/v1/referrals/{id}/schedule ─────────────────────────────────

  Future<ReferralModel> schedule(
      String id, String appointmentDate, String? location) async {
    final response = await apiClient.post('/referrals/$id/schedule', data: {
      'appointment_date': appointmentDate,
      if (location != null && location.isNotEmpty) 'appointment_location': location,
    });
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to schedule referral');
    }
    return ReferralModel.fromJson(
      Map<String, dynamic>.from(response['data'] as Map),
      currentTenantId: getTenantId(),
    );
  }

  // ── POST /api/v1/referrals/{id}/complete ─────────────────────────────────

  Future<ReferralModel> complete(
      String id, String notes, String? recommendations) async {
    final response = await apiClient.post('/referrals/$id/complete', data: {
      'consultation_notes': notes,
      if (recommendations != null && recommendations.isNotEmpty)
        'recommendations': recommendations,
    });
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to complete referral');
    }
    return ReferralModel.fromJson(
      Map<String, dynamic>.from(response['data'] as Map),
      currentTenantId: getTenantId(),
    );
  }

  // ── POST /api/v1/referrals/{id}/cancel ───────────────────────────────────

  Future<ReferralModel> cancel(String id, String reason) async {
    final response =
        await apiClient.post('/referrals/$id/cancel', data: {'reason': reason});
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to cancel referral');
    }
    return ReferralModel.fromJson(
      Map<String, dynamic>.from(response['data'] as Map),
      currentTenantId: getTenantId(),
    );
  }

  // ── GET /api/v1/referrals/{id}/messages ──────────────────────────────────

  Future<List<ReferralMessageModel>> getMessages(String id) async {
    final response = await apiClient.get('/referrals/$id/messages');
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to load messages');
    }
    final raw = response['data'] as List? ?? [];
    return raw
        .map((e) => ReferralMessageModel.fromJson(
              Map<String, dynamic>.from(e as Map),
            ))
        .toList();
  }

  // ── POST /api/v1/referrals/{id}/messages ─────────────────────────────────

  Future<ReferralMessageModel> sendMessage(String id, String message) async {
    final response = await apiClient.post(
      '/referrals/$id/messages',
      data: {'message': message},
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to send message');
    }
    return ReferralMessageModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map));
  }
}
```

- [ ] **Step 2: Verify it compiles**

```bash
flutter analyze lib/data/repositories/referral_repository.dart 2>&1 | tail -3
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/data/repositories/referral_repository.dart
git commit -m "feat: add ReferralRepository wrapping all 9 referral API endpoints"
```

---

## Task 3: ReferralProvider

**Files:**
- Create: `lib/data/providers/referral_provider.dart`

- [ ] **Step 1: Create the provider**

```dart
// lib/data/providers/referral_provider.dart

import 'package:flutter/foundation.dart';
import '../models/referral_models.dart';
import '../repositories/referral_repository.dart';

class ReferralProvider extends ChangeNotifier {
  final ReferralRepository repository;
  final String Function() getCurrentUserId;

  ReferralProvider({
    required this.repository,
    required this.getCurrentUserId,
  });

  // ── State ──────────────────────────────────────────────────────────────────

  List<ReferralModel> _all = [];
  ReferralFilter _filter = ReferralFilter.all;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  int _currentPage = 1;
  bool _hasMore = true;

  // Messages cache: referralId → messages
  final Map<String, List<ReferralMessageModel>> _messages = {};
  bool _isSendingMessage = false;

  // ── Getters ────────────────────────────────────────────────────────────────

  ReferralFilter get filter         => _filter;
  bool get isLoading                => _isLoading;
  bool get isLoadingMore            => _isLoadingMore;
  String? get error                 => _error;
  bool get isSendingMessage         => _isSendingMessage;

  List<ReferralModel> get referrals =>
      _all.where((r) => _filter.matches(r.status)).toList();

  // Badge count: referrals where current user is receiver and status is pending
  int get pendingActionCount =>
      _all.where((r) => r.isReceived && r.status == 'pending').length;

  List<ReferralMessageModel> messagesFor(String referralId) =>
      _messages[referralId] ?? [];

  // ── Load ───────────────────────────────────────────────────────────────────

  Future<void> loadReferrals({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
    }
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final fetched = await repository.list(page: _currentPage);
      if (refresh || _currentPage == 1) {
        _all = fetched;
      } else {
        _all = [..._all, ...fetched];
      }
      _hasMore = fetched.length >= 50;
    } catch (e) {
      _error = _friendly(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    _currentPage++;
    _isLoadingMore = true;
    notifyListeners();

    try {
      final fetched = await repository.list(page: _currentPage);
      _all = [..._all, ...fetched];
      _hasMore = fetched.length >= 50;
    } catch (_) {
      _currentPage--;
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  void setFilter(ReferralFilter f) {
    if (_filter == f) return;
    _filter = f;
    notifyListeners();
  }

  // ── Write ops ─────────────────────────────────────────────────────────────

  Future<ReferralModel?> create(Map<String, dynamic> data) async {
    try {
      final created = await repository.create(data);
      _all = [created, ..._all];
      notifyListeners();
      return created;
    } catch (e) {
      _error = _friendly(e);
      notifyListeners();
      return null;
    }
  }

  Future<bool> accept(String id) => _transition(id, () => repository.accept(id));

  Future<bool> schedule(String id, String date, String? location) =>
      _transition(id, () => repository.schedule(id, date, location));

  Future<bool> complete(String id, String notes, String? recs) =>
      _transition(id, () => repository.complete(id, notes, recs));

  Future<bool> cancel(String id, String reason) =>
      _transition(id, () => repository.cancel(id, reason));

  Future<bool> _transition(String id, Future<ReferralModel> Function() call) async {
    try {
      final updated = await call();
      _all = _all.map((r) => r.id == id ? updated : r).toList();
      notifyListeners();
      return true;
    } catch (e) {
      _error = _friendly(e);
      notifyListeners();
      return false;
    }
  }

  // ── Messages ──────────────────────────────────────────────────────────────

  Future<void> loadMessages(String referralId) async {
    try {
      final msgs = await repository.getMessages(referralId);
      _messages[referralId] = msgs;
      notifyListeners();
    } catch (e) {
      _error = _friendly(e);
      notifyListeners();
    }
  }

  Future<bool> sendMessage(String referralId, String message) async {
    _isSendingMessage = true;
    notifyListeners();
    try {
      final msg = await repository.sendMessage(referralId, message);
      _messages[referralId] = [...(_messages[referralId] ?? []), msg];
      _isSendingMessage = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _friendly(e);
      _isSendingMessage = false;
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  String _friendly(Object e) {
    final msg = e.toString();
    if (msg.contains('SocketException') || msg.contains('Connection')) {
      return 'No internet connection.';
    }
    if (msg.contains('401')) return 'Session expired. Please log in again.';
    if (msg.contains('403')) return 'You do not have permission to perform this action.';
    if (msg.contains('PATIENT_CONSENT_REQUIRED')) {
      return 'This patient has not enabled cross-facility data sharing.';
    }
    if (msg.contains('SAME_FACILITY')) return 'Cannot refer to your own facility.';
    if (msg.contains('RECEIVING_PROVIDER_NOT_CREDENTIALED')) {
      return 'That provider is not registered at the selected facility.';
    }
    if (msg.contains('INVALID_STATUS_TRANSITION')) {
      return 'This action is no longer available — the referral status has changed.';
    }
    if (msg.contains('REFERRAL_CLOSED')) {
      return 'Cannot send messages on a completed or cancelled referral.';
    }
    final match = RegExp(r'ApiException\(\d+\): (.+)').firstMatch(msg);
    if (match != null) return match.group(1)!;
    return msg.contains('Exception:') ? msg.split('Exception:').last.trim() : msg;
  }
}
```

- [ ] **Step 2: Verify it compiles**

```bash
flutter analyze lib/data/providers/referral_provider.dart 2>&1 | tail -3
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/data/providers/referral_provider.dart
git commit -m "feat: add ReferralProvider with filter, write ops, and message cache"
```

---

## Task 4: ReferralsScreen + ReferralCard

**Files:**
- Create: `lib/presentation/referrals/screens/referrals_screen.dart`
- Create: `lib/presentation/referrals/widgets/referral_card.dart`

- [ ] **Step 1: Create the directory structure**

```bash
mkdir -p /home/dh/Forge/sandbox/healthcare_emr_mobile/lib/presentation/referrals/screens
mkdir -p /home/dh/Forge/sandbox/healthcare_emr_mobile/lib/presentation/referrals/widgets
```

- [ ] **Step 2: Create `referral_card.dart`**

```dart
// lib/presentation/referrals/widgets/referral_card.dart

import 'package:flutter/material.dart';
import '../../../data/models/referral_models.dart';
import '../screens/referral_detail_screen.dart';

class ReferralCard extends StatelessWidget {
  final ReferralModel referral;

  const ReferralCard({super.key, required this.referral});

  @override
  Widget build(BuildContext context) {
    final r = referral;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ReferralDetailScreen(referral: r),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _RoleBadge(isSent: r.isSent),
                  const SizedBox(width: 8),
                  _UrgencyDot(urgency: r.urgency),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      r.patientName ?? 'Patient',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _StatusChip(status: r.status),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                r.isSent
                    ? '${r.specialty} · → ${r.toTenantName}'
                    : '${r.specialty} · ← ${r.fromTenantName}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    r.referringProviderName,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                  const Text(' · ',
                      style: TextStyle(fontSize: 11, color: Colors.grey)),
                  Text(
                    _relative(r.referredAt),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                  if (r.isOverdue) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.warning_amber_rounded,
                        size: 13, color: Colors.orange),
                    const Text(' Overdue',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.orange,
                            fontWeight: FontWeight.w500)),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _relative(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _RoleBadge extends StatelessWidget {
  final bool isSent;
  const _RoleBadge({required this.isSent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isSent
            ? Colors.purple.withValues(alpha: 0.12)
            : Colors.teal.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isSent ? 'SENT' : 'RECEIVED',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: isSent ? Colors.purple.shade700 : Colors.teal.shade700,
        ),
      ),
    );
  }
}

class _UrgencyDot extends StatelessWidget {
  final String urgency;
  const _UrgencyDot({required this.urgency});

  @override
  Widget build(BuildContext context) {
    final color = switch (urgency) {
      'emergency' => Colors.red,
      'urgent'    => Colors.orange,
      _           => Colors.grey.shade400,
    };
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = switch (status) {
      'pending'   => (const Color(0xFFFFF3E0), const Color(0xFFE65100), 'Pending'),
      'accepted'  => (const Color(0xFFE3F2FD), const Color(0xFF1565C0), 'Accepted'),
      'scheduled' => (const Color(0xFFE8F5E9), const Color(0xFF2E7D32), 'Scheduled'),
      'completed' => (const Color(0xFFF3E5F5), const Color(0xFF6A1B9A), 'Completed'),
      'cancelled' => (const Color(0xFFEEEEEE), const Color(0xFF616161), 'Cancelled'),
      _           => (const Color(0xFFEEEEEE), const Color(0xFF616161), status),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label,
          style:
              TextStyle(fontSize: 10, color: fg, fontWeight: FontWeight.w600)),
    );
  }
}
```

- [ ] **Step 3: Create `referrals_screen.dart`**

```dart
// lib/presentation/referrals/screens/referrals_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/platform.dart';
import '../../../data/models/referral_models.dart';
import '../../../data/providers/referral_provider.dart';
import '../widgets/referral_card.dart';

class ReferralsScreen extends StatefulWidget {
  const ReferralsScreen({super.key});

  @override
  State<ReferralsScreen> createState() => _ReferralsScreenState();
}

class _ReferralsScreenState extends State<ReferralsScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReferralProvider>().loadReferrals();
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<ReferralProvider>().loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    const title = 'Referrals';
    return kIsIOS
        ? CupertinoPageScaffold(
            navigationBar:
                const CupertinoNavigationBar(middle: Text(title)),
            child: SafeArea(child: _Body(scrollController: _scrollController)),
          )
        : Scaffold(
            appBar: AppBar(title: const Text(title)),
            body: _Body(scrollController: _scrollController),
          );
  }
}

class _Body extends StatelessWidget {
  final ScrollController scrollController;
  const _Body({required this.scrollController});

  @override
  Widget build(BuildContext context) {
    return Consumer<ReferralProvider>(
      builder: (context, provider, _) {
        return Column(
          children: [
            _FilterChips(provider: provider),
            if (provider.error != null)
              _ErrorBanner(
                message: provider.error!,
                onDismiss: provider.clearError,
              ),
            Expanded(
              child: provider.isLoading
                  ? Center(
                      child: kIsIOS
                          ? const CupertinoActivityIndicator()
                          : const CircularProgressIndicator(),
                    )
                  : RefreshIndicator(
                      onRefresh: () =>
                          provider.loadReferrals(refresh: true),
                      child: provider.referrals.isEmpty
                          ? _EmptyState(filter: provider.filter)
                          : ListView.builder(
                              controller: scrollController,
                              padding: const EdgeInsets.only(
                                  top: 8, bottom: 24),
                              itemCount: provider.referrals.length +
                                  (provider.isLoadingMore ? 1 : 0),
                              itemBuilder: (context, i) {
                                if (i == provider.referrals.length) {
                                  return const Padding(
                                    padding:
                                        EdgeInsets.symmetric(vertical: 16),
                                    child: Center(
                                        child:
                                            CircularProgressIndicator()),
                                  );
                                }
                                return ReferralCard(
                                    referral: provider.referrals[i]);
                              },
                            ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _FilterChips extends StatelessWidget {
  final ReferralProvider provider;
  const _FilterChips({required this.provider});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: ReferralFilter.values.map((f) {
          final selected = provider.filter == f;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(f.label),
              selected: selected,
              onSelected: (_) => provider.setFilter(f),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final ReferralFilter filter;
  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    final message = switch (filter) {
      ReferralFilter.all     => 'No referrals yet. Refer a patient from their profile.',
      ReferralFilter.pending => 'No pending referrals.',
      ReferralFilter.active  => 'No active referrals.',
      ReferralFilter.done    => 'No completed or cancelled referrals.',
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600)),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;
  const _ErrorBanner({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.red.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 16, color: Colors.red.shade700),
          const SizedBox(width: 8),
          Expanded(
              child: Text(message,
                  style:
                      TextStyle(fontSize: 12, color: Colors.red.shade700))),
          IconButton(
              icon: const Icon(Icons.close, size: 16),
              onPressed: onDismiss),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Verify both files compile**

```bash
flutter analyze lib/presentation/referrals/screens/referrals_screen.dart lib/presentation/referrals/widgets/referral_card.dart 2>&1 | tail -3
```

Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/referrals/screens/referrals_screen.dart lib/presentation/referrals/widgets/referral_card.dart
git commit -m "feat: add ReferralsScreen with filter chips and ReferralCard"
```

---

## Task 5: ReferralDetailScreen + ReferralMessageThread

**Files:**
- Create: `lib/presentation/referrals/screens/referral_detail_screen.dart`
- Create: `lib/presentation/referrals/widgets/referral_message_thread.dart`

- [ ] **Step 1: Create `referral_message_thread.dart`**

```dart
// lib/presentation/referrals/widgets/referral_message_thread.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/referral_provider.dart';

class ReferralMessageThread extends StatefulWidget {
  final String referralId;
  final bool isOpen; // false = completed/cancelled; disables sending

  const ReferralMessageThread({
    super.key,
    required this.referralId,
    required this.isOpen,
  });

  @override
  State<ReferralMessageThread> createState() => _ReferralMessageThreadState();
}

class _ReferralMessageThreadState extends State<ReferralMessageThread> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReferralProvider>().loadMessages(widget.referralId);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    final ok = await context
        .read<ReferralProvider>()
        .sendMessage(widget.referralId, text);
    if (ok && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId =
        context.read<AuthProvider>().currentUserId ?? '';

    return Consumer<ReferralProvider>(
      builder: (context, provider, _) {
        final messages = provider.messagesFor(widget.referralId);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text('Messages',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
            ),
            if (messages.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                child: Text('No messages yet.',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade500)),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 4),
                  itemCount: messages.length,
                  itemBuilder: (_, i) {
                    final m = messages[i];
                    final isMe = m.senderId == currentUserId;
                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        constraints: BoxConstraints(
                            maxWidth:
                                MediaQuery.of(context).size.width * 0.75),
                        decoration: BoxDecoration(
                          color: isMe
                              ? Colors.blue.shade600
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: isMe
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            if (!isMe)
                              Text(m.senderName,
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w600)),
                            Text(m.message,
                                style: TextStyle(
                                    fontSize: 13,
                                    color: isMe
                                        ? Colors.white
                                        : Colors.grey.shade900)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            if (widget.isOpen)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: InputDecoration(
                          hintText: 'Send a message…',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          isDense: true,
                        ),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    provider.isSendingMessage
                        ? const SizedBox(
                            width: 36,
                            height: 36,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : IconButton(
                            onPressed: _send,
                            icon: const Icon(Icons.send),
                            color: Colors.blue.shade600,
                          ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
```

- [ ] **Step 2: Create `referral_detail_screen.dart`**

```dart
// lib/presentation/referrals/screens/referral_detail_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/platform.dart';
import '../../../data/models/referral_models.dart';
import '../../../data/providers/referral_provider.dart';
import '../widgets/referral_message_thread.dart';

class ReferralDetailScreen extends StatefulWidget {
  final ReferralModel referral;

  const ReferralDetailScreen({super.key, required this.referral});

  @override
  State<ReferralDetailScreen> createState() => _ReferralDetailScreenState();
}

class _ReferralDetailScreenState extends State<ReferralDetailScreen> {
  late ReferralModel _referral;

  @override
  void initState() {
    super.initState();
    _referral = widget.referral;
    // Load full detail (includes clinical fields + status history)
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDetail());
  }

  Future<void> _loadDetail() async {
    try {
      final full = await context.read<ReferralProvider>().repository.show(_referral.id);
      if (mounted) setState(() => _referral = full);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final r = _referral;
    const title = 'Referral';
    return kIsIOS
        ? CupertinoPageScaffold(
            navigationBar: CupertinoNavigationBar(
              middle: const Text(title),
            ),
            child: SafeArea(
              child: _buildBody(r),
            ),
          )
        : Scaffold(
            appBar: AppBar(title: const Text(title)),
            body: _buildBody(r),
          );
  }

  Widget _buildBody(ReferralModel r) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeaderCard(referral: r),
          const SizedBox(height: 12),
          if (r.reason != null) _Section(title: 'Reason', body: r.reason!, expanded: true),
          if (r.clinicalSummary != null) _Section(title: 'Clinical Summary', body: r.clinicalSummary!),
          if (r.relevantHistory != null) _Section(title: 'Relevant History', body: r.relevantHistory!),
          if (r.currentMedications != null) _Section(title: 'Current Medications', body: r.currentMedications!),
          if (r.diagnosticResults != null) _Section(title: 'Diagnostic Results', body: r.diagnosticResults!),
          if (r.consultationNotes != null) _Section(title: 'Consultation Notes', body: r.consultationNotes!, expanded: true),
          if (r.recommendations != null) _Section(title: 'Recommendations', body: r.recommendations!),
          if (r.requiresFollowUp && r.followUpDate != null)
            _InfoRow(label: 'Follow-up date', value: r.followUpDate!),
          if (r.appointmentDate != null) ...[
            _InfoRow(label: 'Appointment', value: r.appointmentDate!),
            if (r.appointmentLocation != null)
              _InfoRow(label: 'Location', value: r.appointmentLocation!),
          ],
          if (r.statusHistory.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Status Timeline',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            ...r.statusHistory.map((h) => _TimelineEntry(entry: h)),
          ],
          const SizedBox(height: 24),
          _ActionBar(referral: r, onUpdated: (updated) => setState(() => _referral = updated)),
          ReferralMessageThread(
            referralId: r.id,
            isOpen: r.isOpen,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final ReferralModel r;
  const _HeaderCard({required this.r});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(r.patientName ?? 'Patient',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 18)),
                ),
                _UrgencyBadge(urgency: r.urgency),
              ],
            ),
            if (r.patientDob != null)
              Text(r.patientDob!,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const Divider(height: 16),
            _InfoRow(label: 'Specialty', value: r.specialty),
            _InfoRow(label: 'From', value: r.fromTenantName),
            _InfoRow(label: 'To', value: r.toTenantName),
            _InfoRow(label: 'Referred by', value: r.referringProviderName),
            if (r.referredToProviderName != null)
              _InfoRow(label: 'Referred to', value: r.referredToProviderName!),
            _InfoRow(label: 'Date', value: r.referredAt.split('T').first),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatefulWidget {
  final String title;
  final String body;
  final bool expanded;

  const _Section({
    required this.title,
    required this.body,
    this.expanded = false,
  });

  @override
  State<_Section> createState() => _SectionState();
}

class _SectionState extends State<_Section> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.expanded;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        initiallyExpanded: _expanded,
        title: Text(widget.title,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 13)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(widget.body,
                style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  final ReferralStatusHistoryModel entry;
  const _TimelineEntry({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
                color: Colors.blue, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              entry.from != null
                  ? '${entry.from} → ${entry.to}'
                  : entry.to,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Text(entry.at.split('T').first,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  final ReferralModel referral;
  final void Function(ReferralModel) onUpdated;

  const _ActionBar({required this.referral, required this.onUpdated});

  @override
  Widget build(BuildContext context) {
    final r = referral;
    if (!r.isOpen) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          if (r.canAccept)
            Expanded(child: _ActionButton(
              label: 'Accept',
              color: Colors.green,
              onTap: () => _accept(context),
            )),
          if (r.canSchedule)
            Expanded(child: _ActionButton(
              label: 'Schedule',
              color: Colors.blue,
              onTap: () => _schedule(context),
            )),
          if (r.canComplete)
            Expanded(child: _ActionButton(
              label: 'Mark complete',
              color: Colors.purple,
              onTap: () => _complete(context),
            )),
          if (r.canCancel) ...[
            if (r.canAccept || r.canSchedule || r.canComplete)
              const SizedBox(width: 8),
            Expanded(child: _ActionButton(
              label: 'Cancel',
              color: Colors.red,
              outlined: true,
              onTap: () => _cancel(context),
            )),
          ],
        ],
      ),
    );
  }

  Future<void> _accept(BuildContext context) async {
    final provider = context.read<ReferralProvider>();
    final ok = await provider.accept(referral.id);
    if (ok && context.mounted) {
      final updated = provider.referrals.firstWhere((r) => r.id == referral.id,
          orElse: () => referral);
      onUpdated(updated);
    }
  }

  Future<void> _schedule(BuildContext context) async {
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ScheduleSheet(),
    );
    if (result == null || !context.mounted) return;
    final provider = context.read<ReferralProvider>();
    final ok = await provider.schedule(referral.id, result['date']!, result['location']);
    if (ok && context.mounted) {
      final updated = provider.referrals.firstWhere((r) => r.id == referral.id,
          orElse: () => referral);
      onUpdated(updated);
    }
  }

  Future<void> _complete(BuildContext context) async {
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CompleteSheet(),
    );
    if (result == null || !context.mounted) return;
    final provider = context.read<ReferralProvider>();
    final ok = await provider.complete(
        referral.id, result['notes']!, result['recommendations']);
    if (ok && context.mounted) {
      final updated = provider.referrals.firstWhere((r) => r.id == referral.id,
          orElse: () => referral);
      onUpdated(updated);
    }
  }

  Future<void> _cancel(BuildContext context) async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CancelSheet(),
    );
    if (reason == null || !context.mounted) return;
    final provider = context.read<ReferralProvider>();
    final ok = await provider.cancel(referral.id, reason);
    if (ok && context.mounted) {
      final updated = provider.referrals.firstWhere((r) => r.id == referral.id,
          orElse: () => referral);
      onUpdated(updated);
      Navigator.of(context).pop();
    }
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool outlined;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.color,
    required this.onTap,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return outlined
        ? OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(foregroundColor: color),
            child: Text(label),
          )
        : ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
                backgroundColor: color, foregroundColor: Colors.white),
            child: Text(label),
          );
  }
}

class _ScheduleSheet extends StatefulWidget {
  const _ScheduleSheet();
  @override
  State<_ScheduleSheet> createState() => _ScheduleSheetState();
}

class _ScheduleSheetState extends State<_ScheduleSheet> {
  String? _date;
  final _locationCtrl = TextEditingController();

  @override
  void dispose() { _locationCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 24, 16,
          16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Schedule Appointment',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now().add(const Duration(days: 1)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) setState(() => _date = picked.toIso8601String());
            },
            icon: const Icon(Icons.calendar_today, size: 16),
            label: Text(_date == null
                ? 'Select appointment date'
                : _date!.split('T').first),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _locationCtrl,
            decoration: const InputDecoration(
              labelText: 'Location (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _date == null
                ? null
                : () => Navigator.of(context)
                    .pop({'date': _date!, 'location': _locationCtrl.text.trim()}),
            child: const Text('Schedule'),
          ),
        ],
      ),
    );
  }
}

class _CompleteSheet extends StatefulWidget {
  const _CompleteSheet();
  @override
  State<_CompleteSheet> createState() => _CompleteSheetState();
}

class _CompleteSheetState extends State<_CompleteSheet> {
  final _notesCtrl = TextEditingController();
  final _recsCtrl  = TextEditingController();

  @override
  void dispose() { _notesCtrl.dispose(); _recsCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 24, 16,
          16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Mark as Complete',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 16),
          TextField(
            controller: _notesCtrl,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Consultation notes *',
              hintText: 'Minimum 10 characters',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _recsCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Recommendations (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _notesCtrl.text.trim().length < 10 ? null : () =>
                Navigator.of(context).pop({
                  'notes': _notesCtrl.text.trim(),
                  'recommendations': _recsCtrl.text.trim(),
                }),
            child: const Text('Mark complete'),
          ),
        ],
      ),
    );
  }
}

class _CancelSheet extends StatefulWidget {
  const _CancelSheet();
  @override
  State<_CancelSheet> createState() => _CancelSheetState();
}

class _CancelSheetState extends State<_CancelSheet> {
  final _reasonCtrl = TextEditingController();
  @override
  void dispose() { _reasonCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 24, 16,
          16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Cancel Referral',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: Colors.red)),
          const SizedBox(height: 16),
          TextField(
            controller: _reasonCtrl,
            maxLines: 3,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Reason *',
              hintText: 'Minimum 10 characters',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _reasonCtrl.text.trim().length < 10
                ? null
                : () =>
                    Navigator.of(context).pop(_reasonCtrl.text.trim()),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white),
            child: const Text('Confirm cancellation'),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: TextStyle(
                    fontSize: 12, color: Colors.grey.shade600)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

class _UrgencyBadge extends StatelessWidget {
  final String urgency;
  const _UrgencyBadge({required this.urgency});

  @override
  Widget build(BuildContext context) {
    if (urgency == 'routine') return const SizedBox.shrink();
    final (color, label) = urgency == 'emergency'
        ? (Colors.red, 'EMERGENCY')
        : (Colors.orange, 'URGENT');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color)),
    );
  }
}
```

- [ ] **Step 3: Verify both files compile**

```bash
flutter analyze lib/presentation/referrals/screens/referral_detail_screen.dart lib/presentation/referrals/widgets/referral_message_thread.dart 2>&1 | tail -3
```

Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/referrals/screens/referral_detail_screen.dart lib/presentation/referrals/widgets/referral_message_thread.dart
git commit -m "feat: add ReferralDetailScreen with action bar, clinical sections, and message thread"
```

---

## Task 6: CreateReferralSheet

**Files:**
- Create: `lib/presentation/referrals/widgets/create_referral_sheet.dart`

- [ ] **Step 1: Create the sheet**

```dart
// lib/presentation/referrals/widgets/create_referral_sheet.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/platform.dart';
import '../../../data/models/patient_models.dart';
import '../../../data/providers/referral_provider.dart';
import '../../../data/repositories/facility_repository.dart';

class CreateReferralSheet extends StatefulWidget {
  final PatientModel patient;

  const CreateReferralSheet({super.key, required this.patient});

  @override
  State<CreateReferralSheet> createState() => _CreateReferralSheetState();
}

class _CreateReferralSheetState extends State<CreateReferralSheet> {
  final _specialtyCtrl  = TextEditingController();
  final _reasonCtrl     = TextEditingController();
  final _summaryCtrl    = TextEditingController();
  final _historyCtrl    = TextEditingController();
  final _medsCtrl       = TextEditingController();
  final _diagnosticsCtrl = TextEditingController();

  String _urgency = 'routine';
  bool _requiresFollowUp = false;
  String? _followUpDate;
  Map<String, dynamic>? _selectedFacility;
  Map<String, dynamic>? _selectedProvider;
  List<Map<String, dynamic>> _facilities = [];
  List<Map<String, dynamic>> _facilityProviders = [];
  bool _loadingFacilities = false;
  bool _loadingProviders = false;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFacilities();
  }

  @override
  void dispose() {
    _specialtyCtrl.dispose();
    _reasonCtrl.dispose();
    _summaryCtrl.dispose();
    _historyCtrl.dispose();
    _medsCtrl.dispose();
    _diagnosticsCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFacilities() async {
    setState(() => _loadingFacilities = true);
    try {
      final repo = FacilityRepository(
          apiClient: context.read<ReferralProvider>().repository.apiClient);
      final facilities = await repo.listTenants();
      setState(() => _facilities = facilities);
    } catch (e) {
      setState(() => _error = 'Failed to load facilities.');
    } finally {
      setState(() => _loadingFacilities = false);
    }
  }

  Future<void> _loadProviders(String tenantId) async {
    setState(() {
      _loadingProviders = true;
      _selectedProvider = null;
      _facilityProviders = [];
    });
    try {
      final repo = FacilityRepository(
          apiClient: context.read<ReferralProvider>().repository.apiClient);
      final providers = await repo.listStaffAtTenant(tenantId);
      setState(() => _facilityProviders = providers);
    } catch (_) {
      setState(() => _facilityProviders = []);
    } finally {
      setState(() => _loadingProviders = false);
    }
  }

  bool get _isValid =>
      _selectedFacility != null &&
      _specialtyCtrl.text.trim().isNotEmpty &&
      _reasonCtrl.text.trim().length >= 10;

  Future<void> _submit() async {
    if (!_isValid) return;
    setState(() { _submitting = true; _error = null; });

    final data = <String, dynamic>{
      'master_patient_id':       widget.patient.globalPatientId,
      'to_tenant_id':            _selectedFacility!['id'],
      'specialty':               _specialtyCtrl.text.trim(),
      'urgency':                 _urgency,
      'reason':                  _reasonCtrl.text.trim(),
      if (_selectedProvider != null)
        'referred_to_provider_id': _selectedProvider!['id'],
      if (_summaryCtrl.text.trim().isNotEmpty)
        'clinical_summary':        _summaryCtrl.text.trim(),
      if (_historyCtrl.text.trim().isNotEmpty)
        'relevant_history':        _historyCtrl.text.trim(),
      if (_medsCtrl.text.trim().isNotEmpty)
        'current_medications':     _medsCtrl.text.trim(),
      if (_diagnosticsCtrl.text.trim().isNotEmpty)
        'diagnostic_results':      _diagnosticsCtrl.text.trim(),
      'requires_follow_up':      _requiresFollowUp,
      if (_requiresFollowUp && _followUpDate != null)
        'follow_up_date':          _followUpDate,
    };

    final created =
        await context.read<ReferralProvider>().create(data);
    if (!mounted) return;
    setState(() => _submitting = false);

    if (created != null) {
      Navigator.of(context).pop(true);
      showAdaptiveToast(context, 'Referral sent');
    } else {
      final providerError = context.read<ReferralProvider>().error;
      setState(() => _error = providerError ?? 'Failed to create referral.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 1.0,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                const Expanded(
                    child: Text('Refer Patient',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 17))),
                Text(widget.patient.fullName,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
          const Divider(height: 1),
          if (_error != null)
            Container(
              color: Colors.red.shade50,
              padding: const EdgeInsets.all(12),
              child: Text(_error!,
                  style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
            ),
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Destination facility
                  const Text('Destination facility *',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87)),
                  const SizedBox(height: 6),
                  _loadingFacilities
                      ? const Center(child: CircularProgressIndicator())
                      : DropdownButtonFormField<Map<String, dynamic>>(
                          value: _selectedFacility,
                          hint: const Text('Select facility'),
                          decoration: const InputDecoration(
                              border: OutlineInputBorder()),
                          items: _facilities
                              .map((f) => DropdownMenuItem(
                                    value: f,
                                    child: Text(f['name'] as String? ?? ''),
                                  ))
                              .toList(),
                          onChanged: (f) {
                            setState(() => _selectedFacility = f);
                            if (f != null) _loadProviders(f['id'] as String);
                          },
                        ),
                  const SizedBox(height: 14),
                  // Optional provider
                  const Text('Specific provider (optional)',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87)),
                  const SizedBox(height: 6),
                  _loadingProviders
                      ? const LinearProgressIndicator()
                      : DropdownButtonFormField<Map<String, dynamic>>(
                          value: _selectedProvider,
                          hint: const Text('Any available provider'),
                          decoration: const InputDecoration(
                              border: OutlineInputBorder()),
                          items: [
                            const DropdownMenuItem(
                                value: null,
                                child: Text('Any available provider')),
                            ..._facilityProviders.map((p) => DropdownMenuItem(
                                  value: p,
                                  child: Text(p['name'] as String? ?? ''),
                                )),
                          ],
                          onChanged: (p) =>
                              setState(() => _selectedProvider = p),
                        ),
                  const SizedBox(height: 14),
                  // Specialty
                  TextField(
                    controller: _specialtyCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Specialty *',
                      hintText: 'e.g. Cardiology, Neurology',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Urgency
                  const Text('Urgency *',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87)),
                  const SizedBox(height: 6),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'routine', label: Text('Routine')),
                      ButtonSegment(value: 'urgent', label: Text('Urgent')),
                      ButtonSegment(
                          value: 'emergency', label: Text('Emergency')),
                    ],
                    selected: {_urgency},
                    onSelectionChanged: (s) =>
                        setState(() => _urgency = s.first),
                  ),
                  const SizedBox(height: 14),
                  // Reason
                  TextField(
                    controller: _reasonCtrl,
                    maxLines: 4,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Reason *',
                      hintText: 'Minimum 10 characters',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Optional sections
                  TextField(
                    controller: _summaryCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Clinical summary (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _historyCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Relevant history (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _medsCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Current medications (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _diagnosticsCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Diagnostic results (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Follow-up
                  SwitchListTile(
                    value: _requiresFollowUp,
                    onChanged: (v) => setState(() => _requiresFollowUp = v),
                    title: const Text('Requires follow-up',
                        style: TextStyle(fontSize: 13)),
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (_requiresFollowUp) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate:
                              DateTime.now().add(const Duration(days: 7)),
                          firstDate:
                              DateTime.now().add(const Duration(days: 1)),
                          lastDate: DateTime.now()
                              .add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setState(() =>
                              _followUpDate = picked.toIso8601String());
                        }
                      },
                      icon: const Icon(Icons.event, size: 16),
                      label: Text(_followUpDate == null
                          ? 'Select follow-up date'
                          : _followUpDate!.split('T').first),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16,
                12 + MediaQuery.of(context).viewInsets.bottom),
            child: ElevatedButton(
              onPressed: (_isValid && !_submitting) ? _submit : null,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Send referral'),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Add `listTenants` and `listStaffAtTenant` to FacilityRepository**

Open `lib/data/repositories/facility_repository.dart`. Add these two methods at the bottom of the class:

```dart
/// List all active facilities — used in referral facility picker.
Future<List<Map<String, dynamic>>> listTenants() async {
  final response = await apiClient.get('/tenants', queryParameters: {'per_page': 100});
  if (response['success'] != true) throw Exception('Failed to load facilities');
  final data = response['data'];
  final raw = data is Map ? (data['data'] as List? ?? []) : (data as List? ?? []);
  return raw
      .map((e) => {'id': e['id'], 'name': e['name']})
      .toList()
      .cast<Map<String, dynamic>>();
}

/// List active staff at a specific tenant — used in referral provider picker.
Future<List<Map<String, dynamic>>> listStaffAtTenant(String tenantId) async {
  final response = await apiClient.get(
    '/staff/memberships',
    queryParameters: {'tenant_id': tenantId, 'per_page': 100},
  );
  if (response['success'] != true) return [];
  final data = response['data'];
  final raw = data is Map ? (data['data'] as List? ?? []) : (data as List? ?? []);
  return raw.map((e) {
    final user = e['user'] as Map?;
    return {
      'id':   user?['id'] ?? e['user_id'],
      'name': user != null
          ? '${user['first_name']} ${user['last_name']}'
          : 'Provider',
    };
  }).toList().cast<Map<String, dynamic>>();
}
```

- [ ] **Step 3: Update CreateReferralSheet import to use existing FacilityRepository**

The sheet already imports `FacilityRepository` — verify the import path matches the actual file:

```bash
ls /home/dh/Forge/sandbox/healthcare_emr_mobile/lib/data/repositories/facility_repository.dart
```

Expected: file exists. If it does not, create a minimal one:
```dart
// lib/data/repositories/facility_repository.dart
import '../../core/api/api_client.dart';

class FacilityRepository {
  final ApiClient apiClient;
  FacilityRepository({required this.apiClient});
}
```
Then add the two methods from Step 2 to it.

- [ ] **Step 4: Verify everything compiles**

```bash
flutter analyze lib/presentation/referrals/widgets/create_referral_sheet.dart lib/data/repositories/facility_repository.dart 2>&1 | tail -3
```

Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/referrals/widgets/create_referral_sheet.dart lib/data/repositories/facility_repository.dart
git commit -m "feat: add CreateReferralSheet and extend FacilityRepository"
```

---

## Task 7: Wire up — main.dart, More screen, PatientDetailScreen

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/presentation/more/more_screen.dart`
- Modify: `lib/presentation/patients/screens/patient_detail_screen.dart`

- [ ] **Step 1: Add ReferralProvider + ReferralRepository to main.dart**

Open `lib/main.dart`. Add these two imports after the sync imports:
```dart
import 'data/repositories/referral_repository.dart';
import 'data/providers/referral_provider.dart';
```

Inside `_MyAppState.build`, after `final syncRepository = ...`:
```dart
final referralRepository = ReferralRepository(
  apiClient: apiClient,
  getTenantId: () {
    // Reads the active tenant ID from SharedPreferences at call time.
    // This is deferred so it always reflects the current session.
    // AuthProvider stores activeTenantId; we can't inject the provider
    // here (it's not built yet), so we read from SharedPreferences directly.
    // The SyncRepository uses the same pattern for clientId.
    return ''; // placeholder; actual value resolved by AuthProvider at use time
  },
);
```

**Correction:** `ReferralRepository` needs `currentTenantId` at parse time to compute `isSent`/`isReceived`. The provider tree isn't available in `main.dart` before `build`. Update the `ReferralRepository` constructor signature to accept a `String Function()` getter, and supply it from `AuthProvider` inside `ReferralProvider.loadReferrals()`:

In `lib/data/providers/referral_provider.dart`, add a `String? _currentTenantId` field and expose a `setTenantId(String id)` method. Call `setTenantId(auth.activeTenantId)` in `loadReferrals()` before parsing.

**Practical approach:** Update `ReferralRepository` to hold a `String currentTenantId` that defaults to `''` and is updated by the provider before each parse. Add this method to `ReferralRepository`:
```dart
String currentTenantId = '';
```
And update all `fromJson(..., currentTenantId: getTenantId())` calls to use `currentTenantId` directly:
```dart
ReferralModel.fromJson(Map<String, dynamic>.from(e as Map), currentTenantId: currentTenantId)
```

Then in `ReferralProvider.loadReferrals()`, before calling `repository.list()`:
```dart
repository.currentTenantId = context?.read<AuthProvider>().activeTenantId ?? '';
```

Since `ReferralProvider` doesn't have a `BuildContext`, pass `currentTenantId` as a parameter:
```dart
Future<void> loadReferrals({bool refresh = false, String currentTenantId = ''}) async {
  repository.currentTenantId = currentTenantId;
  ...
}
```

And in `ReferralsScreen._ReferralsScreenState.initState()`:
```dart
final tenantId = context.read<AuthProvider>().activeTenantId ?? '';
context.read<ReferralProvider>().loadReferrals(currentTenantId: tenantId);
```

Add `activeTenantId` getter to `AuthProvider` if not present:
```dart
// In AuthProvider:
String? get activeTenantId => _activeMembership?.tenantId;
```

Check if this getter already exists:
```bash
grep -n "activeTenantId\|activeMembership" /home/dh/Forge/sandbox/healthcare_emr_mobile/lib/data/providers/auth_provider.dart | head -10
```

If `activeTenantId` is missing, add it alongside the existing membership getters.

- [ ] **Step 2: Wire up in main.dart**

After verifying the tenant ID approach above, add to `main.dart` inside `MultiProvider` after `SyncProvider`:

```dart
ChangeNotifierProvider(
  create: (_) => ReferralProvider(
    repository: ReferralRepository(apiClient: apiClient),
    getCurrentUserId: () => '', // placeholder; not used in provider logic
  ),
),
```

Remove the `getCurrentUserId` parameter from `ReferralProvider` if it was never used — check the provider source before committing.

- [ ] **Step 3: Add Referrals tile to More screen**

Open `lib/presentation/more/more_screen.dart`. Add import:
```dart
import '../../data/providers/referral_provider.dart';
import '../referrals/screens/referrals_screen.dart';
```

In `build`, add to the Account section (after Sync Status):
```dart
Consumer<ReferralProvider>(
  builder: (context, referrals, _) => CupertinoListTile(
    leading: const Icon(
      CupertinoIcons.arrow_right_arrow_left_circle,
      color: AppColors.primary,
    ),
    title: const Text('Referrals'),
    trailing: referrals.pendingActionCount > 0
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${referrals.pendingActionCount}',
                  style: const TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 6),
              const CupertinoListTileChevron(),
            ],
          )
        : const CupertinoListTileChevron(),
    onTap: () => _push(context, const ReferralsScreen()),
  ),
),
```

- [ ] **Step 4: Add "Refer" icon button to PatientDetailScreen**

Open `lib/presentation/patients/screens/patient_detail_screen.dart`. Add import:
```dart
import '../../../data/providers/referral_provider.dart';
import '../../referrals/widgets/create_referral_sheet.dart';
```

In `_PatientDetailScreenState`, add this method:
```dart
Future<void> _openReferralSheet() async {
  if (_patient.globalPatientId == null) {
    showAdaptiveToast(context, 'Patient global ID not available');
    return;
  }
  await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => CreateReferralSheet(patient: _patient),
  );
  if (mounted) {
    final tenantId = context.read<AuthProvider>().activeTenantId ?? '';
    context.read<ReferralProvider>().loadReferrals(currentTenantId: tenantId);
  }
}
```

In the iOS navigation bar's `trailing` Row, add before the pencil button (only for staff):
```dart
if (auth.isStaff)
  CupertinoButton(
    padding: EdgeInsets.zero,
    onPressed: _openReferralSheet,
    child: const Icon(CupertinoIcons.arrow_right_arrow_left_circle),
  ),
```

In the Android `appBar.actions`, add before the edit icon:
```dart
if (auth.isStaff)
  IconButton(
    icon: const Icon(Icons.send_outlined),
    tooltip: 'Refer patient',
    onPressed: _openReferralSheet,
  ),
```

Check what `auth.isStaff` returns — search for it:
```bash
grep -n "isStaff\|staffType" /home/dh/Forge/sandbox/healthcare_emr_mobile/lib/data/providers/auth_provider.dart | head -10
```

Use the correct getter. If `isStaff` doesn't exist, use `auth.staffType != null`.

- [ ] **Step 5: Full analyzer check**

```bash
flutter analyze lib/ 2>&1 | tail -5
```

Expected: `No issues found!`

- [ ] **Step 6: Run all tests**

```bash
flutter test test/referrals/ test/sync/ 2>&1
```

Expected: All tests pass.

- [ ] **Step 7: Commit**

```bash
git add lib/main.dart \
        lib/presentation/more/more_screen.dart \
        lib/presentation/patients/screens/patient_detail_screen.dart \
        lib/data/providers/auth_provider.dart \
        lib/data/providers/referral_provider.dart \
        lib/data/repositories/referral_repository.dart
git commit -m "feat: wire ReferralProvider into app shell, More screen, and patient detail"
```

---

## Self-Review Checklist

- [x] ReferralFilter.matches() with compound statuses (active, done) — Task 1
- [x] isSent/isReceived set at parse time via currentTenantId — Task 1, Task 7
- [x] canAccept/canSchedule/canComplete/canCancel computed correctly — Task 1 + tests
- [x] All 9 API endpoints — Task 2
- [x] Client-side filter (no compound API calls) — Task 3
- [x] pendingActionCount (received + pending only) — Task 3
- [x] Message cache in provider — Task 3
- [x] Error codes mapped to user-friendly messages — Task 3
- [x] Filter chips + empty state per filter — Task 4
- [x] Infinite scroll with loadMore — Task 4
- [x] SENT/RECEIVED role badge + urgency dot — Task 4
- [x] Clinical sections collapsible, reason always expanded — Task 5
- [x] Status timeline — Task 5
- [x] Role-based action bar (accept/schedule/complete/cancel) — Task 5
- [x] Schedule sheet (date picker + location) — Task 5
- [x] Complete sheet (notes required min 10 chars + optional recs) — Task 5
- [x] Cancel sheet (reason required min 10 chars) — Task 5
- [x] Inline message thread — Task 5
- [x] Message thread disabled on closed referrals — Task 5
- [x] globalPatientId used as master_patient_id (no backend change) — Task 6
- [x] PATIENT_CONSENT_REQUIRED error handled — Task 3 + Task 6
- [x] Follow-up toggle + date picker — Task 6
- [x] More screen tile with pendingActionCount badge — Task 7
- [x] Refer icon in patient detail app bar, gated on isStaff — Task 7
- [x] currentTenantId passed to loadReferrals — Task 7
