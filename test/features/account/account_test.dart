import 'package:billfern/features/account/data/auth_repository.dart';
import 'package:billfern/features/account/domain/auth_models.dart';
import 'package:billfern/features/account/domain/data_export.dart';
import 'package:billfern/features/account/domain/guest_migration.dart';
import 'package:billfern/features/account/presentation/providers/account_providers.dart';
import 'package:billfern/features/analytics/presentation/providers/analytics_providers.dart';
import 'package:billfern/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:billfern/features/sync/domain/sync_models.dart';
import 'package:billfern/features/sync/domain/sync_remote.dart';
import 'package:billfern/features/sync/presentation/providers/sync_providers.dart';
import 'package:billfern/shared/data/local_store.dart';
import 'package:billfern/shared/data/subscription_codec.dart';
import 'package:billfern/shared/models/billing_cycle.dart';
import 'package:billfern/shared/models/subscription.dart';
import 'package:billfern/shared/models/subscription_category.dart';
import 'package:billfern/shared/providers/currency_providers.dart';
import 'package:billfern/shared/providers/local_store_providers.dart';
import 'package:billfern/shared/providers/subscription_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_cloud.dart';
import '../../helpers/fixed_clock.dart';

const String alex = 'alex@example.test';
const String blair = 'blair@example.test';
const String alexId = '0a000000-0000-4000-8000-00000000000a';
const String blairId = '0b000000-0000-4000-8000-00000000000b';

Subscription sub(String id, {String name = 'Netflix', int price = 1549}) =>
    Subscription(
      id: id,
      name: name,
      plan: 'Standard',
      priceMinor: price,
      currencyCode: 'USD',
      billingCycle: BillingCycle.monthly,
      category: SubscriptionCategory.entertainment,
      startedOn: DateTime(2026, 1, 1),
      billingAnchor: DateTime(2026, 12, 1),
      notes: 'Shared with family',
    );

/// A container wired like `main`, with in-memory databases.
Future<
  ({
    ProviderContainer container,
    FakeAuthRepository auth,
    SembastLocalStoreOpener opener,
  })
