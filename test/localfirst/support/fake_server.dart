import 'dart:convert';

import 'package:healthcare_emr_mobile/core/localfirst/sync_transport.dart';

/// An in-memory server that behaves like the Laravel sync API (sync contract):
/// payload-bound idempotency over a canonical form, insert-only creates, UUIDv7
/// ids, scope-limited cursor pulls with eviction, and per-item rejection reasons.
///
/// It also records every raw push body, so tests can assert the client resent
/// the same bytes, and has fault-injection hooks for the harness.
class FakeServer implements SyncTransport {
  static final _uuid7 = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$', caseSensitive: false);

  /// Patients this user may see and write.
  final Set<String> scope = {};

  final Map<String, Map<String, dynamic>> vitals = {}; // id -> row (server truth)
  final Map<String, _Seen> _keys = {}; // idempotency key -> hash + result
  final Set<String> registered = {};
  int _seq = 0;

  /// Patients the server believes the device holds (sync_client_scope).
  final Set<String> _held = {};
  final Set<String> _pendingRemoval = {};

  // ── observation ──
  final List<String> pushBodies = [];
  int pushCalls = 0;
  int pullCalls = 0;
  List<String> lastAckRemoved = const [];

  // ── fault injection ──

  /// Answer /register with this status (and register nothing) until cleared.
  int? registerStatus;

  /// Apply the push on the server, then fail the response to the client (the
  /// classic "request landed, response lost" case).
  int dropResponseAfterApplying = 0;

  /// Fail the request before the server sees it.
  int failBeforeApplying = 0;

  /// Answer every request with this status until cleared (401, 503, ...).
  int? forceStatus;

  /// Answer pushes with 200 and no items, applying nothing (a truncated response).
  bool acknowledgeNothing = false;

  /// Answer the next whole-batch push with 422.
  bool rejectNextBatchWith422 = false;

  int get seq => _seq;

  void addVital(String patientId, {int heartRate = 70, String? id, DateTime? at}) {
    final vid = id ?? _newId();
    _seq++;
    vitals[vid] = {
      'id': vid,
      'patient_id': patientId,
      'recorded_by_id': 'colleague',
      'recorded_at': (at ?? DateTime.utc(2026, 10, 21, 8)).toIso8601String(),
      'heart_rate': heartRate,
      'version': 1,
      'status': 'active',
      'amends_id': null,
      'created_at': (at ?? DateTime.utc(2026, 10, 21, 8)).toIso8601String(),
      '_seq': _seq,
    };
  }

  String _newId() {
    // A syntactically valid UUIDv7 that is unique per call.
    final n = (vitals.length + _seq).toRadixString(16).padLeft(12, '0');
    return '01a15e2a-0000-7000-8000-$n';
  }

  // ── transport ──

  @override
  Future<TransportResponse> register(String clientId, {String? appVersion, String? platform}) async {
    if (forceStatus != null) return TransportResponse(forceStatus!, {'message': 'forced'});
    if (registerStatus != null) return TransportResponse(registerStatus!, {'message': 'registration refused'});
    registered.add(clientId);
    return const TransportResponse(201, {'success': true});
  }

  @override
  Future<TransportResponse> push(String rawBody) async {
    pushCalls++;
    pushBodies.add(rawBody);

    if (failBeforeApplying > 0) {
      failBeforeApplying--;
      throw const TransportUnavailable('connectionError');
    }
    if (forceStatus != null) return TransportResponse(forceStatus!, {'message': 'forced'});
    if (rejectNextBatchWith422) {
      rejectNextBatchWith422 = false;
      return const TransportResponse(422, {'message': 'The given data was invalid.'});
    }

    if (acknowledgeNothing) {
      return const TransportResponse(200, {'success': true, 'data': {'items': []}});
    }

    final body = jsonDecode(rawBody) as Map<String, dynamic>;
    if (!registered.contains(body['client_id'])) {
      return const TransportResponse(422, {
        'message': 'Device not registered. Call /sync/register first.',
        'error': {'code': 'UNREGISTERED_DEVICE'},
      });
    }
    final changes = (body['changes'] as List).cast<Map<String, dynamic>>();

    // One malformed entry fails the whole request, like Laravel's validate().
    for (final c in changes) {
      if (c['id'] is! String || c['resource_id'] is! String || c['payload'] is! Map || c['operation'] == null) {
        return const TransportResponse(422, {'message': 'The given data was invalid.'});
      }
    }

    final items = <Map<String, dynamic>>[];
    for (final c in changes) {
      items.add(_process(c));
    }

    if (dropResponseAfterApplying > 0) {
      dropResponseAfterApplying--;
      throw const TransportUnavailable('receiveTimeout');
    }

    return TransportResponse(200, {
      'success': true,
      'data': {'items': items},
    });
  }

