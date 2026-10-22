import 'dart:convert';
import 'dart:math' as math;

import 'package:uuid/uuid.dart';

import '../../data/models/clinical_record_models.dart';
import 'local_store.dart';

class VitalsValidationException implements Exception {
  final Map<String, String> errors;
  VitalsValidationException(this.errors);

  @override
  String toString() => 'VitalsValidationException($errors)';
}

/// Mirrors the server's VitalSignController::vitalSignRules() so an entry that
/// would be rejected is caught while the clinician is still standing at the bed,
/// not discovered later as a dead-lettered entry.
class VitalsValidator {
  static const Map<String, (num, num)> ranges = {
    'blood_pressure_systolic': (40, 300),
    'blood_pressure_diastolic': (20, 200),
    'heart_rate': (20, 300),
    'respiratory_rate': (5, 60),
    'temperature': (30, 45),
    'oxygen_saturation': (50, 100),
    'weight': (0.5, 700),
    'height': (30, 300),
  };

  /// The server validates these as `integer`: 72.5 is rejected, 72 and 72.0 pass.
  static const Set<String> integers = {
    'blood_pressure_systolic',
    'blood_pressure_diastolic',
    'heart_rate',
    'respiratory_rate',
  };

  /// Columns the server validates as `uuid`.
  static const Set<String> uuids = {'encounter_id', 'roster_entry_id', 'ward_id'};

  /// Decimal places the server stores (`decimal:N` casts). Rounding before the
  /// write makes the bedside value equal to what comes back on the next pull.
  static const Map<String, int> decimals = {
    'temperature': 1,
    'oxygen_saturation': 1,
    'weight': 2,
    'height': 1,
    'bmi': 1,
  };

  static final RegExp _uuid = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false);

  static const Map<String, List<String>> units = {
    'temperature_unit': ['C', 'F'],
    'weight_unit': ['kg', 'lbs'],
    'height_unit': ['cm', 'in'],
  };

  /// Fields a caller may supply. Identity (patient, author, version) is never
  /// taken from the caller.
  static const Set<String> fields = {
    'encounter_id', 'roster_entry_id', 'ward_id', 'recorded_at',
    'blood_pressure_systolic', 'blood_pressure_diastolic', 'heart_rate',
    'respiratory_rate', 'temperature', 'temperature_unit', 'oxygen_saturation',
    'weight', 'weight_unit', 'height', 'height_unit', 'bmi', 'notes',
  };

  static Map<String, String> validate(Map<String, dynamic> values) {
    final errors = <String, String>{};

    ranges.forEach((key, range) {
      final v = values[key];
      if (v == null) return;
      if (v is! num) {
        errors[key] = 'must be a number';
      } else if (integers.contains(key) && v != v.truncate()) {
        errors[key] = 'must be a whole number';
      } else if (v < range.$1 || v > range.$2) {
        errors[key] = 'must be between ${range.$1} and ${range.$2}';
      }
    });

    for (final key in uuids) {
      final v = values[key];
      if (v != null && !(v is String && _uuid.hasMatch(v))) errors[key] = 'must be a valid id';
    }

    units.forEach((key, allowed) {
      final v = values[key];
      if (v != null && !allowed.contains(v)) errors[key] = 'must be one of ${allowed.join(', ')}';
    });

    final notes = values['notes'];
    // Laravel counts characters, Dart's length counts UTF-16 units.
    if (notes is String && notes.runes.length > 2000) errors['notes'] = 'is too long';

    return errors;
  }

  /// Applies the server's storage precision to already validated values:
  /// whole numbers become ints and decimals are rounded.
  static Map<String, dynamic> normalize(Map<String, dynamic> values) {
    final out = Map<String, dynamic>.from(values);
    for (final key in integers) {
      final v = out[key];
      if (v is num) out[key] = v.toInt();
    }
    decimals.forEach((key, places) {
      final v = out[key];
      if (v is num) {
        final f = math.pow(10, places).toDouble();
        out[key] = (v * f).round() / f;
      }
    });
    return out;
  }
}

/// A reading plus whether the server has it yet. Unsynced readings are shown to
/// the clinician as such; they are real, saved readings either way.
class LocalVital {
  final VitalSignModel vital;
  final bool synced;
  const LocalVital(this.vital, {required this.synced});

  factory LocalVital.fromRow(Map<String, dynamic> row) =>
      LocalVital(VitalSignModel.fromJson(row), synced: row['_sync_state'] == LocalStore.stateSynced);
}

