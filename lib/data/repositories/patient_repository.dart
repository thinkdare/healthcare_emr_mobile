import '../../core/api/api_client.dart';
import '../../core/database/local_database.dart';
import '../models/patient_models.dart';

/// PatientRepository
///
/// All patient data flows through here. Screens and providers never call
/// the API directly or touch LocalDatabase directly.
///
/// ── CACHE STRATEGY ──────────────────────────────────────────────────────────
///
/// Every method that reads data follows the cache-first pattern:
///
///   1. If the cache is fresh (< 15 min old) and we're offline, return cache.
///   2. If we're online, try the API. On success, update the cache.
///   3. If the API fails (network error) AND we have cached data, return cache
///      and set [isFromCache = true] on the result.
///   4. If the API fails AND there is no cache, rethrow so the UI shows an error.
///
/// Write operations (create, update, delete) always go to the API first.
/// On success, the local cache is updated immediately so the UI is consistent
/// without needing a full refresh.
///
class PatientRepository {
  final ApiClient apiClient;
  final LocalDatabase _db;

  PatientRepository({
    required this.apiClient,
    LocalDatabase? localDatabase,
  }) : _db = localDatabase ?? LocalDatabase.instance;

  // ── READ ───────────────────────────────────────────────────────────────────

  /// Fetch patients for the authenticated provider.
  /// Returns a [PatientsResult] that carries both the list and a flag
  /// indicating whether the data came from the cache.
  Future<PatientsResult> getPatients({
    String? providerId,
    int page = 1,
    int perPage = 25,
    bool forceRefresh = false,
  }) async {
    // If caller wants fresh data, skip cache check
    if (!forceRefresh && providerId != null) {
      final isStale = await _db.isCacheStale(providerId);
      if (!isStale) {
        final cached = await _db.getPatients(
          providerId: providerId,
          limit: perPage,
          offset: (page - 1) * perPage,
        );
        if (cached.isNotEmpty) {
          return PatientsResult(patients: cached, isFromCache: true);
        }
      }
    }

    try {
      final response = await apiClient.get(
        '/patients',
        queryParameters: {
          'page': page,
          'per_page': perPage,
          'paginate': true,
        },
      );

      if (response['success'] != true) {
        throw Exception(response['message'] ?? 'Failed to load patients');
      }

      // Laravel paginatedResponse puts the paginator inside 'data'
      final rawData = response['data'];
      final paginator = rawData is Map<String, dynamic> && rawData.containsKey('data')
          ? PaginatedPatientResponse.fromJson(
              Map<String, dynamic>.from(rawData))
          : PaginatedPatientResponse(
              data: (rawData as List? ?? [])
                  .map((e) => PatientModel.fromJson(
                      Map<String, dynamic>.from(e as Map)))
                  .toList(),
              currentPage: 1,
              perPage: perPage,
              total: (rawData as List? ?? []).length,
              lastPage: 1,
            );

      // Cache the first page (most recent patients)
      if (page == 1 && providerId != null) {
        await _db.replacePatients(providerId, paginator.data);
      }

      return PatientsResult(
        patients: paginator.data,
        total: paginator.total,
        hasMore: paginator.hasMore,
        isFromCache: false,
      );
    } catch (e) {
      // API failed — try the cache as a fallback
      if (providerId != null) {
        final cached = await _db.getPatients(
          providerId: providerId,
          limit: perPage,
          offset: (page - 1) * perPage,
        );
        if (cached.isNotEmpty) {
          return PatientsResult(patients: cached, isFromCache: true);
        }
      }
      rethrow;
    }
  }

