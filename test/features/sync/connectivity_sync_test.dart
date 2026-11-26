import 'dart:async';

import 'package:billfern/features/account/presentation/providers/account_providers.dart';
import 'package:billfern/features/sync/data/connectivity_plus_signal.dart';
import 'package:billfern/features/sync/domain/sync_models.dart';
import 'package:billfern/features/sync/domain/sync_remote.dart';
import 'package:billfern/features/sync/presentation/providers/sync_providers.dart';
import 'package:billfern/shared/providers/local_store_providers.dart';
import 'package:billfern/shared/providers/subscription_providers.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_cloud.dart';
import '../account/account_test.dart' show alex, app, blair, signIn, sub;

const _debounce = Duration(milliseconds: 40);

/// Lets timers, the debounce period and async sync work finish.
Future<void> settle([Duration extra = Duration.zero]) =>
    Future<void>.delayed(_debounce * 3 + extra);

/// A container wired like `main`, signed in as Alex, with a controllable
/// connectivity signal and the sync controller kept alive.
Future<({ProviderContainer c, FakeCloud cloud, FakeConnectivity network})>
_signedIn({FakeCloud? cloud, SyncRemote? remote}) async {
  final theCloud = cloud ?? FakeCloud();
  final network = FakeConnectivity();
  final c = (await app(
    cloud: theCloud,
    remote: remote,
    overrides: [
      connectivitySignalProvider.overrideWithValue(network),
      connectivityDebounceProvider.overrideWithValue(_debounce),
    ],
  )).container;
  final keepAlive = c.listen(syncControllerProvider, (_, _) {});
  addTearDown(keepAlive.close);
  await signIn(c, alex);
  await settle();
  return (c: c, cloud: theCloud, network: network);
}

/// Goes offline and saves a change that cannot be delivered.
Future<void> _editOffline(
  ProviderContainer c,
  FakeCloud cloud,
  FakeConnectivity network,
) async {
  network.emit(false);
  cloud.offline = true;
  await c.read(subscriptionsProvider.notifier).add(sub('offline-edit'));
  await c.read(syncControllerProvider.notifier).sync();
  await settle();
  final status = c.read(syncControllerProvider);
  expect(status.phase, SyncPhase.offline);
  expect(status.pendingCount, 1);
}

Future<List<String>> _pendingIds(ProviderContainer c) async => [
  for (final op in await c.read(activeLocalStoreProvider)!.sync!.pending())
    op.subscriptionId,
];

