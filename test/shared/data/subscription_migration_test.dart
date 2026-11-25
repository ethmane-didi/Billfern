import 'dart:io';

import 'package:billfern/shared/data/subscription_codec.dart';
import 'package:billfern/shared/data/subscription_database.dart';
import 'package:billfern/shared/data/subscription_repository.dart';
import 'package:billfern/shared/models/billing_cycle.dart';
import 'package:billfern/shared/models/subscription.dart';
import 'package:billfern/shared/models/subscription_category.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_io.dart';

/// A record exactly as Phase 3 (schema 1) wrote it.
Map<String, Object?> _v1Record(String id) => {
  'schema': 1,
  'id': id,
  'name': 'Netflix',
  'plan': 'Standard',
  'priceMinor': 1549,
  'currencyCode': 'USD',
  'billingCycle': {'count': 1, 'unit': 'month'},
  'category': 'entertainment',
  'startedOn': '2025-09-01',
  'billingAnchor': '2026-12-01',
  'catalogId': 'netflix',
  'websiteDomain': null,
  'customColor': null,
  'customGlyph': null,
  'status': 'active',
  'pausedOn': null,
  'pauseHistory': [
    {'from': '2026-03-01', 'until': '2026-04-01'},
  ],
  'reminder': 'oneDayBefore',
  'notes': 'Family plan',
  'createdAt': '2025-09-01T10:00:00.000',
};

void main() {
  late Directory dir;
  late String path;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('billfern_migration');
    path = '${dir.path}/billfern.db';
  });

  tearDown(() => dir.delete(recursive: true));

  test('migrates schema 1 records without losing data', () async {
    final store = SembastSubscriptionRepository.store;
    final v1 = await databaseFactoryIo.openDatabase(path); // version 1
    await store.record('netflix').put(v1, _v1Record('netflix'));
    await store.record('broken').put(v1, {'id': 'broken', 'schema': 1});
    await v1.close();

    final db = await SubscriptionDatabase.open(databaseFactoryIo, path);
    expect(db.version, SubscriptionCodec.schemaVersion);

    final migrated = await store.record('netflix').get(db);
    expect(migrated!['schema'], 2);
    expect(migrated['priceHistory'], isEmpty);
    expect(migrated['endedOn'], isNull);
    for (final key in _v1Record('netflix').keys.where((k) => k != 'schema')) {
      expect(migrated[key], _v1Record('netflix')[key], reason: key);
    }
    // Unreadable records are kept exactly as they were.
    expect(await store.record('broken').get(db), {'id': 'broken', 'schema': 1});

    final repository = await SembastSubscriptionRepository.open(db);
    final sub = repository.fetchAll().single;
    expect(sub.priceMinor, 1549);
    expect(sub.pauseHistory, hasLength(1));
    expect(sub.notes, 'Family plan');
    expect(repository.skippedRecords, 1);
    await db.close();
  });

  test('a fresh database opens at the current version', () async {
    final db = await SubscriptionDatabase.open(databaseFactoryIo, path);
    expect(db.version, SubscriptionCodec.schemaVersion);
    expect(await SembastSubscriptionRepository.store.count(db), 0);
    await db.close();
  });

  test('revisions and removed subscriptions survive a restart', () async {
    final sub = Subscription(
      id: 'gym',
      name: 'Gym',
      plan: '',
      priceMinor: 39900,
      currencyCode: 'NOK',
      billingCycle: BillingCycle.monthly,
      category: SubscriptionCategory.health,
      startedOn: DateTime(2026, 1, 1),
      priceHistory: [
        PriceRevision(
          until: DateTime(2026, 6, 1),
          priceMinor: 12000,
          currencyCode: 'USD',
          billingCycle: BillingCycle.yearly,
        ),
      ],
    ).end(DateTime(2026, 11, 20));

    var db = await SubscriptionDatabase.open(databaseFactoryIo, path);
    var repository = await SembastSubscriptionRepository.open(db);
    await repository.save(sub);
    await db.close();

    db = await SubscriptionDatabase.open(databaseFactoryIo, path);
    repository = await SembastSubscriptionRepository.open(db);
    expect(repository.fetchAll(), isEmpty);
    expect(repository.fetchEnded().single, sub);
    await db.close();
  });

  test('malformed revisions are dropped, not the whole record', () {
    final map = SubscriptionCodec.toMap(
      SubscriptionCodec.fromMap(_v1Record('netflix')),
    );
    map['priceHistory'] = [
      {'until': 'nope', 'priceMinor': 100, 'currencyCode': 'USD'},
      {
        'until': '2026-02-01',
        'priceMinor': 1299,
        'currencyCode': 'USD',
        'billingCycle': {'count': 1, 'unit': 'month'},
      },
    ];
    final sub = SubscriptionCodec.fromMap(map);
    expect(sub.priceHistory.single.priceMinor, 1299);
  });
}
