// Live validation against the billfern-dev Supabase project.
//
//   flutter test test_live/live_supabase_test.dart --concurrency=1
//
// Needs (both git-ignored):
//   config/supabase.json             SUPABASE_URL + SUPABASE_PUBLISHABLE_KEY
//   config/supabase.test.local.json  dedicated test users (see the example)
//
// Uses ONLY synthetic test data and dedicated test accounts. Never point it
// at production. Records are created with a per-run id prefix; synced
// deletions leave tombstones by design.
//
// This file deliberately uses plain `test()` (no widget binding), so real
// HTTP is allowed. It lives outside `test/` so normal test runs stay
// offline and hermetic.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:billfern/core/config/supabase_config.dart';
import 'package:billfern/core/utils/uuid.dart';
import 'package:billfern/features/account/domain/guest_migration.dart';
import 'package:billfern/features/sync/data/supabase_sync_remote.dart';
import 'package:billfern/features/sync/domain/sync_engine.dart';
import 'package:billfern/features/sync/domain/sync_models.dart';
import 'package:billfern/features/sync/domain/sync_remote.dart';
import 'package:billfern/shared/data/local_store.dart';
import 'package:billfern/shared/data/subscription_codec.dart';
import 'package:billfern/shared/models/billing_cycle.dart';
import 'package:billfern/shared/models/subscription.dart';
import 'package:billfern/shared/models/subscription_category.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show
        AuthClientOptions,
        AuthException,
        FunctionException,
        PostgrestException,
        SupabaseClient;

class _Live {
  _Live(this.config, this.users);
  final SupabaseConfig config;
  final Map<String, ({String email, String password})> users;
}

_Live? _load() {
  final configFile = File('config/supabase.json');
  final usersFile = File('config/supabase.test.local.json');
  if (!configFile.existsSync() || !usersFile.existsSync()) return null;
  final c = jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
  final config = SupabaseConfig(
    url: '${c['SUPABASE_URL'] ?? ''}',
    publishableKey: '${c['SUPABASE_PUBLISHABLE_KEY'] ?? ''}',
  );
  if (!config.isConfigured) return null;
  final u = jsonDecode(usersFile.readAsStringSync()) as Map<String, dynamic>;
  final users = <String, ({String email, String password})>{};
  for (final key in ['userA', 'userB', 'deleteMe']) {
    final entry = u[key];
    if (entry is Map &&
        entry['email'] is String &&
        entry['password'] is String) {
      users[key] = (
        email: entry['email'] as String,
        password: entry['password'] as String,
      );
    }
  }
  if (!users.containsKey('userA') || !users.containsKey('userB')) return null;
  return _Live(config, users);
}

final String runId = Uuid.v4().substring(0, 8);
String sid(String name) => 'live-$runId-$name';

Subscription synthetic(
  String id, {
  int price = 1000,
  String currency = 'USD',
  String name = 'Test service',
}) => Subscription(
  id: id,
  name: name,
  plan: 'Test plan',
  priceMinor: price,
  currencyCode: currency,
  billingCycle: BillingCycle.monthly,
  category: SubscriptionCategory.productivity,
  startedOn: DateTime(2026, 1, 1),
  billingAnchor: DateTime(2026, 12, 1),
  createdAt: DateTime(2026, 1, 1, 10),
  notes: 'Synthetic test record',
);

/// Wraps the real remote to simulate connectivity problems.
class FlakyRemote implements SyncRemote {
  FlakyRemote(this.inner);
  final SyncRemote inner;
  int failNext = 0;
  int loseNextAcks = 0;

  void _maybeFail() {
    if (failNext > 0) {
      failNext--;
      throw const SyncRemoteException(
        SyncFailureKind.network,
        'simulated offline',
      );
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
    _maybeFail();
    final result = await inner.push(
      opId: opId,
      subscriptionId: subscriptionId,
      kind: kind,
      baseVersion: baseVersion,
      payload: payload,
    );
    if (loseNextAcks > 0) {
      loseNextAcks--;
      throw const SyncRemoteException(
        SyncFailureKind.network,
        'simulated lost ack',
      );
    }
    return result;
  }

  @override
  Future<PullPage> pull({required String? cursor, required int limit}) {
    _maybeFail();
    return inner.pull(cursor: cursor, limit: limit);
  }

  @override
  Future<RemoteProfile?> fetchProfile() => inner.fetchProfile();

  @override
  Future<RemoteProfile> saveProfile({required String displayCurrency}) =>
      inner.saveProfile(displayCurrency: displayCurrency);
}

/// One device: its own client session, local store and engine.
class Device {
  Device(this.client, this.store, this.remote, this.engine);
  final SupabaseClient client;
  final LocalStore store;
  final FlakyRemote remote;
  final SyncEngine engine;

