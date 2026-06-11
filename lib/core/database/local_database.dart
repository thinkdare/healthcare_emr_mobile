import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:path/path.dart' as path_helper;
import '../../data/models/clinical_models.dart';
import '../../data/models/clinical_record_models.dart';
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
/// 2. Encrypted on mobile (Android + iOS) via SQLCipher.
///    A 32-byte random key is generated once and stored in
///    `flutter_secure_storage` under [_kEncryptionKeyName]. On first open
///    after an upgrade from a plaintext install, opening with the key will
///    throw; the plaintext file is deleted and a fresh encrypted DB is
///    created. Cache data re-syncs from the server automatically.
///    Desktop builds use the sqflite_common_ffi factory (no encryption)
///    since those run in a trusted dev environment.
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
  static const int _kVersion = 3;
  static const String _kEncryptionKeyName = 'db_encryption_key_v1';
  static const String _kMigrationPendingSyncKey = 'db_migration_pending_sync';

  // Singleton
  static LocalDatabase? _instance;
  static Database? _db;

  final _secureStorage = const FlutterSecureStorage(
    iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device),
  );

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

    // Web: sqflite has no web support; open without encryption.
    // Desktop: sqflite_common_ffi factory (set in main.dart); no encryption.
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return openDatabase(
        fullPath,
        version: _kVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onOpen: (db) async => db.rawQuery('PRAGMA journal_mode=WAL'),
      );
    }

    // Mobile: SQLCipher-encrypted database.
    final key = await _getOrCreateKey();
    return _openEncrypted(fullPath, key);
  }

  Future<Database> _openEncrypted(String path, String key) async {
    try {
      return await openDatabase(
        path,
        password: key,
        version: _kVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        // Enable WAL mode for better concurrent read performance and crash safety.
        // PRAGMA journal_mode returns a result row, so rawQuery is required —
        // execute() is rejected by sqflite on Android for statements with output.
        onOpen: (db) async => db.rawQuery('PRAGMA journal_mode=WAL'),
      );
    } catch (_) {
      // Pre-existing plaintext DB from a prior install; opening with a key
      // throws a "file is not a database" error. The cache is not authoritative
      // (all data re-syncs from the server), so delete and recreate encrypted.
      // Write a persistent flag before deletion so the sync layer can surface
      // a "please stay connected" banner until the first full sync completes.
      try {
        await _secureStorage.write(
          key: _kMigrationPendingSyncKey,
          value: DateTime.now().toIso8601String(),
        );
      } catch (_) {}
      try {
        await File(path).delete();
      } catch (_) {}
      return openDatabase(
        path,
        password: key,
        version: _kVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onOpen: (db) async => db.rawQuery('PRAGMA journal_mode=WAL'),
      );
    }
  }

  /// True if the DB was wiped and re-created encrypted on this install.
  /// Remains true until a successful full server sync clears it.
  Future<bool> isMigrationPendingSync() async {
    final val = await _secureStorage.read(key: _kMigrationPendingSyncKey);
    return val != null;
  }

  Future<void> clearMigrationPendingSync() async {
    await _secureStorage.delete(key: _kMigrationPendingSyncKey);
  }

  Future<String> _getOrCreateKey() async {
    final existing = await _secureStorage.read(key: _kEncryptionKeyName);
    if (existing != null) return existing;
    final bytes = List<int>.generate(32, (_) => Random.secure().nextInt(256));
    final newKey = base64Url.encode(bytes);
    await _secureStorage.write(key: _kEncryptionKeyName, value: newKey);
    return newKey;
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

  Future<void> _migrateV2toV3(Database db) async {
    // ── appointments_cache ─────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE IF NOT EXISTS appointments_cache (
        id                   TEXT PRIMARY KEY,
        patient_id           TEXT NOT NULL,
        provider_id          TEXT NOT NULL,
        appointment_date     TEXT NOT NULL,
        duration_minutes     INTEGER NOT NULL DEFAULT 30,
        appointment_type     TEXT NOT NULL,
        status               TEXT NOT NULL,
        reason               TEXT,
        notes                TEXT,
        cancellation_reason  TEXT,
        reminder_sent        INTEGER NOT NULL DEFAULT 0,
        checked_in_at        TEXT,
        completed_at         TEXT,
        ward_id              TEXT,
        created_at           TEXT,
        updated_at           TEXT,
        cached_at            TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_appts_patient ON appointments_cache(patient_id)',
    );

    // ── prescriptions_cache ────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE IF NOT EXISTS prescriptions_cache (
        id                         TEXT PRIMARY KEY,
        patient_id                 TEXT NOT NULL,
        prescriber_id              TEXT NOT NULL,
        medication_name            TEXT NOT NULL,
        medication_code            TEXT,
        dosage                     TEXT NOT NULL,
        frequency                  TEXT NOT NULL,
        route                      TEXT,
        duration_days              INTEGER,
        quantity                   INTEGER,
        refills_allowed            INTEGER NOT NULL DEFAULT 0,
        refills_remaining          INTEGER NOT NULL DEFAULT 0,
        prescribed_date            TEXT,
        start_date                 TEXT,
        end_date                   TEXT,
        expires_date               TEXT,
        status                     TEXT NOT NULL,
        special_instructions       TEXT,
        discontinuation_reason     TEXT,
        drug_interactions_checked  INTEGER NOT NULL DEFAULT 0,
        ward_id                    TEXT,
        medication_coding_system   TEXT,
        created_at                 TEXT,
        updated_at                 TEXT,
        cached_at                  TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_rx_patient ON prescriptions_cache(patient_id)',
    );

    // ── lab_results_cache ──────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE IF NOT EXISTS lab_results_cache (
        id                   TEXT PRIMARY KEY,
        patient_id           TEXT NOT NULL,
        ordered_by_id        TEXT NOT NULL,
        performed_by_id      TEXT,
        reviewed_by_id       TEXT,
        test_name            TEXT NOT NULL,
        test_code            TEXT,
        test_type            TEXT,
        priority             TEXT NOT NULL DEFAULT 'routine',
        results              TEXT,
        interpretation       TEXT,
        abnormal_flags       TEXT NOT NULL DEFAULT '[]',
        status               TEXT NOT NULL,
        ordered_date         TEXT,
        sample_collected_at  TEXT,
        completed_at         TEXT,
        reviewed_at          TEXT,
        file_path            TEXT,
        requires_followup    INTEGER NOT NULL DEFAULT 0,
        ward_id              TEXT,
        created_at           TEXT,
        updated_at           TEXT,
        cached_at            TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_labs_patient ON lab_results_cache(patient_id)',
    );

    // ── vitals_cache ───────────────────────────────────────────────────────
    // Not yet in backend SYNCABLE_RESOURCES; table ready for future inclusion.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS vitals_cache (
        id                         TEXT PRIMARY KEY,
        patient_id                 TEXT NOT NULL,
        recorded_by_id             TEXT NOT NULL,
        encounter_id               TEXT,
        roster_entry_id            TEXT,
        ward_id                    TEXT,
        recorded_at                TEXT NOT NULL,
        blood_pressure_systolic    INTEGER,
        blood_pressure_diastolic   INTEGER,
        heart_rate                 INTEGER,
        respiratory_rate           INTEGER,
        temperature                REAL,
        temperature_unit           TEXT,
        oxygen_saturation          REAL,
        weight                     REAL,
        weight_unit                TEXT,
        height                     REAL,
        height_unit                TEXT,
        bmi                        REAL,
        notes                      TEXT,
        version                    INTEGER NOT NULL DEFAULT 1,
        created_at                 TEXT,
        cached_at                  TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_vitals_patient ON vitals_cache(patient_id)',
    );

    // ── diagnoses_cache ────────────────────────────────────────────────────
    // Not yet in backend SYNCABLE_RESOURCES; table ready for future inclusion.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS diagnoses_cache (
        id              TEXT PRIMARY KEY,
        patient_id      TEXT NOT NULL,
        diagnosed_by_id TEXT NOT NULL,
        encounter_id    TEXT,
        ward_id         TEXT,
        icd_code        TEXT,
        icd_version     TEXT,
        description     TEXT NOT NULL,
        diagnosis_type  TEXT NOT NULL,
        status          TEXT NOT NULL,
        onset_date      TEXT,
        resolved_date   TEXT,
        notes           TEXT,
        version         INTEGER NOT NULL DEFAULT 1,
        created_at      TEXT,
        updated_at      TEXT,
        cached_at       TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_dx_patient ON diagnoses_cache(patient_id)',
    );
  }

  // ── Test helpers ───────────────────────────────────────────────────────────

  /// Opens an already-initialised [Database] as the singleton. For tests only.
  /// Callers must open the DB (e.g. via databaseFactoryFfi.openDatabase) and
  /// run schema creation via this method before using LocalDatabase.instance.
  @visibleForTesting
  static Future<LocalDatabase> forTesting(Database openedDb) async {
    final inst = LocalDatabase._();
    await inst._createV1Tables(openedDb);
    _instance = inst;
    _db = openedDb;
    return inst;
  }

  @visibleForTesting
  static Future<void> teardownForTesting() async {
    await _db?.close();
    _db = null;
    _instance = null;
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

    // Fresh installs also get v2 and v3 tables
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

  // ── APPOINTMENT DAO ────────────────────────────────────────────────────────

  Future<void> upsertAppointment(AppointmentModel a) async {
    final db = await database;
    await db.insert(
      'appointments_cache',
      _appointmentToRow(a),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<AppointmentModel>> getAppointmentsByPatient(
      String patientId) async {
    final db = await database;
    final rows = await db.query(
      'appointments_cache',
      where: 'patient_id = ?',
      whereArgs: [patientId],
      orderBy: 'appointment_date DESC',
    );
    return rows.map(_rowToAppointment).toList();
  }

  Future<void> deleteAppointment(String id) async {
    final db = await database;
    await db.delete('appointments_cache', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearAppointmentsForPatient(String patientId) async {
    final db = await database;
    await db.delete(
      'appointments_cache',
      where: 'patient_id = ?',
      whereArgs: [patientId],
    );
  }

  // ── PRESCRIPTION DAO ───────────────────────────────────────────────────────

  Future<void> upsertPrescription(PrescriptionModel rx) async {
    final db = await database;
    await db.insert(
      'prescriptions_cache',
      _prescriptionToRow(rx),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<PrescriptionModel>> getPrescriptionsByPatient(
      String patientId) async {
    final db = await database;
    final rows = await db.query(
      'prescriptions_cache',
      where: 'patient_id = ?',
      whereArgs: [patientId],
      orderBy: 'created_at DESC',
    );
    return rows.map(_rowToPrescription).toList();
  }

  Future<void> deletePrescription(String id) async {
    final db = await database;
    await db.delete('prescriptions_cache', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearPrescriptionsForPatient(String patientId) async {
    final db = await database;
    await db.delete(
      'prescriptions_cache',
      where: 'patient_id = ?',
      whereArgs: [patientId],
    );
  }

  // ── LAB RESULT DAO ─────────────────────────────────────────────────────────

  Future<void> upsertLabResult(LabResultModel lab) async {
    final db = await database;
    await db.insert(
      'lab_results_cache',
      _labResultToRow(lab),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<LabResultModel>> getLabResultsByPatient(
      String patientId) async {
    final db = await database;
    final rows = await db.query(
      'lab_results_cache',
      where: 'patient_id = ?',
      whereArgs: [patientId],
      orderBy: 'created_at DESC',
    );
    return rows.map(_rowToLabResult).toList();
  }

  Future<void> deleteLabResult(String id) async {
    final db = await database;
    await db.delete('lab_results_cache', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearLabResultsForPatient(String patientId) async {
    final db = await database;
    await db.delete(
      'lab_results_cache',
      where: 'patient_id = ?',
      whereArgs: [patientId],
    );
  }

  // ── VITAL SIGN DAO ─────────────────────────────────────────────────────────

  Future<void> upsertVitalSign(VitalSignModel v) async {
    final db = await database;
    await db.insert(
      'vitals_cache',
      _vitalSignToRow(v),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<VitalSignModel>> getVitalSignsByPatient(
      String patientId) async {
    final db = await database;
    final rows = await db.query(
      'vitals_cache',
      where: 'patient_id = ?',
      whereArgs: [patientId],
      orderBy: 'recorded_at DESC',
    );
    return rows.map(_rowToVitalSign).toList();
  }

  Future<void> clearVitalSignsForPatient(String patientId) async {
    final db = await database;
    await db.delete(
      'vitals_cache',
      where: 'patient_id = ?',
      whereArgs: [patientId],
    );
  }

  // ── DIAGNOSIS DAO ──────────────────────────────────────────────────────────

  Future<void> upsertDiagnosis(DiagnosisModel dx) async {
    final db = await database;
    await db.insert(
      'diagnoses_cache',
      _diagnosisToRow(dx),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<DiagnosisModel>> getDiagnosesByPatient(
      String patientId) async {
    final db = await database;
    final rows = await db.query(
      'diagnoses_cache',
      where: 'patient_id = ?',
      whereArgs: [patientId],
      orderBy: 'created_at DESC',
    );
    return rows.map(_rowToDiagnosis).toList();
  }

  Future<void> clearDiagnosesForPatient(String patientId) async {
    final db = await database;
    await db.delete(
      'diagnoses_cache',
      where: 'patient_id = ?',
      whereArgs: [patientId],
    );
  }

  // ── HOUSEKEEPING ──────────────────────────────────────────────────────────

  /// Clear all data for a specific provider — called on logout.
  Future<void> clearProviderData(String providerId) async {
    final db = await database;
    await db.transaction((txn) async {
      // Collect patient IDs first — before deleting the patients rows that
      // the clinical subquery depends on.
      final patientRows = await txn.query(
        'patients_cache',
        columns: ['id'],
        where: 'primary_provider_id = ?',
        whereArgs: [providerId],
      );
      final patientIds = patientRows.map((r) => r['id'] as String).toList();

      if (patientIds.isNotEmpty) {
        final placeholders = List.filled(patientIds.length, '?').join(',');
        for (final table in [
          'appointments_cache',
          'prescriptions_cache',
          'lab_results_cache',
          'vitals_cache',
          'diagnoses_cache',
        ]) {
          await txn.rawDelete(
            'DELETE FROM $table WHERE patient_id IN ($placeholders)',
            patientIds,
          );
        }
      }

      await txn.delete(
        'patients_cache',
        where: 'primary_provider_id = ?',
        whereArgs: [providerId],
      );
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
      for (final table in [
        'patients_cache',
        'appointments_cache',
        'prescriptions_cache',
        'lab_results_cache',
        'vitals_cache',
        'diagnoses_cache',
        'cache_metadata',
        'pending_sync',
      ]) {
        await txn.delete(table);
      }
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

  // ── APPOINTMENT SERIALISATION ─────────────────────────────────────────────

  Map<String, dynamic> _appointmentToRow(AppointmentModel a) => {
        'id':                  a.id,
        'patient_id':          a.patientId,
        'provider_id':         a.providerId,
        'appointment_date':    a.appointmentDate.toIso8601String(),
        'duration_minutes':    a.durationMinutes,
        'appointment_type':    a.appointmentType,
        'status':              a.status,
        'reason':              a.reason,
        'notes':               a.notes,
        'cancellation_reason': a.cancellationReason,
        'reminder_sent':       a.reminderSent ? 1 : 0,
        'checked_in_at':       a.checkedInAt?.toIso8601String(),
        'completed_at':        a.completedAt?.toIso8601String(),
        'ward_id':             a.wardId,
        'created_at':          a.createdAt?.toIso8601String(),
        'updated_at':          a.updatedAt?.toIso8601String(),
        'cached_at':           DateTime.now().toIso8601String(),
      };

  AppointmentModel _rowToAppointment(Map<String, dynamic> r) => AppointmentModel(
        id:                 r['id'] as String,
        patientId:          r['patient_id'] as String,
        providerId:         r['provider_id'] as String,
        appointmentDate:    DateTime.parse(r['appointment_date'] as String),
        durationMinutes:    r['duration_minutes'] as int? ?? 30,
        appointmentType:    r['appointment_type'] as String,
        status:             r['status'] as String,
        reason:             r['reason'] as String?,
        notes:              r['notes'] as String?,
        cancellationReason: r['cancellation_reason'] as String?,
        reminderSent:       (r['reminder_sent'] as int? ?? 0) == 1,
        checkedInAt:        _parseDate(r['checked_in_at']),
        completedAt:        _parseDate(r['completed_at']),
        wardId:             r['ward_id'] as String?,
        createdAt:          _parseDate(r['created_at']),
        updatedAt:          _parseDate(r['updated_at']),
      );

  // ── PRESCRIPTION SERIALISATION ─────────────────────────────────────────────

  Map<String, dynamic> _prescriptionToRow(PrescriptionModel rx) => {
        'id':                        rx.id,
        'patient_id':                rx.patientId,
        'prescriber_id':             rx.prescriberId,
        'medication_name':           rx.medicationName,
        'medication_code':           rx.medicationCode,
        'dosage':                    rx.dosage,
        'frequency':                 rx.frequency,
        'route':                     rx.route,
        'duration_days':             rx.durationDays,
        'quantity':                  rx.quantity,
        'refills_allowed':           rx.refillsAllowed,
        'refills_remaining':         rx.refillsRemaining,
        'prescribed_date':           rx.prescribedDate?.toIso8601String(),
        'start_date':                rx.startDate?.toIso8601String(),
        'end_date':                  rx.endDate?.toIso8601String(),
        'expires_date':              rx.expiresDate?.toIso8601String(),
        'status':                    rx.status,
        'special_instructions':      rx.specialInstructions,
        'discontinuation_reason':    rx.discontinuationReason,
        'drug_interactions_checked': rx.drugInteractionsChecked ? 1 : 0,
        'ward_id':                   rx.wardId,
        'medication_coding_system':  rx.medicationCodingSystem,
        'created_at':                rx.createdAt?.toIso8601String(),
        'updated_at':                rx.updatedAt?.toIso8601String(),
        'cached_at':                 DateTime.now().toIso8601String(),
      };

  PrescriptionModel _rowToPrescription(Map<String, dynamic> r) =>
      PrescriptionModel(
        id:                       r['id'] as String,
        patientId:                r['patient_id'] as String,
        prescriberId:             r['prescriber_id'] as String,
        medicationName:           r['medication_name'] as String,
        medicationCode:           r['medication_code'] as String?,
        dosage:                   r['dosage'] as String? ?? '',
        frequency:                r['frequency'] as String? ?? '',
        route:                    r['route'] as String?,
        durationDays:             r['duration_days'] as int?,
        quantity:                 r['quantity'] as int?,
        refillsAllowed:           r['refills_allowed'] as int? ?? 0,
        refillsRemaining:         r['refills_remaining'] as int? ?? 0,
        prescribedDate:           _parseDate(r['prescribed_date']),
        startDate:                _parseDate(r['start_date']),
        endDate:                  _parseDate(r['end_date']),
        expiresDate:              _parseDate(r['expires_date']),
        status:                   r['status'] as String? ?? 'active',
        specialInstructions:      r['special_instructions'] as String?,
        discontinuationReason:    r['discontinuation_reason'] as String?,
        drugInteractionsChecked:  (r['drug_interactions_checked'] as int? ?? 0) == 1,
        wardId:                   r['ward_id'] as String?,
        medicationCodingSystem:   r['medication_coding_system'] as String?,
        createdAt:                _parseDate(r['created_at']),
        updatedAt:                _parseDate(r['updated_at']),
      );

  // ── LAB RESULT SERIALISATION ───────────────────────────────────────────────

  Map<String, dynamic> _labResultToRow(LabResultModel lab) => {
        'id':                  lab.id,
        'patient_id':          lab.patientId,
        'ordered_by_id':       lab.orderedById,
        'performed_by_id':     lab.performedById,
        'reviewed_by_id':      lab.reviewedById,
        'test_name':           lab.testName,
        'test_code':           lab.testCode,
        'test_type':           lab.testType,
        'priority':            lab.priority,
        'results':             lab.results,
        'interpretation':      lab.interpretation,
        'abnormal_flags':      jsonEncode(lab.abnormalFlags),
        'status':              lab.status,
        'ordered_date':        lab.orderedDate?.toIso8601String(),
        'sample_collected_at': lab.sampleCollectedAt?.toIso8601String(),
        'completed_at':        lab.completedAt?.toIso8601String(),
        'reviewed_at':         lab.reviewedAt?.toIso8601String(),
        'file_path':           lab.filePath,
        'requires_followup':   lab.requiresFollowup ? 1 : 0,
        'ward_id':             lab.wardId,
        'created_at':          lab.createdAt?.toIso8601String(),
        'updated_at':          lab.updatedAt?.toIso8601String(),
        'cached_at':           DateTime.now().toIso8601String(),
      };

  LabResultModel _rowToLabResult(Map<String, dynamic> r) {
    List<String> flags = [];
    try {
      final raw = jsonDecode(r['abnormal_flags'] as String? ?? '[]') as List;
      flags = raw.map((e) => e as String).toList();
    } catch (_) {}

    return LabResultModel(
      id:                 r['id'] as String,
      patientId:          r['patient_id'] as String,
      orderedById:        r['ordered_by_id'] as String,
      performedById:      r['performed_by_id'] as String?,
      reviewedById:       r['reviewed_by_id'] as String?,
      testName:           r['test_name'] as String,
      testCode:           r['test_code'] as String?,
      testType:           r['test_type'] as String?,
      priority:           r['priority'] as String? ?? 'routine',
      results:            r['results'] as String?,
      interpretation:     r['interpretation'] as String?,
      abnormalFlags:      flags,
      status:             r['status'] as String? ?? 'pending',
      orderedDate:        _parseDate(r['ordered_date']),
      sampleCollectedAt:  _parseDate(r['sample_collected_at']),
      completedAt:        _parseDate(r['completed_at']),
      reviewedAt:         _parseDate(r['reviewed_at']),
      filePath:           r['file_path'] as String?,
      requiresFollowup:   (r['requires_followup'] as int? ?? 0) == 1,
      wardId:             r['ward_id'] as String?,
      createdAt:          _parseDate(r['created_at']),
      updatedAt:          _parseDate(r['updated_at']),
    );
  }

  // ── VITAL SIGN SERIALISATION ───────────────────────────────────────────────

  Map<String, dynamic> _vitalSignToRow(VitalSignModel v) => {
        'id':                       v.id,
        'patient_id':               v.patientId,
        'recorded_by_id':           v.recordedById,
        'encounter_id':             v.encounterId,
        'roster_entry_id':          v.rosterEntryId,
        'ward_id':                  v.wardId,
        'recorded_at':              v.recordedAt.toIso8601String(),
        'blood_pressure_systolic':  v.bloodPressureSystolic,
        'blood_pressure_diastolic': v.bloodPressureDiastolic,
        'heart_rate':               v.heartRate,
        'respiratory_rate':         v.respiratoryRate,
        'temperature':              v.temperature,
        'temperature_unit':         v.temperatureUnit,
        'oxygen_saturation':        v.oxygenSaturation,
        'weight':                   v.weight,
        'weight_unit':              v.weightUnit,
        'height':                   v.height,
        'height_unit':              v.heightUnit,
        'bmi':                      v.bmi,
        'notes':                    v.notes,
        'version':                  v.version,
        'created_at':               v.createdAt?.toIso8601String(),
        'cached_at':                DateTime.now().toIso8601String(),
      };

  VitalSignModel _rowToVitalSign(Map<String, dynamic> r) => VitalSignModel(
        id:                      r['id'] as String,
        patientId:               r['patient_id'] as String,
        recordedById:            r['recorded_by_id'] as String,
        encounterId:             r['encounter_id'] as String?,
        rosterEntryId:           r['roster_entry_id'] as String?,
        wardId:                  r['ward_id'] as String?,
        recordedAt:              DateTime.parse(r['recorded_at'] as String),
        bloodPressureSystolic:   r['blood_pressure_systolic'] as int?,
        bloodPressureDiastolic:  r['blood_pressure_diastolic'] as int?,
        heartRate:               r['heart_rate'] as int?,
        respiratoryRate:         r['respiratory_rate'] as int?,
        temperature:             r['temperature'] as double?,
        temperatureUnit:         r['temperature_unit'] as String?,
        oxygenSaturation:        r['oxygen_saturation'] as double?,
        weight:                  r['weight'] as double?,
        weightUnit:              r['weight_unit'] as String?,
        height:                  r['height'] as double?,
        heightUnit:              r['height_unit'] as String?,
        bmi:                     r['bmi'] as double?,
        notes:                   r['notes'] as String?,
        version:                 r['version'] as int? ?? 1,
        createdAt:               _parseDate(r['created_at']),
      );

  // ── DIAGNOSIS SERIALISATION ────────────────────────────────────────────────

  Map<String, dynamic> _diagnosisToRow(DiagnosisModel dx) => {
        'id':              dx.id,
        'patient_id':      dx.patientId,
        'diagnosed_by_id': dx.diagnosedById,
        'encounter_id':    dx.encounterId,
        'ward_id':         dx.wardId,
        'icd_code':        dx.icdCode,
        'icd_version':     dx.icdVersion,
        'description':     dx.description,
        'diagnosis_type':  dx.diagnosisType,
        'status':          dx.status,
        'onset_date':      dx.onsetDate?.toIso8601String(),
        'resolved_date':   dx.resolvedDate?.toIso8601String(),
        'notes':           dx.notes,
        'version':         dx.version,
        'created_at':      dx.createdAt?.toIso8601String(),
        'updated_at':      dx.updatedAt?.toIso8601String(),
        'cached_at':       DateTime.now().toIso8601String(),
      };

  DiagnosisModel _rowToDiagnosis(Map<String, dynamic> r) => DiagnosisModel(
        id:             r['id'] as String,
        patientId:      r['patient_id'] as String,
        diagnosedById:  r['diagnosed_by_id'] as String,
        encounterId:    r['encounter_id'] as String?,
        wardId:         r['ward_id'] as String?,
        icdCode:        r['icd_code'] as String?,
        icdVersion:     r['icd_version'] as String?,
        description:    r['description'] as String,
        diagnosisType:  r['diagnosis_type'] as String? ?? 'primary',
        status:         r['status'] as String? ?? 'active',
        onsetDate:      _parseDate(r['onset_date']),
        resolvedDate:   _parseDate(r['resolved_date']),
        notes:          r['notes'] as String?,
        version:        r['version'] as int? ?? 1,
        createdAt:      _parseDate(r['created_at']),
        updatedAt:      _parseDate(r['updated_at']),
      );

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