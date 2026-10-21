// End-to-end check of the real client against a real backend: the real Dio
// transport, the real wire format (headers, bodies, array parameters) and the
// real Laravel sync API. Skipped unless these are set:
//
//   SYNC_LIVE_TOKEN   a Sanctum token for a staff user with patients in scope
//   SYNC_LIVE_TENANT  that user's facility id
//   and: flutter test --dart-define=API_BASE_URL=http://127.0.0.1:8180/api/v1
//
// Backend side: SYNC_API_ENABLED=true in a non-production environment (the
// endpoints are hard-blocked in production), and the tenant migrations applied.
//
//   SYNC_LIVE_TOKEN=... SYNC_LIVE_TENANT=... LD_LIBRARY_PATH=<sqlite dir> \
//     flutter test --dart-define=API_BASE_URL=http://127.0.0.1:8180/api/v1 test/localfirst/live_backend_test.dart

import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_emr_mobile/core/api/api_client.dart';
import 'package:healthcare_emr_mobile/core/localfirst/local_store.dart';
import 'package:healthcare_emr_mobile/core/localfirst/sync_engine.dart';
import 'package:healthcare_emr_mobile/core/localfirst/sync_transport.dart';
import 'package:healthcare_emr_mobile/core/localfirst/vitals_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // flutter_test answers every HttpClient request with a canned 400; this test
  // talks to a real server.
  HttpOverrides.global = null;
  sqfliteFfiInit();

  final token = Platform.environment['SYNC_LIVE_TOKEN'];
  final tenant = Platform.environment['SYNC_LIVE_TENANT'];
  final skip = (token == null || tenant == null) ? 'set SYNC_LIVE_TOKEN and SYNC_LIVE_TENANT to run against a live backend' : null;

  late Directory dir;
  late LocalStore store;
  late SyncEngine engine;
  late ApiSyncTransport transport;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({'auth_token': token ?? '', 'active_tenant_id': tenant ?? ''});
    dir = await Directory.systemTemp.createTemp('live_');
    store = await LocalStore.open(path: '${dir.path}/live.db', factory: databaseFactoryFfi);
    transport = ApiSyncTransport(ApiClient());
    engine = SyncEngine(store: store, transport: transport);
  });

  tearDown(() async {
    await store.close();
    await dir.delete(recursive: true);
  });

  test('registers, pulls the user\'s scope, pushes a reading and gets it back', () async {
    final first = await engine.syncNow();
    expect(first.outcome, SyncOutcome.ok, reason: first.detail);

    final patients = await store.recordsOf('patients');
    expect(patients, isNotEmpty, reason: 'the user has patients in scope');
    final patientId = patients.first['id'] as String;
    expect(await store.getCursor(), greaterThan(0));

    final repo = VitalsRepository(store: store, userId: 'live', beforeWrite: () async => null);
    final saved = await repo.record(patientId: patientId, values: {'heart_rate': 77, 'temperature': 36.8, 'notes': 'Flutter live test'});
    expect((await store.pending()).length, 1);

    final second = await engine.syncNow();
    expect(second.outcome, SyncOutcome.ok, reason: second.detail);
    expect(second.pushed, 1);
    expect(await store.pending(), isEmpty);
    expect(await store.deadLetters(), isEmpty);

    // The server's own copy came back through pull and replaced the local one.
    final mine = (await repo.list(patientId)).firstWhere((v) => v.vital.id == saved.vital.id);
    expect(mine.synced, isTrue);
    expect(mine.vital.heartRate, 77);
    expect(mine.vital.recordedById, isNot('live'), reason: 'the server sets the author from the authenticated user');

    // A fresh device (new database, same account) sees the reading too.
    final other = await LocalStore.open(path: '${dir.path}/other.db', factory: databaseFactoryFfi);
    final otherEngine = SyncEngine(store: other, transport: transport);
    expect((await otherEngine.syncNow()).outcome, SyncOutcome.ok);
    expect((await other.vitalById(saved.vital.id)), isNotNull);
    await other.close();
  }, skip: skip);

  test('a reading for a patient the user cannot access is dead-lettered with the server\'s reason', () async {
    expect((await engine.syncNow()).outcome, SyncOutcome.ok);
    final repo = VitalsRepository(store: store, userId: 'live', beforeWrite: () async => null);
    await repo.record(patientId: const Uuid().v7(), values: {'heart_rate': 70});

    final report = await engine.syncNow();

    expect(report.deadLettered, 1);
    final dead = (await store.deadLetters()).single;
    expect(dead.error, 'no_access_grant');
    expect(dead.retryable, isTrue);
  }, skip: skip);

  test('the array parameter for acknowledging removals is understood by Laravel', () async {
    expect((await engine.syncNow()).outcome, SyncOutcome.ok);
    final clientId = await store.getMeta('client_id');

    // Two UUIDs the server has nothing to say about; a 422 here would mean the
    // ack_removed[] encoding is wrong.
    final res = await transport.pull(clientId: clientId!, cursor: 0, limit: 1, ackRemoved: [const Uuid().v4(), const Uuid().v4()]);

    expect(res.status, 200, reason: res.message);
  }, skip: skip);

  test('resending a stored entry after a lost response is a replay: exactly one reading on the server', () async {
    expect((await engine.syncNow()).outcome, SyncOutcome.ok);
    final patientId = (await store.recordsOf('patients')).first['id'] as String;
    final repo = VitalsRepository(store: store, userId: 'live', beforeWrite: () async => null);
    final saved = await repo.record(patientId: patientId, values: {'heart_rate': 66});
    final entry = (await store.pending()).single;

    // The first send "succeeds" but the client pretends it never heard back.
    final clientId = (await store.getMeta('client_id'))!;
    final raw = '{"client_id":"$clientId","changes":[${entry.body}]}';
    expect((await transport.push(raw)).status, 200);

    // Normal sync now resends the very same stored bytes.
    final report = await engine.syncNow();
    expect(report.outcome, SyncOutcome.ok);
    expect(await store.pending(), isEmpty);
    expect((await repo.list(patientId)).where((v) => v.vital.id == saved.vital.id), hasLength(1));
  }, skip: skip);
}
