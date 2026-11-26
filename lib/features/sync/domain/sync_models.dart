import 'package:flutter/foundation.dart';

import '../../../shared/data/subscription_codec.dart';
import '../../../shared/models/subscription.dart';

/// What a pending operation does to a subscription in the cloud.
enum OutboxKind { upsert, delete }

/// A local change waiting to be acknowledged by the server.
///
/// Stored in the account database's `sync_outbox` store in the same
/// transaction as the change itself. [opId] is a UUID sent with every
/// attempt, so the server applies a retried operation only once.
@immutable
class OutboxOperation {
  const OutboxOperation({
    required this.opId,
    required this.sequence,
    required this.subscriptionId,
    required this.kind,
    required this.createdAt,
    this.payload,
    this.attempts = 0,
    this.nextAttemptAt,
    this.lastError,
    this.parked = false,
  });

  final String opId;

  /// Local order: operations are sent oldest first.
  final int sequence;
  final String subscriptionId;
  final OutboxKind kind;

  /// [SubscriptionCodec] map of the subscription for [OutboxKind.upsert].
  final Map<String, Object?>? payload;
  final DateTime createdAt;

  /// Delivery attempts so far. An operation that has been attempted may
  /// have reached the server, so it is never merged with newer changes.
  final int attempts;

  /// Earliest time of the next automatic attempt (backoff).
  final DateTime? nextAttemptAt;

  /// Last failure, for the Settings screen. Never contains user data.
  final String? lastError;

  /// The server rejected it permanently; kept (never discarded) until the
  /// user retries.
  final bool parked;

  Subscription? get subscription =>
      payload == null ? null : SubscriptionCodec.fromMap(payload!);

  OutboxOperation copyWith({
    String? opId,
    OutboxKind? kind,
    Map<String, Object?>? payload,
    bool clearPayload = false,
    int? attempts,
    DateTime? nextAttemptAt,
    bool clearNextAttempt = false,
    String? lastError,
    bool clearError = false,
    bool? parked,
  }) => OutboxOperation(
    opId: opId ?? this.opId,
    sequence: sequence,
    subscriptionId: subscriptionId,
    kind: kind ?? this.kind,
    payload: clearPayload ? null : (payload ?? this.payload),
    createdAt: createdAt,
    attempts: attempts ?? this.attempts,
    nextAttemptAt: clearNextAttempt
        ? null
        : (nextAttemptAt ?? this.nextAttemptAt),
    lastError: clearError ? null : (lastError ?? this.lastError),
    parked: parked ?? this.parked,
  );

  Map<String, Object?> toMap() => {
    'opId': opId,
    'sequence': sequence,
    'subscriptionId': subscriptionId,
    'kind': kind.name,
    'payload': payload,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'attempts': attempts,
    'nextAttemptAt': nextAttemptAt?.toUtc().toIso8601String(),
    'lastError': lastError,
    'parked': parked,
  };

  static OutboxOperation fromMap(Map<String, Object?> map) => OutboxOperation(
    opId: map['opId']! as String,
    sequence: map['sequence']! as int,
    subscriptionId: map['subscriptionId']! as String,
    kind: OutboxKind.values.byName(map['kind']! as String),
    payload: (map['payload'] as Map?)?.cast<String, Object?>(),
    createdAt: DateTime.parse(map['createdAt']! as String),
    attempts: map['attempts'] as int? ?? 0,
    nextAttemptAt: map['nextAttemptAt'] == null
        ? null
        : DateTime.parse(map['nextAttemptAt']! as String),
    lastError: map['lastError'] as String?,
    parked: map['parked'] as bool? ?? false,
  );
}

/// A subscription as stored in the cloud.
@immutable
class RemoteSubscription {
  const RemoteSubscription({
    required this.id,
    required this.version,
    required this.serverSequence,
    this.payload,
    this.deletedAt,
  });

  final String id;

  /// Optimistic-concurrency version; increases with every server change.
  final int version;

  /// Server-assigned change sequence used as the pull cursor.
  final int serverSequence;

  /// [SubscriptionCodec] map; `null` only for tombstones without data.
  final Map<String, Object?>? payload;

  /// Set when the subscription was deleted (tombstone).
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  Subscription? get subscription =>
      payload == null || isDeleted ? null : SubscriptionCodec.fromMap(payload!);

  Map<String, Object?> toMap() => {
    'id': id,
    'version': version,
    'serverSequence': serverSequence,
    'payload': payload,
    'deletedAt': deletedAt?.toUtc().toIso8601String(),
  };

  static RemoteSubscription fromMap(Map<String, Object?> map) =>
      RemoteSubscription(
        id: map['id']! as String,
        version: (map['version']! as num).toInt(),
        serverSequence: (map['serverSequence'] as num?)?.toInt() ?? 0,
        payload: (map['payload'] as Map?)?.cast<String, Object?>(),
        deletedAt: map['deletedAt'] == null
            ? null
            : DateTime.parse(map['deletedAt']! as String),
      );
}