/// The local-first write path for vital signs.
///
/// Every write goes to the local database and the outbox in one transaction;
/// nothing here touches the network. Reads come only from the local database.
/// A background sync engine ([SyncEngine]) pushes the outbox and pulls changes.
class VitalsRepository {
  final LocalStore store;
  final String userId;
  final DateTime Function() _now;
  final Uuid _uuid;

  /// Called before every write. Throws (e.g. [CeilingReached]) when the
  /// offline-session policy forbids it; returns the break-glass reason when the
  /// write is made under break-glass, which is attached to the payload.
  final Future<String?> Function()? beforeWrite;

  /// Called after a write is saved so the sync engine can try right away.
  final void Function()? onWritten;

  VitalsRepository({
    required this.store,
    required this.userId,
    DateTime Function()? clock,
    Uuid? uuid,
    this.beforeWrite,
    this.onWritten,
  })  : _now = clock ?? DateTime.now,
        _uuid = uuid ?? const Uuid();

  Future<List<LocalVital>> list(String patientId) async {
    final rows = await store.vitalsFor(patientId);
    return rows.map(LocalVital.fromRow).toList();
  }

  /// Records a new reading.
  Future<LocalVital> record({required String patientId, required Map<String, dynamic> values}) {
    return _write(patientId: patientId, values: values, amends: null);
  }

  /// Records a correction: a NEW reading that points at [original]. The original
  /// is never edited; it stays on record.
  Future<LocalVital> amend({required VitalSignModel original, required Map<String, dynamic> corrections}) async {
    if (original.isEnteredInError) {
      throw StateError('An entry marked as entered in error cannot be amended.');
    }

    final base = <String, dynamic>{
      'encounter_id': original.encounterId,
      'roster_entry_id': original.rosterEntryId,
      'ward_id': original.wardId,
      'recorded_at': original.recordedAt.toUtc().toIso8601String(),
      'blood_pressure_systolic': original.bloodPressureSystolic,
      'blood_pressure_diastolic': original.bloodPressureDiastolic,
      'heart_rate': original.heartRate,
      'respiratory_rate': original.respiratoryRate,
      'temperature': original.temperature,
      'temperature_unit': original.temperatureUnit,
      'oxygen_saturation': original.oxygenSaturation,
      'weight': original.weight,
      'weight_unit': original.weightUnit,
      'height': original.height,
      'height_unit': original.heightUnit,
      'bmi': original.bmi,
      'notes': original.notes,
    }..removeWhere((_, v) => v == null);

    return _write(
      patientId: original.patientId,
      values: {...base, ..._only(corrections)},
      amends: original.id,
    );
  }

  Map<String, dynamic> _only(Map<String, dynamic> values) =>
      {for (final e in values.entries) if (VitalsValidator.fields.contains(e.key)) e.key: e.value};

  Future<LocalVital> _write({
    required String patientId,
    required Map<String, dynamic> values,
    required String? amends,
  }) async {
    final breakGlass = await beforeWrite?.call();

    final raw = _only(values);
    raw['recorded_at'] ??= _now().toUtc().toIso8601String();

    final errors = VitalsValidator.validate(raw);
    if (errors.isNotEmpty) throw VitalsValidationException(errors);
    final clean = VitalsValidator.normalize(raw);

    final nowIso = _now().toUtc().toIso8601String();
    final id = _uuid.v7();
    final key = _uuid.v7();

    final payload = <String, dynamic>{
      'patient_id': patientId,
      ...clean,
      'amends_id': ?amends,
      'break_glass_reason': ?breakGlass,
    };

    // Serialised exactly once. This text is what every retry sends.
    final body = jsonEncode(<String, dynamic>{
      'id': key,
      'schema_version': LocalStore.outboxSchemaVersion,
      'resource_type': 'vitals',
      'resource_id': id,
      'operation': 'create',
      'client_version': 0,
      'client_timestamp': nowIso,
      'payload': payload,
    });

    final local = <String, dynamic>{
      'id': id,
      'patient_id': patientId,
      'recorded_by_id': userId,
      ...clean,
      'version': 1,
      'created_at': nowIso,
      'amends_id': amends,
      'status': 'active',
    };

    // One transaction: the reading and its outbox entry exist together or not at all.
    await store.transaction((txn) async {
      await store.insertLocalVital(txn, local, createdAt: nowIso);
      await store.enqueue(
        txn,
        idempotencyKey: key,
        resourceType: 'vitals',
        resourceId: id,
        patientId: patientId,
        body: body,
        createdAt: nowIso,
      );
    });

    onWritten?.call();
    return LocalVital.fromRow({...local, '_sync_state': LocalStore.stateLocal});
  }
}
