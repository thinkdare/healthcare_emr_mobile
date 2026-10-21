import 'dart:async';

import 'sync_engine.dart';

/// Decides WHEN to run a sync round.
///
/// Background execution cannot be relied on: many phones common in Nigerian
/// facilities (Transsion Tecno, Infinix, itel) kill background work far more
/// aggressively than stock Android Doze. So syncing is triggered by things that
/// only happen while the app is in front of a clinician:
///   - the app returning to the foreground,
///   - connectivity coming back,
///   - a write having just been saved,
///   - a timer, while the app is in the foreground.
/// A platform background task (WorkManager) is a supplement for later, never the
/// mechanism; the queue is durable on disk either way and drains on next open.
class SyncCoordinator {
  final SyncRunner engine;
  final Duration foregroundInterval;
  final Duration debounce;
  final Duration initialBackoff;
  final Duration maxBackoff;

  /// Called after every round, for UI state and telemetry.
  final void Function(SyncReport report)? onReport;

  /// Called when the server answers 401: the session must be re-established.
  final void Function()? onAuthExpired;

  StreamSubscription<bool>? _connectivity;
  Timer? _periodic;
  Timer? _debounced;
  Timer? _retry;
  Duration _backoff = Duration.zero;
  bool _started = false;
  bool _disposed = false;

  SyncCoordinator({
    required this.engine,
    Stream<bool>? connectivity,
    this.foregroundInterval = const Duration(seconds: 60),
    this.debounce = const Duration(milliseconds: 500),
    this.initialBackoff = const Duration(seconds: 15),
    this.maxBackoff = const Duration(minutes: 10),
    this.onReport,
    this.onAuthExpired,
  }) : _connectivityStream = connectivity;

  final Stream<bool>? _connectivityStream;

  void start() {
    if (_started || _disposed) return;
    _started = true;

    _connectivity = _connectivityStream?.listen((online) {
      if (online) trigger();
    });
    _periodic = Timer.periodic(foregroundInterval, (_) => trigger());
    trigger();
  }

  /// Ask for a round soon. Many calls in quick succession collapse into one.
  void trigger() {
    if (!_started || _disposed) return;
    _debounced?.cancel();
    _debounced = Timer(debounce, _run);
  }

  /// The app came back to the foreground: try straight away.
  void onResume() => trigger();

  Future<void> _run() async {
    if (_disposed) return;

    final report = await engine.syncNow();
    if (_disposed) return;
    onReport?.call(report);

    switch (report.outcome) {
      case SyncOutcome.ok:
        _backoff = Duration.zero;
        _retry?.cancel();
      case SyncOutcome.authExpired:
        // Retrying cannot help until the user signs in again.
        _retry?.cancel();
        onAuthExpired?.call();
      case SyncOutcome.offline:
      case SyncOutcome.serverUnavailable:
        _backoff = _backoff == Duration.zero ? initialBackoff : _min(_backoff * 2, maxBackoff);
        _retry?.cancel();
        _retry = Timer(_backoff, _run);
    }
  }

  Duration _min(Duration a, Duration b) => a < b ? a : b;

  /// Seconds until the next automatic retry, for UI ("will retry in 30s").
  Duration get currentBackoff => _backoff;

  void dispose() {
    _disposed = true;
    _connectivity?.cancel();
    _periodic?.cancel();
    _debounced?.cancel();
    _retry?.cancel();
  }
}
