import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_emr_mobile/core/localfirst/local_first_session.dart';
import 'package:healthcare_emr_mobile/core/localfirst/local_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/fake_server.dart';
import 'support/harness.dart';

void main() {
  initSqlite();

  late Directory dir;
  late FakeServer server;
  late LocalFirstSession session;

  Future<LocalStore> open(String userId) => LocalStore.open(path: '${dir.path}/emr_user_$userId.db', factory: databaseFactoryFfi);

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('lfs_');
    server = FakeServer()..scope.add('p1');
    session = LocalFirstSession(transport: server, openStore: open, startSync: false);
  });

  tearDown(() async {
    await session.detach();
    session.dispose();
    await dir.delete(recursive: true);
  });

  test('attaching a user opens their own store and detaching closes it', () async {
    expect(session.isActive, isFalse);

    await session.attach('u1');
    expect(session.isActive, isTrue);
    await session.vitals!.record(patientId: 'p1', values: {'heart_rate': 70});

    await session.detach();
    expect(session.isActive, isFalse);
    expect(session.vitals, isNull);
  });

  test('switching users never exposes the previous user\'s readings', () async {
    await session.attach('u1');
    await session.vitals!.record(patientId: 'p1', values: {'heart_rate': 70});

    await session.attach('u2');

    expect(await session.vitals!.list('p1'), isEmpty);
    expect(File('${dir.path}/emr_user_u1.db').existsSync(), isTrue);
    expect(File('${dir.path}/emr_user_u2.db').existsSync(), isTrue);
  });

  test('signing out wipes the store when nothing is waiting to sync', () async {
    await session.attach('u1');
    server.addVital('p1', heartRate: 70);
    await session.store!.setMeta('cursor', '5');
    await session.store!.transaction((txn) => session.store!.upsertServerVital(txn, {
          'id': 'v1', 'patient_id': 'p1', 'seq': 5,
          'data': {'id': 'v1', 'patient_id': 'p1', 'recorded_by_id': 's', 'recorded_at': '2026-10-21T08:00:00Z', 'heart_rate': 70},
        }));

    await session.detach(signedOut: true);
    await session.attach('u1');

    expect(await session.vitals!.list('p1'), isEmpty, reason: 'PHI does not sit on the device after logout');
    expect(await session.store!.getCursor(), 0);
  });

  test('signing out NEVER discards unsynced readings', () async {
    await session.attach('u1');
    await session.vitals!.record(patientId: 'p1', values: {'heart_rate': 70});

    await session.detach(signedOut: true);
    await session.attach('u1');

    expect((await session.vitals!.list('p1')).single.vital.heartRate, 70);
    expect((await session.store!.pending()).length, 1, reason: 'still queued for when they sign in again');
  });

  test('attaching the same user twice keeps the same store', () async {
    await session.attach('u1');
    final first = session.store;
    await session.attach('u1');
    expect(identical(session.store, first), isTrue);
  });
}
