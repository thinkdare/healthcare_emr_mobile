import 'dart:convert';

import 'package:uuid/uuid.dart';

import 'local_store.dart';
import 'sync_transport.dart';

/// Why a sync round stopped.
enum SyncOutcome {
  /// Push and pull both completed.
  ok,

  /// No usable network. Nothing is lost: entries stay queued, same bytes.
  offline,

  /// The server answered 401. The session needs re-authentication; the queue is untouched.
  authExpired,

  /// The sync API is switched off or the server asked us to back off
  /// (404 disabled, 429, 5xx, 503 tenant not upgraded). Entries stay queued.
  serverUnavailable,
}

class SyncReport {
  final SyncOutcome outcome;
  final int pushed;
  final int deadLettered;
  final int pulledChanges;
  final int purgedPatients;

  /// Patients the server asked us to drop but that still hold unsynced writes.
  final List<String> keptForUnsyncedWrites;
  final String? detail;

  const SyncReport({
    required this.outcome,
    this.pushed = 0,
    this.deadLettered = 0,
    this.pulledChanges = 0,
    this.purgedPatients = 0,
    this.keptForUnsyncedWrites = const [],
    this.detail,
  });
}

/// Pushes the outbox and pulls changes (sync contract, sections 2 to 6).
///
/// Properties the harness checks:
///  - an entry's bytes are never regenerated: retries send the stored text;
///  - an entry leaves the outbox only after the server confirms it, so a crash
///    mid-sync re-sends it and the server's idempotency makes that a no-op;
///  - a rejected entry is dead-lettered on its own and never blocks the rest;
///  - the pull cursor is stored in the same transaction as the page it describes;
///  - a patient is purged on `scope.removed` only if no unsynced write remains
///    for them, and the purge is acknowledged to the server afterwards.
/// What the coordinator needs from an engine; lets it be tested without a database.
abstract class SyncRunner {
  Future<SyncReport> syncNow();
}

class SyncEngine implements SyncRunner {
  final LocalStore store;
  final SyncTransport transport;
  final DateTime Function() _now;
  final int pushBatchSize;
  final int pullLimit;
  final int maxPullPages;
  final String? appVersion;
  final String? platform;

  /// Called when a round proves the device is online and authenticated.
  final Future<void> Function()? onOnlineConfirmed;

  Future<SyncReport>? _inflight;

  SyncEngine({
    required this.store,
    required this.transport,
    DateTime Function()? clock,
    this.pushBatchSize = 50,
    this.pullLimit = 200,
    this.maxPullPages = 500,
    this.appVersion,
    this.platform,
    this.onOnlineConfirmed,
  }) : _now = clock ?? DateTime.now;

  /// Runs one push-then-pull round. Concurrent callers share the same round.
  @override
  Future<SyncReport> syncNow() => _inflight ??= _run().whenComplete(() => _inflight = null);

  Future<SyncReport> _run() async {
    var pushed = 0;
    var dead = 0;
    var pulled = 0;
    var purged = 0;
    final kept = <String>[];

    SyncReport stop(SyncOutcome o, [String? detail]) => SyncReport(
          outcome: o,
          pushed: pushed,
          deadLettered: dead,
          pulledChanges: pulled,
          purgedPatients: purged,
          keptForUnsyncedWrites: kept,
          detail: detail,
        );

    try {
      final clientId = await _clientId();

      final registered = await _ensureRegistered(clientId);
      if (registered != null) return stop(registered);

      // ── push ────────────────────────────────────────────────────────────
      while (true) {
        final batch = await store.pending(limit: pushBatchSize);
        if (batch.isEmpty) break;

        final r = await _pushBatch(clientId, batch);
        pushed += r.completed;
        dead += r.deadLettered;
        if (r.stop != null) return stop(r.stop!);

        // A 200 that acknowledges nothing leaves the same entries pending, so
        // asking again at once would loop forever. Stop and retry next round.
        if (r.completed + r.deadLettered == 0) {
          return stop(SyncOutcome.serverUnavailable, 'push response acknowledged no entries');
        }
      }

      // ── pull ────────────────────────────────────────────────────────────
      for (var page = 0; page < maxPullPages; page++) {
        final acks = await store.pendingAcks();
        final cursor = await store.getCursor();

        final res = await transport.pull(clientId: clientId, cursor: cursor, limit: pullLimit, ackRemoved: acks);

        if (!res.ok) {
          // The server forgot this device (e.g. a restored database): register
          // again on the next round.
          if (res.errorCode == 'UNREGISTERED_DEVICE') await store.setMeta('registered', '0');
          return stop(_classify(res) ?? SyncOutcome.serverUnavailable, res.message);
        }

        final data = (res.json?['data'] as Map?)?.cast<String, dynamic>() ?? const {};
        final changes = (data['changes'] as List? ?? const []).cast<Map>().map((m) => m.cast<String, dynamic>()).toList();
        final scope = (data['scope'] as Map?)?.cast<String, dynamic>() ?? const {};
        final removed = (scope['removed'] as List? ?? const []).cast<String>();
        final newCursor = (data['cursor'] as num?)?.toInt() ?? cursor;

        final result = await store.transaction((txn) async {
          for (final c in changes) {
            if (c['deleted'] == true) {
              await store.deleteChange(txn, c['resource'] as String, c['id'] as String);
            } else if (c['resource'] == 'vitals') {
              await store.upsertServerVital(txn, c);
            } else {
              await store.upsertRecord(txn, c);
            }
          }

          var purgedHere = 0;
          final keptHere = <String>[];
          for (final pid in removed) {
            // Unsynced writes win: a patient with anything still queued (or
            // dead-lettered, awaiting the clinician) stays until it is pushed.
            if (await store.unsyncedCountFor(pid, txn) > 0) {
              keptHere.add(pid);
            } else {
              await store.purgePatient(txn, pid);
              purgedHere++;
            }
          }

          // The cursor moves in the same transaction as the page it covers.
          if (newCursor > cursor) await store.setMeta('cursor', '$newCursor', txn);

          // The server has now seen these acknowledgements.
          await store.clearAcks(txn, acks);
          return (purged: purgedHere, kept: keptHere);
        });

        pulled += changes.length;
        purged += result.purged;
        kept
          ..clear()
          ..addAll(result.kept);

        // A purge leaves an acknowledgement to send. Take another pass right away
        // so the server stops repeating the removal, instead of waiting for the
        // next round.
        if (data['has_more'] != true && result.purged == 0) break;
      }

      await onOnlineConfirmed?.call();
      return stop(SyncOutcome.ok);
    } on TransportUnavailable catch (e) {
      return stop(SyncOutcome.offline, e.reason);
    }
  }

