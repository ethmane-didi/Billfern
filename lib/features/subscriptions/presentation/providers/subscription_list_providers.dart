import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/models/subscription.dart';
import '../../../../shared/models/subscription_category.dart';
import '../../../../shared/providers/clock_provider.dart';
import '../../../../shared/providers/currency_providers.dart';
import '../../../../shared/providers/subscription_providers.dart';
import '../../domain/subscription_list_query.dart';

class SubscriptionListQueryNotifier extends Notifier<SubscriptionListQuery> {
  @override
  SubscriptionListQuery build() => const SubscriptionListQuery();

  void setText(String text) => state = state.copyWith(text: text);

  void setStatus(StatusFilter status) => state = state.copyWith(status: status);

  void setCategory(SubscriptionCategory? category) => state = category == null
      ? state.copyWith(clearCategory: true)
      : state.copyWith(category: category);

  void setSort(SubscriptionSort sort) => state = state.copyWith(sort: sort);

  /// Clears search and filters but keeps the sort order.
  void clearFilters() => state = SubscriptionListQuery(sort: state.sort);
}

final subscriptionListQueryProvider =
    NotifierProvider<SubscriptionListQueryNotifier, SubscriptionListQuery>(
      SubscriptionListQueryNotifier.new,
    );

/// The subscriptions list after search, filters and sorting.
final filteredSubscriptionsProvider = Provider<List<Subscription>>((ref) {
  return ref
      .watch(subscriptionListQueryProvider)
      .apply(
        ref.watch(subscriptionsProvider),
        converter: ref.watch(moneyConverterProvider),
        today: ref.watch(todayProvider),
      );
});

/// Counts for the All / Active / Paused tabs.
final statusCountsProvider = Provider<Map<StatusFilter, int>>((ref) {
  final subs = ref.watch(subscriptionsProvider);
  return {
    for (final filter in StatusFilter.values)
      filter: subs.where(filter.matches).length,
  };
});

/// Categories present in the user's subscriptions, in enum order.
final usedCategoriesProvider = Provider<List<SubscriptionCategory>>((ref) {
  final used = {
    for (final sub in ref.watch(subscriptionsProvider)) sub.category,
  };
  return [
    for (final category in SubscriptionCategory.values)
      if (used.contains(category)) category,
  ];
});
