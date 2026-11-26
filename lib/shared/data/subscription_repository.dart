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

/// Records local changes for cloud synchronization, inside the same
/// sembast transaction as the change itself (so a crash can never leave a
/// saved change without its pending sync operation, or the reverse).
abstract interface class SubscriptionChangeRecorder {
  Future<void> recordUpsert(DatabaseClient txn, Subscription subscription);
  Future<void> recordDelete(DatabaseClient txn, String id);
}

/// Device-local repository backed by a sembast database: one record per
/// subscription in the `subscriptions` store, keyed by id.
///
/// Each identity (guest, or each signed-in account) has its own database
/// file, so data never leaks between accounts. Account databases pass a
/// [SubscriptionChangeRecorder] so every local change also enqueues a
/// pending sync operation atomically.
class SembastSubscriptionRepository implements SubscriptionRepository {
  SembastSubscriptionRepository._(this._database, this._cache, this._recorder);

  static final StoreRef<String, Map<String, Object?>> store =
      stringMapStoreFactory.store('subscriptions');

  final Database _database;
  final Map<String, Subscription> _cache;
  final SubscriptionChangeRecorder? _recorder;

  /// The database this repository reads and writes.
  Database get database => _database;

  /// Records that could not be decoded (kept on disk, skipped in the app).
  @visibleForTesting
  int skippedRecords = 0;

  /// Loads all records into memory.
  static Future<SembastSubscriptionRepository> open(
    Database database, {
    SubscriptionChangeRecorder? recorder,
  }) async {
    final (cache, skipped) = await _load(database);
    return SembastSubscriptionRepository._(database, cache, recorder)
      ..skippedRecords = skipped;
  }

  static Future<(Map<String, Subscription>, int)> _load(
    DatabaseClient client,
  ) async {
    final records = await store.find(client);
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
    return (cache, skipped);
  }

  @override
  List<Subscription> fetchAll() =>
      List.unmodifiable(_cache.values.where((sub) => !sub.isEnded));

  @override
  List<Subscription> fetchEnded() =>
      List.unmodifiable(_cache.values.where((sub) => sub.isEnded));

  /// Every stored subscription, current and ended.
  List<Subscription> fetchEverything() => List.unmodifiable(_cache.values);

  /// The stored subscription with [id], current or ended.
  Subscription? find(String id) => _cache[id];

  @override
  Future<void> save(Subscription subscription) async {
    await _database.transaction((txn) async {
      await store
          .record(subscription.id)
          .put(txn, SubscriptionCodec.toMap(subscription));
      await _recorder?.recordUpsert(txn, subscription);
    });
    _cache[subscription.id] = subscription;
  }

  @override
  Future<void> delete(String id) async {
    await _database.transaction((txn) async {
      await store.record(id).delete(txn);
      await _recorder?.recordDelete(txn, id);
    });
    _cache.remove(id);
  }

  /// Applies changes that came **from** the cloud: no sync operations are
  /// recorded. [extra] runs in the same transaction (e.g. to store record
  /// versions and the pull cursor), so either everything is applied or
  /// nothing is.
  Future<void> applyRemote({
    Iterable<Subscription> upserts = const [],
    Iterable<String> deletes = const [],
    Future<void> Function(Transaction txn)? extra,
  }) async {
    final upsertList = upserts.toList();
    final deleteList = deletes.toList();
    await _database.transaction((txn) async {
      for (final subscription in upsertList) {
        await store
            .record(subscription.id)
            .put(txn, SubscriptionCodec.toMap(subscription));
      }
      for (final id in deleteList) {
        await store.record(id).delete(txn);
      }
      await extra?.call(txn);
    });
    for (final subscription in upsertList) {
      _cache[subscription.id] = subscription;
    }
    deleteList.forEach(_cache.remove);
  }

  /// Saves [subscription] and runs [extra] in one transaction, recording a
  /// sync operation like [save] (used by the guest-data migration).
  Future<void> saveWith(
    Subscription subscription,
    Future<void> Function(Transaction txn) extra,
  ) async {
    await _database.transaction((txn) async {
      await store
          .record(subscription.id)
          .put(txn, SubscriptionCodec.toMap(subscription));
      await _recorder?.recordUpsert(txn, subscription);
      await extra(txn);
    });
    _cache[subscription.id] = subscription;
  }

  /// Removes every subscription (explicit local-data reset).
  Future<void> clearAll() async {
    await store.delete(_database);
    _cache.clear();
  }
}