  Subscription? find(String id) => store.subscriptions.find(id);
  Future<void> save(Subscription s) => store.subscriptions.save(s);
}

void main() {
  final live = _load();
  if (live == null) {
    test(
      'live Supabase validation',
      () {},
      skip: 'Missing config/supabase.json or config/supabase.test.local.json',
    );
    return;
  }

  SupabaseClient newClient() => SupabaseClient(
    live.config.url,
    live.config.publishableKey,
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );

  Future<SupabaseClient> signedIn(String who) async {
    final user = live.users[who]!;
    final client = newClient();
    await client.auth.signInWithPassword(
      email: user.email,
      password: user.password,
    );
    return client;
  }

  Future<Device> device(String who, {int pageSize = 200}) async {
    final client = await signedIn(who);
    final opener = SembastLocalStoreOpener(newDatabaseFactoryMemory(), '/live');
    final store = await opener.open(
      LocalIdentity.account(client.auth.currentUser!.id),
    );
    final remote = FlakyRemote(SupabaseSyncRemote(client));
    final engine = SyncEngine(
      store: store.sync!,
      repository: store.subscriptions,
      remote: remote,
      pageSize: pageSize,
    );
    return Device(client, store, remote, engine);
  }

  Matcher postgrestCode(String code) =>
      isA<PostgrestException>().having((e) => e.code, 'code', code);

  group('authentication', () {
    test('password test users can sign in; wrong passwords cannot', () async {
      final a = await signedIn('userA');
      expect(a.auth.currentSession, isNotNull);
      expect(a.auth.currentUser!.id, isNotEmpty);
      await expectLater(
        newClient().auth.signInWithPassword(
          email: live.users['userA']!.email,
          password: 'definitely-wrong-${Random().nextInt(1 << 30)}',
        ),
        throwsA(isA<AuthException>()),
      );
    });
  });

  group('database security (real RLS and privileges)', () {
    test('anonymous clients cannot read or call anything private', () async {
      final anon = newClient();
      await expectLater(
        anon.from('subscriptions').select(),
        throwsA(postgrestCode('42501')),
      );
      await expectLater(
        anon.from('profiles').select(),
        throwsA(postgrestCode('42501')),
      );
      await expectLater(
        anon.from('subscription_revisions').select(),
        throwsA(postgrestCode('42501')),
      );
      await expectLater(
        anon.rpc<dynamic>(
          'sync_pull',
          params: {'p_after_xid': null, 'p_after_seq': 0},
        ),
        throwsA(isA<PostgrestException>()),
      );
      await expectLater(
        anon.rpc<dynamic>(
          'sync_push',
          params: {
            'p_op_id': Uuid.v4(),
            'p_subscription_id': sid('anon'),
            'p_kind': 'upsert',
            'p_base_version': null,
            'p_payload': SubscriptionCodec.toMap(synthetic(sid('anon'))),
          },
        ),
        throwsA(isA<PostgrestException>()),
      );
    });

    test(
      'another account cannot read, write or reference my records',
      () async {
        final a = await device('userA');
        final b = await signedIn('userB');
        final id = sid('isolation');
        await a.save(synthetic(id));
        expect((await a.engine.sync()).succeeded, isTrue);

        // A can read its own row through RLS.
        final own = await a.client
            .from('subscriptions')
            .select('id')
            .eq('id', id);
        expect(own, hasLength(1));

        // B sees nothing of A's.
        expect(
          await b.from('subscriptions').select('id').eq('id', id),
          isEmpty,
        );
        expect(
          await b
              .from('subscription_revisions')
              .select()
              .eq('subscription_id', id),
          isEmpty,
        );
        final bPull = await SupabaseSyncRemote(b)
            .pull(cursor: null, limit: 500);
        expect(bPull.records.where((r) => r.id == id), isEmpty);

        final aUser = a.client.auth.currentUser!.id;
        // Direct writes are refused for everyone (sync_push is the only path).
        await expectLater(
          b.from('subscriptions').insert({
            'user_id': aUser,
            'id': sid('forged'),
            'name': 'Forged',
            'category': 'productivity',
            'price_minor': 1,
            'currency_code': 'USD',
            'billing_unit': 'month',
            'billing_count': 1,
            'started_on': '2026-01-01',
            'status': 'active',
            'reminder': 'none',
          }),
          throwsA(postgrestCode('42501')),
        );
        await expectLater(
          b.from('subscriptions').update({'name': 'Hacked'}).eq('id', id),
          throwsA(postgrestCode('42501')),
        );
        await expectLater(
          b.from('subscriptions').delete().eq('id', id),
          throwsA(postgrestCode('42501')),
        );
        await expectLater(
          a.client
              .from('subscriptions')
              .update({'deleted_at': null, 'version': 999})
              .eq('id', id),
          throwsA(postgrestCode('42501')),
        );
        // A payment record cannot reference another user's subscription.
        await expectLater(
          b.from('payment_records').insert({
            'user_id': b.auth.currentUser!.id,
            'subscription_id': id,
            'subscription_name': 'Test',
            'amount_minor': 1,
            'currency_code': 'USD',
            'paid_on': '2026-11-01',
            'status': 'confirmed',
            'source': 'manual',
          }),
          throwsA(postgrestCode('23503')),
        );
        // B cannot create rows under A's identity in its own tables either.
        await expectLater(
          b.from('profiles').insert({
            'user_id': aUser,
            'display_currency': 'USD',
          }),
          throwsA(postgrestCode('42501')),
        );
        // A's id is a separate record for B (ids are per user).
        final bDevice = await device('userB');
        await bDevice.save(synthetic(id, name: 'B own'));
        expect((await bDevice.engine.sync()).succeeded, isTrue);
        await a.engine.sync();
        expect(a.find(id)!.name, 'Test service');
      },
    );
  });

  group('synchronization', () {
    test('two devices: create, pull, history and mixed currencies', () async {
      final d1 = await device('userA');
      final d2 = await device('userA', pageSize: 2);
      final base = synthetic(sid('history'), price: 19900, currency: 'NOK');
      final withHistory = base
          .copyWith(priceMinor: 22900)
          .revisedFrom(base, DateTime(2026, 11, 24))
          .pause(DateTime(2026, 6, 1))
          .resume(DateTime(2026, 7, 1));
      await d1.save(withHistory);
      await d1.save(synthetic(sid('eur'), price: 1500, currency: 'EUR'));
      await d1.save(synthetic(sid('archived')).end(DateTime(2026, 10, 1)));
      expect((await d1.engine.sync()).succeeded, isTrue);
      expect(await d1.store.sync!.pending(), isEmpty);

      final report = await d2.engine.sync();
      expect(report.succeeded, isTrue);
      for (final id in [sid('history'), sid('eur'), sid('archived')]) {
        expect(
          SubscriptionCodec.toMap(d2.find(id)!),
          SubscriptionCodec.toMap(d1.find(id)!),
          reason: id,
        );
      }
      expect(d2.find(sid('history'))!.priceHistory.single.priceMinor, 19900);
      expect(
        d2.store.subscriptions.fetchEnded().map((s) => s.id),
        contains(sid('archived')),
      );
    });

    test('offline changes survive and duplicates are applied once', () async {
      final d1 = await device('userA');
      final id = sid('offline');
      d1.remote.failNext = 1;
      await d1.save(synthetic(id));
      expect((await d1.engine.sync()).failure, SyncFailureKind.network);
      expect(await d1.store.sync!.pending(), hasLength(1));

      d1.remote.loseNextAcks = 1; // server applies, response lost
      expect(
        (await d1.engine.sync(manual: true)).failure,
        SyncFailureKind.network,
      );
      expect((await d1.engine.sync(manual: true)).succeeded, isTrue);
      expect(await d1.store.sync!.pending(), isEmpty);

      final row = await d1.client
          .from('subscriptions')
          .select('version')
          .eq('id', id)
          .single();
      expect(row['version'], 1, reason: 'retried operation applied once');
    });

    test('conflicts are detected and resolved explicitly', () async {
      final d1 = await device('userA');
      final d2 = await device('userA');
      final id = sid('conflict');
      await d1.save(synthetic(id, price: 1000));
      await d1.engine.sync();
      await d2.engine.sync();

      await d1.save(d1.find(id)!.copyWith(priceMinor: 1500));
      await d1.engine.sync();
      await d2.save(d2.find(id)!.copyWith(priceMinor: 900));
      expect((await d2.engine.sync()).conflicts, 1);
      expect(
        d2.find(id)!.priceMinor,
        900,
        reason: 'local edit kept until decided',
      );

      await d2.engine.resolveConflict(id, ConflictChoice.useCloud);
      expect(d2.find(id)!.priceMinor, 1500);

      await d2.save(d2.find(id)!.copyWith(priceMinor: 1700));
      await d2.engine.sync();
      await d1.save(d1.find(id)!.copyWith(priceMinor: 1100));
      expect((await d1.engine.sync()).conflicts, 1);
      await d1.engine.resolveConflict(id, ConflictChoice.keepThisDevice);
      expect((await d1.engine.sync()).succeeded, isTrue);
      await d2.engine.sync();
      expect(d2.find(id)!.priceMinor, 1100);
    });

    test('tombstones stop outdated devices from restoring deletions', () async {
      final d1 = await device('userA');
      final d2 = await device('userA');
      final id = sid('tombstone');
      await d1.save(synthetic(id));
      await d1.engine.sync();
      await d2.engine.sync();

      await d1.store.subscriptions.delete(id);
      await d1.engine.sync();
      await d2.save(d2.find(id)!.copyWith(priceMinor: 4242));
      expect((await d2.engine.sync()).conflicts, 1);

      final row = await d1.client
          .from('subscriptions')
          .select('deleted_at, price_minor')
          .eq('id', id)
          .single();
      expect(row['deleted_at'], isNotNull, reason: 'still deleted');
      expect(row['price_minor'], 1000, reason: 'outdated edit not applied');

      await d2.engine.resolveConflict(id, ConflictChoice.useCloud);
      expect(d2.find(id), isNull);
    });

    test('guest data migrates with consent, history intact', () async {
      final account = await device('userA');
      final guest = await SembastLocalStoreOpener(
        newDatabaseFactoryMemory(),
        '/live-guest',
      ).open(LocalIdentity.guest);
      final records = [
        synthetic(sid('guest-1'), name: 'Same name'),
        synthetic(sid('guest-2'), name: 'Same name'),
        synthetic(sid('guest-old')).end(DateTime(2026, 9, 1)),
      ];
      for (final r in records) {
        await guest.subscriptions.save(r);
      }
      const service = GuestMigrationService();
      expect(await service.merge(guest: guest, account: account.store), 3);
      expect(await service.merge(guest: guest, account: account.store), 0);
      expect((await account.engine.sync()).succeeded, isTrue);

      final other = await device('userA');
      await other.engine.sync();
      for (final r in records) {
        expect(
          SubscriptionCodec.toMap(other.find(r.id)!),
          SubscriptionCodec.toMap(r),
        );
      }
      expect(guest.subscriptions.fetchEverything(), hasLength(3));
    });

    test('display currency round-trips between devices', () async {
      final a1 = SupabaseSyncRemote(await signedIn('userA'));
      final a2 = SupabaseSyncRemote(await signedIn('userA'));
      final saved = await a1.saveProfile(displayCurrency: 'NOK');
      expect(saved.displayCurrency, 'NOK');
      final seen = await a2.fetchProfile();
      expect(seen!.displayCurrency, 'NOK');
      final changed = await a2.saveProfile(displayCurrency: 'EUR');
      expect(changed.updatedAt, isNot(saved.updatedAt));
      expect((await a1.fetchProfile())!.displayCurrency, 'EUR');
    });
  });

  group('account deletion', () {
    test('requires an authenticated owner and confirmation', () async {
      final anon = newClient();
      await expectLater(
        anon.functions.invoke(
          'delete-account',
          body: {'confirm': 'DELETE MY ACCOUNT'},
        ),
        throwsA(
          isA<FunctionException>().having((e) => e.status, 'status', 401),
        ),
      );
      if (!live.users.containsKey('deleteMe')) {
        markTestSkipped('No deleteMe user configured');
        return;
      }
      final victim = await device('deleteMe');
      await victim.save(synthetic(sid('delete-me')));
      expect((await victim.engine.sync()).succeeded, isTrue);

      await expectLater(
        victim.client.functions.invoke(
          'delete-account',
          body: {'confirm': 'nope'},
        ),
        throwsA(
          isA<FunctionException>().having((e) => e.status, 'status', 400),
        ),
      );
      final response = await victim.client.functions.invoke(
        'delete-account',
        body: {'confirm': 'DELETE MY ACCOUNT'},
      );
      expect(response.status, 200);

      // The account no longer exists…
      await expectLater(signedIn('deleteMe'), throwsA(isA<AuthException>()));
      // …and its still-valid token cannot recreate records.
      await victim.save(synthetic(sid('after-delete')));
      final report = await victim.engine.sync();
      expect(report.succeeded, isFalse);
      expect(await victim.store.sync!.pending(), isNotEmpty);
    });
  });
}
