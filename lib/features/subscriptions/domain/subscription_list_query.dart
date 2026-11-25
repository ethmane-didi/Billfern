import 'package:flutter/foundation.dart';

import '../../../core/money/currency_converter.dart';
import '../../../shared/data/subscription_catalog.dart';
import '../../../shared/models/subscription.dart';
import '../../../shared/models/subscription_category.dart';

/// Status filter of the subscriptions list.
enum StatusFilter {
  all('All'),
  active('Active'),
  paused('Paused');

  const StatusFilter(this.label);

  final String label;

  bool matches(Subscription sub) => switch (this) {
    StatusFilter.all => true,
    StatusFilter.active => sub.isActive,
    StatusFilter.paused => !sub.isActive,
  };
}

/// Sort order of the subscriptions list.
enum SubscriptionSort {
  nextRenewal('Next renewal'),
  name('Name'),
  priceHighToLow('Price: high to low'),
  priceLowToHigh('Price: low to high');

  const SubscriptionSort(this.label);

  final String label;
}

/// Search, filter and sort settings for the subscriptions list.
@immutable
class SubscriptionListQuery {
  const SubscriptionListQuery({
    this.text = '',
    this.status = StatusFilter.all,
    this.category,
    this.sort = SubscriptionSort.nextRenewal,
  });

  final String text;
  final StatusFilter status;

  /// `null` means every category.
  final SubscriptionCategory? category;
  final SubscriptionSort sort;

  bool get hasFilters =>
      text.trim().isNotEmpty || status != StatusFilter.all || category != null;

  SubscriptionListQuery copyWith({
    String? text,
    StatusFilter? status,
    SubscriptionCategory? category,
    bool clearCategory = false,
    SubscriptionSort? sort,
  }) => SubscriptionListQuery(
    text: text ?? this.text,
    status: status ?? this.status,
    category: clearCategory ? null : (category ?? this.category),
    sort: sort ?? this.sort,
  );

  /// Applies the query to [subscriptions].
  ///
  /// - Search matches name, plan, category and notes, ignoring case and
  ///   accents.
  /// - Price sorting compares the monthly equivalent converted with
  ///   [converter], so different currencies and billing cycles rank fairly;
  ///   subscriptions without an exchange rate go last.
  /// - Next renewal puts paused subscriptions last.
  List<Subscription> apply(
    List<Subscription> subscriptions, {
    required MoneyConverter converter,
    required DateTime today,
  }) {
    final needle = SubscriptionCatalog.normalize(text);
    final results = subscriptions.where((sub) {
      if (!status.matches(sub)) return false;
      if (category != null && sub.category != category) return false;
      if (needle.isEmpty) return true;
      return [
        sub.name,
        sub.plan,
        sub.category.label,
        sub.notes ?? '',
      ].any((field) => SubscriptionCatalog.normalize(field).contains(needle));
    }).toList();

    int byName(Subscription a, Subscription b) =>
        a.name.toLowerCase().compareTo(b.name.toLowerCase());

    int? monthly(Subscription sub) =>
        converter.convert(sub.monthlyCost)?.minorUnits;

    int byPrice(Subscription a, Subscription b, {required bool descending}) {
      final pa = monthly(a);
      final pb = monthly(b);
      if (pa == null || pb == null) {
        if (pa == pb) return byName(a, b);
        return pa == null ? 1 : -1;
      }
      final compared = descending ? pb.compareTo(pa) : pa.compareTo(pb);
      return compared != 0 ? compared : byName(a, b);
    }

    results.sort(switch (sort) {
      SubscriptionSort.name => byName,
      SubscriptionSort.priceHighToLow => (a, b) => byPrice(
        a,
        b,
        descending: true,
      ),
      SubscriptionSort.priceLowToHigh => (a, b) => byPrice(
        a,
        b,
        descending: false,
      ),
      SubscriptionSort.nextRenewal => (a, b) {
        final ra = a.nextRenewal(today);
        final rb = b.nextRenewal(today);
        if (ra == null || rb == null) {
          if (ra == rb) return byName(a, b);
          return ra == null ? 1 : -1;
        }
        final compared = ra.compareTo(rb);
        return compared != 0 ? compared : byName(a, b);
      },
    });
    return results;
  }
}
