import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/date_math.dart';
import '../data/app_preference_store.dart';
import '../data/subscription_repository.dart';
import '../models/subscription.dart';
import 'clock_provider.dart';

/// Whose data the app shows.
enum DataMode {
  /// The user's own subscriptions, persisted on the device.
  personal,

  /// Read-only-in-spirit sample subscriptions held in memory; changes are
  /// discarded on restart and never touch personal data.
  sample,
}

/// Small settings store. `main` overrides this with `shared_preferences`.
final appPreferenceStoreProvider = Provider<AppPreferenceStore>(
  (ref) => InMemoryAppPreferenceStore(),
);

class DataModeNotifier extends Notifier<DataMode> {
  @override
  DataMode build() {
    final saved = ref
        .watch(appPreferenceStoreProvider)
        .read(PreferenceKeys.dataMode);
    return DataMode.values.firstWhere(
      (mode) => mode.name == saved,
      orElse: () => DataMode.personal,
    );
  }

  Future<void> set(DataMode mode) async {
    state = mode;
    await ref
        .read(appPreferenceStoreProvider)
        .write(PreferenceKeys.dataMode, mode.name);
  }
}

final dataModeProvider = NotifierProvider<DataModeNotifier, DataMode>(
  DataModeNotifier.new,
);

/// The user's own subscriptions. `main` overrides this with the sembast
/// repository; the in-memory default keeps tests hermetic.
final personalSubscriptionRepositoryProvider = Provider<SubscriptionRepository>(
  (ref) => InMemorySubscriptionRepository(),
);

/// Sample subscriptions, built relative to today.
final sampleSubscriptionRepositoryProvider = Provider<SubscriptionRepository>(
  (ref) => DemoSubscriptionRepository(today: ref.watch(todayProvider)),
);

/// The repository for the current [DataMode].
final subscriptionRepositoryProvider = Provider<SubscriptionRepository>(
  (ref) => switch (ref.watch(dataModeProvider)) {
    DataMode.personal => ref.watch(personalSubscriptionRepositoryProvider),
    DataMode.sample => ref.watch(sampleSubscriptionRepositoryProvider),
  },
);

/// Generates unique subscription ids. Override in tests for stable ids.
final subscriptionIdGeneratorProvider = Provider<String Function()>((ref) {
  final random = Random();
  final now = ref.watch(clockProvider);
  return () {
    final time = now().microsecondsSinceEpoch.toRadixString(36);
    final noise = random.nextInt(1 << 32).toRadixString(36).padLeft(7, '0');
    return 'sub_${time}_$noise';
  };
});

/// Every tracked subscription, de-duplicated by id (first occurrence wins),
/// plus the mutations the app performs on them.
///
/// This is the single source of truth: the dashboard, subscription list,
/// details and (future) analytics all derive from it, so every change shows
/// up everywhere at once.
class SubscriptionsNotifier extends Notifier<List<Subscription>> {
  @override
  List<Subscription> build() =>
      _dedupe(ref.watch(subscriptionRepositoryProvider).fetchAll());

  SubscriptionRepository get _repository =>
      ref.read(subscriptionRepositoryProvider);

  static List<Subscription> _dedupe(List<Subscription> all) {
    final seen = <String>{};
    return List.unmodifiable(all.where((sub) => seen.add(sub.id)));
  }

  void _refresh() => state = _dedupe(_repository.fetchAll());

  /// Adds the user's own subscription. Adding from sample mode switches to
  /// personal mode first, so sample data is never mixed with real data.
  Future<void> add(Subscription subscription) async {
    if (ref.read(dataModeProvider) == DataMode.sample) {
      await ref.read(dataModeProvider.notifier).set(DataMode.personal);
    }
    await _repository.save(subscription);
    _refresh();
  }

  /// Replaces an existing subscription (matched by id).
  ///
  /// When the price, currency or billing cycle changes, the previous terms
  /// are recorded in [Subscription.priceHistory] so earlier months keep the
  /// price that applied then. The stored history always comes from the
  /// existing record, so an edit can never drop it.
  Future<void> update(Subscription subscription) async {
    final previous = byId(subscription.id);
    final next = previous == null
        ? subscription
        : subscription.revisedFrom(previous, _today);
    await _repository.save(next);
    _refresh();
  }

  Future<void> pause(String id) => _change(id, (s) => s.pause(_today));

  Future<void> resume(String id) => _change(id, (s) => s.resume(_today));

  /// Removes a subscription from the user's list.
  ///
  /// When it already counted towards an earlier month it is kept as an
  /// ended record so the spending history does not change; one added this
  /// month has no history and is deleted outright.
  Future<void> delete(String id) async {
    final current = byId(id);
    final monthStart = DateMath.monthStart(_today);
    if (current != null && current.startedOn.isBefore(monthStart)) {
      await _repository.save(current.end(_today));
    } else {
      await _repository.delete(id);
    }
    _refresh();
  }

  DateTime get _today => ref.read(todayProvider);

  Future<void> _change(
    String id,
    Subscription Function(Subscription) edit,
  ) async {
    final current = byId(id);
    if (current == null) return;
    await update(edit(current));
  }

  Subscription? byId(String id) {
    for (final sub in state) {
      if (sub.id == id) return sub;
    }
    return null;
  }
}

final subscriptionsProvider =
    NotifierProvider<SubscriptionsNotifier, List<Subscription>>(
      SubscriptionsNotifier.new,
    );

/// Removed subscriptions kept only for spending history (see
/// [SubscriptionsNotifier.delete]). Recomputed after every mutation.
final endedSubscriptionsProvider = Provider<List<Subscription>>((ref) {
  ref.watch(subscriptionsProvider);
  return ref.watch(subscriptionRepositoryProvider).fetchEnded();
});

/// Every subscription that can affect spending history: current ones plus
/// ended ones. History calculations (monthly totals of past months) use
/// this; lists, renewals, categories and projections use
/// [subscriptionsProvider].
final subscriptionHistoryProvider = Provider<List<Subscription>>((ref) {
  return List.unmodifiable([
    ...ref.watch(subscriptionsProvider),
    ...ref.watch(endedSubscriptionsProvider),
  ]);
});

/// Subscriptions that are currently charging.
final activeSubscriptionsProvider = Provider<List<Subscription>>((ref) {
  return List.unmodifiable(
    ref.watch(subscriptionsProvider).where((sub) => sub.isActive),
  );
});

/// One subscription by id, or `null` once it has been deleted.
final subscriptionByIdProvider = Provider.family<Subscription?, String>((
  ref,
  id,
) {
  for (final sub in ref.watch(subscriptionsProvider)) {
    if (sub.id == id) return sub;
  }
  return null;
});
