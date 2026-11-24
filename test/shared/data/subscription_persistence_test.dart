import 'dart:io';

import 'package:billfern/shared/data/subscription_codec.dart';
import 'package:billfern/shared/data/subscription_repository.dart';
import 'package:billfern/shared/models/billing_cycle.dart';
import 'package:billfern/shared/models/reminder_preference.dart';
import 'package:billfern/shared/models/subscription.dart';
import 'package:billfern/shared/models/subscription_category.dart';
import 'package:billfern/shared/models/subscription_glyph.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_io.dart';

Subscription _sample({String id = 'gym', String currency = 'NOK'}) =>
    Subscription(
      id: id,
      name: 'Local Gym',
      plan: 'Student',
      priceMinor: 39900,
      currencyCode: currency,
      billingCycle: const BillingCycle.custom(4, BillingUnit.week),
      category: SubscriptionCategory.health,
      startedOn: DateTime(2026, 6, 1),
      billingAnchor: DateTime(2026, 12, 2),
      websiteDomain: 'gym.no',
      customColor: const Color(0xFF00897B),
      customGlyph: SubscriptionGlyph.dumbbell,
      status: SubscriptionStatus.paused,
      pausedOn: DateTime(2026, 11, 10),
      pauseHistory: [
        PausePeriod(from: DateTime(2026, 8, 1), until: DateTime(2026, 9, 1)),
      ],
      reminder: ReminderPreference.oneWeekBefore,
      notes: 'Cancel in summer',
      createdAt: DateTime(2026, 6, 1, 18, 30),
    );

void _expectSame(Subscription a, Subscription b) {
  expect(SubscriptionCodec.toMap(a), SubscriptionCodec.toMap(b));
}

void main() {
  group('SubscriptionCodec', () {
    test('round-trips every field, keeping integer minor units', () {
      final original = _sample();
      final map = SubscriptionCodec.toMap(original);
      expect(map['priceMinor'], 39900);
      expect(map['currencyCode'], 'NOK');
      expect(map['schema'], SubscriptionCodec.schemaVersion);
      final decoded = SubscriptionCodec.fromMap(map);
      _expectSame(decoded, original);
      expect(decoded.pauseHistory, original.pauseHistory);
      expect(decoded.billingCycle, original.billingCycle);
    });

    test('rejects unusable records', () {
      expect(
        () => SubscriptionCodec.fromMap({'id': 'x', 'name': 'X'}),
        throwsFormatException,
      );
      expect(
        () => SubscriptionCodec.fromMap({
          ...SubscriptionCodec.toMap(_sample()),
          'priceMinor': 12.5,
        }),
        throwsFormatException,
      );
    });
  });

  group('SembastSubscriptionRepository', () {
    late Directory dir;
    late String path;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('billfern_db_test');
      path = '${dir.path}/billfern.db';
    });
    tearDown(() => dir.deleteSync(recursive: true));

    Future<SembastSubscriptionRepository> open() async =>
        SembastSubscriptionRepository.open(
          await databaseFactoryIo.openDatabase(path),
        );

    test('subscriptions survive an app restart', () async {
      final db = await databaseFactoryIo.openDatabase(path);
      final first = await SembastSubscriptionRepository.open(db);
      expect(first.fetchAll(), isEmpty);

      await first.save(_sample());
      await first.save(_sample(id: 'gym-2', currency: 'EUR'));
      await db.close();

      final second = await open();
      expect(second.fetchAll().map((s) => s.id), ['gym', 'gym-2']);
      _expectSame(second.fetchAll().first, _sample());
      expect(second.fetchAll().last.currencyCode, 'EUR');
    });

    test('updates and deletes persist', () async {
      final db = await databaseFactoryIo.openDatabase(path);
      final repo = await SembastSubscriptionRepository.open(db);
      await repo.save(_sample());
      await repo.save(_sample().copyWith(priceMinor: 44900));
      await repo.save(_sample(id: 'other'));
      await repo.delete('other');
      await db.close();

      final reopened = await open();
      expect(reopened.fetchAll(), hasLength(1));
      expect(reopened.fetchAll().single.priceMinor, 44900);
    });

    test('skips corrupt records without losing the rest', () async {
      final db = await databaseFactoryIo.openDatabase(path);
      await SembastSubscriptionRepository.store.record('broken').put(db, {
        'id': 'broken',
      });
      await SembastSubscriptionRepository.store
          .record('gym')
          .put(db, SubscriptionCodec.toMap(_sample()));
      final repo = await SembastSubscriptionRepository.open(db);
      expect(repo.fetchAll().map((s) => s.id), ['gym']);
      expect(repo.skippedRecords, 1);
      await db.close();
    });
  });

  test('demo repository never shares state with personal data', () async {
    final demo = DemoSubscriptionRepository(today: DateTime(2026, 11, 24));
    final personal = InMemorySubscriptionRepository();
    await demo.delete('netflix');
    expect(personal.fetchAll(), isEmpty);
    expect(
      DemoSubscriptionRepository(today: DateTime(2026, 11, 24))
          .fetchAll()
          .any((s) => s.id == 'netflix'),
      isTrue,
      reason: 'a fresh demo session starts from the original sample data',
    );
  });
}