void main() {
  group('ConnectivityPlusSignal', () {
    test('any network interface counts as online; none is offline', () {
      expect(
        ConnectivityPlusSignal.isOnline([ConnectivityResult.none]),
        isFalse,
      );
      expect(
        ConnectivityPlusSignal.isOnline([ConnectivityResult.wifi]),
        isTrue,
      );
      expect(
        ConnectivityPlusSignal.isOnline([
          ConnectivityResult.mobile,
          ConnectivityResult.vpn,
        ]),
        isTrue,
      );
    });
  });

  group('automatic sync when connectivity returns', () {
    test('pending offline changes are sent without tapping Retry', () async {
      final s = await _signedIn();
      await _editOffline(s.c, s.cloud, s.network);
      final ops = await s.c.read(activeLocalStoreProvider)!.sync!.pending();
      expect(ops.single.nextAttemptAt, isNotNull); // backing off

      s.cloud.offline = false;
      s.network.emit(true);
      await settle();

      expect(s.cloud.row('offline-edit'), isNotNull);
      final status = s.c.read(syncControllerProvider);
      expect(status.phase, SyncPhase.synced);
      expect(status.pendingCount, 0);
      expect(
        [for (final x in s.c.read(subscriptionsProvider)) x.id],
        ['offline-edit'],
      );
    });

    test('flapping connectivity is debounced into one run', () async {
      final s = await _signedIn();
      await _editOffline(s.c, s.cloud, s.network);
      s.cloud.offline = false;
      final pushes = s.cloud.pushCalls;
      final pulls = s.cloud.pullCalls;

      for (var i = 0; i < 5; i++) {
        s.network
          ..emit(true)
          ..emit(false);
      }
      s.network.emit(true);
      await settle();

      expect(s.cloud.pushCalls - pushes, 1);
      // One run pulls; reloading after the push may schedule one follow-up
      // pull for the echo. Never one run per event.
      expect(s.cloud.pullCalls - pulls, lessThanOrEqualTo(2));
      expect(s.cloud.row('offline-edit'), isNotNull);
    });

    test(
      'going offline before the quiet period ends cancels the run',
      () async {
        final s = await _signedIn();
        await _editOffline(s.c, s.cloud, s.network);
        final pushes = s.cloud.pushCalls;
        s.network
          ..emit(true)
          ..emit(false);
        await settle();
        expect(s.cloud.pushCalls, pushes);
        expect(await _pendingIds(s.c), ['offline-edit']);
      },
    );

    test('connectivity is a hint: if Supabase is still unreachable the '
        'change stays queued and backoff resumes', () async {
      final s = await _signedIn();
      await _editOffline(s.c, s.cloud, s.network);
      final before =
          (await s.c.read(activeLocalStoreProvider)!.sync!.pending()).single;

      s.network.emit(true); // Wi-Fi without internet: cloud still offline
      await settle();

      final after =
          (await s.c.read(activeLocalStoreProvider)!.sync!.pending()).single;
      expect(after.opId, before.opId); // the same durable operation
      expect(after.attempts, before.attempts + 1);
      expect(after.nextAttemptAt, isNotNull); // backing off again
      expect(after.parked, isFalse);
      expect(s.c.read(syncControllerProvider).phase, SyncPhase.offline);

      // No loop: nothing else is sent without a new trigger.
      final pushes = s.cloud.pushCalls;
      final pulls = s.cloud.pullCalls;
      await settle(const Duration(milliseconds: 200));
      expect(s.cloud.pushCalls, pushes);
      expect(s.cloud.pullCalls, pulls);
    });

    test('reconnecting with nothing to send makes no request', () async {
      final s = await _signedIn();
      expect(s.c.read(syncControllerProvider).phase, SyncPhase.synced);
      final pushes = s.cloud.pushCalls;
      final pulls = s.cloud.pullCalls;

      s.network
        ..emit(false)
        ..emit(true);
      await settle();
      // A first "online" event (no known offline period) is not a trigger.
      s.network.emit(true);
      await settle();

      expect(s.cloud.pushCalls, pushes);
      expect(s.cloud.pullCalls, pulls);
    });

    test(
      'rejected (parked) operations are not retried automatically',
      () async {
        final s = await _signedIn();
        s.cloud.rejectIds.add('invalid');
        await s.c.read(subscriptionsProvider.notifier).add(sub('invalid'));
        await s.c.read(syncControllerProvider.notifier).sync();
        await settle();
        expect(s.c.read(syncControllerProvider).parkedCount, 1);
        final pushes = s.cloud.pushCalls;

        s.network
          ..emit(false)
          ..emit(true);
        await settle();

        expect(s.cloud.pushCalls, pushes);
        expect(s.c.read(syncControllerProvider).parkedCount, 1);
      },
    );

    test('a run that started before the network returned finishes first, '
        'then exactly one fresh run follows', () async {
      final cloud = FakeCloud();
      final gated = _GatedRemote(FakeSyncRemote(cloud));
      final s = await _signedIn(cloud: cloud, remote: gated);
      await _editOffline(s.c, s.cloud, s.network);

      // An automatic retry is in flight on the dead network.
      gated.gate = Completer<void>();
      final inFlight = s.c.read(syncControllerProvider.notifier).sync();
      await Future<void>.delayed(Duration.zero);

      s.network.emit(true);
      await settle(); // reconnect handler is now waiting for the old run
      s.cloud.offline = false;
      final pushes = s.cloud.pushCalls;
      expect(s.cloud.pushCalls, pushes); // still waiting for the old run
      gated.gate!.complete(); // the old request fails (it was offline)
      gated.gate = null;
      final old = await inFlight;
      await settle();

      expect(old!.failure, SyncFailureKind.network);
      expect(s.cloud.row('offline-edit'), isNotNull);
      expect(s.cloud.pushCalls - pushes, 1); // exactly one fresh delivery
      expect(s.c.read(syncControllerProvider).pendingCount, 0);
    });
  });

  group('lifecycle and isolation', () {
    test('guests never listen to connectivity or contact the server', () async {
      final cloud = FakeCloud();
      final network = FakeConnectivity();
      final c = (await app(
        cloud: cloud,
        overrides: [
          connectivitySignalProvider.overrideWithValue(network),
          connectivityDebounceProvider.overrideWithValue(_debounce),
        ],
      )).container;
      final keepAlive = c.listen(syncControllerProvider, (_, _) {});
      addTearDown(keepAlive.close);
      await c.read(subscriptionsProvider.notifier).add(sub('guest'));

      expect(network.hasListener, isFalse);
      network
        ..emit(false)
        ..emit(true);
      await settle();
      expect(cloud.pushCalls, 0);
      expect(cloud.pullCalls, 0);
      expect(c.read(syncControllerProvider).phase, SyncPhase.localOnly);
    });

    test('signing out stops listening and keeps pending changes', () async {
      final s = await _signedIn();
      expect(s.network.hasListener, isTrue);
      await _editOffline(s.c, s.cloud, s.network);

      await s.c.read(authControllerProvider.notifier).signOut();
      await settle();
      expect(s.network.hasListener, isFalse);

      s.cloud.offline = false;
      s.network.emit(true);
      await settle();
      expect(s.cloud.row('offline-edit'), isNull); // not sent while signed out

      // Back in: the change is still queued in Alex's database, and the
      // next reconnect delivers it.
      await signIn(s.c, alex);
      await settle();
      expect(await _pendingIds(s.c), ['offline-edit']);
      expect(s.network.hasListener, isTrue);
      s.network
        ..emit(false)
        ..emit(true);
      await settle();
      expect(s.cloud.row('offline-edit'), isNotNull);
    });

    test(
      'another account never sends the previous account\'s changes',
      () async {
        final s = await _signedIn();
        await _editOffline(s.c, s.cloud, s.network);
        await s.c.read(authControllerProvider.notifier).signOut();
        await signIn(s.c, blair);
        await settle();
        expect(await _pendingIds(s.c), isEmpty); // Blair's own (empty) outbox

        s.cloud.offline = false;
        s.network
          ..emit(false)
          ..emit(true);
        await settle();
        expect(s.cloud.row('offline-edit'), isNull);
      },
    );

    test('disposing the app cancels the listener and timers', () async {
      final s = await _signedIn();
      await _editOffline(s.c, s.cloud, s.network);
      s.cloud.offline = false;
      s.network.emit(true); // debounce timer pending
      s.c.dispose();
      expect(s.network.hasListener, isFalse);
      final pushes = s.cloud.pushCalls;
      await settle();
      expect(s.cloud.pushCalls, pushes);
    });
  });
}

