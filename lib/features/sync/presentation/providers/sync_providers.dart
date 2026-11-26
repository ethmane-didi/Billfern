import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sembast/sembast.dart' show DatabaseException;

import '../../../../shared/models/subscription.dart';
import '../../../../shared/providers/clock_provider.dart';
import '../../../../shared/providers/currency_providers.dart';
import '../../../../shared/providers/local_store_providers.dart';
import '../../../../shared/providers/subscription_providers.dart';
import '../../../account/presentation/providers/account_providers.dart';
import '../../data/sync_store.dart';
import '../../domain/connectivity_signal.dart';
import '../../domain/profile_sync.dart';
import '../../domain/sync_engine.dart';
import '../../domain/sync_models.dart';
import '../../domain/sync_remote.dart';

/// Cloud side of sync. `main` overrides it when Supabase is configured.
final syncRemoteProvider = Provider<SyncRemote?>((ref) => null);

/// Delay before syncing after a local change (batches quick edits).
final syncDebounceProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 2),
);

/// Network connectivity changes. `main` overrides it with
/// `ConnectivityPlusSignal` when cloud sync is configured; tests use fakes.
final connectivitySignalProvider = Provider<ConnectivitySignal>(
  (ref) => const NoConnectivitySignal(),
);

/// Quiet period after connectivity returns before syncing, so flapping
/// networks (Wi-Fi hand-offs, tunnels) cause at most one run.
final connectivityDebounceProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 3),
);

/// The engine for the signed-in account's local store, or `null` when
/// cloud sync is not available (guest, local-only build, sample data never
/// reaches it because sample mode has no account store).
final syncEngineProvider = Provider<SyncEngine?>((ref) {
  final store = ref.watch(activeLocalStoreProvider);
  final remote = ref.watch(syncRemoteProvider);
  final account = ref.watch(currentAccountProvider);
  final sync = store?.sync;
  if (store == null || sync == null || remote == null || account == null) {
    return null;
  }
  if (store.identity.userId != account.id.toLowerCase()) return null;
  return SyncEngine(
    store: sync,
    repository: store.subscriptions,
    remote: remote,
    clock: ref.watch(clockProvider),
  );
});

/// Synchronization status and actions.
///
/// Triggers: sign-in (store opened), local changes (debounced), app resume,
/// connectivity returning (debounced), manual "Sync now", and a retry timer
/// that follows the backoff schedule.
class SyncController extends Notifier<SyncStatus> {
  Timer? _debounce;
  Timer? _retry;
  Timer? _reconnect;

  SyncEngine? get _engine => ref.read(syncEngineProvider);

  @override
  SyncStatus build() {
    final engine = ref.watch(syncEngineProvider);
    ref.onDispose(() {
      _debounce?.cancel();
      _retry?.cancel();
      _reconnect?.cancel();
    });
    // Guests, local-only builds and sample data have no engine, so they
    // never listen to connectivity or touch the network.
    if (engine == null) return SyncStatus.localOnly;
    _watchConnectivity(ref.watch(connectivitySignalProvider));

    // Local edits schedule a sync. Remote changes applied by the engine do
    // not create operations, so they do not cause sync loops.
    ref.listen<List<Subscription>>(subscriptionsProvider, (previous, next) {
      if (previous != null && !identical(previous, next)) schedule();
    });
    // A changed display currency is synced to the profile too.
    ref.listen<String>(preferredCurrencyProvider, (previous, next) {
      if (previous != null && previous != next) schedule();
    });
    Future.microtask(() => sync());
    return const SyncStatus(phase: SyncPhase.pending);
  }

  /// Listens for the network coming back (offline → online). The listener
  /// belongs to this build: an identity switch or sign-out rebuilds or
  /// disposes the controller, which cancels it.
  void _watchConnectivity(ConnectivitySignal signal) {
    bool? online;
    final subscription = signal.changes.listen((next) {
      final wasOffline = online == false;
      online = next;
      _reconnect?.cancel();
      if (next && wasOffline) {
        _reconnect = Timer(
          ref.read(connectivityDebounceProvider),
          () => unawaited(_onReconnected()),
        );
      }
    }, onError: (Object _) {});
    ref.onDispose(subscription.cancel);
  }

  /// Connectivity returned: a hint, not proof that Supabase is reachable.
  ///
  /// Syncs only when there is something to deliver or the last run failed
  /// for lack of network, so reconnecting costs no request otherwise.
  /// Backoff delays are cleared (attempt counts kept); if the run fails,
  /// backoff resumes as usual. A run that started before the network came
  /// back is allowed to finish first, then one fresh run follows.
  Future<void> _onReconnected() async {
    final engine = _engine;
    if (engine == null || !ref.mounted) return;
    try {
      final ops = await engine.store.pending();
      final deliverable = ops.any((op) => !op.parked);
      if (!ref.mounted) return;
      if (!deliverable && state.phase != SyncPhase.offline) return;
      await engine.expediteRetries();
      if (engine.isRunning) await engine.sync();
      if (!ref.mounted || !identical(engine, _engine)) return;
      await sync();
    } on DatabaseException {
      // The store was closed by an identity switch; nothing to do.
    }
  }

