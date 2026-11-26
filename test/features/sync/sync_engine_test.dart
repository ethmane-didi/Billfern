import 'dart:io';

import 'package:billfern/features/sync/data/sync_store.dart';
import 'package:billfern/features/sync/domain/sync_engine.dart';
import 'package:billfern/features/sync/domain/sync_models.dart';
import 'package:billfern/shared/data/local_store.dart';
import 'package:billfern/shared/data/subscription_codec.dart';
import 'package:billfern/shared/models/billing_cycle.dart';
import 'package:billfern/shared/models/subscription.dart';
import 'package:billfern/shared/models/subscription_category.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_io.dart';

import '../../helpers/fake_cloud.dart';

final DateTime today = DateTime(2026, 11, 24);
DateTime now = DateTime(2026, 11, 24, 9);

const String userA = '0a000000-0000-4000-8000-00000000000a';

Subscription sub(
  String id, {
  int price = 1000,
  String currency = 'USD',
  String name = 'Netflix',
}) => Subscription(
  id: id,
  name: name,
  plan: '',
  priceMinor: price,
  currencyCode: currency,
  billingCycle: BillingCycle.monthly,
  category: SubscriptionCategory.entertainment,
  startedOn: DateTime(2026, 1, 1),
  billingAnchor: DateTime(2026, 12, 1),
  createdAt: DateTime(2026, 1, 1, 10),
);

/// One device: its own local account store and an engine on a shared cloud.
class Device {
  Device._(this.store, this.engine);

  final LocalStore store;
  final SyncEngine engine;

  static Future<Device> open(
    FakeCloud cloud, {
    SembastLocalStoreOpener? opener,
    int pageSize = 200,
  }) async {
    final store = await (opener ?? memoryOpener(clock: () => now)).open(
      LocalIdentity.account(userA),
    );
    return Device._(
      store,
      SyncEngine(
        store: store.sync!,
        repository: store.subscriptions,
        remote: FakeSyncRemote(cloud),
        clock: () => now,
        pageSize: pageSize,
      ),
    );
  }

  SyncStore get sync => store.sync!;

  Future<void> save(Subscription s) => store.subscriptions.save(s);

  Subscription? find(String id) => store.subscriptions.find(id);
}

