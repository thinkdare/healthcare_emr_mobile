import 'dart:io';

import 'package:healthcare_emr_mobile/core/localfirst/local_store.dart';
import 'package:healthcare_emr_mobile/core/localfirst/offline_session_policy.dart';
import 'package:healthcare_emr_mobile/core/localfirst/sync_engine.dart';
import 'package:healthcare_emr_mobile/core/localfirst/vitals_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'fake_server.dart';

/// Must be called once per test file. Needs libsqlite3.so on the library path
/// (see CLAUDE.md "Running tests").
void initSqlite() {
  sqfliteFfiInit();
}

/// A device: an on-disk store (so "kill the app" is a real close and reopen),
/// a repository and an engine, over a [FakeServer]. [now] is the device clock,
/// settable per test for skew and long-offline scenarios.
class Device {
  final Directory dir;
  final FakeServer server;
  final String userId;
  DateTime now;

  late LocalStore store;
  late VitalsRepository vitals;
  late SyncEngine engine;

  Device._(this.dir, this.server, this.userId, this.now);

  static Future<Device> create(FakeServer server, {String userId = 'user-1', DateTime? now, Directory? dir}) async {
    final d = Device._(dir ?? await Directory.systemTemp.createTemp('lf_'), server, userId, now ?? DateTime.utc(2026, 10, 21, 9));
    await d.boot();
    return d;
  }

  String get path => '${dir.path}/emr_user_$userId.db';

  /// Opens the files fresh, as a newly started app would.
  Future<void> boot({Future<String?> Function()? beforeWrite}) async {
    store = await LocalStore.open(path: path, factory: databaseFactoryFfi);
    vitals = VitalsRepository(store: store, userId: userId, clock: () => now, beforeWrite: beforeWrite);
    engine = SyncEngine(store: store, transport: server, clock: () => now);
  }

  /// The process dies: the database is closed with no clean shutdown logic.
  Future<void> kill() => store.close();

  Future<void> restart({Future<String?> Function()? beforeWrite}) async {
    await kill();
    await boot(beforeWrite: beforeWrite);
  }

  Future<SyncReport> sync() => engine.syncNow();

  /// Installs the offline-session policy (72h ceiling) on this device's writes.
  Future<OfflineSessionPolicy> useOfflinePolicy() async {
    final policy = OfflineSessionPolicy(store: store, clock: () => now);
    vitals = VitalsRepository(store: store, userId: userId, clock: () => now, beforeWrite: policy.checkWrite);
    return policy;
  }

  Future<void> dispose() async {
    try {
      await store.close();
    } catch (_) {}
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}
