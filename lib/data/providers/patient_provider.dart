import 'package:flutter/material.dart';
import '../models/patient_models.dart';
import '../repositories/patient_repository.dart';

/// PatientProvider
///
/// State management for the patient list, search, and dashboard stats.
/// Follows the exact same pattern as the existing SubscriptionProvider:
///   - private backing fields with public getters
///   - isLoading / error lifecycle
///   - clearError() method
///
/// The dashboard uses this provider for stats.
/// The patient list screen uses this provider for data + search.
///
class PatientProvider extends ChangeNotifier {
  final PatientRepository repository;

  PatientProvider({required this.repository});

  // ── State ──────────────────────────────────────────────────────────────────

  List<PatientModel> _patients = [];
  PatientModel? _selectedPatient;
  DashboardStatsModel _stats = const DashboardStatsModel();

  bool _isLoading = false;
  bool _isLoadingStats = false;
  bool _isSearching = false;
  String? _error;

  // Pagination
  int _currentPage = 1;
  bool _hasMore = false;
  bool _isLoadingMore = false;

  // Cache indicator
  bool _patientsFromCache = false;
  bool _statsFromCache = false;

  // Search
  String _searchQuery = '';
  List<PatientModel> _searchResults = [];

  // ── Getters ────────────────────────────────────────────────────────────────

  List<PatientModel> get patients => _patients;
  PatientModel? get selectedPatient => _selectedPatient;
  DashboardStatsModel get stats => _stats;

  bool get isLoading => _isLoading;
  bool get isLoadingStats => _isLoadingStats;
  bool get isSearching => _isSearching;
  bool get isLoadingMore => _isLoadingMore;
  String? get error => _error;

  bool get hasMore => _hasMore;
  bool get patientsFromCache => _patientsFromCache;
  bool get statsFromCache => _statsFromCache;

  String get searchQuery => _searchQuery;
  List<PatientModel> get searchResults => _searchResults;
  bool get isShowingSearchResults => _searchQuery.isNotEmpty;

  /// The list displayed in the UI — either search results or the full list
  List<PatientModel> get displayList =>
      isShowingSearchResults ? _searchResults : _patients;

  // ── LOAD PATIENTS ──────────────────────────────────────────────────────────

  Future<void> loadPatients({
    String? providerId,
    bool forceRefresh = false,
  }) async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    _currentPage = 1;
    notifyListeners();

    try {
      final result = await repository.getPatients(
        providerId: providerId,
        page: 1,
        forceRefresh: forceRefresh,
      );
      _patients = result.patients;
      _hasMore = result.hasMore;
      _patientsFromCache = result.isFromCache;
    } catch (e) {
      _error = _friendlyError(e);
      _patients = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore({String? providerId}) async {
    if (_isLoadingMore || !_hasMore) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final result = await repository.getPatients(
        providerId: providerId,
        page: _currentPage + 1,
        forceRefresh: true, // always fetch next page from server
      );
      _patients = [..._patients, ...result.patients];
      _hasMore = result.hasMore;
      _currentPage++;
      _patientsFromCache = result.isFromCache;
    } catch (_) {
      // Silently fail on pagination errors — user still has previous pages
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  // ── SEARCH ─────────────────────────────────────────────────────────────────

  Future<void> search(String query, {String? providerId}) async {
    _searchQuery = query;

    if (query.trim().length < 2) {
      _searchResults = [];
      notifyListeners();
      return;
    }

    _isSearching = true;
    notifyListeners();

    try {
      final result = await repository.searchPatients(
        query: query.trim(),
        providerId: providerId,
      );
      _searchResults = result.patients;
    } catch (_) {
      _searchResults = [];
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  void clearSearch() {
    _searchQuery = '';
    _searchResults = [];
    notifyListeners();
  }

  // ── SINGLE PATIENT ─────────────────────────────────────────────────────────

  Future<void> loadPatient(String patientId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _selectedPatient = await repository.getPatient(
        patientId,
        fromCacheFirst: true,
      );
    } catch (e) {
      _error = _friendlyError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setSelectedPatient(PatientModel patient) {
    _selectedPatient = patient;
    notifyListeners();
  }

  void clearSelectedPatient() {
    _selectedPatient = null;
    notifyListeners();
  }

  // ── CREATE / UPDATE / DELETE ───────────────────────────────────────────────

  Future<PatientModel?> createPatient(Map<String, dynamic> data) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final patient = await repository.createPatient(data);
      // Prepend to the list so it appears at the top immediately
      _patients = [patient, ..._patients];
      // Bump stats
      _stats = _stats.copyWith(
        totalPatients: _stats.totalPatients + 1,
        activePatients: _stats.activePatients + 1,
        recentPatients: _stats.recentPatients + 1,
      );
      _isLoading = false;
      notifyListeners();
      return patient;
    } catch (e) {
      _error = _friendlyError(e);
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<PatientModel?> updatePatient(
    String patientId,
    Map<String, dynamic> data,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updated = await repository.updatePatient(patientId, data);
      // Replace the entry in the list
      _patients = _patients.map((p) => p.id == patientId ? updated : p).toList();
      if (_selectedPatient?.id == patientId) {
        _selectedPatient = updated;
      }
      _isLoading = false;
      notifyListeners();
      return updated;
    } catch (e) {
      _error = _friendlyError(e);
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<bool> deletePatient(String patientId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await repository.deletePatient(patientId);
      _patients = _patients.where((p) => p.id != patientId).toList();
      _stats = _stats.copyWith(
        totalPatients: (_stats.totalPatients - 1).clamp(0, 99999),
        activePatients: (_stats.activePatients - 1).clamp(0, 99999),
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _friendlyError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ── DASHBOARD STATS ────────────────────────────────────────────────────────

  Future<void> loadDashboardStats(String providerId) async {
    _isLoadingStats = true;
    notifyListeners();

    try {
      _stats = await repository.getDashboardStats(providerId);
      _statsFromCache = _stats.isFromCache;
    } catch (_) {
      // Keep previous stats on failure — stats are non-critical
    } finally {
      _isLoadingStats = false;
      notifyListeners();
    }
  }

  // ── HOUSEKEEPING ──────────────────────────────────────────────────────────

  Future<void> clearCacheOnLogout(String providerId) async {
    await repository.clearCache(providerId);
    _patients = [];
    _searchResults = [];
    _searchQuery = '';
    _selectedPatient = null;
    _stats = const DashboardStatsModel();
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('SocketException') || msg.contains('Connection')) {
      return 'No internet connection. Showing cached data.';
    }
    if (msg.contains('401')) return '[401] Session expired. Please log out and log back in.';
    if (msg.contains('403')) return '[403] Access denied: $msg';
    if (msg.contains('404')) return '[404] Not found: $msg';
    // Include raw error so the exact API message / stack is visible during debugging
    return 'Error: $msg';
  }
}