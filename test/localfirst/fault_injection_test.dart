// Fault-injection harness for the local-first vitals slice.
//
// Case numbers match "11. Fault-injection acceptance" in
// healthcare-emr/docs/superpowers/specs/2026-10-21-offline-sync-contract.md.
// The server is an in-memory fake that implements the contract's semantics
// (see support/fake_server.dart); the same flows are run against the real Laravel
// API by contract_test.dart when SYNC_CONTRACT_BASE_URL is set.
//
// Run with libsqlite3.so on the library path (CLAUDE.md, "Running tests").

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_emr_mobile/core/localfirst/offline_session_policy.dart';
import 'package:healthcare_emr_mobile/core/localfirst/sync_engine.dart';
import 'package:healthcare_emr_mobile/core/localfirst/vitals_repository.dart';

import 'support/fake_server.dart';
import 'support/harness.dart';

const patient = 'p-ward-1';
const otherPatient = 'p-ward-2';

void main() {
  initSqlite();

  late FakeServer server;
  late Device device;

  setUp(() async {
    server = FakeServer()..scope.addAll([patient, otherPatient]);
    device = await Device.create(server);
  });

  tearDown(() => device.dispose());

  group('1. airplane mode / failure mid-write', () {
    test('a reading and its outbox entry are saved together or not at all', () async {
      // The write path is a single transaction. If it is interrupted after the
      // reading was inserted, neither survives.
      await expectLater(
        device.store.transaction((txn) async {
          await device.store.insertLocalVital(
            txn,
            {'id': 'x', 'patient_id': patient, 'recorded_at': '2026-10-21T09:00:00Z', 'status': 'active'},
            createdAt: '2026-10-21T09:00:00Z',
          );
          throw StateError('process killed here');
        }),
        throwsStateError,
      );

      expect(await device.store.vitalsFor(patient), isEmpty);
      expect(await device.store.pending(), isEmpty);
    });

    test('a write with no network at all still succeeds and is visible immediately', () async {
      server.failBeforeApplying = 99; // the network is down for the whole test

      final saved = await device.vitals.record(patientId: patient, values: {'heart_rate': 72});
      expect(saved.synced, isFalse);

      final shown = await device.vitals.list(patient);
      expect(shown.single.vital.heartRate, 72);
      expect((await device.store.pending()).length, 1);

      final report = await device.sync();
      expect(report.outcome, SyncOutcome.offline);
      expect((await device.store.pending()).length, 1, reason: 'nothing is lost while offline');
    });
  });

  group('2. app killed mid-sync / 15. same bytes on retry', () {
    test('the server applied the push but the response was lost: restart resends identical bytes, applied once', () async {
      await device.vitals.record(patientId: patient, values: {'heart_rate': 72});
      server.dropResponseAfterApplying = 1;

      expect((await device.sync()).outcome, SyncOutcome.offline);
      expect(server.vitals.length, 1, reason: 'the first request landed');
      expect((await device.store.pending()).length, 1, reason: 'but the client never saw the confirmation');

      await device.restart(); // process death, then a cold start

      final report = await device.sync();
      expect(report.outcome, SyncOutcome.ok);
      expect(server.vitals.length, 1, reason: 'replay is a no-op, never a duplicate');
      expect(await device.store.pending(), isEmpty);
      expect((await device.vitals.list(patient)).single.synced, isTrue);

      final firstChange = _changes(server.pushBodies[0]).single;
      final secondChange = _changes(server.pushBodies[1]).single;
      expect(jsonEncode(secondChange), jsonEncode(firstChange), reason: 'the stored bytes are resent unchanged');
    });

    test('a differently serialised retry (key order, 72.0) is the same request, not a mismatch', () async {
      await device.vitals.record(patientId: patient, values: {'heart_rate': 72, 'temperature': 37.0});
      expect((await device.sync()).outcome, SyncOutcome.ok);

      // What a client with a different JSON serialiser would send for the same entry.
      final original = _changes(server.pushBodies.first).single;
      final payload = (original['payload'] as Map).cast<String, dynamic>();
      final reordered = {
        'payload': {
          'temperature': 37,
          'heart_rate': 72.0,
          ...Map.fromEntries(payload.entries.where((e) => e.key != 'temperature' && e.key != 'heart_rate').toList().reversed),
        },
        'client_version': original['client_version'],
        'operation': original['operation'],
        'resource_id': original['resource_id'],
        'resource_type': original['resource_type'],
        'id': original['id'],
      };

      final res = await server.push(jsonEncode({'client_id': server.registered.first, 'changes': [reordered]}));
      expect(((res.json!['data'] as Map)['items'] as List).single['outcome'], 'completed');
      expect(server.vitals.length, 1);
    });
  });

  group('3, 4, 5. replay, tampering, id reuse', () {
    test('replaying a completed entry is a no-op', () async {
      await device.vitals.record(patientId: patient, values: {'heart_rate': 72});
      await device.sync();
      final body = server.pushBodies.last;

      await server.push(body);
      await server.push(body);

      expect(server.vitals.length, 1);
    });

    test('an entry whose bytes were altered after its first send is rejected and cannot change the record', () async {
      await device.vitals.record(patientId: patient, values: {'heart_rate': 72});
      server.dropResponseAfterApplying = 1;
      await device.sync(); // first attempt landed; response lost

      // Something edits the stored entry (a bug or a tampered device).
      final entry = (await device.store.pending()).single;
      final tampered = entry.body.replaceFirst('"heart_rate":72', '"heart_rate":150');
      expect(tampered, isNot(entry.body));
      await device.store.db.update('outbox', {'body': tampered}, where: 'idempotency_key = ?', whereArgs: [entry.idempotencyKey]);

      final report = await device.sync();

      expect(report.deadLettered, 1, reason: 'the server answered idempotency_payload_mismatch');
      expect(server.vitals.values.single['heart_rate'], 72, reason: 'the stored request is never overwritten');
      // The same pull then shows the device the server's real record, which
      // retires the moot entry. Whatever the device now shows is the server's 72.
      expect((await device.vitals.list(patient)).single.vital.heartRate, 72);
      expect(await device.store.pending(), isEmpty);
    });

    test('an id that already exists is rejected under a new key, never overwritten', () async {
      const clash = '01a15e2a-0000-7000-8000-aaaaaaaaaaaa';
      server.addVital('p-hidden', heartRate: 60, id: clash); // exists, but not in this device's scope

      await device.vitals.record(patientId: patient, values: {'heart_rate': 99});
      final e = (await device.store.pending()).single;
      await device.store.db.update('outbox', {'body': e.body.replaceFirst(e.resourceId, clash), 'resource_id': clash},
          where: 'idempotency_key = ?', whereArgs: [e.idempotencyKey]);

      await device.sync();

      expect((await device.store.deadLetters()).single.error, 'resource_id_already_exists');
      expect(server.vitals[clash]!['heart_rate'], 60);
      expect(server.vitals[clash]!['patient_id'], 'p-hidden');
    });
  });

  group('6. clock skew', () {
    for (final skew in [const Duration(hours: 5), const Duration(hours: -5)]) {
      test('a device clock ${skew.inHours}h off does not affect ordering or sync', () async {
        device.now = DateTime.utc(2026, 10, 21, 9).add(skew);

        await device.vitals.record(patientId: patient, values: {'heart_rate': 70});
        await device.vitals.record(patientId: patient, values: {'heart_rate': 71});
        expect((await device.sync()).outcome, SyncOutcome.ok);

        // Ordering on the server and the pull cursor come from the server's sequence.
        expect(server.vitals.values.map((v) => v['heart_rate']), [70, 71]);
        expect(await device.store.getCursor(), server.seq);
        expect((await device.sync()).pulledChanges, 0);
      });
    }
  });

  group('7. 72 hours offline, then reconnect', () {
    test('writes stop at the ceiling, break-glass continues with a logged reason, reconnecting resets it', () async {
      final policy = await device.useOfflinePolicy();
      await policy.markOnline();

      await device.vitals.record(patientId: patient, values: {'heart_rate': 70});

      device.now = device.now.add(const Duration(hours: 73));
      await expectLater(device.vitals.record(patientId: patient, values: {'heart_rate': 71}), throwsA(isA<CeilingReached>()));

      await policy.breakGlass('Network outage on ward 3; patient deteriorating');
      await device.vitals.record(patientId: patient, values: {'heart_rate': 72});

      final report = await _syncOnline(device, policy);
      expect(report.outcome, SyncOutcome.ok);
      expect(server.vitals.length, 2, reason: 'both saved readings reached the server');
      expect(server.vitals.values.where((v) => v['break_glass_reason'] != null).single['heart_rate'], 72);

      // Back online: the ceiling is reset and normal writes work again.
      await device.vitals.record(patientId: patient, values: {'heart_rate': 73});
      expect(jsonDecode(await device.store.getMeta('break_glass_log') ?? '[]'), hasLength(1));
    });

    test('break-glass needs a reason', () async {
      final policy = OfflineSessionPolicy(store: device.store, clock: () => device.now);
      await expectLater(policy.breakGlass('  '), throwsArgumentError);
      await expectLater(policy.breakGlass('x' * 501), throwsArgumentError, reason: 'the server refuses a reason over 500 characters');
    });
  });

  group('9. paging', () {
    test('a long backlog arrives in pages with no gaps or repeats, cursor stored per page', () async {
      for (var i = 0; i < 25; i++) {
        server.addVital(patient, heartRate: 60 + i);
      }
      final small = SyncEngine(store: device.store, transport: server, pullLimit: 7, clock: () => device.now);

      final report = await small.syncNow();

      expect(report.outcome, SyncOutcome.ok);
      expect(report.pulledChanges, 25);
      expect((await device.vitals.list(patient)).length, 25);
      expect(server.pullCalls, greaterThanOrEqualTo(4));
      expect(await device.store.getCursor(), server.seq);
    });
  });

  group('10. a poison entry does not block the queue', () {
    test('the bad entry is dead-lettered on its own and the entries behind it still sync', () async {
      await device.vitals.record(patientId: patient, values: {'heart_rate': 70});
      await device.vitals.record(patientId: 'p-not-mine', values: {'heart_rate': 71}); // no access
      await device.vitals.record(patientId: patient, values: {'heart_rate': 72});

      final report = await device.sync();

      expect(report.outcome, SyncOutcome.ok);
      expect(report.pushed, 2);
      expect(report.deadLettered, 1);
      expect(server.vitals.values.map((v) => v['heart_rate']).toSet(), {70, 72});

      final dead = (await device.store.deadLetters()).single;
      expect(dead.error, 'no_access_grant');
      expect(dead.retryable, isTrue, reason: 'access may be granted later');
    });

    test('a whole-request 422 is isolated to the offending entry', () async {
      await device.vitals.record(patientId: patient, values: {'heart_rate': 70});
      await device.vitals.record(patientId: patient, values: {'heart_rate': 71});
      // Corrupt the second entry so the server cannot even parse it.
      final second = (await device.store.pending()).last;
      await device.store.db.update('outbox', {'body': second.body.replaceFirst('"operation":"create"', '"operation":null')},
          where: 'idempotency_key = ?', whereArgs: [second.idempotencyKey]);

      final report = await device.sync();

      expect(report.pushed, 1);
      expect(report.deadLettered, 1);
      expect(server.vitals.length, 1);
    });

    test('a retryable dead letter goes back in the queue with the same bytes once access exists', () async {
      await device.vitals.record(patientId: 'p-later', values: {'heart_rate': 70});
      await device.sync();
      final dead = (await device.store.deadLetters()).single;

      server.scope.add('p-later');
      await device.store.retryDeadLetter(dead.idempotencyKey);
      await device.sync();

      expect(server.vitals.length, 1);
      expect(await device.store.deadLetters(), isEmpty);
      expect(jsonEncode(_changes(server.pushBodies.first).single), jsonEncode(_changes(server.pushBodies.last).single));
    });
  });

  group('10b. a push response that acknowledges nothing', () {
    test('ends the round instead of re-sending the same batch in a loop', () async {
      server.acknowledgeNothing = true;
      await device.vitals.record(patientId: patient, values: {'heart_rate': 70});

      final report = await device.sync();

      expect(report.outcome, SyncOutcome.serverUnavailable);
      expect(server.pushCalls, 1);
      expect(await device.store.pending(), hasLength(1), reason: 'still queued, same bytes');

      server.acknowledgeNothing = false;
      expect((await device.sync()).outcome, SyncOutcome.ok);
      expect(await device.store.pending(), isEmpty);
      expect(server.vitals, hasLength(1));
    });
  });

  group('10c. the server does not know this device', () {
    test('a refused registration keeps the readings queued and retries registration', () async {
      server.registerStatus = 422;
      await device.vitals.record(patientId: patient, values: {'heart_rate': 70});

      final report = await device.sync();

      expect(report.outcome, SyncOutcome.serverUnavailable);
      expect(await device.store.deadLetters(), isEmpty);
      expect(await device.store.pending(), hasLength(1));

      server.registerStatus = null;
      expect((await device.sync()).outcome, SyncOutcome.ok);
      expect(server.vitals, hasLength(1));
      expect(await device.store.pending(), isEmpty);
    });

    test('a server that forgot the device does not dead-letter queued readings', () async {
      expect((await device.sync()).outcome, SyncOutcome.ok); // registers
      server.registered.clear(); // reinstall or restored database on the server

      await device.vitals.record(patientId: patient, values: {'heart_rate': 71});
      final report = await device.sync();

      expect(report.outcome, SyncOutcome.serverUnavailable);
      expect(await device.store.deadLetters(), isEmpty);
      expect(await device.store.pending(), hasLength(1));

      expect((await device.sync()).outcome, SyncOutcome.ok, reason: 'registers again, then pushes');
      expect(server.vitals.values.single['heart_rate'], 71);
    });
  });

  group('11. app upgrade with a non-empty outbox', () {
    test('50 queued entries (some from an older entry format) survive a restart and all sync', () async {
      for (var i = 0; i < 50; i++) {
        await device.vitals.record(patientId: patient, values: {'heart_rate': 60 + (i % 40)});
      }
      // Entries written by an older app version.
      await device.store.db.rawUpdate('UPDATE outbox SET schema_version = 0 WHERE seq <= 25');

      await device.restart(); // the upgraded app starts with a full queue

      expect((await device.store.pending(limit: 100)).length, 50);
      final report = await device.sync();

      expect(report.outcome, SyncOutcome.ok);
      expect(server.vitals.length, 50);
      expect(await device.store.pending(), isEmpty);
    });
  });

  group('12. failure while applying a pull page', () {
    test('a page that fails half way applies nothing and the cursor does not move', () async {
      server.addVital(patient, heartRate: 70);
      server.addVital(patient, heartRate: 71);
      // Make the second row impossible to store (recorded_at is NOT NULL).
      server.vitals.values.last['recorded_at'] = null;

      await expectLater(device.sync(), throwsA(anything));

      expect(await device.vitals.list(patient), isEmpty, reason: 'the page is all-or-nothing');
      expect(await device.store.getCursor(), 0);

      server.vitals.values.last['recorded_at'] = '2026-10-21T08:00:00Z'; // the problem is fixed
      expect((await device.sync()).outcome, SyncOutcome.ok);
      expect((await device.vitals.list(patient)).length, 2);
    });
  });

  group('13. token expiry mid-push', () {
    test('a 401 stops the round with the queue untouched; after re-auth it drains with no duplicates', () async {
      await device.vitals.record(patientId: patient, values: {'heart_rate': 70});
      await device.vitals.record(patientId: patient, values: {'heart_rate': 71});

      server.forceStatus = 401;
      expect((await device.sync()).outcome, SyncOutcome.authExpired);
      expect((await device.store.pending()).length, 2);
      expect(server.vitals, isEmpty);

      server.forceStatus = null; // signed in again
      expect((await device.sync()).outcome, SyncOutcome.ok);
      expect(server.vitals.length, 2);
    });

    test('the sync API being switched off (404) or the facility not upgraded (503) keeps everything queued', () async {
      await device.vitals.record(patientId: patient, values: {'heart_rate': 70});
      for (final status in [404, 503, 500, 429]) {
        server.forceStatus = status;
        expect((await device.sync()).outcome, SyncOutcome.serverUnavailable, reason: 'status $status');
        expect((await device.store.pending()).length, 1);
      }
    });
  });

  group('14 and 16. a patient leaving scope', () {
    test('with nothing unsynced the patient is purged and the removal acknowledged', () async {
      server.addVital(patient, heartRate: 70);
      await device.sync();
      expect((await device.vitals.list(patient)).length, 1);

      server.removeFromScope(patient);
      final report = await device.sync();

      expect(report.purgedPatients, 1);
      expect(await device.vitals.list(patient), isEmpty);
      expect(server.lastAckRemoved, [patient], reason: 'the purge is acknowledged in the same round');
      expect(await device.store.pendingAcks(), isEmpty, reason: 'nothing left to acknowledge once the server has seen it');

      await device.sync();
      expect(server.lastAckRemoved, isEmpty, reason: 'the server stopped repeating it');
    });

    test('a patient with an unsynced write is kept, and purged only after that write is pushed', () async {
      server.addVital(patient, heartRate: 70);
      await device.sync();

      await device.vitals.record(patientId: patient, values: {'heart_rate': 99}); // written offline
      server.removeFromScope(patient);
      server.failBeforeApplying = 1; // still offline: the push cannot go out

      final offline = await device.sync();
      expect(offline.outcome, SyncOutcome.offline);
      expect((await device.vitals.list(patient)).length, 2, reason: 'nothing may be purged while a write is unsynced');

      // Back online. The push goes first; the server rejects it (the patient
      // left scope) so it is dead-lettered and the clinician still sees it.
      final back = await device.sync();
      expect(back.keptForUnsyncedWrites, [patient]);
      expect(await device.store.deadLetters(), hasLength(1));
      expect(await device.vitals.list(patient), isNotEmpty, reason: 'a dead-lettered write keeps the patient on the device');
    });

    test('a write that does reach the server lets the patient go on the next round', () async {
      server.addVital(patient, heartRate: 70);
      await device.sync();

      await device.vitals.record(patientId: patient, values: {'heart_rate': 99});
      expect((await device.sync()).outcome, SyncOutcome.ok);

      server.removeFromScope(patient);
      final report = await device.sync();

      expect(report.purgedPatients, 1);
      expect(await device.vitals.list(patient), isEmpty);
    });

    test('a patient entering scope receives their history even though it is older than the cursor', () async {
      server.scope.remove(otherPatient);
      server.addVital(otherPatient, heartRate: 55, at: DateTime.utc(2026, 10, 18));
      server.addVital(patient, heartRate: 70);
      await device.sync();
      expect((await device.vitals.list(otherPatient)), isEmpty);

      server.scope.add(otherPatient); // handed over
      await device.sync();

      expect((await device.vitals.list(otherPatient)).single.vital.heartRate, 55);
    });
  });

  group('amendments', () {
    test('a correction is a new reading that points at the original, which is never edited', () async {
      final first = await device.vitals.record(patientId: patient, values: {'heart_rate': 72, 'temperature': 37.0});
      await device.sync();

      final fixed = await device.vitals.amend(original: first.vital, corrections: {'heart_rate': 82});
      expect(fixed.vital.amendsId, first.vital.id);
      expect(fixed.vital.temperature, 37.0, reason: 'unchanged values carry over');

      await device.sync();

      final list = await device.vitals.list(patient);
      expect(list.length, 2);
      expect(list.firstWhere((v) => v.vital.id == first.vital.id).vital.heartRate, 72);
      expect(server.vitals[fixed.vital.id]!['amends_id'], first.vital.id);
    });

    test('values the server would reject are refused at the bedside', () async {
      await expectLater(device.vitals.record(patientId: patient, values: {'heart_rate': 900}), throwsA(anything));
      await expectLater(device.vitals.record(patientId: patient, values: {'temperature_unit': 'K'}), throwsA(anything));
      expect(await device.store.pending(), isEmpty, reason: 'nothing queued for an invalid reading');
    });

    test('identity cannot be supplied by the caller', () async {
      await device.vitals.record(patientId: patient, values: {
        'heart_rate': 72,
        'patient_id': 'someone-else',
        'recorded_by_id': 'forged',
        'version': 99,
      });

      final payload = (_changes((await device.store.pending()).single.body.isEmpty ? '{}' : '{"changes":[${(await device.store.pending()).single.body}]}').single['payload'] as Map);
      expect(payload['patient_id'], patient);
      expect(payload.containsKey('recorded_by_id'), isFalse);
      expect(payload.containsKey('version'), isFalse);
    });
  });

  group('bedside validation matches the server', () {
    test('a fractional heart rate or blood pressure is refused, a whole-number double is sent as an int', () async {
      for (final key in ['heart_rate', 'respiratory_rate', 'blood_pressure_systolic', 'blood_pressure_diastolic']) {
        await expectLater(
          device.vitals.record(patientId: patient, values: {key: 72.5}),
          throwsA(isA<VitalsValidationException>()),
          reason: '$key is validated as integer on the server',
        );
      }
      expect(await device.store.pending(), isEmpty);

      await device.vitals.record(patientId: patient, values: {'heart_rate': 72.0});
      final payload = _changes('{"changes":[${(await device.store.pending()).single.body}]}').single['payload'] as Map;
      expect(payload['heart_rate'], 72);
      expect(payload['heart_rate'], isA<int>());
    });

    test('ids must be uuids and notes are counted in characters, not UTF-16 units', () async {
      await expectLater(
        device.vitals.record(patientId: patient, values: {'heart_rate': 70, 'ward_id': 'ward-3'}),
        throwsA(isA<VitalsValidationException>()),
      );
      // 2000 emoji are 4000 UTF-16 units but 2000 characters: the server accepts them.
      await device.vitals.record(patientId: patient, values: {'heart_rate': 70, 'notes': '😀' * 2000});
      await expectLater(
        device.vitals.record(patientId: patient, values: {'heart_rate': 70, 'notes': '😀' * 2001}),
        throwsA(isA<VitalsValidationException>()),
      );
    });

    test('decimals are rounded to the precision the server stores, so the bedside value does not change after sync', () async {
      final local = await device.vitals.record(
        patientId: patient,
        values: {'heart_rate': 70, 'temperature': 37.26, 'oxygen_saturation': 97.44, 'weight': 70.126, 'height': 170.04},
      );
      expect(local.vital.temperature, 37.3);
      expect(local.vital.oxygenSaturation, 97.4);
      expect(local.vital.weight, 70.13);
      expect(local.vital.height, 170.0);

      final entry = (await device.store.pending()).single;
      final payload = _changes('{"changes":[${entry.body}]}').single['payload'] as Map;
      expect(payload['temperature'], 37.3);
      expect(payload['weight'], 70.13);
    });
  });

  group('per-user isolation', () {
    test('two users on one device have separate databases', () async {
      final other = await Device.create(server, userId: 'user-2');
      await device.vitals.record(patientId: patient, values: {'heart_rate': 70});

      expect(await other.vitals.list(patient), isEmpty);
      expect(other.path, isNot(device.path));
      await other.dispose();
    });
  });
}

/// The `changes` array of a recorded push body.
List<Map<String, dynamic>> _changes(String rawBody) =>
    ((jsonDecode(rawBody) as Map)['changes'] as List).cast<Map<String, dynamic>>();

/// A sync round that also proves the device is online, as the session does.
Future<SyncReport> _syncOnline(Device device, OfflineSessionPolicy policy) async {
  final report = await device.sync();
  if (report.outcome == SyncOutcome.ok) await policy.markOnline();
  return report;
}
