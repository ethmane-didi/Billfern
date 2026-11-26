import 'dart:async';
import 'dart:math';

import 'package:sembast/sembast.dart' show DatabaseException;

import '../../../shared/data/subscription_repository.dart';
import '../../../shared/models/subscription.dart';
import '../data/sync_store.dart';
import 'sync_models.dart';
import 'sync_remote.dart';

/// Bounded exponential backoff for failed deliveries.
class RetryPolicy {
  const RetryPolicy({
    this.baseDelay = const Duration(seconds: 5),
    this.maxDelay = const Duration(minutes: 15),
  });

  final Duration baseDelay;
  final Duration maxDelay;

  /// Delay before attempt number `attempts + 1` (5 s, 10 s, 20 s … ≤ 15 min).
  Duration delayAfter(int attempts) {
    final exponent = min(max(attempts - 1, 0), 16);
    final millis = baseDelay.inMilliseconds * (1 << exponent);
    return Duration(milliseconds: min(millis, maxDelay.inMilliseconds));
  }
}

/// Result of one synchronization run.
class SyncReport {
  const SyncReport({
    this.pushed = 0,
    this.pulled = 0,
    this.conflicts = 0,
    this.failure,
    this.ran = true,
  });

  final int pushed;
  final int pulled;
  final int conflicts;
  final SyncFailureKind? failure;

  /// `false` when the run was skipped (e.g. nothing due during backoff).
  final bool ran;

  bool get succeeded => failure == null;
}

/// Pushes local changes and pulls remote changes for one account.
///
/// Rules:
/// - Only one run at a time: concurrent [sync] calls share the same run.
/// - Operations are sent oldest first. A transient failure stops the push
///   (later operations may depend on earlier ones) and schedules a retry
///   with bounded backoff. Nothing is ever silently discarded: rejected
///   operations are parked and shown to the user.
/// - An operation is removed only after the server acknowledges it.
/// - A version mismatch becomes a [SyncConflict] that the user resolves
///   explicitly (unless both sides are already identical). Financial data
///   is never silently overwritten.
/// - Pulled changes are applied in one transaction per page together with
///   the cursor, and never create outgoing operations. Subscriptions with
///   pending local changes or conflicts are left untouched by a pull; the
///   version check on push detects the divergence.
class SyncEngine {
  SyncEngine({
    required this.store,
    required this.repository,
    required this.remote,
    DateTime Function()? clock,
    this.retry = const RetryPolicy(),
    this.pageSize = 200,
  }) : _clock = clock ?? DateTime.now;

  final SyncStore store;
  final SembastSubscriptionRepository repository;
  final SyncRemote remote;
  final RetryPolicy retry;
  final int pageSize;
  final DateTime Function() _clock;

  Future<SyncReport>? _running;

  /// Whether a run is in progress.
  bool get isRunning => _running != null;

  /// Runs push then pull. [manual] ignores backoff timers.
  ///
  /// Concurrent automatic requests share the running sync. A manual request
  /// made while an automatic run is in progress runs again afterwards, so
  /// "Sync now" is never swallowed by a run that respected backoff.
  Future<SyncReport> sync({bool manual = false}) {
    final running = _running;
    if (running != null) {
      if (!manual || _runningManual) return running;
      return running.then((_) => sync(manual: true));
    }
    _runningManual = manual;
    final run = _run(manual: manual).whenComplete(() {
      _running = null;
      _runningManual = false;
    });
    _running = run;
    return run;
  }

  bool _runningManual = false;

  Future<SyncReport> _run({required bool manual}) async {
    var pushed = 0;
    var conflicts = 0;
    try {
      final push = await _push(manual: manual);
      pushed = push.$1;
      conflicts = push.$2;
      final pulled = await _pull();
      await store.setLastSyncedAt(_clock());
      return SyncReport(pushed: pushed, pulled: pulled, conflicts: conflicts);
    } on SyncRemoteException catch (error) {
      return SyncReport(
        pushed: pushed,
        conflicts: conflicts,
        failure: error.kind,
      );
    } on DatabaseException {
      // The local store was closed (identity switch, erase): stop quietly.
      // Every write is atomic, and an operation delivered without its
      // acknowledgement being stored is deduplicated by the server on retry.
      return SyncReport(pushed: pushed, conflicts: conflicts, ran: false);
    }
  }

