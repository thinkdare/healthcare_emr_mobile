import 'package:flutter/material.dart';
import '../models/models.dart';
import '../models/auth_models.dart';
import '../repositories/auth_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AuthState — the current login / session state
// ─────────────────────────────────────────────────────────────────────────────

enum AuthState {
  loading,        // Checking stored token on app start
  unauthenticated,
  awaitingTwoFactor,
  awaitingFacility, // Logged in but no facility selected yet
  authenticated,
}

// ─────────────────────────────────────────────────────────────────────────────
// AuthProvider
// ─────────────────────────────────────────────────────────────────────────────

class AuthProvider extends ChangeNotifier {
  final AuthRepository repository;

  AuthProvider({required this.repository});

  // ── State ──────────────────────────────────────────────────────────────────

  AuthState _state = AuthState.loading;
  AuthState get state => _state;

  bool get isLoading => _state == AuthState.loading;
  bool get isAuthenticated => _state == AuthState.authenticated;
  bool get needsFacilitySelection => _state == AuthState.awaitingFacility;
  bool get requiresTwoFactor => _state == AuthState.awaitingTwoFactor;

  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;

  AuthFacilityModel? _activeFacility;
  AuthFacilityModel? get activeFacility => _activeFacility;

  StaffMembershipModel? _activeMembership;
  StaffMembershipModel? get activeMembership => _activeMembership;

  List<AuthFacilityModel> _availableFacilities = [];
  List<AuthFacilityModel> get availableFacilities => _availableFacilities;

  String? _twoFactorChallengeToken;

  String? _error;
  String? get error => _error;

  // ── Convenience getters used by the UI ────────────────────────────────────

  /// Used as cache key in PatientRepository / PatientProvider.
  String? get currentUserId => _currentUser?.id;

  String get displayName => _currentUser?.name ?? 'Provider';
  String get initials => _currentUser?.initials ?? 'P';
  String get staffTypeDisplay => _activeMembership?.displayType ?? '';
  String get facilityName => _activeFacility?.name ?? '';
  String get organizationName => _activeFacility?.organization?.name ?? '';
  String? get organizationId => _activeFacility?.organization?.id;

  String? get activeTenantId => _activeMembership?.tenantId;
  bool get isStaff => _activeMembership != null;

  bool get canPrescribe => _activeMembership?.canPrescribe ?? false;
  bool get canOrderLabs => _activeMembership?.canOrderLabs ?? false;
  bool get canEmergencyAccess => _activeMembership?.canEmergencyAccess ?? false;
  String get department => _activeMembership?.department ?? '';
  String get staffType => _activeMembership?.staffType ?? '';

  // ── Initialisation ─────────────────────────────────────────────────────────

  /// Called once at startup — restores session from secure storage.
  Future<void> initialize() async {
    _state = AuthState.loading;
    notifyListeners();

    try {
      final user = await repository.getCurrentUser();
      if (user == null) {
        _state = AuthState.unauthenticated;
        notifyListeners();
        return;
      }
      _currentUser = user;

      // Check if there is a stored tenant selection
      final tenantId = await repository.apiClient.getTenantId();
      if (tenantId != null) {
        // Reload facilities to get the membership details for the stored tenant
        final facilities = await repository.getFacilities();
        _availableFacilities = facilities;
        final stored = facilities.where((f) => f.id == tenantId).firstOrNull;
        if (stored != null) {
          _activeFacility = stored;
          _activeMembership = stored.membership;
          _state = AuthState.authenticated;
          notifyListeners();
          return;
        }
      }

      // Token exists but no facility selected — prompt picker
      _state = AuthState.awaitingFacility;
    } catch (_) {
      _state = AuthState.unauthenticated;
    }

    notifyListeners();
  }

  // ── Login ──────────────────────────────────────────────────────────────────

  /// Returns true if login succeeded (or 2FA challenge was issued).
  /// Returns false on credential error.
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _error = null;

