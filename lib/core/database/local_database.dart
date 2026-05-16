import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path_helper;
import '../../data/models/patient_models.dart';

/// LocalDatabase
///
/// Single source of truth for the SQLite cache. All table definitions,
/// migrations, and data-access operations live here. Screens and providers
/// never touch the Database object directly — they go through this class.
///
/// ── DESIGN DECISIONS ──────────────────────────────────────────────────────
///
/// 1. ONE database file per app install.
///    The file is `emr_cache.db` in the app's documents directory.
///    Multi-user support (multiple providers logging in on the same device)
///    is handled by scoping every query on provider_id.
///
/// 2. Plaintext cache, not encrypted SQLite (Phase 2 scope).
///    The data stored here is the same PII that the server decrypts before
///    sending. Full SQLCipher encryption is Phase 7. For now we mitigate
///    risk by: (a) caching only the current provider's patients, (b) clearing
///    all data on logout, (c) relying on device-level encryption (iOS Data
///    Protection, Android Full Disk Encryption).
///
/// 3. Cache-only — no sync queue in Phase 2.
///    Writes go to the server first. On success, the cache is updated.
///    The sync queue (offline writes → server) is Phase 7.
///
/// 4. Version-based migrations.
///    Bump [_kVersion] and add a migration block in [_onUpgrade] when the
///    schema changes. Never alter existing columns — add new ones only.
///
/// 5. JSON columns for arrays.
///    allergies, current_medications, chronic_conditions are stored as JSON
///    strings because SQLite has no native array type. They are encoded on
///    write and decoded on read inside the DAO methods.
///
class LocalDatabase {
  static const String _kDatabaseName = 'emr_cache.db';
  static const int _kVersion = 2;

  // Singleton
  static LocalDatabase? _instance;
  static Database? _db;

  LocalDatabase._();

  static LocalDatabase get instance {
    _instance ??= LocalDatabase._();
    return _instance!;
  }

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final fullPath = path_helper.join(dbPath, _kDatabaseName);

    return openDatabase(
      fullPath,
      version: _kVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      // Enable WAL mode for better concurrent read performance and crash safety.
      // PRAGMA journal_mode returns a result row, so rawQuery is required —
      // execute() is rejected by sqflite on Android for statements with output.
      onOpen: (db) async => await db.rawQuery('PRAGMA journal_mode=WAL'),
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createV1Tables(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) await _migrateV1toV2(db);
  }