  Map<String, dynamic> _process(Map<String, dynamic> c) {
    final key = c['id'] as String;
    final hash = canonical({
      'resource_type': c['resource_type'],
      'resource_id': c['resource_id'],
      'operation': c['operation'],
      'client_version': c['client_version'],
      'payload': c['payload'],
    });

    final seen = _keys[key];
    if (seen != null) {
      if (seen.hash != hash) return {'id': key, 'outcome': 'rejected', 'error': 'idempotency_payload_mismatch'};
      if (seen.outcome == 'completed') return {'id': key, 'outcome': 'completed'};
    }

    Map<String, dynamic> reject(String why, {String outcome = 'rejected'}) {
      _keys[key] = _Seen(hash, outcome);
      return {'id': key, 'outcome': outcome, 'error': why};
    }

    if (c['resource_type'] != 'vitals') return reject('resource_not_syncable');
    if (c['operation'] != 'create') return reject('amend_instead');

    final payload = (c['payload'] as Map).cast<String, dynamic>();
    final patientId = payload['patient_id'] as String?;
    if (patientId == null) return reject('missing_patient_id');
    if (!scope.contains(patientId)) return reject('no_access_grant', outcome: 'forbidden');

    final id = c['resource_id'] as String;
    if (!_uuid7.hasMatch(id)) return reject('resource_id_not_uuid7');
    if (vitals.containsKey(id)) return reject('resource_id_already_exists');

    _seq++;
    vitals[id] = {
      'id': id,
      'patient_id': patientId,
      'recorded_by_id': 'user-1',
      'recorded_at': payload['recorded_at'],
      'heart_rate': payload['heart_rate'],
      'blood_pressure_systolic': payload['blood_pressure_systolic'],
      'blood_pressure_diastolic': payload['blood_pressure_diastolic'],
      'temperature': payload['temperature'],
      'notes': payload['notes'],
      'amends_id': payload['amends_id'],
      'break_glass_reason': payload['break_glass_reason'],
      'version': 1,
      'status': 'active',
      'created_at': c['client_timestamp'],
      '_seq': _seq,
    };
    _keys[key] = _Seen(hash, 'completed');
    return {'id': key, 'outcome': 'completed'};
  }

  /// A patient leaves this user's scope (discharge, transfer).
  void removeFromScope(String patientId) => scope.remove(patientId);

  @override
  Future<TransportResponse> pull({
    required String clientId,
    required int cursor,
    required int limit,
    required List<String> ackRemoved,
  }) async {
    pullCalls++;
    lastAckRemoved = ackRemoved;

    if (forceStatus != null) return TransportResponse(forceStatus!, {'message': 'forced'});
    if (!registered.contains(clientId)) {
      return const TransportResponse(422, {'message': 'Device not registered.', 'error': {'code': 'UNREGISTERED_DEVICE'}});
    }

    _pendingRemoval.removeAll(ackRemoved);

    // Left scope: report until acknowledged.
    for (final p in _held.toList()) {
      if (!scope.contains(p)) {
        _pendingRemoval.add(p);
        _held.remove(p);
      }
    }
    // Entered scope: held now; the client's history is re-sequenced (below).
    final added = <String>[];
    for (final p in scope) {
      if (_held.add(p)) {
        added.add(p);
        // Re-sequence this patient's rows so the stream delivers their history.
        for (final v in vitals.values.where((v) => v['patient_id'] == p)) {
          v['_seq'] = ++_seq;
        }
      }
    }

    final visible = vitals.values.where((v) => _held.contains(v['patient_id']) && (v['_seq'] as int) > cursor).toList()
      ..sort((a, b) => (a['_seq'] as int).compareTo(b['_seq'] as int));
    final page = visible.take(limit).toList();

    final changes = page
        .map((v) => {
              'resource': 'vitals',
              'id': v['id'],
              'patient_id': v['patient_id'],
              'seq': v['_seq'],
              'deleted': false,
              'version': 1,
              'data': Map<String, dynamic>.of(v)..remove('_seq'),
            })
        .toList();

    return TransportResponse(200, {
      'success': true,
      'data': {
        'changes': changes,
        'cursor': page.isEmpty ? cursor : page.last['_seq'],
        'has_more': visible.length > limit,
        'scope': {'added': added, 'removed': _pendingRemoval.toList()},
      },
    });
  }

  /// RFC 8785-style canonical form, enough for the keys and numbers used here.
  static String canonical(dynamic v) {
    if (v is Map) {
      final keys = v.keys.map((k) => k.toString()).toList()..sort();
      return '{${keys.map((k) => '${jsonEncode(k)}:${canonical(v[k])}').join(',')}}';
    }
    if (v is List) return '[${v.map(canonical).join(',')}]';
    if (v is double && v == v.truncateToDouble()) return v.toInt().toString();
    return jsonEncode(v);
  }
}

class _Seen {
  final String hash;
  final String outcome;
  _Seen(this.hash, this.outcome);
}