/// Holds requests until [gate] completes (in-flight requests). A request
/// that started while the cloud was offline fails when released.
class _GatedRemote implements SyncRemote {
  _GatedRemote(this._inner);

  final FakeSyncRemote _inner;
  Completer<void>? gate;

  Future<void> _hold() async {
    final pending = gate;
    if (pending == null) return;
    final wasOffline = _inner.cloud.offline;
    await pending.future;
    if (wasOffline) {
      throw const SyncRemoteException(SyncFailureKind.network, 'offline');
    }
  }

  @override
  Future<PushResult> push({
    required String opId,
    required String subscriptionId,
    required OutboxKind kind,
    required int? baseVersion,
    Map<String, Object?>? payload,
  }) async {
    await _hold();
    return _inner.push(
      opId: opId,
      subscriptionId: subscriptionId,
      kind: kind,
      baseVersion: baseVersion,
      payload: payload,
    );
  }

  @override
  Future<PullPage> pull({required String? cursor, required int limit}) async {
    await _hold();
    return _inner.pull(cursor: cursor, limit: limit);
  }

  @override
  Future<RemoteProfile?> fetchProfile() => _inner.fetchProfile();

  @override
  Future<RemoteProfile> saveProfile({required String displayCurrency}) =>
      _inner.saveProfile(displayCurrency: displayCurrency);
}