/// Outcome of pushing one operation.
sealed class PushResult {
  const PushResult();
}

/// Applied (or already applied earlier: duplicate delivery).
final class PushApplied extends PushResult {
  const PushApplied({required this.version, this.deleted = false});

  final int version;
  final bool deleted;
}

/// The server holds a different version: someone else changed it.
/// [remote] is `null` when the record no longer exists in the cloud.
final class PushConflict extends PushResult {
  const PushConflict(this.remote);

  final RemoteSubscription? remote;
}

/// One page of remote changes after a cursor.
@immutable
class PullPage {
  const PullPage({
    required this.records,
    required this.hasMore,
    required this.cursor,
  });

  /// In server change order.
  final List<RemoteSubscription> records;
  final bool hasMore;

  /// Opaque position after the last record (`null` when [records] is
  /// empty). Store it and pass it to the next pull.
  final String? cursor;
}

/// The user's cloud profile (non-financial preferences).
@immutable
class RemoteProfile {
  const RemoteProfile({required this.displayCurrency, required this.updatedAt});

  final String? displayCurrency;

  /// Server timestamp of the last change, compared only for equality (never
  /// against device clocks).
  final String updatedAt;
}

/// Why a remote call failed.
enum SyncFailureKind {
  /// No connection, timeout or server unavailable: retry later.
  network,

  /// The session is missing or expired: sign in again.
  unauthorized,

  /// The server rejected the data (validation): retrying will not help.
  rejected,
}

class SyncRemoteException implements Exception {
  const SyncRemoteException(this.kind, this.message);

  final SyncFailureKind kind;

  /// Diagnostic text. Never includes user data or tokens.
  final String message;

  @override
  String toString() => 'SyncRemoteException(${kind.name}): $message';
}

/// A change made on this device that conflicts with the cloud.
@immutable
class SyncConflict {
  const SyncConflict({
    required this.subscriptionId,
    required this.detectedAt,
    this.remote,
  });

  final String subscriptionId;

  /// The cloud version; `null` when it was permanently removed there.
  final RemoteSubscription? remote;
  final DateTime detectedAt;

  Map<String, Object?> toMap() => {
    'subscriptionId': subscriptionId,
    'remote': remote?.toMap(),
    'detectedAt': detectedAt.toUtc().toIso8601String(),
  };

  static SyncConflict fromMap(Map<String, Object?> map) => SyncConflict(
    subscriptionId: map['subscriptionId']! as String,
    remote: map['remote'] == null
        ? null
        : RemoteSubscription.fromMap(
            (map['remote']! as Map).cast<String, Object?>(),
          ),
    detectedAt: DateTime.parse(map['detectedAt']! as String),
  );
}

/// How the user resolves a [SyncConflict].
enum ConflictChoice {
  /// Keep this device's version and send it to the cloud.
  keepThisDevice,

  /// Replace this device's version with the cloud version.
  useCloud,
}

/// Overall synchronization state shown to the user.
enum SyncPhase {
  /// Cloud sync is not available (guest or no backend configured).
  localOnly,

  /// No connection; changes are kept and sent later.
  offline,
  syncing,

  /// Everything acknowledged by the server.
  synced,

  /// Changes waiting to be sent.
  pending,

  /// A change conflicts with the cloud and needs a decision.
  conflict,

  /// The last attempt failed (see the error).
  failed,
}

/// Snapshot of synchronization state for the UI.
@immutable
class SyncStatus {
  const SyncStatus({
    required this.phase,
    this.pendingCount = 0,
    this.conflictCount = 0,
    this.parkedCount = 0,
    this.lastSyncedAt,
    this.error,
  });

  static const SyncStatus localOnly = SyncStatus(phase: SyncPhase.localOnly);

  final SyncPhase phase;
  final int pendingCount;
  final int conflictCount;

  /// Operations the server rejected; never discarded.
  final int parkedCount;
  final DateTime? lastSyncedAt;
  final SyncFailureKind? error;

  /// Never reports success while operations are unacknowledged.
  bool get isFullySynced =>
      phase == SyncPhase.synced && pendingCount == 0 && conflictCount == 0;

  SyncStatus copyWith({
    SyncPhase? phase,
    int? pendingCount,
    int? conflictCount,
    int? parkedCount,
    DateTime? lastSyncedAt,
    SyncFailureKind? error,
    bool clearError = false,
  }) => SyncStatus(
    phase: phase ?? this.phase,
    pendingCount: pendingCount ?? this.pendingCount,
    conflictCount: conflictCount ?? this.conflictCount,
    parkedCount: parkedCount ?? this.parkedCount,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    error: clearError ? null : (error ?? this.error),
  );
}