  Future<(int, int)> _push({required bool manual}) async {
    var pushed = 0;
    var conflicts = 0;
    final now = _clock();
    for (final op in await store.pending()) {
      if (op.parked) continue;
      final due = op.nextAttemptAt;
      if (!manual && due != null && due.isAfter(now)) {
        // Keep order: an operation still backing off blocks later ones.
        break;
      }
      if (await store.conflictFor(store.database, op.subscriptionId) != null) {
        continue; // waits for the user's decision
      }

      // Record the attempt before sending: an attempted operation may reach
      // the server even if we crash before the response.
      final attempt = op.copyWith(attempts: op.attempts + 1);
      await store.putOperation(store.database, attempt);
      final baseVersion = await store.versionOf(
        store.database,
        op.subscriptionId,
      );

      final PushResult result;
      try {
        result = await remote.push(
          opId: op.opId,
          subscriptionId: op.subscriptionId,
          kind: op.kind,
          baseVersion: baseVersion,
          payload: op.payload,
        );
      } on SyncRemoteException catch (error) {
        if (error.kind == SyncFailureKind.rejected) {
          await store.putOperation(
            store.database,
            attempt.copyWith(parked: true, lastError: error.message),
          );
          continue;
        }
        await store.putOperation(
          store.database,
          attempt.copyWith(
            nextAttemptAt: _clock().add(retry.delayAfter(attempt.attempts)),
            lastError: error.message,
          ),
        );
        rethrow;
      }

      switch (result) {
        case PushApplied(:final version, :final deleted):
          await store.database.transaction((txn) async {
            await store.removeOperation(txn, op.opId);
            await store.setVersion(
              txn,
              op.subscriptionId,
              version,
              deleted: deleted,
            );
          });
          pushed++;
        case PushConflict(:final remote):
          if (await _resolveIfIdentical(op.subscriptionId, remote)) {
            pushed++;
            continue;
          }
          await store.database.transaction((txn) async {
            await store.removeOperationsFor(txn, op.subscriptionId);
            await store.putConflict(
              txn,
              SyncConflict(
                subscriptionId: op.subscriptionId,
                remote: remote,
                detectedAt: _clock(),
              ),
            );
          });
          conflicts++;
      }
    }
    return (pushed, conflicts);
  }

  /// A "conflict" where both sides already hold the same data (e.g. a
  /// repeated migration) is not a real conflict: adopt the server version.
  Future<bool> _resolveIfIdentical(
    String id,
    RemoteSubscription? remote,
  ) async {
    final local = repository.find(id);
    final same = remote == null
        ? local == null
        : (remote.isDeleted ? local == null : remote.subscription == local);
    if (!same) return false;
    await store.database.transaction((txn) async {
      await store.removeOperationsFor(txn, id);
      if (remote != null) {
        await store.setVersion(
          txn,
          id,
          remote.version,
          deleted: remote.isDeleted,
        );
      }
    });
    return true;
  }

  Future<int> _pull() async {
    var applied = 0;
    var cursor = await store.cursor();
    while (true) {
      final page = await remote.pull(cursor: cursor, limit: pageSize);
      if (page.records.isEmpty) break;
      final pending = {
        for (final op in await store.pending()) op.subscriptionId,
      };
      final conflicted = {
        for (final c in await store.conflictList()) c.subscriptionId,
      };
      final upserts = <String, Subscription>{};
      final deletes = <String>{};
      final pageCursor = page.cursor ?? cursor;
      for (final record in page.records) {
        if (pending.contains(record.id) || conflicted.contains(record.id)) {
          continue;
        }
        if (record.isDeleted) {
          deletes.add(record.id);
          upserts.remove(record.id);
        } else {
          final sub = record.subscription;
          if (sub == null) continue;
          upserts[record.id] = sub;
          deletes.remove(record.id);
        }
      }
      final applyRecords = [
        for (final r in page.records)
          if (!pending.contains(r.id) && !conflicted.contains(r.id)) r,
      ];
      await repository.applyRemote(
        upserts: upserts.values,
        deletes: deletes,
        extra: (txn) async {
          for (final record in applyRecords) {
            await store.setVersion(
              txn,
              record.id,
              record.version,
              deleted: record.isDeleted,
            );
          }
          await store.setCursor(txn, pageCursor);
        },
      );
      applied += applyRecords.length;
      cursor = pageCursor;
      if (!page.hasMore) break;
    }
    return applied;
  }