void main() {
  late FakeCloud cloud;

  setUp(() {
    cloud = FakeCloud();
    now = DateTime(2026, 11, 24, 9);
  });

  group('offline-first local changes', () {
    test('saving offline records a pending operation atomically', () async {
      final device = await Device.open(cloud);
      cloud.offline = true;
      await device.save(sub('a'));

      expect(device.find('a'), isNotNull);
      final ops = await device.sync.pending();
      expect(ops.single.subscriptionId, 'a');
      expect(ops.single.kind, OutboxKind.upsert);

      final report = await device.engine.sync();
      expect(report.failure, SyncFailureKind.network);
      final after = (await device.sync.pending()).single;
      expect(after.attempts, 1);
      expect(after.nextAttemptAt, isNotNull);
      final status = await device.engine.status(phase: SyncPhase.offline);
      expect(status.phase, SyncPhase.offline);
      expect(status.pendingCount, 1);
      expect(status.isFullySynced, isFalse);
    });

    test('changes sync when connectivity returns', () async {
      final device = await Device.open(cloud);
      cloud.offline = true;
      await device.save(sub('a'));
      await device.engine.sync();

      cloud.offline = false;
      // Still backing off: an automatic run sends nothing.
      expect((await device.engine.sync()).pushed, 0);
      // After the backoff delay (or a manual retry) it is delivered.
      now = now.add(const Duration(minutes: 1));
      final report = await device.engine.sync();
      expect(report.pushed, 1);
      expect(await device.sync.pending(), isEmpty);
      expect(cloud.versionOf('a'), 1);
      expect(await device.sync.versionOf(device.sync.database, 'a'), 1);
      final status = await device.engine.status(phase: SyncPhase.synced);
      expect(status.isFullySynced, isTrue);
    });

    test(
      'edit, pause, resume and archive sync as version-checked updates',
      () async {
        final device = await Device.open(cloud);
        await device.save(sub('a'));
        await device.engine.sync();

        await device.save(device.find('a')!.copyWith(priceMinor: 1299));
        await device.engine.sync();
        await device.save(device.find('a')!.pause(DateTime(2026, 11, 10)));
        await device.engine.sync();
        await device.save(device.find('a')!.resume(today));
        await device.engine.sync();
        await device.save(device.find('a')!.end(today));
        await device.engine.sync();

        final remote = cloud.row('a')!.subscription!;
        expect(cloud.versionOf('a'), 5);
        expect(remote.priceMinor, 1299);
        expect(remote.pauseHistory, [
          PausePeriod(from: DateTime(2026, 11, 10), until: today),
        ]);
        expect(remote.endedOn, today);
        expect(remote, device.find('a'));
      },
    );

    test('quick successive edits before syncing are merged', () async {
      final device = await Device.open(cloud);
      await device.save(sub('a'));
      await device.save(device.find('a')!.copyWith(priceMinor: 1100));
      await device.save(device.find('a')!.copyWith(priceMinor: 1200));
      expect(await device.sync.pending(), hasLength(1));
      await device.engine.sync();
      expect(cloud.pushCalls, 1);
      expect(cloud.row('a')!.subscription!.priceMinor, 1200);
    });

    test('deletion leaves a tombstone in the cloud', () async {
      final device = await Device.open(cloud);
      await device.save(sub('a'));
      await device.engine.sync();
      await device.store.subscriptions.delete('a');
      await device.engine.sync();
      expect(cloud.isDeleted('a'), isTrue);
      expect(await device.sync.pending(), isEmpty);
    });
  });

  group('delivery guarantees', () {
    test('a lost acknowledgement is retried without applying twice', () async {
      final device = await Device.open(cloud);
      await device.save(sub('a'));
      cloud.loseNextResponses = 1;
      final first = await device.engine.sync();
      expect(first.failure, SyncFailureKind.network);
      expect(cloud.versionOf('a'), 1); // applied on the server

      final second = await device.engine.sync(manual: true);
      expect(second.succeeded, isTrue);
      expect(cloud.versionOf('a'), 1); // not applied again
      expect(await device.sync.pending(), isEmpty);
      expect(await device.sync.versionOf(device.sync.database, 'a'), 1);
    });

    test('attempted operations are never merged with newer edits', () async {
      final device = await Device.open(cloud);
      await device.save(sub('a'));
      cloud.offline = true;
      await device.engine.sync(); // attempt 1 fails
      await device.save(device.find('a')!.copyWith(priceMinor: 1500));
      expect(await device.sync.pending(), hasLength(2));
      cloud.offline = false;
      await device.engine.sync(manual: true);
      expect(await device.sync.pending(), isEmpty);
      expect(cloud.row('a')!.subscription!.priceMinor, 1500);
      expect(cloud.versionOf('a'), 2);
    });

    test('rejected operations are parked, never discarded', () async {
      final device = await Device.open(cloud);
      await device.save(sub('a'));
      await device.save(sub('bad', name: 'Bad'));
      await device.save(sub('c'));
      cloud.rejectIds.add('bad');

      final report = await device.engine.sync();
      expect(report.pushed, 2);
      expect(cloud.row('a'), isNotNull);
      expect(cloud.row('c'), isNotNull);
      final ops = await device.sync.pending();
      expect(ops.single.subscriptionId, 'bad');
      expect(ops.single.parked, isTrue);
      final status = await device.engine.status(phase: SyncPhase.synced);
      expect(status.phase, SyncPhase.failed);
      expect(status.parkedCount, 1);

      cloud.rejectIds.clear();
      await device.engine.retryParked();
      await device.engine.sync();
      expect(await device.sync.pending(), isEmpty);
    });

    test('concurrent sync calls share one run', () async {
      final device = await Device.open(cloud);
      await device.save(sub('a'));
      final runs = [device.engine.sync(), device.engine.sync()];
      final reports = await Future.wait(runs);
      expect(identical(reports[0], reports[1]), isTrue);
      expect(cloud.pushCalls, 1);
    });

    test('pending operations survive an app restart', () async {
      final dir = await Directory.systemTemp.createTemp('billfern_sync');
      addTearDown(() => dir.delete(recursive: true));
      final opener = SembastLocalStoreOpener(databaseFactoryIo, dir.path);

      var device = await Device.open(cloud, opener: opener);
      cloud.offline = true;
      await device.save(sub('a'));
      await device.engine.sync();
      await device.store.close(); // "app killed"

      cloud.offline = false;
      device = await Device.open(cloud, opener: opener);
      expect(device.find('a'), isNotNull);
      final pending = await device.sync.pending();
      expect(pending.single.attempts, 1);
      await device.engine.sync(manual: true);
      expect(cloud.versionOf('a'), 1);
      expect(await device.sync.pending(), isEmpty);
      await device.store.close();
    });

    test('retry backoff is exponential and bounded', () {
      const policy = RetryPolicy();
      expect(policy.delayAfter(1), const Duration(seconds: 5));
      expect(policy.delayAfter(2), const Duration(seconds: 10));
      expect(policy.delayAfter(4), const Duration(seconds: 40));
      expect(policy.delayAfter(30), const Duration(minutes: 15));
    });
  });

  group('downloading changes', () {
    test('pulls pages in sequence order without creating operations', () async {
      final writer = await Device.open(cloud);
      for (var i = 0; i < 5; i++) {
        await writer.save(sub('s$i', price: 100 + i));
      }
      await writer.engine.sync();

      final reader = await Device.open(cloud, pageSize: 2);
      final report = await reader.engine.sync();
      expect(report.pulled, 5);
      expect(reader.store.subscriptions.fetchAll(), hasLength(5));
      expect(await reader.sync.pending(), isEmpty);
      expect(await reader.sync.cursor(), '5');
      expect(cloud.pushCalls, 5); // the reader pushed nothing
    });

    test('a pull never overwrites a pending local change', () async {
      final a = await Device.open(cloud);
      await a.save(sub('x'));
      await a.engine.sync();
      final b = await Device.open(cloud);
      await b.engine.sync();

      cloud.offline = true;
      await b.save(b.find('x')!.copyWith(priceMinor: 2000)); // pending on B
      cloud.offline = false;
      cloud.serverEdit(
        'x',
        SubscriptionCodec.toMap(sub('x').copyWith(priceMinor: 3000)),
      );
      // B's push conflicts; its local edit is kept, not silently replaced.
      await b.engine.sync();
      expect(b.find('x')!.priceMinor, 2000);
      expect(await b.sync.conflictList(), hasLength(1));
    });

    test('deletions from another device are applied locally', () async {
      final a = await Device.open(cloud);
      await a.save(sub('x'));
      await a.engine.sync();
      final b = await Device.open(cloud);
      await b.engine.sync();
      expect(b.find('x'), isNotNull);

      await a.store.subscriptions.delete('x');
      await a.engine.sync();
      await b.engine.sync();
      expect(b.find('x'), isNull);
    });
  });

  group('conflicts', () {
    Future<(Device, Device)> twoDevices() async {
      final a = await Device.open(cloud);
      await a.save(sub('x', price: 1000));
      await a.engine.sync();
      final b = await Device.open(cloud);
      await b.engine.sync();
      return (a, b);
    }

    test('conflicting price changes are never silently overwritten', () async {
      final (a, b) = await twoDevices();
      await a.save(a.find('x')!.copyWith(priceMinor: 1500));
      await a.engine.sync();
      await b.save(b.find('x')!.copyWith(priceMinor: 900));
      final report = await b.engine.sync();

      expect(report.conflicts, 1);
      expect(cloud.row('x')!.subscription!.priceMinor, 1500);
      expect(b.find('x')!.priceMinor, 900);
      final status = await b.engine.status(phase: SyncPhase.synced);
      expect(status.phase, SyncPhase.conflict);
      expect(status.isFullySynced, isFalse);
    });

    test('"use cloud" adopts the other device\'s version', () async {
      final (a, b) = await twoDevices();
      await a.save(a.find('x')!.copyWith(billingCycle: BillingCycle.yearly));
      await a.engine.sync();
      await b.save(b.find('x')!.copyWith(priceMinor: 900));
      await b.engine.sync();

      await b.engine.resolveConflict('x', ConflictChoice.useCloud);
      expect(b.find('x')!.billingCycle, BillingCycle.yearly);
      expect(b.find('x')!.priceMinor, 1000);
      expect(await b.sync.conflictList(), isEmpty);
      expect(await b.sync.pending(), isEmpty);
    });

    test('"keep this device" replaces the cloud version explicitly', () async {
      final (a, b) = await twoDevices();
      await a.save(a.find('x')!.copyWith(priceMinor: 1500));
      await a.engine.sync();
      await b.save(b.find('x')!.copyWith(priceMinor: 900));
      await b.engine.sync();

      await b.engine.resolveConflict('x', ConflictChoice.keepThisDevice);
      await b.engine.sync();
      expect(cloud.row('x')!.subscription!.priceMinor, 900);
      await a.engine.sync();
      expect(a.find('x')!.priceMinor, 900);
    });

    test('concurrent pause and resume become a conflict', () async {
      final (a, b) = await twoDevices();
      await a.save(a.find('x')!.pause(today));
      await a.engine.sync();
      await b.save(b.find('x')!.copyWith(notes: 'Family plan'));
      expect((await b.engine.sync()).conflicts, 1);
    });

    test('deletion on one device vs edit on another', () async {
      final (a, b) = await twoDevices();
      await a.store.subscriptions.delete('x');
      await a.engine.sync();
      await b.save(b.find('x')!.copyWith(priceMinor: 1200));
      await b.engine.sync();

      // The outdated edit did not resurrect the record.
      expect(cloud.isDeleted('x'), isTrue);
      final conflict = (await b.sync.conflictList()).single;
      expect(conflict.remote!.isDeleted, isTrue);

      // The user can restore it deliberately.
      await b.engine.resolveConflict('x', ConflictChoice.keepThisDevice);
      await b.engine.sync();
      expect(cloud.isDeleted('x'), isFalse);
      expect(cloud.row('x')!.subscription!.priceMinor, 1200);
    });

    test('accepting a deletion removes the local copy', () async {
      final (a, b) = await twoDevices();
      await a.store.subscriptions.delete('x');
      await a.engine.sync();
      await b.save(b.find('x')!.copyWith(priceMinor: 1200));
      await b.engine.sync();
      await b.engine.resolveConflict('x', ConflictChoice.useCloud);
      expect(b.find('x'), isNull);
      expect(await b.sync.pending(), isEmpty);
    });

    test('identical data on both sides is not a conflict', () async {
      final a = await Device.open(cloud);
      await a.save(sub('x'));
      await a.engine.sync();
      // A second device adds the very same record without knowing its
      // version (e.g. a repeated guest migration).
      final b = await Device.open(cloud);
      await b.save(sub('x'));
      final report = await b.engine.sync();
      expect(report.conflicts, 0);
      expect(await b.sync.conflictList(), isEmpty);
      expect(await b.sync.pending(), isEmpty);
    });
  });

  test('history and mixed currencies survive a round trip', () async {
    final a = await Device.open(cloud);
    final original = sub('x', price: 19900, currency: 'NOK')
        .copyWith(priceMinor: 22900)
        .revisedFrom(sub('x', price: 19900, currency: 'NOK'), today)
        .pause(DateTime(2026, 6, 1))
        .resume(DateTime(2026, 7, 1));
    await a.save(original);
    await a.engine.sync();

    final b = await Device.open(cloud);
    await b.engine.sync();
    final copy = b.find('x')!;
    expect(copy, original);
    expect(copy.priceHistory.single.priceMinor, 19900);
    expect(copy.pauseHistory, hasLength(1));
    expect(copy.currencyCode, 'NOK');
  });
}
