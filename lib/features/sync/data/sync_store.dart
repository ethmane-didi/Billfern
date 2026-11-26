import 'package:sembast/sembast.dart';

import '../../../core/utils/uuid.dart';
import '../../../shared/data/subscription_codec.dart';
import '../../../shared/data/subscription_repository.dart';
import '../../../shared/models/subscription.dart';
import '../domain/sync_models.dart';

/// Synchronization state kept in an **account** database (never in the
/// guest database, never for sample data):
///
/// - `sync_outbox`: pending operations, keyed by opId.
/// - `sync_versions`: the last server version acknowledged or pulled per
///   subscription (the base for optimistic concurrency).
/// - `sync_conflicts`: unresolved conflicts.
/// - `sync_meta`: pull cursor, last successful sync and other flags.
///
/// As a [SubscriptionChangeRecorder] it enqueues operations inside the
/// caller's transaction, so a local change and its pending operation are
/// committed together.
class SyncStore implements SubscriptionChangeRecorder {
  SyncStore(
    this._database, {
    DateTime Function()? clock,
    String Function()? newOpId,
  }) : _clock = clock ?? DateTime.now,
       _newOpId = newOpId ?? Uuid.v4;

  final Database _database;
  final DateTime Function() _clock;
  final String Function() _newOpId;

  static final StoreRef<String, Map<String, Object?>> outbox =
      stringMapStoreFactory.store('sync_outbox');
  static final StoreRef<String, Map<String, Object?>> versions =
      stringMapStoreFactory.store('sync_versions');
  static final StoreRef<String, Map<String, Object?>> conflicts =
      stringMapStoreFactory.store('sync_conflicts');
  static final StoreRef<String, Object?> meta = StoreRef<String, Object?>(
    'sync_meta',
  );

  static const String cursorKey = 'cursor';
  static const String lastSyncedKey = 'lastSyncedAt';
  static const String sequenceKey = 'outboxSequence';
  static const String profileCurrencyKey = 'syncedDisplayCurrency';
  static const String guestMigrationKey = 'guestMigration';

  Database get database => _database;

  // ---- Recording local changes -------------------------------------------

  @override
  Future<void> recordUpsert(DatabaseClient txn, Subscription subscription) =>
      _enqueue(
        txn,
        subscription.id,
        OutboxKind.upsert,
        SubscriptionCodec.toMap(subscription),
      );

  @override
  Future<void> recordDelete(DatabaseClient txn, String id) =>
      _enqueue(txn, id, OutboxKind.delete, null);

  /// Adds an operation, merging it into an existing **unsent** operation for
  /// the same subscription (attempted operations may already be on the
  /// server, so they are left alone and a new operation follows them).
  Future<void> _enqueue(
    DatabaseClient txn,
    String subscriptionId,
    OutboxKind kind,
    Map<String, Object?>? payload,
  ) async {
    final pending = await pendingFor(txn, subscriptionId);
    final unsent = pending.where((op) => op.attempts == 0 && !op.parked);
    if (unsent.isNotEmpty) {
      final op = unsent.last;
      await outbox
          .record(op.opId)
          .put(
            txn,
            op
                .copyWith(
                  kind: kind,
                  payload: payload,
                  clearPayload: payload == null,
                )
                .toMap(),
          );
      return;
    }
    final sequence =
        ((await meta.record(sequenceKey).get(txn)) as int? ?? 0) + 1;
    await meta.record(sequenceKey).put(txn, sequence);
    final op = OutboxOperation(
      opId: _newOpId(),
      sequence: sequence,
      subscriptionId: subscriptionId,
      kind: kind,
      payload: payload,
      createdAt: _clock(),
    );
    await outbox.record(op.opId).put(txn, op.toMap());
  }

  // ---- Outbox ------------------------------------------------------------

  Future<List<OutboxOperation>> pending([DatabaseClient? client]) async {
    final records = await outbox.find(
      client ?? _database,
      finder: Finder(sortOrders: [SortOrder('sequence')]),
    );
    return [for (final r in records) OutboxOperation.fromMap(r.value)];
  }

  Future<List<OutboxOperation>> pendingFor(
    DatabaseClient client,
    String subscriptionId,
  ) async {
    final records = await outbox.find(
      client,
      finder: Finder(
        filter: Filter.equals('subscriptionId', subscriptionId),
        sortOrders: [SortOrder('sequence')],
      ),
    );
    return [for (final r in records) OutboxOperation.fromMap(r.value)];
  }

  Future<void> putOperation(DatabaseClient client, OutboxOperation op) =>
      outbox.record(op.opId).put(client, op.toMap());

  Future<void> removeOperation(DatabaseClient client, String opId) =>
      outbox.record(opId).delete(client);

  Future<void> removeOperationsFor(DatabaseClient client, String id) =>
      outbox.delete(
        client,
        finder: Finder(filter: Filter.equals('subscriptionId', id)),
      );

  Future<int> pendingCount() => outbox.count(_database);

  // ---- Versions ----------------------------------------------------------

  Future<int?> versionOf(DatabaseClient client, String id) async {
    final value = await versions.record(id).get(client);
    return (value?['version'] as num?)?.toInt();
  }

  Future<void> setVersion(
    DatabaseClient client,
    String id,
    int version, {
    bool deleted = false,
  }) =>
      versions.record(id).put(client, {'version': version, 'deleted': deleted});

  Future<void> removeVersion(DatabaseClient client, String id) =>
      versions.record(id).delete(client);

  // ---- Conflicts ---------------------------------------------------------

  Future<List<SyncConflict>> conflictList([DatabaseClient? client]) async {
    final records = await conflicts.find(client ?? _database);
    return [for (final r in records) SyncConflict.fromMap(r.value)];
  }

  Future<SyncConflict?> conflictFor(DatabaseClient client, String id) async {
    final value = await conflicts.record(id).get(client);
    return value == null ? null : SyncConflict.fromMap(value);
  }

  Future<void> putConflict(DatabaseClient client, SyncConflict conflict) =>
      conflicts.record(conflict.subscriptionId).put(client, conflict.toMap());

  Future<void> removeConflict(DatabaseClient client, String id) =>
      conflicts.record(id).delete(client);

  // ---- Meta --------------------------------------------------------------

  /// Opaque pull cursor (`null` = pull everything).
  Future<String?> cursor([DatabaseClient? client]) async {
    final value = await meta.record(cursorKey).get(client ?? _database);
    return value is String ? value : null;
  }

  Future<void> setCursor(DatabaseClient client, String? value) =>
      writeMeta(client, cursorKey, value);

  Future<DateTime?> lastSyncedAt() async {
    final value = await meta.record(lastSyncedKey).get(_database);
    return value is String ? DateTime.parse(value) : null;
  }

  Future<void> setLastSyncedAt(DateTime value) => meta
      .record(lastSyncedKey)
      .put(_database, value.toUtc().toIso8601String());

  Future<Object?> readMeta(String key) => meta.record(key).get(_database);

  Future<void> writeMeta(DatabaseClient client, String key, Object? value) =>
      value == null
      ? meta.record(key).delete(client)
      : meta.record(key).put(client, value);
}
