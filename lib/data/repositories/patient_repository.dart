import 'package:uuid/uuid.dart';
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
              total: (rawData ?? []).length,
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
    String? providerId,
    int page = 1,
    int perPage = 25,
  }) async {
    try {
      final response = await apiClient.get(
        '/patients',
        queryParameters: {
          'search': query,
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
              total: (rawData ?? []).length,
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

  Future<PatientModel> createPatient(
    Map<String, dynamic> data, {
    required String providerId,
  }) async {
    try {
      final response = await apiClient.post('/patients', data: data);
      if (response['success'] != true) {
        throw Exception(response['message'] ?? 'Failed to create patient');
      }
      final patient = PatientModel.fromJson(
          Map<String, dynamic>.from(response['data'] as Map));
      await _db.upsertPatient(patient);
      return patient;
    } catch (e) {
      if (_isNetworkError(e)) {
        // The server assigns ids on success, but there's no server
        // round-trip here — generate the id client-side and use it as the
        // actual eventual server id (see SyncController::createOfflinePatient()
        // on the backend, which creates the record with this exact id).
        // Without this, the patient would be invisible everywhere — not
        // shown locally (nothing was ever cached) and not created
        // server-side — until the device reconnects AND a pull() happens to
        // bring it back, which is what used to happen here.
        final newId = const Uuid().v4();

        final placeholder = PatientModel(
          id: newId,
          primaryProviderId: providerId,
          firstName: data['first_name'] as String,
          lastName: data['last_name'] as String,
          dateOfBirth: data['date_of_birth'] as String,
          gender: data['gender'] as String,
          bloodType: data['blood_type'] as String?,
          phone: data['phone'] as String?,
          email: data['email'] as String?,
          address: data['address'] as String?,
          emergencyContactName: data['emergency_contact_name'] as String? ?? '',
          emergencyContactPhone: data['emergency_contact_phone'] as String? ?? '',
          // Allergies in particular must never be silently dropped from the
          // local cache — a provider relying on the cached record while
          // still offline needs to see them, not just whatever syncs back
          // later.
          allergies: (data['allergies'] as List? ?? [])
              .map((a) => AllergyModel.fromJson(Map<String, dynamic>.from(a as Map)))
              .toList(),
          currentMedications: (data['current_medications'] as List? ?? [])
              .map((m) => MedicationModel.fromJson(Map<String, dynamic>.from(m as Map)))
              .toList(),
          chronicConditions: List<String>.from(data['chronic_conditions'] as List? ?? []),
          insuranceProvider: data['insurance_provider'] as String?,
          insuranceNumber: data['insurance_number'] as String?,
          medicalHistory: data['medical_history'] as String?,
        );
        await _db.upsertPatient(placeholder);

        await _queueOfflineWrite(
            operation: 'create', resourceId: newId, payload: data);
        throw Exception(
            'Offline — patient will be created when you reconnect.');
      }
      rethrow;
    }
  }

  Future<PatientModel> updatePatient(
    String patientId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response =
          await apiClient.put('/patients/$patientId', data: data);
      if (response['success'] != true) {
        throw Exception(response['message'] ?? 'Failed to update patient');
      }
      final patient = PatientModel.fromJson(
          Map<String, dynamic>.from(response['data'] as Map));
      await _db.upsertPatient(patient);
      return patient;
    } catch (e) {
      if (_isNetworkError(e)) {
        await _queueOfflineWrite(
            operation: 'update', resourceId: patientId, payload: data);
        throw Exception(
            'Offline — changes will sync when you reconnect.');
      }
      rethrow;
    }
  }

  Future<void> deletePatient(String patientId) async {
    final response = await apiClient.delete('/patients/$patientId');
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to delete patient');
    }
    await _db.markPatientInactive(patientId);
  }

  /// GET /patients/{id}/audit-log — primary provider or super_admin only.
  Future<List<Map<String, dynamic>>> getAuditLog(
    String patientId, {
    int page = 1,
    int perPage = 50,
  }) async {
    final response = await apiClient.get(
      '/patients/$patientId/audit-log',
      queryParameters: {'page': page, 'per_page': perPage},
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to load audit log');
    }
    final data = response['data'] as List? ?? [];
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// POST /patients/{id}/activate — Records department staff only. Sets
  /// record_status=active with a time-limited activation window.
  Future<Map<String, dynamic>> activatePatient(String patientId) async {
    final response = await apiClient.post('/patients/$patientId/activate');
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to activate patient record');
    }
    return Map<String, dynamic>.from(response['data'] as Map);
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

  // ── OFFLINE WRITE HELPERS ─────────────────────────────────────────────────

  Future<void> _queueOfflineWrite({
    required String operation,
    String? resourceId,
    required Map<String, dynamic> payload,
  }) async {
    await _db.queuePendingSync(
      id: const Uuid().v4(),
      resourceType: 'patients',
      resourceId: resourceId,
      operation: operation,
      payload: payload,
    );
  }

  bool _isNetworkError(Object e) {
    final msg = e.toString();
    return msg.contains('SocketException') ||
        msg.contains('Connection refused') ||
        msg.contains('Connection reset') ||
        msg.contains('Network is unreachable') ||
        msg.contains('HandshakeException');
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