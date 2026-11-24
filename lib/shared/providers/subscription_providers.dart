import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/subscription_repository.dart';
import '../models/subscription.dart';
import 'clock_provider.dart';

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>(
  (ref) => MockSubscriptionRepository(today: ref.watch(todayProvider)),
);

/// Every tracked subscription, de-duplicated by id (first occurrence wins).
///
/// This is the single source of truth: all totals, charts and lists are
/// derived from it.
final subscriptionsProvider = Provider<List<Subscription>>((ref) {
  final all = ref.watch(subscriptionRepositoryProvider).fetchAll();
  final seen = <String>{};
  return List.unmodifiable(all.where((sub) => seen.add(sub.id)));
});

/// Subscriptions that are currently charging.
final activeSubscriptionsProvider = Provider<List<Subscription>>((ref) {
  return List.unmodifiable(
    ref.watch(subscriptionsProvider).where((sub) => sub.isActive),
  );
});