  /// Syncs after the debounce delay.
  void schedule() {
    if (_engine == null) return;
    _debounce?.cancel();
    _debounce = Timer(ref.read(syncDebounceProvider), () => sync());
  }

  /// Runs a sync now. [manual] ignores backoff (the "Sync now" / "Retry"
  /// buttons).
  Future<SyncReport?> sync({bool manual = false}) async {
    final engine = _engine;
    if (engine == null) return null;
    try {
      return await _sync(engine, manual: manual);
    } on DatabaseException {
      // The store was closed by an identity switch or erase; the new store
      // has its own controller run.
      return null;
    }
  }

  Future<SyncReport?> _sync(SyncEngine engine, {required bool manual}) async {
    if (manual) await engine.retryParked();
    if (!ref.mounted) return null;
    state = state.copyWith(phase: SyncPhase.syncing, clearError: true);
    final report = await engine.sync(manual: manual);
    if (!ref.mounted || !identical(engine, _engine)) return report;
    if (report.pulled > 0 || report.pushed > 0) {
      ref.read(subscriptionsProvider.notifier).reload();
    }
    if (!report.ran) return report;
    if (report.succeeded) await _syncProfile(engine);
    if (!ref.mounted) return report;
    final phase = switch (report.failure) {
      null => SyncPhase.synced,
      SyncFailureKind.network => SyncPhase.offline,
      _ => SyncPhase.failed,
    };
    final next = await engine.status(phase: phase, error: report.failure);
    if (!ref.mounted) return report;
    state = next;
    await _scheduleRetry(engine);
    return report;
  }

  /// Two-way display-currency sync (see [ProfileSyncPolicy]).
  Future<void> _syncProfile(SyncEngine engine) async {
    if (!ref.mounted) return;
    try {
      final remote = await engine.remote.fetchProfile();
      if (!ref.mounted) return;
      final synced = SyncedProfile.fromMap(
        await engine.store.readMeta(SyncStore.profileCurrencyKey),
      );
      if (!ref.mounted) return;
      final action = ProfileSyncPolicy.decide(
        localCurrency: ref.read(preferredCurrencyProvider),
        synced: synced,
        remote: remote,
      );
      final RemoteProfile baseline;
      switch (action) {
        case PushCurrency(:final currency):
          baseline = await engine.remote.saveProfile(displayCurrency: currency);
        case ApplyCurrency(:final currency, :final remote):
          baseline = remote;
          await _recordProfile(engine, currency, baseline);
          if (ref.mounted) {
            await ref.read(preferredCurrencyProvider.notifier).select(currency);
          }
          return;
        case RecordBaseline(:final remote):
          baseline = remote;
      }
      if (!ref.mounted) return;
      await _recordProfile(
        engine,
        baseline.displayCurrency ?? ref.read(preferredCurrencyProvider),
        baseline,
      );
    } on SyncRemoteException {
      // Retried on the next successful sync.
    } on DatabaseException {
      // The store was closed by an identity switch.
    }
  }

  Future<void> _recordProfile(
    SyncEngine engine,
    String currency,
    RemoteProfile remote,
  ) => engine.store.writeMeta(
    engine.store.database,
    SyncStore.profileCurrencyKey,
    SyncedProfile(
      currency: currency,
      remoteUpdatedAt: remote.updatedAt,
    ).toMap(),
  );

  Future<void> _scheduleRetry(SyncEngine engine) async {
    _retry?.cancel();
    final ops = await engine.store.pending();
    final due = [
      for (final op in ops)
        if (!op.parked && op.nextAttemptAt != null) op.nextAttemptAt!,
    ];
    if (due.isEmpty) return;
    due.sort();
    // Same clock as the engine that stamped nextAttemptAt.
    final delay = due.first.difference(ref.read(clockProvider)());
    _retry = Timer(delay.isNegative ? Duration.zero : delay, () => sync());
  }

  Future<void> resolveConflict(String id, ConflictChoice choice) async {
    final engine = _engine;
    if (engine == null) return;
    await engine.resolveConflict(id, choice);
    if (!ref.mounted) return;
    ref.read(subscriptionsProvider.notifier).reload();
    await sync(manual: true);
  }
}

final syncControllerProvider = NotifierProvider<SyncController, SyncStatus>(
  SyncController.new,
);

/// Unresolved conflicts with the local version, for the Settings screen.
final syncConflictsProvider = FutureProvider<List<SyncConflict>>((ref) async {
  ref.watch(syncControllerProvider);
  final engine = ref.watch(syncEngineProvider);
  if (engine == null) return const [];
  return engine.store.conflictList();
});