    try {
      final result = await repository.login(email: email, password: password);

      if (result is LoginTwoFactorRequired) {
        _twoFactorChallengeToken = result.challengeToken;
        _state = AuthState.awaitingTwoFactor;
        notifyListeners();
        return true;
      }

      // Full login — load user then facilities
      _currentUser = await repository.getCurrentUser();
      await _loadFacilities();
      return true;
    } on Exception catch (e) {
      _error = _friendlyError(e.toString());
      _state = AuthState.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  // ── 2FA ───────────────────────────────────────────────────────────────────

  Future<bool> verifyTwoFactor(String code) async {
    if (_twoFactorChallengeToken == null) return false;
    _error = null;

    try {
      await repository.verifyTwoFactor(
        challengeToken: _twoFactorChallengeToken!,
        code: code,
      );
      _twoFactorChallengeToken = null;
      _currentUser = await repository.getCurrentUser();
      await _loadFacilities();
      return true;
    } on Exception catch (e) {
      _error = _friendlyError(e.toString());
      notifyListeners();
      return false;
    }
  }

  // ── Facility selection ─────────────────────────────────────────────────────

  Future<void> _loadFacilities() async {
    _availableFacilities = await repository.getFacilities();

    if (_availableFacilities.length == 1) {
      // Auto-select when there is only one facility
      await selectFacility(_availableFacilities.first);
    } else {
      _state = AuthState.awaitingFacility;
      notifyListeners();
    }
  }

  Future<void> selectFacility(AuthFacilityModel facility) async {
    try {
      final result = await repository.selectFacility(facility.id);
      _activeFacility = facility;
      _activeMembership = result.membership;
      _state = AuthState.authenticated;
      notifyListeners();
    } on Exception catch (e) {
      _error = _friendlyError(e.toString());
      notifyListeners();
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    await repository.logout();
    _currentUser = null;
    _activeFacility = null;
    _activeMembership = null;
    _availableFacilities = [];
    _twoFactorChallengeToken = null;
    _error = null;
    _state = AuthState.unauthenticated;
    notifyListeners();
  }

  // ── Misc ──────────────────────────────────────────────────────────────────

  // ── 2FA management ────────────────────────────────────────────────────────

  /// Returns { 'secret', 'qr_code_url' } for displaying during setup.
  Future<Map<String, dynamic>?> twoFactorSetup() async {
    _error = null;
    try {
      return await repository.twoFactorSetup();
    } on Exception catch (e) {
      _error = _friendlyError(e.toString());
      notifyListeners();
      return null;
    }
  }

  /// Confirm first TOTP code; returns backup codes on success, null on failure.
  Future<List<String>?> twoFactorEnable(String code) async {
    _error = null;
    try {
      final codes = await repository.twoFactorEnable(code);
      // Refresh user so twoFactorEnabled flag reflects the change.
      _currentUser = await repository.getCurrentUser();
      notifyListeners();
      return codes;
    } on Exception catch (e) {
      _error = _friendlyError(e.toString());
      notifyListeners();
      return null;
    }
  }

  Future<bool> twoFactorDisable(String password) async {
    _error = null;
    try {
      await repository.twoFactorDisable(password);
      _currentUser = await repository.getCurrentUser();
      notifyListeners();
      return true;
    } on Exception catch (e) {
      _error = _friendlyError(e.toString());
      notifyListeners();
      return false;
    }
  }

  Future<int?> twoFactorBackupCodeCount() async {
    try {
      return await repository.twoFactorBackupCodeCount();
    } catch (_) {
      return null;
    }
  }

  Future<List<String>?> twoFactorRegenerateBackupCodes() async {
    _error = null;
    try {
      return await repository.twoFactorRegenerateBackupCodes();
    } on Exception catch (e) {
      _error = _friendlyError(e.toString());
      notifyListeners();
      return null;
    }
  }

  // ── Password ──────────────────────────────────────────────────────────────

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _error = null;
    try {
      await repository.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      return true;
    } on Exception catch (e) {
      _error = _friendlyError(e.toString());
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  String _friendlyError(String raw) {
    if (raw.contains('401') || raw.contains('Invalid')) {
      return 'Invalid email or password.';
    }
    if (raw.contains('429')) return 'Too many attempts. Please wait a minute.';
    if (raw.contains('SocketException') || raw.contains('Connection')) {
      return 'Cannot reach the server. Check your connection.';
    }
    return 'Something went wrong. Please try again.';
  }
}
