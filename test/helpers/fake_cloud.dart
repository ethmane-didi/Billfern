import 'dart:async';

import 'package:billfern/features/account/data/auth_repository.dart';
import 'package:billfern/features/account/domain/auth_models.dart';
import 'package:billfern/features/sync/domain/connectivity_signal.dart';
import 'package:billfern/features/sync/domain/sync_models.dart';
import 'package:billfern/features/sync/domain/sync_remote.dart';
import 'package:billfern/shared/data/local_store.dart';
import 'package:sembast/sembast_memory.dart';

/// In-memory server for ONE user that mirrors the semantics of the
/// `sync_push` / `sync_pull` SQL functions: idempotent operation ids,
/// version checks, tombstones, server sequence cursor and pagination.
/// Several devices (engines) can share one cloud.
class FakeCloud {
  final Map<String, _Row> _rows = {};
  final Map<String, PushResult> _operations = {};
  int _sequence = 0;
  String? profileCurrency;

  /// Every push received (including duplicates).
  int pushCalls = 0;

  /// Every pull request received.
  int pullCalls = 0;

  /// Simulates no connection.
  bool offline = false;

  /// Applies the next push but loses the response (network error after the
  /// server committed).
  int loseNextResponses = 0;

  /// Subscription ids the server rejects (validation error).
  final Set<String> rejectIds = {};

  int get rowCount => _rows.length;

  RemoteSubscription? row(String id) => _rows[id]?.record;

  int? versionOf(String id) => _rows[id]?.version;

  bool isDeleted(String id) => _rows[id]?.deletedAt != null;

  PushResult push({
    required String opId,
    required String subscriptionId,
    required OutboxKind kind,
    required int? baseVersion,
    Map<String, Object?>? payload,
  }) {
    final prior = _operations[opId];
    if (prior != null) return prior;
    final existing = _rows[subscriptionId];
    late PushResult result;
    if (kind == OutboxKind.delete) {
      if (existing == null) {
        result = const PushApplied(version: 0, deleted: true);
      } else if (existing.deletedAt != null) {
        result = PushApplied(version: existing.version, deleted: true);
      } else if (baseVersion != existing.version) {
        result = PushConflict(existing.record);
      } else {
        existing
          ..deletedAt = DateTime.utc(2026, 11, 24, 12)
          ..version += 1
          ..sequence = ++_sequence;
        result = PushApplied(version: existing.version, deleted: true);
      }
    } else {
      if (existing == null) {
        if (baseVersion != null) {
          result = const PushConflict(null);
        } else {
          _rows[subscriptionId] = _Row(
            id: subscriptionId,
            payload: Map.of(payload!),
            version: 1,
            sequence: ++_sequence,
          );
          result = const PushApplied(version: 1);
        }
      } else if (baseVersion != existing.version) {
        result = PushConflict(existing.record);
      } else {
        existing
          ..payload = Map.of(payload!)
          ..deletedAt = null
          ..version += 1
          ..sequence = ++_sequence;
        result = PushApplied(version: existing.version);
      }
    }
    _operations[opId] = result;
    return result;
  }

  /// Cursor = last sequence as text (the real server uses "xid:seq").
  PullPage pull({required String? cursor, required int limit}) {
    final after = int.tryParse(cursor ?? '') ?? 0;
    final changed = _rows.values.where((r) => r.sequence > after).toList()
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
    final page = changed.take(limit).toList();
    return PullPage(
      records: [for (final r in page) r.record],
      hasMore: changed.length > limit,
      cursor: page.isEmpty ? null : '${page.last.sequence}',
    );
  }

  /// Server-side profile; [profileClock] stands in for `updated_at`.
  int profileClock = 0;

  RemoteProfile? get profile => profileCurrency == null
      ? null
      : RemoteProfile(
          displayCurrency: profileCurrency,
          updatedAt: 't$profileClock',
        );

  RemoteProfile saveProfile(String currency) {
    profileCurrency = currency;
    profileClock++;
    return profile!;
  }

  /// A change made by another device directly on the server.
  void serverEdit(String id, Map<String, Object?> payload) {
    final row = _rows[id]!;
    row
      ..payload = Map.of(payload)
      ..version += 1
      ..sequence = ++_sequence;
  }
}

class _Row {
  _Row({
    required this.id,
    required this.payload,
    required this.version,
    required this.sequence,
  });

  final String id;
  Map<String, Object?> payload;
  int version;
  int sequence;
  DateTime? deletedAt;

  RemoteSubscription get record => RemoteSubscription(
    id: id,
    version: version,
    serverSequence: sequence,
    payload: Map.of(payload),
    deletedAt: deletedAt,
  );
}

