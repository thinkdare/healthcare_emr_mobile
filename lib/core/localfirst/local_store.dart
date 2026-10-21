import 'dart:convert';

import 'package:sqflite_sqlcipher/sqflite.dart';

/// Per-user local database for the local-first write path (ADR 0001).
///
/// One file per user, never shared: switching users on a shared tablet must not
/// expose another user's cached PHI. In production the file is SQLCipher
/// encrypted with a key held in the OS keystore (see [LocalStoreFactory]); tests
/// open it unencrypted through the ffi factory.
///
/// Rules this class exists to make hard to break:
///  - a clinical write and its outbox entry are saved in ONE transaction
///    ([transaction]); the network is never on the write path;
///  - the UI reads only from here;
///  - the outbox keeps the EXACT serialised bytes of each entry and they are
///    retried unchanged (the server hashes a canonical form, but the client must
///    not rely on re-serialising being harmless).
class LocalStore {
  static const int schemaVersion = 1;

  /// Version stamped on every outbox entry. The server accepts the current and
  /// previous version; bump it when the entry format changes and add a migration
  /// for entries still queued by an older app.
  static const int outboxSchemaVersion = 1;

  static const String stateLocal = 'local';
  static const String stateSynced = 'synced';

  static const String outboxPending = 'pending';
  static const String outboxDeadLetter = 'dead_letter';

  final Database db;

  LocalStore._(this.db);

  /// Opens (creating if needed) the store at [path]. Pass [password] for
  /// SQLCipher on Android and iOS. Tests and desktop pass a [factory] (the ffi
  /// factory) and no password.
  static Future<LocalStore> open({required String path, String? password, DatabaseFactory? factory}) async {
    final Database database;
    if (factory != null) {
      database = await factory.openDatabase(
        path,
        options: OpenDatabaseOptions(version: schemaVersion, onCreate: _create, onOpen: _onOpen),
      );
    } else if (password == null) {
      database = await openDatabase(path, version: schemaVersion, onCreate: _create, onOpen: _onOpen);
    } else {
      database = await openDatabase(path, password: password, version: schemaVersion, onCreate: _create, onOpen: _onOpen);
    }
    return LocalStore._(database);
  }

  static Future<void> _onOpen(Database db) async {
    // PRAGMA journal_mode returns a row, so rawQuery (not execute).
    await db.rawQuery('PRAGMA journal_mode=WAL');
  }