  /// Search patients. Uses the API when online; falls back to SQLite LIKE
  /// search when offline.
  Future<PatientsResult> searchPatients({
    required String query,
    String searchBy = 'name',
    String? providerId,
    int page = 1,
    int perPage = 25,
  }) async {
    try {
      final response = await apiClient.get(
        '/patients/search',
        queryParameters: {
          'q': query,
          'search_by': searchBy,
          'page': page,
          'per_page': perPage,
        },
      );

      if (response['success'] != true) {
        throw Exception(response['message'] ?? 'Search failed');
      }

      final rawData = response['data'];
      final paginator = rawData is Map<String, dynamic> && rawData.containsKey('data')
          ? PaginatedPatientResponse.fromJson(Map<String, dynamic>.from(rawData))
          : PaginatedPatientResponse(
              data: (rawData as List? ?? [])
                  .map((e) => PatientModel.fromJson(
                      Map<String, dynamic>.from(e as Map)))
                  .toList(),
              currentPage: 1,
              perPage: perPage,
              total: (rawData as List? ?? []).length,
              lastPage: 1,
            );

      return PatientsResult(
        patients: paginator.data,
        total: paginator.total,
        hasMore: paginator.hasMore,
        isFromCache: false,
      );
    } catch (_) {
      // Offline fallback — SQLite LIKE search
      if (providerId != null) {
        final cached = await _db.getPatients(
          providerId: providerId,
          searchTerm: query,
          limit: perPage,
          offset: (page - 1) * perPage,
        );
        return PatientsResult(patients: cached, isFromCache: true);
      }
      rethrow;
    }
  }

  /// Get a single patient by ID. Tries cache first if [fromCacheFirst] is true.
  Future<PatientModel?> getPatient(
    String patientId, {
    bool fromCacheFirst = false,
  }) async {
    if (fromCacheFirst) {
      final cached = await _db.getPatient(patientId);
      if (cached != null) return cached;
    }

    try {
      final response = await apiClient.get('/patients/$patientId');
      if (response['success'] != true) {
        throw Exception(response['message'] ?? 'Failed to load patient');
      }
      final patient = PatientModel.fromJson(
          Map<String, dynamic>.from(response['data'] as Map));
      await _db.upsertPatient(patient);
      return patient;
    } catch (_) {
      return _db.getPatient(patientId); // cache fallback
    }
  }

  // ── WRITE ──────────────────────────────────────────────────────────────────

  Future<PatientModel> createPatient(Map<String, dynamic> data) async {
    final response = await apiClient.post('/patients', data: data);
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to create patient');
    }
    final patient =
        PatientModel.fromJson(Map<String, dynamic>.from(response['data'] as Map));
    await _db.upsertPatient(patient);
    return patient;
  }

  Future<PatientModel> updatePatient(
    String patientId,
    Map<String, dynamic> data,
  ) async {
    final response = await apiClient.patch('/patients/$patientId', data: data);
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to update patient');
    }
    final patient =
        PatientModel.fromJson(Map<String, dynamic>.from(response['data'] as Map));
    await _db.upsertPatient(patient);
    return patient;
  }

  Future<void> deletePatient(String patientId) async {
    final response = await apiClient.delete('/patients/$patientId');
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to delete patient');
    }
    await _db.markPatientInactive(patientId);
  }

  // ── STATS ──────────────────────────────────────────────────────────────────

  /// Derive dashboard stats from the local cache.
  /// These are counts only — no PII leaves the cache.
  Future<DashboardStatsModel> getDashboardStats(String providerId) async {
    final total  = await _db.getPatientCount(providerId);
    final recent = await _db.getRecentPatientCount(providerId, days: 7);
    final lastFetched = await _db.patientsLastFetched(providerId);

    return DashboardStatsModel(
      totalPatients:  total,
      activePatients: total, // active = total in Phase 2 (soft-deleted are excluded)
      recentPatients: recent,
      lastRefreshed:  lastFetched,
      isFromCache:    true,
    );
  }

  // ── CACHE MANAGEMENT ──────────────────────────────────────────────────────

  /// Clear cache for a specific provider — call on logout.
  Future<void> clearCache(String providerId) async {
    await _db.clearProviderData(providerId);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PatientsResult — value object returned by read methods
// ─────────────────────────────────────────────────────────────────────────────

class PatientsResult {
  final List<PatientModel> patients;
  final int total;
  final bool hasMore;
  final bool isFromCache;

  const PatientsResult({
    required this.patients,
    this.total = 0,
    this.hasMore = false,
    required this.isFromCache,
  });
}