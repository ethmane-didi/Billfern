import 'package:flutter/painting.dart';
import 'package:flutter/foundation.dart';

import '../../core/money/money.dart';
import '../../core/utils/date_math.dart';
import 'billing_cycle.dart';
import 'subscription_category.dart';
import 'subscription_glyph.dart';

/// Whether a subscription is currently charging.
enum SubscriptionStatus {
  active('Active'),
  paused('Paused');

  const SubscriptionStatus(this.label);

  final String label;
}

/// A recurring payment the user tracks.
///
/// The price is stored in integer minor units ([priceMinor]) of the
/// subscription's own [currencyCode]; it never changes when the user switches
/// display currency. Identity is the
/// [id]: two instances with the same id are the same subscription. Several
/// subscriptions may share a [catalogId] (e.g. personal and business Notion
/// accounts).
///
/// Branding is not stored here. A catalog-backed subscription takes its logo
/// and colour from the catalog via [catalogId]; a custom one may set
/// [websiteDomain], [customColor] and [customGlyph].
@immutable
class Subscription {
  const Subscription({
    required this.id,
    required this.name,
    required this.plan,
    required this.priceMinor,
    required this.currencyCode,
    required this.billingCycle,
    required this.category,
    required this.startedOn,
    this.catalogId,
    this.websiteDomain,
    this.customColor,
    this.customGlyph,
    this.status = SubscriptionStatus.active,
    this.pausedOn,
  }) : assert(priceMinor >= 0, 'Price cannot be negative.'),
       assert(
         (status == SubscriptionStatus.paused) == (pausedOn != null),
         'pausedOn is required for, and only for, paused subscriptions.',
       );

  final String id;
  final String name;
  final String plan;

  /// Price charged every [billingCycle], in cents.
  final int priceMinor;

  final BillingCycle billingCycle;
  final SubscriptionCategory category;

  /// First billing date; later renewals fall on the same day of the month.
  final DateTime startedOn;

  /// Catalog service this subscription is for, or `null` for a custom one.
  final String? catalogId;

  /// ISO 4217 code of [priceMinor] — the currency the user is charged in.
  final String currencyCode;

  /// Optional website of a custom subscription, e.g. `example.com`. Used by
  /// a future remote logo provider.
  final String? websiteDomain;

  /// Optional colour of a custom subscription's logo tile.
  final Color? customColor;

  /// Optional icon of a custom subscription.
  final SubscriptionGlyph? customGlyph;

  final SubscriptionStatus status;

  /// When the subscription was paused. Set only when [status] is paused.
  final DateTime? pausedOn;

  bool get isActive => status == SubscriptionStatus.active;

  /// Price per [billingCycle], in [currencyCode].
  Money get price => Money(priceMinor, currencyCode);

  /// Equivalent monthly cost, in [currencyCode].
  Money get monthlyCost => billingCycle.monthlyCost(price);

  /// Cost over twelve months, in [currencyCode].
  Money get annualCost => billingCycle.annualCost(price);

  /// Whether this subscription contributed to spending in the calendar month
  /// starting at [monthStart]: it had started before the month ended and was
  /// not paused before the month ended.
  bool isBilledInMonth(DateTime monthStart) {
    final nextMonth = DateMath.addMonths(DateMath.monthStart(monthStart), 1);
    final pausedOn = this.pausedOn;
    return startedOn.isBefore(nextMonth) &&
        (pausedOn == null || !pausedOn.isBefore(nextMonth));
  }

  /// The next billing date on or after [today], or `null` when paused.
  DateTime? nextRenewal(DateTime today) {
    if (!isActive) return null;
    final anchor = DateMath.dateOnly(startedOn);
    final day = DateMath.dateOnly(today);
    final step = billingCycle.months;

    // The first renewal is one full cycle after the start date.
    var cycles = (DateMath.monthsBetween(anchor, day) / step).ceil();
    if (cycles < 1) cycles = 1;
    while (DateMath.addMonths(anchor, cycles * step).isBefore(day)) {
      cycles++;
    }
    while (cycles > 1 &&
        !DateMath.addMonths(anchor, (cycles - 1) * step).isBefore(day)) {
      cycles--;
    }
    return DateMath.addMonths(anchor, cycles * step);
  }

  @override
  bool operator ==(Object other) => other is Subscription && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Subscription($id, $name, $priceMinor $currencyCode/$billingCycle)';
}