  static Future<void> _create(Database db, int version) async {
    await db.execute('CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)');

    await db.execute('''
      CREATE TABLE vitals (
        id          TEXT PRIMARY KEY,
        patient_id  TEXT NOT NULL,
        recorded_at TEXT NOT NULL,
        data        TEXT NOT NULL,
        amends_id   TEXT,
        status      TEXT NOT NULL DEFAULT 'active',
        sync_state  TEXT NOT NULL,
        server_seq  INTEGER,
        created_at  TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX vitals_patient ON vitals (patient_id, recorded_at DESC)');

    // The outbox. `body` is the exact JSON text sent for this entry.
    await db.execute('''
      CREATE TABLE outbox (
        seq             INTEGER PRIMARY KEY AUTOINCREMENT,
        idempotency_key TEXT NOT NULL UNIQUE,
        schema_version  INTEGER NOT NULL,
        resource_type   TEXT NOT NULL,
        resource_id     TEXT NOT NULL,
        patient_id      TEXT NOT NULL,
        body            TEXT NOT NULL,
        state           TEXT NOT NULL,
        error           TEXT,
        retryable       INTEGER NOT NULL DEFAULT 0,
        attempts        INTEGER NOT NULL DEFAULT 0,
        created_at      TEXT NOT NULL,
        last_attempt_at TEXT
      )
    ''');
    await db.execute('CREATE INDEX outbox_state ON outbox (state, seq)');
    await db.execute('CREATE INDEX outbox_patient ON outbox (patient_id)');

    // Everything pulled that has no typed table yet (patients, appointments, ...).
    await db.execute('''
      CREATE TABLE records (
        resource   TEXT NOT NULL,
        id         TEXT NOT NULL,
        patient_id TEXT NOT NULL,
        seq        INTEGER NOT NULL,
        data       TEXT NOT NULL,
        PRIMARY KEY (resource, id)
      )
    ''');
    await db.execute('CREATE INDEX records_patient ON records (patient_id)');

    // Patients purged from this device whose removal the server has not yet
    // been told about. Sent as ack_removed on the next pull.
    await db.execute('CREATE TABLE scope_acks (patient_id TEXT PRIMARY KEY)');
  }

  Future<void> close() => db.close();

  /// All writes go through here so a record and its outbox entry commit together.
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) => db.transaction(action);

  // ── meta ──────────────────────────────────────────────────────────────────

  Future<String?> getMeta(String key, [DatabaseExecutor? e]) async {
    final rows = await (e ?? db).query('meta', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> setMeta(String key, String value, [DatabaseExecutor? e]) async {
    await (e ?? db).insert('meta', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> getCursor([DatabaseExecutor? e]) async => int.tryParse(await getMeta('cursor', e) ?? '') ?? 0;

  // ── vitals ────────────────────────────────────────────────────────────────

  /// Newest first. Includes entered-in-error readings (struck through in the UI).
  Future<List<Map<String, dynamic>>> vitalsFor(String patientId) async {
    final rows = await db.query('vitals', where: 'patient_id = ?', whereArgs: [patientId], orderBy: 'recorded_at DESC, created_at DESC');
    return rows.map(_vitalRow).toList();
  }

  Map<String, dynamic> _vitalRow(Map<String, Object?> r) {
    final data = Map<String, dynamic>.from(jsonDecode(r['data'] as String) as Map);
    data['id'] = r['id'];
    data['patient_id'] = r['patient_id'];
    data['amends_id'] = r['amends_id'];
    data['status'] = r['status'];
    data['_sync_state'] = r['sync_state'];
    return data;
  }

  Future<Map<String, dynamic>?> vitalById(String id, [DatabaseExecutor? e]) async {
    final rows = await (e ?? db).query('vitals', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : _vitalRow(rows.first);
  }

  Future<void> insertLocalVital(DatabaseExecutor e, Map<String, dynamic> vital, {required String createdAt}) async {
    await e.insert('vitals', {
      'id': vital['id'],
      'patient_id': vital['patient_id'],
      'recorded_at': vital['recorded_at'],
      'data': jsonEncode(vital),
      'amends_id': vital['amends_id'],
      'status': vital['status'] ?? 'active',
      'sync_state': stateLocal,
      'created_at': createdAt,
    });
  }

  /// Applies a vital received from the server. If the same id is still queued
  /// locally (the push succeeded but its response was lost) the outbox entry is
  /// retired: the server already has it.
  Future<void> upsertServerVital(DatabaseExecutor e, Map<String, dynamic> change) async {
    final data = Map<String, dynamic>.from(change['data'] as Map);
    final id = change['id'] as String;
    await e.insert(
      'vitals',
      {
        'id': id,
        'patient_id': change['patient_id'],
        'recorded_at': data['recorded_at'],
        'data': jsonEncode(data),
        'amends_id': data['amends_id'],
        'status': data['status'] ?? 'active',
        'sync_state': stateSynced,
        'server_seq': change['seq'],
        'created_at': data['created_at'] ?? data['recorded_at'],
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await e.delete('outbox', where: "resource_type = 'vitals' AND resource_id = ?", whereArgs: [id]);
  }

  Future<void> markVitalSynced(DatabaseExecutor e, String id) async {
    await e.update('vitals', {'sync_state': stateSynced}, where: 'id = ?', whereArgs: [id]);
  }

  // ── generic records ───────────────────────────────────────────────────────

  Future<void> upsertRecord(DatabaseExecutor e, Map<String, dynamic> change) async {
    await e.insert(
      'records',
      {
        'resource': change['resource'],
        'id': change['id'],
        'patient_id': change['patient_id'],
        'seq': change['seq'],
        'data': jsonEncode(change['data']),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteChange(DatabaseExecutor e, String resource, String id) async {
    if (resource == 'vitals') {
      // A tombstone for a vital the server removed. Local unsynced vitals are
      // never deleted by a tombstone for another id.
      await e.delete('vitals', where: 'id = ?', whereArgs: [id]);
    } else {
      await e.delete('records', where: 'resource = ? AND id = ?', whereArgs: [resource, id]);
    }
  }

  Future<List<Map<String, dynamic>>> recordsOf(String resource, {String? patientId}) async {
    final rows = await db.query(
      'records',
      where: patientId == null ? 'resource = ?' : 'resource = ? AND patient_id = ?',
      whereArgs: patientId == null ? [resource] : [resource, patientId],
    );
    return rows.map((r) => Map<String, dynamic>.from(jsonDecode(r['data'] as String) as Map)).toList();
  }

  // ── outbox ────────────────────────────────────────────────────────────────

  Future<void> enqueue(
    DatabaseExecutor e, {
    required String idempotencyKey,
    required String resourceType,
    required String resourceId,
    required String patientId,
    required String body,
    required String createdAt,
  }) async {
    await e.insert('outbox', {
      'idempotency_key': idempotencyKey,
      'schema_version': outboxSchemaVersion,
      'resource_type': resourceType,
      'resource_id': resourceId,
      'patient_id': patientId,
      'body': body,
      'state': outboxPending,
      'created_at': createdAt,
    });
  }

  /// Pending entries, oldest first. Dead-lettered entries are skipped, so a bad
  /// entry never blocks the ones behind it.
  Future<List<OutboxEntry>> pending({int limit = 50}) async {
    final rows = await db.query('outbox', where: 'state = ?', whereArgs: [outboxPending], orderBy: 'seq ASC', limit: limit);
    return rows.map(OutboxEntry.fromRow).toList();
  }

  Future<List<OutboxEntry>> deadLetters() async {
    final rows = await db.query('outbox', where: 'state = ?', whereArgs: [outboxDeadLetter], orderBy: 'seq ASC');
    return rows.map(OutboxEntry.fromRow).toList();
  }

  Future<void> completeEntry(DatabaseExecutor e, OutboxEntry entry) async {
    await e.delete('outbox', where: 'idempotency_key = ?', whereArgs: [entry.idempotencyKey]);
    if (entry.resourceType == 'vitals') await markVitalSynced(e, entry.resourceId);
  }

  Future<void> deadLetterEntry(DatabaseExecutor e, OutboxEntry entry, String error, {required bool retryable}) async {
    await e.update(
      'outbox',
      {'state': outboxDeadLetter, 'error': error, 'retryable': retryable ? 1 : 0},
      where: 'idempotency_key = ?',
      whereArgs: [entry.idempotencyKey],
    );
  }

  Future<void> recordAttempt(DatabaseExecutor e, Iterable<OutboxEntry> entries, String at) async {
    for (final entry in entries) {
      await e.rawUpdate(
        'UPDATE outbox SET attempts = attempts + 1, last_attempt_at = ? WHERE idempotency_key = ?',
        [at, entry.idempotencyKey],
      );
    }
  }

  /// Puts a retryable dead-lettered entry back in the queue (same bytes).
  Future<void> retryDeadLetter(String idempotencyKey) async {
    await db.update(
      'outbox',
      {'state': outboxPending, 'error': null},
      where: 'idempotency_key = ? AND state = ?',
      whereArgs: [idempotencyKey, outboxDeadLetter],
    );
  }

  /// Entries (pending or dead-lettered) that still hold unsynced data for the patient.
  Future<int> unsyncedCountFor(String patientId, [DatabaseExecutor? e]) async {
    final rows = await (e ?? db).rawQuery('SELECT COUNT(*) AS c FROM outbox WHERE patient_id = ?', [patientId]);
    return (rows.first['c'] as int?) ?? 0;
  }

  Future<OutboxStats> stats(DateTime now) async {
    final depth = await db.rawQuery('SELECT COUNT(*) AS c FROM outbox WHERE state = ?', [outboxPending]);
    final dead = await db.rawQuery('SELECT COUNT(*) AS c FROM outbox WHERE state = ?', [outboxDeadLetter]);
    final oldest = await db.rawQuery('SELECT MIN(created_at) AS t FROM outbox WHERE state = ?', [outboxPending]);
    final t = oldest.first['t'] as String?;
    return OutboxStats(
      pending: (depth.first['c'] as int?) ?? 0,
      deadLetters: (dead.first['c'] as int?) ?? 0,
      oldestPendingAge: t == null ? null : now.difference(DateTime.parse(t)),
    );
  }

  // ── scope ─────────────────────────────────────────────────────────────────

  /// Removes every locally held record for [patientId]. Callers must have
  /// checked that no unsynced writes exist for the patient.
  Future<void> purgePatient(DatabaseExecutor e, String patientId) async {
    await e.delete('vitals', where: 'patient_id = ?', whereArgs: [patientId]);
    await e.delete('records', where: 'patient_id = ?', whereArgs: [patientId]);
    await e.insert('scope_acks', {'patient_id': patientId}, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<List<String>> pendingAcks([DatabaseExecutor? e]) async {
    final rows = await (e ?? db).query('scope_acks');
    return rows.map((r) => r['patient_id'] as String).toList();
  }

  Future<void> clearAcks(DatabaseExecutor e, Iterable<String> ids) async {
    for (final id in ids) {
      await e.delete('scope_acks', where: 'patient_id = ?', whereArgs: [id]);
    }
  }

  /// Wipes everything (remote wipe, revoked device). Unsynced entries should be
  /// quarantine-uploaded first; that path is not built yet.
  Future<void> wipe() async {
    for (final table in ['vitals', 'outbox', 'records', 'scope_acks', 'meta']) {
      await db.delete(table);
    }
  }
}

class OutboxEntry {
  final int seq;
  final String idempotencyKey;
  final int schemaVersion;
  final String resourceType;
  final String resourceId;
  final String patientId;

  /// Exact JSON text of this entry. Sent as-is on every attempt.
  final String body;
  final String state;
  final String? error;
  final bool retryable;
  final int attempts;
  final DateTime createdAt;

  const OutboxEntry({
    required this.seq,
    required this.idempotencyKey,
    required this.schemaVersion,
    required this.resourceType,
    required this.resourceId,
    required this.patientId,
    required this.body,
    required this.state,
    required this.error,
    required this.retryable,
    required this.attempts,
    required this.createdAt,
  });

  factory OutboxEntry.fromRow(Map<String, Object?> r) => OutboxEntry(
        seq: r['seq'] as int,
        idempotencyKey: r['idempotency_key'] as String,
        schemaVersion: r['schema_version'] as int,
        resourceType: r['resource_type'] as String,
        resourceId: r['resource_id'] as String,
        patientId: r['patient_id'] as String,
        body: r['body'] as String,
        state: r['state'] as String,
        error: r['error'] as String?,
        retryable: (r['retryable'] as int? ?? 0) == 1,
        attempts: r['attempts'] as int? ?? 0,
        createdAt: DateTime.parse(r['created_at'] as String),
      );
}

class OutboxStats {
  final int pending;
  final int deadLetters;

  /// Age of the oldest unsynced entry: the number the unsynced-writes alert is about.
  final Duration? oldestPendingAge;

  const OutboxStats({required this.pending, required this.deadLetters, required this.oldestPendingAge});
}
