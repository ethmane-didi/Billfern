import 'package:flutter/foundation.dart';
import 'package:sembast/sembast.dart';

import '../models/subscription.dart';
import 'mock_subscriptions.dart';
import 'subscription_codec.dart';

/// Source of the user's subscriptions.
///
/// Reads are a synchronous in-memory snapshot so the dashboard's derived
/// calculations stay synchronous; writes are asynchronous and persist
/// through to the backing store. A future Supabase implementation can keep
/// this shape (load once, then cache) or `subscriptionsProvider` can move to
/// an `AsyncNotifier`.
///
/// Removed subscriptions that already contributed to past months are kept
/// as **ended** records ([Subscription.endedOn]) so history never changes
/// after a deletion; [fetchAll] never returns them.
abstract interface class SubscriptionRepository {
  /// Current (not ended) subscriptions, in insertion order.
  List<Subscription> fetchAll();

  /// Removed subscriptions kept only for spending history.
  List<Subscription> fetchEnded();

  /// Inserts or replaces the subscription with the same id.
  Future<void> save(Subscription subscription);

  /// Permanently removes the record, history included.
  Future<void> delete(String id);
}

/// Non-persistent repository. Used for sample data and in tests.
class InMemorySubscriptionRepository implements SubscriptionRepository {
  InMemorySubscriptionRepository([Iterable<Subscription> seed = const []]) {
    for (final subscription in seed) {
      _items.putIfAbsent(subscription.id, () => subscription);
    }
  }

  final Map<String, Subscription> _items = {};

  @override
  List<Subscription> fetchAll() =>
      List.unmodifiable(_items.values.where((sub) => !sub.isEnded));

  @override
  List<Subscription> fetchEnded() =>
      List.unmodifiable(_items.values.where((sub) => sub.isEnded));

  @override
  Future<void> save(Subscription subscription) async {
    _items[subscription.id] = subscription;
  }

  @override
  Future<void> delete(String id) async {
    _items.remove(id);
  }
}

/// **Sample data only.** Serves [buildMockSubscriptions] relative to
/// [today]. Changes live in memory and are discarded on restart, so demo
/// data never mixes with the user's own subscriptions.
class DemoSubscriptionRepository extends InMemorySubscriptionRepository {
  DemoSubscriptionRepository({required DateTime today})
    : super(buildMockSubscriptions(today));
}

/// Device-local repository backed by a sembast database: one record per
/// subscription in the `subscriptions` store, keyed by id.
class SembastSubscriptionRepository implements SubscriptionRepository {
  SembastSubscriptionRepository._(this._database, this._cache);

  static final StoreRef<String, Map<String, Object?>> store =
      stringMapStoreFactory.store('subscriptions');

  final Database _database;
  final Map<String, Subscription> _cache;

  /// Records that could not be decoded (kept on disk, skipped in the app).
  @visibleForTesting
  int skippedRecords = 0;

  /// Loads all records into memory.
  static Future<SembastSubscriptionRepository> open(Database database) async {
    final records = await store.find(database);
    final cache = <String, Subscription>{};
    var skipped = 0;
    for (final record in records) {
      try {
        final subscription = SubscriptionCodec.fromMap(record.value);
        cache[subscription.id] = subscription;
      } on FormatException {
        skipped++;
      }
    }
    return SembastSubscriptionRepository._(database, cache)
      ..skippedRecords = skipped;
  }

  @override
  List<Subscription> fetchAll() =>
      List.unmodifiable(_cache.values.where((sub) => !sub.isEnded));

  @override
  List<Subscription> fetchEnded() =>
      List.unmodifiable(_cache.values.where((sub) => sub.isEnded));

  @override
  Future<void> save(Subscription subscription) async {
    await store
        .record(subscription.id)
        .put(_database, SubscriptionCodec.toMap(subscription));
    _cache[subscription.id] = subscription;
  }

  @override
  Future<void> delete(String id) async {
    await store.record(id).delete(_database);
    _cache.remove(id);
  }
}
