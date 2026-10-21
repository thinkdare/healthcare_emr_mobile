import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show ChangeNotifier, kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart' show getDatabasesPath;

import 'local_store.dart';
import 'offline_session_policy.dart';
import 'sync_coordinator.dart';
import 'sync_engine.dart';
import 'sync_transport.dart';
import 'vitals_repository.dart';

/// Opens the per-user encrypted store. One database file and one key per user.
class LocalStoreFactory {
  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );

  static Future<LocalStore> openForUser(String userId) async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, 'emr_user_$userId.db');

    // SQLCipher on Android and iOS. Web and desktop run unencrypted, as the
    // existing database does (trusted dev environments only).
    final encrypt = !kIsWeb && _isMobile();
    return LocalStore.open(path: path, password: encrypt ? await _keyFor(userId) : null);
  }

  static bool _isMobile() {
    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  static Future<String> _keyFor(String userId) async {
    final name = 'db_key_user_$userId';
    final existing = await _storage.read(key: name);
    if (existing != null) return existing;
    final key = base64Url.encode(List<int>.generate(32, (_) => Random.secure().nextInt(256)));
    await _storage.write(key: name, value: key);
    return key;
  }
}

/// Owns the local-first machinery for the signed-in user: store, repository,
/// sync engine and coordinator. Created when a user signs in, torn down when
/// they sign out; the next user gets their own database.
class LocalFirstSession extends ChangeNotifier {
  final SyncTransport transport;
  final Future<LocalStore> Function(String userId) openStore;
  final Stream<bool> Function()? connectivity;
  final String? appVersion;
  final String? platform;

  /// Called when the server rejects the session (401).
  final void Function()? onAuthExpired;

  /// False in tests that drive the engine by hand.
  final bool startSync;

  String? _userId;
  LocalStore? _store;
  VitalsRepository? _vitals;
  SyncCoordinator? _coordinator;
  OfflineSessionPolicy? _policy;
  SyncReport? _lastReport;
  int _generation = 0;

  LocalFirstSession({
    required this.transport,
    required this.openStore,
    this.connectivity,
    this.appVersion,
    this.platform,
    this.onAuthExpired,
    this.startSync = true,
  });

  bool get isActive => _vitals != null;
  VitalsRepository? get vitals => _vitals;
  LocalStore? get store => _store;
  OfflineSessionPolicy? get policy => _policy;
  SyncReport? get lastReport => _lastReport;

  /// Opens the store for [userId]. Safe to call repeatedly with the same user.
  Future<void> attach(String userId) async {
    if (_userId == userId && isActive) return;
    await detach();

    final gen = ++_generation;
    final store = await openStore(userId);
    if (gen != _generation) {
      await store.close(); // detached or switched while opening
      return;
    }

    final policy = OfflineSessionPolicy(store: store);
    await policy.markOnline(); // the user has just authenticated online

    late final SyncCoordinator coordinator;
    final engine = SyncEngine(
      store: store,
      transport: transport,
      appVersion: appVersion,
      platform: platform,
      onOnlineConfirmed: policy.markOnline,
    );
    coordinator = SyncCoordinator(
      engine: engine,
      connectivity: connectivity?.call(),
      onReport: (r) {
        _lastReport = r;
        notifyListeners();
      },
      onAuthExpired: onAuthExpired,
    );

    _userId = userId;
    _store = store;
    _policy = policy;
    _coordinator = coordinator;
    _vitals = VitalsRepository(
      store: store,
      userId: userId,
      beforeWrite: policy.checkWrite,
      onWritten: coordinator.trigger,
    );

    if (startSync) coordinator.start();
    notifyListeners();
  }

  /// Closes the store. With [signedOut], also wipes it when nothing is waiting to
  /// sync, so PHI does not sit on the device after logout. Unsynced entries are
  /// never discarded: the encrypted file is kept until they have been pushed.
  Future<void> detach({bool signedOut = false}) async {
    _generation++;
    _coordinator?.dispose();
    final store = _store;
    if (signedOut && store != null) {
      final stats = await store.stats(DateTime.now());
      if (stats.pending == 0 && stats.deadLetters == 0) await store.wipe();
    }
    _coordinator = null;
    _store = null;
    _vitals = null;
    _policy = null;
    _userId = null;
    _lastReport = null;
    await store?.close();
    notifyListeners();
  }

  /// The app returned to the foreground.
  void onResume() => _coordinator?.onResume();

  /// Run a round now (pull-to-refresh, "sync now").
  void syncSoon() => _coordinator?.trigger();

  @override
  void dispose() {
    _coordinator?.dispose();
    super.dispose();
  }
}

/// Maps connectivity_plus to a plain online/offline stream.
Stream<bool> connectivityStream() =>
    Connectivity().onConnectivityChanged.map((results) => results.any((r) => r != ConnectivityResult.none));