  Future<void> _migrateV1toV2(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pending_sync (
        id             TEXT PRIMARY KEY,
        resource_type  TEXT NOT NULL,
        resource_id    TEXT,
        operation      TEXT NOT NULL,
        payload        TEXT NOT NULL,
        client_version INTEGER NOT NULL DEFAULT 0,
        queued_at      TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createV1Tables(Database db) async {
    // ── patients_cache ─────────────────────────────────────────────────────
    // Mirrors the patient_records table on the server.
    // All columns are nullable except id and provider_id to allow partial
    // updates without overwriting fields we don't yet have locally.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS patients_cache (
        id                      TEXT PRIMARY KEY,
        primary_provider_id     TEXT NOT NULL,
        current_facility_id     TEXT,
        first_name              TEXT NOT NULL,
        last_name               TEXT NOT NULL,
        date_of_birth           TEXT NOT NULL,
        gender                  TEXT NOT NULL,
        blood_type              TEXT,
        phone                   TEXT,
        email                   TEXT,
        address                 TEXT,
        emergency_contact_name  TEXT NOT NULL,
        emergency_contact_phone TEXT NOT NULL,
        allergies               TEXT NOT NULL DEFAULT '[]',
        current_medications     TEXT NOT NULL DEFAULT '[]',
        chronic_conditions      TEXT NOT NULL DEFAULT '[]',
        insurance_provider      TEXT,
        insurance_number        TEXT,
        patient_portal_enabled  INTEGER NOT NULL DEFAULT 0,
        is_active               INTEGER NOT NULL DEFAULT 1,
        last_synced_at          TEXT,
        created_at              TEXT,
        updated_at              TEXT,
        primary_provider_json   TEXT,
        current_facility_json   TEXT,
        cached_at               TEXT NOT NULL
      )
    ''');

    // Index on provider_id — almost every query filters by this
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_patients_provider
        ON patients_cache(primary_provider_id)
    ''');

    // Index for name search (SQLite LIKE on these columns)
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_patients_name
        ON patients_cache(first_name, last_name)
    ''');

    // ── cache_metadata ─────────────────────────────────────────────────────
    // Lightweight key-value store for cache housekeeping.
    // Keys: 'patients_last_fetched_{providerId}', 'app_version', etc.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cache_metadata (
        key        TEXT PRIMARY KEY,
        value      TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Fresh installs also get the v2 table
    await _migrateV1toV2(db);
  }

  // ── PATIENT DAO ────────────────────────────────────────────────────────────

  /// Replace all cached patients for a provider with a fresh list from the API.
  /// Called after a successful full-page fetch.
  Future<void> replacePatients(
    String providerId,
    List<PatientModel> patients,
  ) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      // Remove stale rows for this provider only — don't touch other providers
      await txn.delete(
        'patients_cache',
        where: 'primary_provider_id = ?',
        whereArgs: [providerId],
      );

      // Bulk insert
      final batch = txn.batch();
      for (final patient in patients) {
        batch.insert(
          'patients_cache',
          _patientToRow(patient, now),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });

    // Record when we last refreshed this provider's patient list
    await setMetadata('patients_last_fetched_$providerId', now);
  }

  /// Upsert a single patient — used after create or update API calls.
  Future<void> upsertPatient(PatientModel patient) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.insert(
      'patients_cache',
      _patientToRow(patient, now),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Soft-remove a patient from the cache (mark inactive + set deleted flag).
  /// We don't physically delete because the record may still be needed for
  /// display in lists before the next full refresh.
  Future<void> markPatientInactive(String patientId) async {
    final db = await database;
    await db.update(
      'patients_cache',
      {'is_active': 0, 'cached_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [patientId],
    );
  }

  /// Get all active cached patients for a provider, optionally filtered.
  Future<List<PatientModel>> getPatients({
    required String providerId,
    String? searchTerm,
    bool activeOnly = true,
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await database;

    final conditions = <String>['primary_provider_id = ?'];
    final args = <dynamic>[providerId];

    if (activeOnly) {
      conditions.add('is_active = 1');
    }

    if (searchTerm != null && searchTerm.isNotEmpty) {
      // SQLite LIKE search — case-insensitive via LOWER()
      final term = '%${searchTerm.toLowerCase()}%';
      conditions.add(
        '(LOWER(first_name) LIKE ? OR LOWER(last_name) LIKE ? OR LOWER(email) LIKE ?)',
      );
      args.addAll([term, term, term]);
    }

    final where = conditions.join(' AND ');

    final rows = await db.query(
      'patients_cache',
      where: where,
      whereArgs: args,
      orderBy: 'last_name ASC, first_name ASC',
      limit: limit,
      offset: offset,
    );

    return rows.map(_rowToPatient).toList();
  }

  /// Get a single patient by ID.
  Future<PatientModel?> getPatient(String patientId) async {
    final db = await database;
    final rows = await db.query(
      'patients_cache',
      where: 'id = ?',
      whereArgs: [patientId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _rowToPatient(rows.first);
  }

  /// Total count of active patients for a provider — used in the stats card.
  Future<int> getPatientCount(String providerId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM patients_cache WHERE primary_provider_id = ? AND is_active = 1',
      [providerId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Count of patients created (cached_at) within the last N days.
  Future<int> getRecentPatientCount(String providerId, {int days = 7}) async {
    final db = await database;
    final since = DateTime.now().subtract(Duration(days: days)).toIso8601String();
    final result = await db.rawQuery(
      '''SELECT COUNT(*) as count FROM patients_cache
         WHERE primary_provider_id = ?
           AND is_active = 1
           AND created_at >= ?''',
      [providerId, since],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ── METADATA DAO ──────────────────────────────────────────────────────────

  Future<void> setMetadata(String key, String value) async {
    final db = await database;
    await db.insert(
      'cache_metadata',
      {
        'key': key,
        'value': value,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getMetadata(String key) async {
    final db = await database;
    final rows = await db.query(
      'cache_metadata',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  /// Returns the DateTime when patients were last fetched for this provider.
  Future<DateTime?> patientsLastFetched(String providerId) async {
    final raw = await getMetadata('patients_last_fetched_$providerId');
    if (raw == null) return null;
    try {
      return DateTime.parse(raw);
    } catch (_) {
      return null;
    }
  }

  /// True if the cache is stale — i.e. last fetch was more than [maxAge] ago.
  Future<bool> isCacheStale(
    String providerId, {
    Duration maxAge = const Duration(minutes: 15),
  }) async {
    final lastFetched = await patientsLastFetched(providerId);
    if (lastFetched == null) return true;
    return DateTime.now().difference(lastFetched) > maxAge;
  }

  // ── HOUSEKEEPING ──────────────────────────────────────────────────────────

  /// Clear all data for a specific provider — called on logout.
  Future<void> clearProviderData(String providerId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        'patients_cache',
        where: 'primary_provider_id = ?',
        whereArgs: [providerId],
      );
      // Remove provider-specific metadata keys
      await txn.delete(
        'cache_metadata',
        where: "key LIKE ?",
        whereArgs: ['%$providerId%'],
      );
    });
  }

  /// Wipe the entire cache — called when the user switches accounts or
  /// the APP_KEY changes (decryption would fail for stale data anyway).
  Future<void> clearAll() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('patients_cache');
      await txn.delete('cache_metadata');
    });
  }

  /// Close the database — call on app dispose.
  Future<void> close() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }

  // ── SERIALISATION HELPERS ────────────────────────────────────────────────

  Map<String, dynamic> _patientToRow(PatientModel p, String cachedAt) {
    return {
      'id':                      p.id,
      'primary_provider_id':     p.primaryProviderId,
      'current_facility_id':     p.currentFacilityId,
      'first_name':              p.firstName,
      'last_name':               p.lastName,
      'date_of_birth':           p.dateOfBirth,
      'gender':                  p.gender,
      'blood_type':              p.bloodType,
      'phone':                   p.phone,
      'email':                   p.email,
      'address':                 p.address,
      'emergency_contact_name':  p.emergencyContactName,
      'emergency_contact_phone': p.emergencyContactPhone,
      'allergies':               jsonEncode(p.allergies.map((a) => a.toJson()).toList()),
      'current_medications':     jsonEncode(p.currentMedications.map((m) => m.toJson()).toList()),
      'chronic_conditions':      jsonEncode(p.chronicConditions),
      'insurance_provider':      p.insuranceProvider,
      'insurance_number':        p.insuranceNumber,
      'patient_portal_enabled':  p.patientPortalEnabled ? 1 : 0,
      'is_active':               p.isActive ? 1 : 0,
      'last_synced_at':          p.lastSyncedAt?.toIso8601String(),
      'created_at':              p.createdAt?.toIso8601String(),
      'updated_at':              p.updatedAt?.toIso8601String(),
      'primary_provider_json':   p.primaryProvider != null
          ? jsonEncode(p.primaryProvider!.toJson())
          : null,
      'current_facility_json':   p.currentFacility != null
          ? jsonEncode(p.currentFacility!.toJson())
          : null,
      'cached_at':               cachedAt,
    };
  }

  PatientModel _rowToPatient(Map<String, dynamic> row) {
    List<AllergyModel> allergies = [];
    List<MedicationModel> medications = [];
    List<String> conditions = [];

    try {
      final allergyJson = jsonDecode(row['allergies'] as String? ?? '[]') as List;
      allergies = allergyJson
          .map((e) => AllergyModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {}

    try {
      final medJson =
          jsonDecode(row['current_medications'] as String? ?? '[]') as List;
      medications = medJson
          .map((e) => MedicationModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {}

    try {
      final condJson =
          jsonDecode(row['chronic_conditions'] as String? ?? '[]') as List;
      conditions = condJson.map((e) => e as String).toList();
    } catch (_) {}

    PatientProviderLite? provider;
    PatientFacilityLite? facility;

    try {
      final providerJson = row['primary_provider_json'] as String?;
      if (providerJson != null) {
        provider = PatientProviderLite.fromJson(
            Map<String, dynamic>.from(jsonDecode(providerJson) as Map));
      }
    } catch (_) {}

    try {
      final facilityJson = row['current_facility_json'] as String?;
      if (facilityJson != null) {
        facility = PatientFacilityLite.fromJson(
            Map<String, dynamic>.from(jsonDecode(facilityJson) as Map));
      }
    } catch (_) {}

    return PatientModel(
      id:                      row['id'] as String,
      primaryProviderId:       row['primary_provider_id'] as String,
      currentFacilityId:       row['current_facility_id'] as String?,
      firstName:               row['first_name'] as String,
      lastName:                row['last_name'] as String,
      dateOfBirth:             row['date_of_birth'] as String,
      gender:                  row['gender'] as String,
      bloodType:               row['blood_type'] as String?,
      phone:                   row['phone'] as String?,
      email:                   row['email'] as String?,
      address:                 row['address'] as String?,
      emergencyContactName:    row['emergency_contact_name'] as String,
      emergencyContactPhone:   row['emergency_contact_phone'] as String,
      allergies:               allergies,
      currentMedications:      medications,
      chronicConditions:       conditions,
      insuranceProvider:       row['insurance_provider'] as String?,
      insuranceNumber:         row['insurance_number'] as String?,
      patientPortalEnabled:    (row['patient_portal_enabled'] as int? ?? 0) == 1,
      isActive:                (row['is_active'] as int? ?? 1) == 1,
      lastSyncedAt:            _parseDate(row['last_synced_at']),
      createdAt:               _parseDate(row['created_at']),
      updatedAt:               _parseDate(row['updated_at']),
      primaryProvider:         provider,
      currentFacility:         facility,
    );
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    try {
      return DateTime.parse(value as String);
    } catch (_) {
      return null;
    }
  }

  // ── PENDING SYNC DAO ───────────────────────────────────────────────────────

  Future<void> queuePendingSync({
    required String id,
    required String resourceType,
    String? resourceId,
    required String operation,
    required Map<String, dynamic> payload,
    int clientVersion = 0,
  }) async {
    final db = await database;
    await db.insert(
      'pending_sync',
      {
        'id': id,
        'resource_type': resourceType,
        'resource_id': resourceId,
        'operation': operation,
        'payload': jsonEncode(payload),
        'client_version': clientVersion,
        'queued_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getPendingSyncItems() async {
    final db = await database;
    final rows = await db.query('pending_sync', orderBy: 'queued_at ASC');
    return rows.map((r) {
      final copy = Map<String, dynamic>.from(r);
      copy['payload'] = jsonDecode(r['payload'] as String);
      return copy;
    }).toList();
  }

  Future<void> removePendingSyncItem(String id) async {
    final db = await database;
    await db.delete('pending_sync', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getPendingSyncCount() async {
    final db = await database;
    final result =
        await db.rawQuery('SELECT COUNT(*) as count FROM pending_sync');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> clearPendingSync() async {
    final db = await database;
    await db.delete('pending_sync');
  }
}