>
app({
  AccountUserSeed? restored,
  List<Subscription> guestSeed = const [],
  AuthRepository? authOverride,
  FakeCloud? cloud,
  SyncRemote? remote,
  List<Override> overrides = const [],
}) async {
  final opener = memoryOpener(clock: () => fixedNow);
  final guest = await opener.open(LocalIdentity.guest);
  for (final s in guestSeed) {
    await guest.subscriptions.save(s);
  }
  final auth = FakeAuthRepository(currentUser: restored?.user);
  final initial = restored == null
      ? guest
      : await opener.open(LocalIdentity.account(restored.user.id));
  if (restored != null) await guest.close();
  final container = ProviderContainer(
    overrides: [
      ...baseTestOverrides,
      ...preferenceOverrides(),
      authRepositoryProvider.overrideWithValue(authOverride ?? auth),
      localStoreOpenerProvider.overrideWithValue(opener),
      initialLocalStoreProvider.overrideWithValue(initial),
      if (remote != null)
        syncRemoteProvider.overrideWithValue(remote)
      else if (cloud != null)
        syncRemoteProvider.overrideWithValue(FakeSyncRemote(cloud)),
      syncDebounceProvider.overrideWithValue(Duration.zero),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);
  return (container: container, auth: auth, opener: opener);
}

class AccountUserSeed {
  const AccountUserSeed(this.user);
  final AccountUser user;
}

Future<void> signIn(ProviderContainer c, String email) async {
  final auth = c.read(authControllerProvider.notifier);
  await auth.requestCode(email, createAccount: false);
  await auth.verifyCode(email, '123456');
}

List<String> visibleIds(ProviderContainer c) =>
    [for (final s in c.read(subscriptionsProvider)) s.id]..sort();

void main() {
  group('authentication', () {
    test('without a backend Billfern stays local-only', () async {
      final c = (await app(authOverride: const LocalOnlyAuthRepository()))
          .container;
      expect(c.read(authControllerProvider), isA<AuthUnavailable>());
      await c.read(subscriptionsProvider.notifier).add(sub('local'));
      expect(visibleIds(c), ['local']);
      expect(c.read(syncControllerProvider).phase, SyncPhase.localOnly);
      await expectLater(
        c
            .read(authControllerProvider.notifier)
            .requestCode(alex, createAccount: true),
        throwsA(
          isA<AuthFailure>().having(
            (f) => f.kind,
            'kind',
            AuthFailureKind.notConfigured,
          ),
        ),
      );
    });

    test('guests can use everything without an account', () async {
      final c = (await app()).container;
      expect(c.read(authControllerProvider), isA<SignedOut>());
      await c.read(subscriptionsProvider.notifier).add(sub('g1'));
      expect(visibleIds(c), ['g1']);
      expect(c.read(activeLocalStoreProvider)!.sync, isNull); // no outbox
    });

    test('creating an account and verifying the code signs in', () async {
      final setup = await app();
      final c = setup.container;
      final auth = c.read(authControllerProvider.notifier);
      await auth.requestCode('new@example.test', createAccount: true);
      await auth.verifyCode('new@example.test', '123456');
      final status = c.read(authControllerProvider);
      expect(status, isA<SignedIn>());
      expect(c.read(activeLocalStoreProvider)!.identity.isGuest, isFalse);
    });

    test('authentication failures are reported, not swallowed', () async {
      final setup = await app();
      final auth = setup.container.read(authControllerProvider.notifier);
      await expectLater(
        auth.requestCode('nobody@example.test', createAccount: false),
        throwsA(
          isA<AuthFailure>().having(
            (f) => f.kind,
            'kind',
            AuthFailureKind.accountNotFound,
          ),
        ),
      );
      await auth.requestCode(alex, createAccount: false);
      await expectLater(
        auth.verifyCode(alex, '000000'),
        throwsA(
          isA<AuthFailure>().having(
            (f) => f.kind,
            'kind',
            AuthFailureKind.invalidCode,
          ),
        ),
      );
      setup.auth.failNextRequest = AuthFailureKind.rateLimited;
      await expectLater(
        auth.requestCode(alex, createAccount: false),
        throwsA(
          isA<AuthFailure>().having(
            (f) => f.kind,
            'kind',
            AuthFailureKind.rateLimited,
          ),
        ),
      );
      expect(setup.container.read(authControllerProvider), isA<SignedOut>());
    });

    test('a restored session opens the account store at launch', () async {
      final c = (await app(
        restored: const AccountUserSeed(AccountUser(id: alexId, email: alex)),
      )).container;
      expect(c.read(authControllerProvider), isA<SignedIn>());
      expect(
        c.read(activeLocalStoreProvider)!.identity,
        LocalIdentity.account(alexId),
      );
    });

    test('an expired session returns to guest data and says so', () async {
      final setup = await app(
        restored: const AccountUserSeed(AccountUser(id: alexId, email: alex)),
      );
      final c = setup.container;
      await c.read(subscriptionsProvider.notifier).add(sub('acct'));
      c.read(authControllerProvider);
      setup.auth.expireSession();
      await pumpEventQueue();
      final status = c.read(authControllerProvider);
      expect(status, isA<SignedOut>());
      expect((status as SignedOut).sessionExpired, isTrue);
      expect(visibleIds(c), isEmpty); // account data hidden, not deleted

      await signIn(c, alex);
      expect(visibleIds(c), ['acct']);
    });
  });

  group('account isolation', () {
    test('switching accounts never shows another account\'s data', () async {
      final c = (await app(guestSeed: [sub('guest')])).container;
      expect(visibleIds(c), ['guest']);

      await signIn(c, alex);
      expect(visibleIds(c), isEmpty);
      await c.read(subscriptionsProvider.notifier).add(sub('alex-1'));

      await c.read(authControllerProvider.notifier).signOut();
      expect(visibleIds(c), ['guest']);

      await signIn(c, blair);
      expect(visibleIds(c), isEmpty);
      await c.read(subscriptionsProvider.notifier).add(sub('blair-1'));
      final blairOps = await c.read(activeLocalStoreProvider)!.sync!.pending();
      expect([for (final op in blairOps) op.subscriptionId], ['blair-1']);

      await c.read(authControllerProvider.notifier).signOut();
      await signIn(c, alex);
      expect(visibleIds(c), ['alex-1']);
      final alexOps = await c.read(activeLocalStoreProvider)!.sync!.pending();
      expect([for (final op in alexOps) op.subscriptionId], ['alex-1']);
    });

    test('signing out keeps unsynced changes for the next sign-in', () async {
      final cloud = FakeCloud()..offline = true;
      final c = (await app(cloud: cloud)).container;
      await signIn(c, alex);
      await c.read(subscriptionsProvider.notifier).add(sub('pending'));
      await c.read(syncControllerProvider.notifier).sync();
      expect(cloud.rowCount, 0);

      await c.read(authControllerProvider.notifier).signOut();
      cloud.offline = false;
      await signIn(c, alex);
      await c.read(syncControllerProvider.notifier).sync(manual: true);
      expect(cloud.row('pending'), isNotNull);
    });

    test('Retry sync after reconnecting sends pending changes at once, '
        'ignoring a long backoff', () async {
      final cloud = FakeCloud();
      final c = (await app(cloud: cloud)).container;
      final keepAlive = c.listen(syncControllerProvider, (_, _) {});
      addTearDown(keepAlive.close);
      await signIn(c, alex);
      await c.read(syncControllerProvider.notifier).sync();

      cloud.offline = true;
      await c.read(subscriptionsProvider.notifier).add(sub('offline-edit'));
      // Several automatic attempts fail, so the backoff grows.
      for (var i = 0; i < 4; i++) {
        await c.read(syncControllerProvider.notifier).sync(manual: i.isOdd);
      }
      final offline = c.read(syncControllerProvider);
      expect(offline.phase, SyncPhase.offline);
      expect(offline.pendingCount, 1);
      final ops = await c.read(activeLocalStoreProvider)!.sync!.pending();
      expect(ops.single.nextAttemptAt, isNotNull); // backing off
      expect(visibleIds(c), ['offline-edit']); // local data intact

      cloud.offline = false;
      final report = await c
          .read(syncControllerProvider.notifier)
          .sync(manual: true);
      expect(report!.pushed, 1);
      final status = c.read(syncControllerProvider);
      expect(status.phase, SyncPhase.synced);
      expect(status.pendingCount, 0);
      expect(cloud.row('offline-edit'), isNotNull);
      expect(visibleIds(c), ['offline-edit']);
    });

    test('sample data never enters an account or its outbox', () async {
      final cloud = FakeCloud();
      final c = (await app(cloud: cloud)).container;
      await signIn(c, alex);
      await c.read(dataModeProvider.notifier).set(DataMode.sample);
      expect(c.read(subscriptionsProvider), isNotEmpty);
      await c.read(subscriptionsProvider.notifier).delete('netflix');
      await c.read(syncControllerProvider.notifier).sync(manual: true);
      expect(await c.read(activeLocalStoreProvider)!.sync!.pending(), isEmpty);
      expect(cloud.rowCount, 0);
      expect(cloud.pushCalls, 0);
    });
  });

  group('guest-to-account migration', () {
    final history = sub('hist', name: 'Spotify', price: 1199)
        .copyWith(priceMinor: 1299)
        .revisedFrom(sub('hist', name: 'Spotify', price: 1199), fixedNow)
        .pause(DateTime(2026, 5, 1))
        .resume(DateTime(2026, 6, 1));
    final ended = sub('old', name: 'Old service').end(DateTime(2026, 10, 1));
    final guestData = [
      sub('n1'),
      sub('n2'), // same service name, different subscription
      history,
      ended,
    ];

    test('asks for consent and summarises what would be uploaded', () async {
      final c = (await app(guestSeed: guestData)).container;
      await signIn(c, alex);
      final state = await c.read(guestMigrationProvider.future);
      expect(state, isA<GuestMigrationNeeded>());
      final summary = (state as GuestMigrationNeeded).summary;
      expect(summary.currentCount, 3);
      expect(summary.endedCount, 1);
      expect(summary.accountHasData, isFalse);
      // Nothing is uploaded before consent.
      expect(await c.read(activeLocalStoreProvider)!.sync!.pending(), isEmpty);
    });

    test(
      'merging preserves every field, history and duplicates by name',
      () async {
        final cloud = FakeCloud();
        final c = (await app(guestSeed: guestData, cloud: cloud)).container;
        await signIn(c, alex);
        await c.read(guestMigrationProvider.future);
        final copied = await c.read(guestMigrationProvider.notifier).merge();
        expect(copied, 4);
        await c.read(syncControllerProvider.notifier).sync(manual: true);

        for (final original in guestData) {
          final remote = cloud.row(original.id)!.subscription!;
          expect(
            SubscriptionCodec.toMap(remote),
            SubscriptionCodec.toMap(original),
          );
        }
        expect(cloud.row('n1'), isNotNull);
        expect(cloud.row('n2'), isNotNull);
        expect(c.read(endedSubscriptionsProvider).single.id, 'old');
        expect(
          await c.read(guestMigrationProvider.future),
          isA<NoGuestMigration>(),
        );
      },
    );

    test('merging is idempotent and resumable', () async {
      final setup = await app(guestSeed: guestData);
      final account = await setup.opener.open(LocalIdentity.account(alexId));
      final guest = await setup.opener.open(LocalIdentity.guest);
      const service = GuestMigrationService();
      // Simulate an interrupted run: one record already copied.
      await account.subscriptions.save(guestData.first);
      expect(await service.merge(guest: guest, account: account), 3);
      expect(await service.merge(guest: guest, account: account), 0);
      expect(account.subscriptions.fetchEverything(), hasLength(4));
      expect(await account.sync!.pending(), hasLength(4));
      // Guest data is never deleted.
      expect(guest.subscriptions.fetchEverything(), hasLength(4));
    });

    test('declining keeps guest data on the device only', () async {
      final cloud = FakeCloud();
      final c = (await app(guestSeed: guestData, cloud: cloud)).container;
      await signIn(c, alex);
      await c.read(guestMigrationProvider.future);
      await c.read(guestMigrationProvider.notifier).decline();
      await c.read(syncControllerProvider.notifier).sync(manual: true);
      expect(cloud.rowCount, 0);
      expect(
        await c.read(guestMigrationProvider.future),
        isA<NoGuestMigration>(),
      );
      await c.read(authControllerProvider.notifier).signOut();
      expect(visibleIds(c), ['hist', 'n1', 'n2']);
    });

    test(
      'an account that already has cloud data is merged, not replaced',
      () async {
        final cloud = FakeCloud();
        // Another device already uploaded a subscription.
        final other = (await app(cloud: cloud)).container;
        await signIn(other, alex);
        await other
            .read(subscriptionsProvider.notifier)
            .add(sub('cloud-1', name: 'Netflix'));
        await other.read(syncControllerProvider.notifier).sync(manual: true);

        final c = (await app(guestSeed: [sub('n1')], cloud: cloud)).container;
        await signIn(c, alex);
        await c.read(syncControllerProvider.notifier).sync(manual: true);
        final state = await c.read(guestMigrationProvider.future);
        expect((state as GuestMigrationNeeded).summary.accountHasData, isTrue);
        await c.read(guestMigrationProvider.notifier).merge();
        await c.read(syncControllerProvider.notifier).sync(manual: true);
        expect(visibleIds(c), ['cloud-1', 'n1']);
        expect(cloud.rowCount, 2);
      },
    );
  });

  group('deletion, reset and export', () {
    test('account deletion erases the account\'s local data', () async {
      final setup = await app(guestSeed: [sub('guest')]);
      final c = setup.container;
      await signIn(c, alex);
      await c.read(subscriptionsProvider.notifier).add(sub('acct'));
      await c.read(authControllerProvider.notifier).deleteAccount();

      expect(setup.auth.deleteCalls, 1);
      expect(c.read(authControllerProvider), isA<SignedOut>());
      expect(visibleIds(c), ['guest']);
      final reopened = await setup.opener.open(LocalIdentity.account(alexId));
      expect(reopened.subscriptions.fetchEverything(), isEmpty);
      expect(await reopened.sync!.pending(), isEmpty);
    });

    test('a failed deletion keeps everything', () async {
      final setup = await app();
      final c = setup.container;
      await signIn(c, alex);
      await c.read(subscriptionsProvider.notifier).add(sub('acct'));
      setup.auth.deleteFails = true;
      await expectLater(
        c.read(authControllerProvider.notifier).deleteAccount(),
        throwsA(isA<AuthFailure>()),
      );
      expect(c.read(authControllerProvider), isA<SignedIn>());
      expect(visibleIds(c), ['acct']);
    });

    test('erasing guest data on this device removes history too', () async {
      final c = (await app(
        guestSeed: [sub('a'), sub('b').end(DateTime(2026, 10, 1))],
      )).container;
      expect(c.read(subscriptionHistoryProvider), hasLength(2));
      await c.read(authControllerProvider.notifier).eraseThisDevice();
      expect(c.read(subscriptionHistoryProvider), isEmpty);
      expect(c.read(activeLocalStoreProvider)!.identity.isGuest, isTrue);
    });

    test(
      'erasing an account\'s device copy re-downloads from the cloud',
      () async {
        final cloud = FakeCloud();
        final c = (await app(cloud: cloud)).container;
        await signIn(c, alex);
        await c.read(subscriptionsProvider.notifier).add(sub('acct'));
        await c.read(syncControllerProvider.notifier).sync(manual: true);

        await c.read(authControllerProvider.notifier).eraseThisDevice();
        expect(visibleIds(c), isEmpty);
        await c.read(syncControllerProvider.notifier).sync(manual: true);
        expect(visibleIds(c), ['acct']);
      },
    );

    test('export includes current and archived subscriptions', () {
      final json = const DataExportService().build([
        sub('a'),
        sub('b').end(DateTime(2026, 10, 1)),
      ], exportedAt: fixedNow);
      expect(json['format'], 'billfern-export');
      expect((json['subscriptions']! as List).single, containsPair('id', 'a'));
      expect(
        (json['endedSubscriptions']! as List).single,
        containsPair('priceMinor', 1549),
      );
    });
  });

  test(
    'synced devices show identical dashboard and analytics figures',
    () async {
      final cloud = FakeCloud();
      final a = (await app(cloud: cloud)).container;
      await signIn(a, alex);
      final notifier = a.read(subscriptionsProvider.notifier);
      await notifier.add(sub('usd'));
      await notifier.add(
        Subscription(
          id: 'nok',
          name: 'Viaplay',
          plan: '',
          priceMinor: 19900,
          currencyCode: 'NOK',
          billingCycle: BillingCycle.monthly,
          category: SubscriptionCategory.entertainment,
          startedOn: DateTime(2026, 3, 1),
          billingAnchor: DateTime(2026, 12, 3),
        ),
      );
      await notifier.update(notifier.byId('usd')!.copyWith(priceMinor: 1799));
      await notifier.add(sub('gone'));
      await notifier.delete('gone'); // started before this month: archived
      await a.read(syncControllerProvider.notifier).sync(manual: true);

      final b = (await app(cloud: cloud)).container;
      await signIn(b, alex);
      await b.read(syncControllerProvider.notifier).sync(manual: true);

      for (final read in [
        (ProviderContainer c) => c.read(spendingSummaryProvider).monthlyTotal,
        (ProviderContainer c) =>
            c.read(spendingSummaryProvider).previousMonthTotal,
        (ProviderContainer c) =>
            c.read(spendingSummaryProvider).projectedYearly,
        (ProviderContainer c) => c
            .read(spendingTrendProvider)
            .points
            .map((p) => p.estimated)
            .toList(),
        (ProviderContainer c) =>
            c.read(categoryBreakdownProvider).map((s) => s.total).toList(),
      ]) {
        expect(read(b), read(a));
      }
      expect(
        b.read(spendingSummaryProvider).isEstimate,
        isTrue,
      ); // NOK converted
      expect(b.read(endedSubscriptionsProvider).single.id, 'gone');
    },
  );

  test('the display currency syncs in both directions', () async {
    final cloud = FakeCloud();
    final a = (await app(cloud: cloud)).container;
    await signIn(a, alex);
    await a.read(syncControllerProvider.notifier).sync(manual: true);
    expect(cloud.profileCurrency, 'USD'); // first device uploads

    await a.read(preferredCurrencyProvider.notifier).select('NOK');
    await a.read(syncControllerProvider.notifier).sync(manual: true);
    expect(cloud.profileCurrency, 'NOK');

    // A second device adopts the account's currency…
    final b = (await app(cloud: cloud)).container;
    await signIn(b, alex);
    await b.read(syncControllerProvider.notifier).sync(manual: true);
    expect(b.read(preferredCurrencyProvider), 'NOK');

    // …and a change made there reaches the first device.
    await b.read(preferredCurrencyProvider.notifier).select('EUR');
    await b.read(syncControllerProvider.notifier).sync(manual: true);
    expect(cloud.profileCurrency, 'EUR');
    await a.read(syncControllerProvider.notifier).sync(manual: true);
    expect(a.read(preferredCurrencyProvider), 'EUR');
    // Stored amounts never change with the display currency.
    expect(a.read(subscriptionsProvider), isEmpty);
  });

  test('the guest database keeps its original file name', () {
    expect(LocalIdentity.guest.databaseFileName, 'billfern.db');
    expect(
      LocalIdentity.account(alexId).databaseFileName,
      'billfern_account_$alexId.db',
    );
    expect(() => LocalIdentity.account('../../etc'), throwsArgumentError);
  });
}