  /// Resolves a conflict with the user's explicit [choice].
  Future<void> resolveConflict(String id, ConflictChoice choice) async {
    final conflict = await store.conflictFor(store.database, id);
    if (conflict == null) return;
    final remoteRecord = conflict.remote;
    switch (choice) {
      case ConflictChoice.useCloud:
        final cloud = remoteRecord?.subscription;
        await repository.applyRemote(
          upserts: [?cloud],
          deletes: [if (cloud == null) id],
          extra: (txn) async {
            await store.removeConflict(txn, id);
            await store.removeOperationsFor(txn, id);
            if (remoteRecord != null) {
              await store.setVersion(
                txn,
                id,
                remoteRecord.version,
                deleted: remoteRecord.isDeleted,
              );
            }
          },
        );
      case ConflictChoice.keepThisDevice:
        final local = repository.find(id);
        await store.database.transaction((txn) async {
          await store.removeConflict(txn, id);
          // Base the new operation on the cloud version the user has seen,
          // so it intentionally replaces (or restores) that version.
          if (remoteRecord != null) {
            await store.setVersion(
              txn,
              id,
              remoteRecord.version,
              deleted: remoteRecord.isDeleted,
            );
          } else {
            await store.removeVersion(txn, id);
          }
          if (local != null) {
            await store.recordUpsert(txn, local);
          } else if (remoteRecord != null && !remoteRecord.isDeleted) {
            await store.recordDelete(txn, id);
          }
        });
    }
  }

  /// Moves parked (rejected) operations back into the queue.
  Future<void> retryParked() async {
    await store.database.transaction((txn) async {
      for (final op in await store.pending(txn)) {
        if (op.parked || op.nextAttemptAt != null) {
          await store.putOperation(
            txn,
            op.copyWith(
              parked: false,
              clearNextAttempt: true,
              clearError: true,
            ),
          );
        }
      }
    });
  }

  /// Makes operations that are waiting for their backoff delay due now
  /// (used when network connectivity returns). Attempt counts are kept, so
  /// a further failure still backs off for longer. Parked (rejected)
  /// operations are left alone: only the user's "Retry sync" re-queues them.
  Future<void> expediteRetries() async {
    await store.database.transaction((txn) async {
      for (final op in await store.pending(txn)) {
        if (!op.parked && op.nextAttemptAt != null) {
          await store.putOperation(txn, op.copyWith(clearNextAttempt: true));
        }
      }
    });
  }

  /// Current status for the UI.
  Future<SyncStatus> status({
    required SyncPhase phase,
    SyncFailureKind? error,
  }) async {
    final ops = await store.pending();
    final conflictCount = (await store.conflictList()).length;
    final parked = ops.where((op) => op.parked).length;
    final pendingCount = ops.length;
    final effective = switch (phase) {
      SyncPhase.syncing => SyncPhase.syncing,
      _ when conflictCount > 0 => SyncPhase.conflict,
      _ when parked > 0 => SyncPhase.failed,
      SyncPhase.synced when pendingCount > 0 => SyncPhase.pending,
      _ => phase,
    };
    return SyncStatus(
      phase: effective,
      pendingCount: pendingCount,
      conflictCount: conflictCount,
      parkedCount: parked,
      lastSyncedAt: await store.lastSyncedAt(),
      error: error,
    );
  }
}