/// [SyncRemote] client for a [FakeCloud].
class FakeSyncRemote implements SyncRemote {
  FakeSyncRemote(this.cloud);

  final FakeCloud cloud;

  @override
  Future<PushResult> push({
    required String opId,
    required String subscriptionId,
    required OutboxKind kind,
    required int? baseVersion,
    Map<String, Object?>? payload,
  }) async {
    cloud.pushCalls++;
    if (cloud.offline) {
      throw const SyncRemoteException(SyncFailureKind.network, 'offline');
    }
    if (cloud.rejectIds.contains(subscriptionId)) {
      throw const SyncRemoteException(SyncFailureKind.rejected, '23514');
    }
    final result = cloud.push(
      opId: opId,
      subscriptionId: subscriptionId,
      kind: kind,
      baseVersion: baseVersion,
      payload: payload,
    );
    if (cloud.loseNextResponses > 0) {
      cloud.loseNextResponses--;
      throw const SyncRemoteException(SyncFailureKind.network, 'lost');
    }
    return result;
  }

  @override
  Future<PullPage> pull({required String? cursor, required int limit}) async {
    cloud.pullCalls++;
    if (cloud.offline) {
      throw const SyncRemoteException(SyncFailureKind.network, 'offline');
    }
    return cloud.pull(cursor: cursor, limit: limit);
  }

  @override
  Future<RemoteProfile?> fetchProfile() async {
    if (cloud.offline) {
      throw const SyncRemoteException(SyncFailureKind.network, 'offline');
    }
    return cloud.profile;
  }

  @override
  Future<RemoteProfile> saveProfile({required String displayCurrency}) async {
    if (cloud.offline) {
      throw const SyncRemoteException(SyncFailureKind.network, 'offline');
    }
    return cloud.saveProfile(displayCurrency);
  }
}

/// Scriptable [AuthRepository] for tests.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.currentUser, this.validCode = '123456'});

  @override
  AccountUser? currentUser;

  final String validCode;
  final StreamController<AuthChange> _changes = StreamController.broadcast();
  final List<String> requestedEmails = [];

  /// Every code passed to [verifyEmailCode], exactly as received.
  final List<String> verifiedCodes = [];
  AuthFailureKind? failNextRequest;
  int deleteCalls = 0;
  bool deleteFails = false;

  /// Users that exist (for sign-in without creating an account).
  final Map<String, String> accounts = {
    'alex@example.test': '0a000000-0000-4000-8000-00000000000a',
    'blair@example.test': '0b000000-0000-4000-8000-00000000000b',
  };

  @override
  bool get isConfigured => true;

  @override
  Stream<AuthChange> get changes => _changes.stream;

  @override
  Future<void> requestEmailCode(
    String email, {
    required bool createAccount,
  }) async {
    final failure = failNextRequest;
    failNextRequest = null;
    if (failure != null) throw AuthFailure(failure);
    if (!isPlausibleEmail(email)) {
      throw const AuthFailure(AuthFailureKind.invalidEmail);
    }
    if (!createAccount && !accounts.containsKey(email)) {
      throw const AuthFailure(AuthFailureKind.accountNotFound);
    }
    accounts.putIfAbsent(email, () => '0c000000-0000-4000-8000-00000000000c');
    requestedEmails.add(email);
  }

  @override
  Future<AccountUser> verifyEmailCode(String email, String code) async {
    verifiedCodes.add(code);
    if (code != validCode || !accounts.containsKey(email)) {
      throw const AuthFailure(AuthFailureKind.invalidCode);
    }
    final user = AccountUser(id: accounts[email]!, email: email);
    currentUser = user;
    return user;
  }

  @override
  Future<void> signOut() async => currentUser = null;

  @override
  Future<void> deleteAccount() async {
    deleteCalls++;
    if (deleteFails) throw const AuthFailure(AuthFailureKind.offline);
    currentUser = null;
  }

  /// Simulates the server ending the session (e.g. revoked refresh token).
  void expireSession() {
    currentUser = null;
    _changes.add(const AuthChange(null, sessionExpired: true));
  }
}

/// A fresh in-memory local-store opener (one per test).
SembastLocalStoreOpener memoryOpener({DateTime Function()? clock}) =>
    SembastLocalStoreOpener(
      newDatabaseFactoryMemory(),
      '/billfern-test',
      clock: clock,
    );

/// Scriptable [ConnectivitySignal] for tests.
class FakeConnectivity implements ConnectivitySignal {
  final StreamController<bool> _controller = StreamController.broadcast();

  @override
  Stream<bool> get changes => _controller.stream;

  /// Whether anything is listening (cloud sync active).
  bool get hasListener => _controller.hasListener;

  void emit(bool online) => _controller.add(online);
}
