import 'dart:convert';
import 'dart:io' show File, Platform;
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' as sqlcipher;
import 'package:path/path.dart' as path_helper;
import '../../data/models/patient_models.dart';
import '../../data/models/clinical_record_models.dart';

/// LocalDatabase
///
/// Single source of truth for the SQLite cache. All table definitions,
/// migrations, and data-access operations live here. Screens and providers
/// never touch the Database object directly — they go through this class.
///
/// ── DESIGN DECISIONS ──────────────────────────────────────────────────────
///
/// 1. ONE database file per app install.
///    Multi-user support (multiple providers logging in on the same device)
///    is handled by scoping every query on provider_id.
///
/// 2. Encrypted on iOS/Android, plaintext on desktop.
///    `sqflite_sqlcipher` only ships native SQLCipher builds for iOS and
///    Android — there is no currently-maintained package providing prebuilt
///    SQLCipher binaries for Linux/macOS/Windows (sqlcipher_flutter_libs,
///    the package that used to fill this gap, is an obsolete no-op as of
///    0.7.0 per its own README). Desktop therefore stays on the plaintext
///    sqflite_common_ffi path already wired in main.dart — the same
///    device-level-encryption mitigation this class used everywhere before
///    this migration (iOS Data Protection / Android Full Disk Encryption /
///    OS-level disk encryption on desktop). iOS/Android are the platforms
///    the product's actual "cached PHI on a ward device" threat model is
///    about, so this isn't a corner cut on the scenario that matters — it's
///    a real ecosystem limit on the scenario that's secondary (dev/desktop
///    convenience builds).
///
/// 3. Migration from the pre-encryption plaintext DB is NOT a wipe.
///    See [_migrateFromLegacyPlaintextDb] — the old cache tables are
///    discarded (safe: read-only, refetched from the server), but any rows
///    in pending_sync (a clinician's not-yet-synced offline writes) are
///    carried over into the new encrypted file before the old one is
///    deleted. Silently discarding a queued offline vital sign or diagnosis
///    on an app update would be a real clinical-data-loss bug, not just a
///    cache miss.
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
  static const String _kLegacyPlaintextDatabaseName = 'emr_cache.db';
  static const String _kEncryptedDatabaseName = 'emr_cache_v2.db';
  static const int _kVersion = 3;
  static const _kEncryptionKeyStorageKey = 'local_db_encryption_key';

  static const _secureStorage = FlutterSecureStorage();

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

  bool get _supportsEncryption =>
      !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  Future<Database> _open() async {
    if (!_supportsEncryption) {
      // Desktop/test — unchanged plaintext path via whatever databaseFactory
      // main.dart configured (sqflite_common_ffi off-device).
      final dbPath = await getDatabasesPath();
      final fullPath = path_helper.join(dbPath, _kLegacyPlaintextDatabaseName);
      return openDatabase(
        fullPath,
        version: _kVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onOpen: (db) async => await db.rawQuery('PRAGMA journal_mode=WAL'),
      );
    }

    final dbPath = await getDatabasesPath();
    final encryptedPath = path_helper.join(dbPath, _kEncryptedDatabaseName);
    final legacyPath = path_helper.join(dbPath, _kLegacyPlaintextDatabaseName);

    if (!await File(encryptedPath).exists() && await File(legacyPath).exists()) {
      await _migrateFromLegacyPlaintextDb(legacyPath, encryptedPath);
    }

    final key = await _getOrCreateEncryptionKey();

    return sqlcipher.openDatabase(
      encryptedPath,
      password: key,
      version: _kVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      // Enable WAL mode for better concurrent read performance and crash safety.
      // PRAGMA journal_mode returns a result row, so rawQuery is required —
      // execute() is rejected by sqflite on Android for statements with output.
      onOpen: (db) async => await db.rawQuery('PRAGMA journal_mode=WAL'),
    );
  }

  /// Carries pending_sync rows from the old plaintext DB into a fresh
  /// encrypted one, then deletes the old file. Everything else in the old
  /// DB (patients/vitals/diagnoses cache, cache_metadata) is left behind —
  /// it's read-only cache data that gets refetched from the server on the
  /// next load, unlike pending_sync which represents real unsynced writes.
  Future<void> _migrateFromLegacyPlaintextDb(
    String legacyPath,
    String encryptedPath,
  ) async {
    List<Map<String, Object?>> pendingRows = [];
    try {
      final legacyDb = await openDatabase(legacyPath, readOnly: true);
      try {
        pendingRows = await legacyDb.query('pending_sync');
      } finally {
        await legacyDb.close();
      }
    } catch (_) {
      // Legacy DB unreadable/corrupt — nothing to carry over, proceed to
      // create a fresh encrypted DB rather than blocking startup on it.
      pendingRows = [];
    }

    final key = await _getOrCreateEncryptionKey();
    final encryptedDb = await sqlcipher.openDatabase(
      encryptedPath,
      password: key,
      version: _kVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    if (pendingRows.isNotEmpty) {
      final batch = encryptedDb.batch();
      for (final row in pendingRows) {
        batch.insert('pending_sync', row,
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    }
    await encryptedDb.close();

    try {
      await File(legacyPath).delete();
    } catch (_) {
      // Non-fatal — worst case the old plaintext file lingers unused on disk.
    }
  }

  Future<String> _getOrCreateEncryptionKey() async {
    final existing = await _secureStorage.read(key: _kEncryptionKeyStorageKey);
    if (existing != null) return existing;

    final random = Random.secure();
    final keyBytes = List<int>.generate(32, (_) => random.nextInt(256));
    final key = base64UrlEncode(keyBytes);
    await _secureStorage.write(key: _kEncryptionKeyStorageKey, value: key);
    return key;
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createV1Tables(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) await _migrateV1toV2(db);
    if (oldVersion < 3) await _migrateV2toV3(db);
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

  /// Offline caching for vitals and diagnoses — scoped to these two
  /// resource types deliberately (not the full clinical domain). Both are
  /// clinician-authored, low-conflict-risk, append-mostly data with a
  /// straightforward version-based conflict story; prescriptions/labs/
  /// appointments are a different risk class (clinical-safety adjudication,
  /// device-sourced data, facility-wide scheduling conflicts respectively)
  /// and are deliberately left online-only for now.
  ///
  /// Full records are stored as a JSON blob (data_json) rather than mapped
  /// to individual columns — unlike patients_cache, nothing here needs
  /// field-level SQL search, so a blob avoids ~20 columns of mapping code
  /// per resource type that would just drift from the model over time.
  Future<void> _migrateV2toV3(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS vitals_cache (
        id           TEXT PRIMARY KEY,
        patient_id   TEXT NOT NULL,
        recorded_at  TEXT NOT NULL,
        version      INTEGER NOT NULL DEFAULT 1,
        data_json    TEXT NOT NULL,
        cached_at    TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_vitals_patient
        ON vitals_cache(patient_id)
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS diagnoses_cache (
        id           TEXT PRIMARY KEY,
        patient_id   TEXT NOT NULL,
        created_at   TEXT,
        version      INTEGER NOT NULL DEFAULT 1,
        data_json    TEXT NOT NULL,
        cached_at    TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_diagnoses_patient
        ON diagnoses_cache(patient_id)
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

    // Fresh installs also get the v2/v3 tables
    await _migrateV1toV2(db);
    await _migrateV2toV3(db);
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

  // ── VITALS DAO ─────────────────────────────────────────────────────────────

  Future<void> replaceVitals(String patientId, List<VitalSignModel> vitals) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      await txn.delete('vitals_cache', where: 'patient_id = ?', whereArgs: [patientId]);
      final batch = txn.batch();
      for (final v in vitals) {
        batch.insert('vitals_cache', _vitalToRow(v, now), conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> upsertVital(VitalSignModel vital) async {
    final db = await database;
    await db.insert(
      'vitals_cache',
      _vitalToRow(vital, DateTime.now().toIso8601String()),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteVitalFromCache(String id) async {
    final db = await database;
    await db.delete('vitals_cache', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<VitalSignModel>> getCachedVitals(String patientId) async {
    final db = await database;
    final rows = await db.query(
      'vitals_cache',
      where: 'patient_id = ?',
      whereArgs: [patientId],
      orderBy: 'recorded_at DESC',
    );
    return rows
        .map((r) => VitalSignModel.fromJson(
            Map<String, dynamic>.from(jsonDecode(r['data_json'] as String) as Map)))
        .toList();
  }

  Map<String, dynamic> _vitalToRow(VitalSignModel v, String cachedAt) => {
        'id': v.id,
        'patient_id': v.patientId,
        'recorded_at': v.recordedAt.toIso8601String(),
        'version': v.version,
        'data_json': jsonEncode(v.toJson()),
        'cached_at': cachedAt,
      };

  // ── DIAGNOSES DAO ──────────────────────────────────────────────────────────

  Future<void> replaceDiagnoses(String patientId, List<DiagnosisModel> diagnoses) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      await txn.delete('diagnoses_cache', where: 'patient_id = ?', whereArgs: [patientId]);
      final batch = txn.batch();
      for (final d in diagnoses) {
        batch.insert('diagnoses_cache', _diagnosisToRow(d, now), conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> upsertDiagnosis(DiagnosisModel diagnosis) async {
    final db = await database;
    await db.insert(
      'diagnoses_cache',
      _diagnosisToRow(diagnosis, DateTime.now().toIso8601String()),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteDiagnosisFromCache(String id) async {
    final db = await database;
    await db.delete('diagnoses_cache', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<DiagnosisModel>> getCachedDiagnoses(String patientId) async {
    final db = await database;
    final rows = await db.query(
      'diagnoses_cache',
      where: 'patient_id = ?',
      whereArgs: [patientId],
      orderBy: 'created_at DESC',
    );
    return rows
        .map((r) => DiagnosisModel.fromJson(
            Map<String, dynamic>.from(jsonDecode(r['data_json'] as String) as Map)))
        .toList();
  }

  Map<String, dynamic> _diagnosisToRow(DiagnosisModel d, String cachedAt) => {
        'id': d.id,
        'patient_id': d.patientId,
        'created_at': d.createdAt?.toIso8601String(),
        'version': d.version,
        'data_json': jsonEncode(d.toJson()),
        'cached_at': cachedAt,
      };

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
  /// vitals_cache/diagnoses_cache have no provider_id column (they're
  /// patient-scoped, not provider-scoped) — cleared in full, same as the
  /// patients_cache rows being clinical data with no reason to persist
  /// across a logout regardless of whose they were.
  Future<void> clearProviderData(String providerId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        'patients_cache',
        where: 'primary_provider_id = ?',
        whereArgs: [providerId],
      );
      await txn.delete('vitals_cache');
      await txn.delete('diagnoses_cache');
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
      await txn.delete('vitals_cache');
      await txn.delete('diagnoses_cache');
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