  // ── registration ──────────────────────────────────────────────────────────

  Future<String> _clientId() async {
    final existing = await store.getMeta('client_id');
    if (existing != null) return existing;
    final id = const Uuid().v4();
    await store.setMeta('client_id', id);
    return id;
  }

  /// Returns null when registered, or the outcome to stop with.
  Future<SyncOutcome?> _ensureRegistered(String clientId) async {
    if (await store.getMeta('registered') == '1') return null;

    final res = await transport.register(clientId, appVersion: appVersion, platform: platform);
    if (!res.ok) {
      // Any failure leaves the device unregistered. Carrying on would make the
      // push fail with UNREGISTERED_DEVICE, which must never reach the entries.
      return _classify(res) ?? SyncOutcome.serverUnavailable;
    }

    await store.setMeta('registered', '1');
    return null;
  }

  // ── push ──────────────────────────────────────────────────────────────────

  Future<_PushResult> _pushBatch(String clientId, List<OutboxEntry> batch) async {
    final attemptAt = _now().toUtc().toIso8601String();
    await store.transaction((txn) => store.recordAttempt(txn, batch, attemptAt));

    // The stored text of every entry, verbatim, inside a hand-assembled body so
    // nothing here re-serialises an entry.
    final body = '{"client_id":${jsonEncode(clientId)},"changes":[${batch.map((e) => e.body).join(',')}]}';

    final res = await transport.push(body);

    if (res.status == 200) {
      return _applyPushItems(batch, res);
    }

    final failure = _classify(res);
    if (failure != null) return _PushResult(stop: failure);

    // The server does not know this device (reinstall, restored database, or a
    // registration that never took). That says nothing about the entries: keep
    // them queued and register again next round.
    if (res.errorCode == 'UNREGISTERED_DEVICE') {
      await store.setMeta('registered', '0');
      return const _PushResult(stop: SyncOutcome.serverUnavailable);
    }

    // A 4xx for the whole request (typically 422). Isolate the offending entry
    // instead of failing the batch: one bad entry must not stall the queue.
    if (batch.length > 1) {
      var completed = 0;
      var dead = 0;
      for (final entry in batch) {
        final r = await _pushBatch(clientId, [entry]);
        completed += r.completed;
        dead += r.deadLettered;
        if (r.stop != null) return _PushResult(completed: completed, deadLettered: dead, stop: r.stop);
      }
      return _PushResult(completed: completed, deadLettered: dead);
    }

    await store.transaction((txn) => store.deadLetterEntry(txn, batch.single, 'rejected: ${res.message}', retryable: false));
    return const _PushResult(deadLettered: 1);
  }

  Future<_PushResult> _applyPushItems(List<OutboxEntry> batch, TransportResponse res) async {
    final items = ((res.json?['data'] as Map?)?['items'] as List? ?? const []).cast<Map>().map((m) => m.cast<String, dynamic>());
    final byKey = {for (final i in items) i['id'] as String: i};

    var completed = 0;
    var dead = 0;

    await store.transaction((txn) async {
      for (final entry in batch) {
        final item = byKey[entry.idempotencyKey];
        if (item == null) continue; // not acknowledged: stays queued, resent next round

        switch (item['outcome']) {
          case 'completed':
            await store.completeEntry(txn, entry);
            completed++;
          case 'forbidden':
            // Access may be granted later, so the clinician can retry it.
            await store.deadLetterEntry(txn, entry, (item['error'] as String?) ?? 'forbidden', retryable: true);
            dead++;
          default:
            await store.deadLetterEntry(txn, entry, (item['error'] as String?) ?? 'rejected', retryable: false);
            dead++;
        }
      }
    });

    return _PushResult(completed: completed, deadLettered: dead);
  }

  /// Maps a non-success response to the outcome that stops the round, or null
  /// when the response is a normal success.
  SyncOutcome? _classify(TransportResponse res) {
    if (res.ok) return null;
    if (res.status == 401) return SyncOutcome.authExpired;
    if (res.status == 404 || res.status == 429 || res.status == 503 || res.status >= 500) {
      return SyncOutcome.serverUnavailable;
    }
    return null; // other 4xx: handled by the caller (isolate or dead-letter)
  }
}

class _PushResult {
  final int completed;
  final int deadLettered;
  final SyncOutcome? stop;
  const _PushResult({this.completed = 0, this.deadLettered = 0, this.stop});
}
