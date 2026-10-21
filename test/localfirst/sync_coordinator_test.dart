import 'dart:async';

// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_emr_mobile/core/localfirst/sync_coordinator.dart';
import 'package:healthcare_emr_mobile/core/localfirst/sync_engine.dart';

class _FakeRunner implements SyncRunner {
  final List<SyncOutcome> script;
  int rounds = 0;
  _FakeRunner(this.script);

  @override
  Future<SyncReport> syncNow() async {
    final outcome = rounds < script.length ? script[rounds] : script.last;
    rounds++;
    return SyncReport(outcome: outcome);
  }
}

void main() {
  group('when a round runs', () {
    test('starting, a write, a resume and regained connectivity each trigger a round; bursts collapse into one', () {
      fakeAsync((async) {
        final runner = _FakeRunner([SyncOutcome.ok]);
        final connectivity = StreamController<bool>.broadcast();
        final c = SyncCoordinator(engine: runner, connectivity: connectivity.stream, foregroundInterval: const Duration(hours: 1))..start();

        async.elapse(const Duration(seconds: 1));
        expect(runner.rounds, 1, reason: 'on start');

        c.trigger();
        c.trigger();
        c.onResume();
        async.elapse(const Duration(seconds: 1));
        expect(runner.rounds, 2, reason: 'a burst of triggers is one round');

        connectivity.add(false);
        async.elapse(const Duration(seconds: 1));
        expect(runner.rounds, 2, reason: 'going offline does not sync');

        connectivity.add(true);
        async.elapse(const Duration(seconds: 1));
        expect(runner.rounds, 3, reason: 'connectivity returning does');

        c.dispose();
        connectivity.close();
      });
    });

    test('while in the foreground it also syncs on a timer', () {
      fakeAsync((async) {
        final runner = _FakeRunner([SyncOutcome.ok]);
        final c = SyncCoordinator(engine: runner, foregroundInterval: const Duration(seconds: 60))..start();

        async.elapse(const Duration(minutes: 5, seconds: 2));

        expect(runner.rounds, greaterThanOrEqualTo(5));
        c.dispose();
      });
    });
  });

  group('after a failed round', () {
    test('it retries with growing, capped backoff and resets once a round succeeds', () {
      fakeAsync((async) {
        final runner = _FakeRunner([
          SyncOutcome.offline, SyncOutcome.offline, SyncOutcome.offline, SyncOutcome.offline, SyncOutcome.ok,
        ]);
        final c = SyncCoordinator(
          engine: runner,
          foregroundInterval: const Duration(days: 1),
          initialBackoff: const Duration(seconds: 15),
          maxBackoff: const Duration(seconds: 40),
        )..start();

        async.elapse(const Duration(seconds: 1));
        expect(runner.rounds, 1);
        expect(c.currentBackoff, const Duration(seconds: 15));

        async.elapse(const Duration(seconds: 15));
        expect(runner.rounds, 2);
        expect(c.currentBackoff, const Duration(seconds: 30));

        async.elapse(const Duration(seconds: 30));
        expect(runner.rounds, 3);
        expect(c.currentBackoff, const Duration(seconds: 40), reason: 'capped');

        async.elapse(const Duration(seconds: 40));
        expect(runner.rounds, 4);

        async.elapse(const Duration(seconds: 40));
        expect(runner.rounds, 5);
        expect(c.currentBackoff, Duration.zero, reason: 'success resets it');

        c.dispose();
      });
    });

    test('an expired session stops retrying and asks for sign-in', () {
      fakeAsync((async) {
        var expired = 0;
        final runner = _FakeRunner([SyncOutcome.authExpired]);
        final c = SyncCoordinator(engine: runner, foregroundInterval: const Duration(days: 1), onAuthExpired: () => expired++)..start();

        async.elapse(const Duration(minutes: 30));

        expect(expired, 1);
        expect(runner.rounds, 1, reason: 'retrying cannot help until the user signs in');
        c.dispose();
      });
    });
  });

  test('nothing runs before start() or after dispose()', () {
    fakeAsync((async) {
      final runner = _FakeRunner([SyncOutcome.ok]);
      final c = SyncCoordinator(engine: runner, foregroundInterval: const Duration(seconds: 10));

      c.trigger();
      async.elapse(const Duration(minutes: 1));
      expect(runner.rounds, 0);

      c.start();
      async.elapse(const Duration(seconds: 1));
      final before = runner.rounds;
      c.dispose();
      async.elapse(const Duration(minutes: 5));
      expect(runner.rounds, before);
    });
  });
}
