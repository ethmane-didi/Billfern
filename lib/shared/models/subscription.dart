import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../../core/money/money.dart';
import '../../core/utils/date_math.dart';
import 'billing_cycle.dart';
import 'reminder_preference.dart';
import 'subscription_category.dart';
import 'subscription_glyph.dart';

/// Whether a subscription is currently charging.
enum SubscriptionStatus {
  active('Active'),
  paused('Paused');

  const SubscriptionStatus(this.label);

  final String label;
}

/// A finished pause: billing stopped on [from] and restarted on [until].
@immutable
class PausePeriod {
  const PausePeriod({required this.from, required this.until});

  final DateTime from;
  final DateTime until;

  /// Whether [day] falls inside the pause (`from` inclusive, `until`
  /// exclusive).
  bool contains(DateTime day) => !day.isBefore(from) && day.isBefore(until);

  @override
  bool operator ==(Object other) =>
      other is PausePeriod && other.from == from && other.until == until;

  @override
  int get hashCode => Object.hash(from, until);
}

/// Billing terms that applied **before** a price, currency or billing-cycle
/// change: [priceMinor] in [currencyCode] every [billingCycle], in force
/// until [until] (exclusive). Kept so past months are never recalculated
/// with today's price.
@immutable
class PriceRevision {
  const PriceRevision({
    required this.until,
    required this.priceMinor,
    required this.currencyCode,
    required this.billingCycle,
  });

  final DateTime until;
  final int priceMinor;
  final String currencyCode;
  final BillingCycle billingCycle;

  Money get price => Money(priceMinor, currencyCode);

  /// Equivalent monthly cost under these terms.
  Money get monthlyCost => billingCycle.monthlyCost(price);

  @override
  bool operator ==(Object other) =>
      other is PriceRevision &&
      other.until == until &&
      other.priceMinor == priceMinor &&
      other.currencyCode == currencyCode &&
      other.billingCycle == billingCycle;

  @override
  int get hashCode =>
      Object.hash(until, priceMinor, currencyCode, billingCycle);
}

/// A recurring payment the user tracks.
///
/// The price is stored in integer minor units ([priceMinor]) of the
/// subscription's own [currencyCode]; it never changes when the user switches
/// display currency. Identity is the [id] (two instances with the same id
/// are the same subscription); `==` compares all fields so changes are
/// observable. Several subscriptions may share a [catalogId]
/// (e.g. personal and business Notion accounts).
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
    this.billingAnchor,
    this.catalogId,
    this.websiteDomain,
    this.customColor,
    this.customGlyph,
    this.status = SubscriptionStatus.active,
    this.pausedOn,
    this.pauseHistory = const [],
    this.priceHistory = const [],
    this.endedOn,
    this.reminder = ReminderPreference.oneDayBefore,
    this.notes,
    this.createdAt,
  }) : assert(priceMinor >= 0, 'Price cannot be negative.'),
       assert(
         (status == SubscriptionStatus.paused) == (pausedOn != null),
         'pausedOn is required for, and only for, paused subscriptions.',
       );

  final String id;
  final String name;

  /// Plan or tier, e.g. "Premium". May be empty.
  final String plan;

  /// Price charged every [billingCycle], in minor units of [currencyCode].
  final int priceMinor;

  /// ISO 4217 code of [priceMinor] — the currency the user is charged in.
  final String currencyCode;

  final BillingCycle billingCycle;
  final SubscriptionCategory category;

  /// When spending started counting (first charge, or when tracking began).
  /// Months before it are not part of the spending history.
  final DateTime startedOn;

  /// A known billing date; renewals fall a whole number of cycles from it.
  /// Defaults to [startedOn]. Editing the renewal date moves only this, so
  /// history is preserved.
  final DateTime? billingAnchor;

  /// Catalog service this subscription is for, or `null` for a custom one.
  final String? catalogId;

  /// Optional website, normalised to a bare domain (e.g. `example.com`).
  final String? websiteDomain;

  /// Optional colour of a custom subscription's logo tile.
  final Color? customColor;

  /// Optional icon of a custom subscription.
  final SubscriptionGlyph? customGlyph;

  final SubscriptionStatus status;

  /// Start of the current pause. Set only when [status] is paused.
  final DateTime? pausedOn;

  /// Earlier, finished pauses (oldest first).
  final List<PausePeriod> pauseHistory;

  /// Earlier billing terms (oldest first), recorded whenever the price,
  /// currency or billing cycle changes. Each applies until its `until`
  /// date; the current fields apply from the last one onwards.
  final List<PriceRevision> priceHistory;

  /// When the user removed the subscription. Ended subscriptions are kept
  /// only so the spending history of earlier months stays intact; they never
  /// appear in lists, totals for the current month or projections.
  final DateTime? endedOn;

  /// When to remind the user before a renewal. Stored now; notifications are
  /// scheduled in a later phase.
  final ReminderPreference reminder;

  final String? notes;

  /// When the user added the subscription to Billfern.
  final DateTime? createdAt;

  /// Charging now: not paused and not removed.
  bool get isActive => status == SubscriptionStatus.active && endedOn == null;

  /// Removed by the user; kept only for history.
  bool get isEnded => endedOn != null;

  /// Paused (and not removed).
  bool get isPaused => status == SubscriptionStatus.paused && endedOn == null;

  /// Price per [billingCycle], in [currencyCode].
  Money get price => Money(priceMinor, currencyCode);

  /// Equivalent monthly cost, in [currencyCode].
  Money get monthlyCost => billingCycle.monthlyCost(price);

  /// Cost over twelve months, in [currencyCode].
  Money get annualCost => billingCycle.annualCost(price);

  /// Equivalent monthly cost under the terms in force on [day], in the
  /// currency charged then. Days before the first recorded change use the
  /// oldest terms; days after the last change use the current terms.
  Money monthlyCostOn(DateTime day) {
    final date = DateMath.dateOnly(day);
    for (final revision in priceHistory) {
      if (date.isBefore(revision.until)) return revision.monthlyCost;
    }
    return monthlyCost;
  }

  /// When the subscription was added, falling back to its billing anchor.
  DateTime get addedOn => createdAt ?? startedOn;

  /// Whether the subscription was paused on [day].
  bool isPausedOn(DateTime day) {
    final current = pausedOn;
    if (current != null && !day.isBefore(current)) return true;
    return pauseHistory.any((period) => period.contains(day));
  }

  /// Whether this subscription counts towards spending in the calendar month
  /// starting at [monthStart]: it had started before the month ended, was
  /// not paused on the month's last day and had not been removed by then.
  /// Past months keep counting after a later pause, price change or removal,
  /// and months spent paused stay excluded after resuming.
  bool isBilledInMonth(DateTime monthStart) {
    final nextMonth = DateMath.addMonths(DateMath.monthStart(monthStart), 1);
    final lastDay = lastDayOfMonth(monthStart);
    final ended = endedOn;
    return startedOn.isBefore(nextMonth) &&
        !isPausedOn(lastDay) &&
        (ended == null || lastDay.isBefore(ended));
  }

  /// Monthly-equivalent cost counted for the month starting at
  /// [monthStart], using the terms in force on its last day — the same day
  /// [isBilledInMonth] checks.
  Money monthlyCostForMonth(DateTime monthStart) =>
      monthlyCostOn(lastDayOfMonth(monthStart));

  /// Last calendar day of the month containing [date].
  static DateTime lastDayOfMonth(DateTime date) => DateTime(
    date.year,
    date.month,
    DateMath.daysInMonth(date.year, date.month),
  );

  /// Billing dates from [from] to [to] (both inclusive), oldest first.
  /// Empty unless the subscription is charging. Dates are computed from the
  /// billing anchor (never by chaining), so month-end and leap-day anchors
  /// return to their day whenever the month allows it.
  Iterable<DateTime> billingDatesBetween(DateTime from, DateTime to) sync* {
    if (!isActive) return;
    final start = DateMath.dateOnly(from);
    final end = DateMath.dateOnly(to);
    final anchor = DateMath.dateOnly(billingAnchor ?? startedOn);
    final cycle = billingCycle;
    var periods = anchor.isBefore(start)
        ? cycle.approximatePeriodsBetween(anchor, start) - 1
        : 0;
    if (periods < 0) periods = 0;
    while (true) {
      final date = cycle.advance(anchor, periods);
      if (date.isAfter(end)) return;
      if (!date.isBefore(start)) yield date;
      periods++;
    }
  }

  /// The next billing date on or after [today], or `null` when paused.
  DateTime? nextRenewal(DateTime today) =>
      isActive ? scheduledRenewal(today) : null;

  /// The next date on or after [today] that falls on the billing schedule,
  /// ignoring status (used to pre-fill the edit form of a paused
  /// subscription).
  DateTime scheduledRenewal(DateTime today) {
    final anchor = DateMath.dateOnly(billingAnchor ?? startedOn);
    final day = DateMath.dateOnly(today);
    final cycle = billingCycle;
    if (!anchor.isBefore(day)) return anchor;

    var periods = cycle.approximatePeriodsBetween(anchor, day);
    if (periods < 1) periods = 1;
    while (cycle.advance(anchor, periods).isBefore(day)) {
      periods++;
    }
    while (periods > 1 && !cycle.advance(anchor, periods - 1).isBefore(day)) {
      periods--;
    }
    return cycle.advance(anchor, periods);
  }

  /// A paused copy, starting today. No-op when already paused.
  Subscription pause(DateTime today) => isActive
      ? copyWith(
          status: SubscriptionStatus.paused,
          pausedOn: DateMath.dateOnly(today),
        )
      : this;

  /// An active copy; the finished pause moves to [pauseHistory]. No-op when
  /// already active.
  Subscription resume(DateTime today) {
    final from = pausedOn;
    if (!isPaused || from == null) return this;
    final until = DateMath.dateOnly(today);
    return Subscription(
      id: id,
      name: name,
      plan: plan,
      priceMinor: priceMinor,
      currencyCode: currencyCode,
      billingCycle: billingCycle,
      category: category,
      startedOn: startedOn,
      billingAnchor: billingAnchor,
      catalogId: catalogId,
      websiteDomain: websiteDomain,
      customColor: customColor,
      customGlyph: customGlyph,
      pauseHistory: [
        ...pauseHistory,
        if (until.isAfter(from)) PausePeriod(from: from, until: until),
      ],
      priceHistory: priceHistory,
      endedOn: endedOn,
      reminder: reminder,
      notes: notes,
      createdAt: createdAt,
    );
  }

  /// Whether the billing terms (price, currency or cycle) differ from
  /// [other]'s.
  bool hasDifferentTermsFrom(Subscription other) =>
      other.priceMinor != priceMinor ||
      other.currencyCode != currencyCode ||
      other.billingCycle != billingCycle;

  /// This edit of [previous], with [previous]'s terms recorded in
  /// [priceHistory] when the price, currency or cycle changed on [today].
  ///
  /// Nothing is recorded when the terms are unchanged, when the subscription
  /// has not started yet, or when the terms already changed earlier today
  /// (the terms before today are already recorded).
  Subscription revisedFrom(Subscription previous, DateTime today) {
    final day = DateMath.dateOnly(today);
    final history = previous.priceHistory;
    if (!hasDifferentTermsFrom(previous) ||
        !day.isAfter(DateMath.dateOnly(previous.startedOn)) ||
        (history.isNotEmpty && !day.isAfter(history.last.until))) {
      return _withPriceHistory(history);
    }
    return _withPriceHistory([
      ...history,
      PriceRevision(
        until: day,
        priceMinor: previous.priceMinor,
        currencyCode: previous.currencyCode,
        billingCycle: previous.billingCycle,
      ),
    ]);
  }

  /// A removed copy, ended on [today], kept for history only.
  Subscription end(DateTime today) => Subscription(
    id: id,
    name: name,
    plan: plan,
    priceMinor: priceMinor,
    currencyCode: currencyCode,
    billingCycle: billingCycle,
    category: category,
    startedOn: startedOn,
    billingAnchor: billingAnchor,
    catalogId: catalogId,
    websiteDomain: websiteDomain,
    customColor: customColor,
    customGlyph: customGlyph,
    status: status,
    pausedOn: pausedOn,
    pauseHistory: pauseHistory,
    priceHistory: priceHistory,
    endedOn: DateMath.dateOnly(today),
    reminder: reminder,
    notes: notes,
    createdAt: createdAt,
  );

  Subscription _withPriceHistory(List<PriceRevision> history) => Subscription(
    id: id,
    name: name,
    plan: plan,
    priceMinor: priceMinor,
    currencyCode: currencyCode,
    billingCycle: billingCycle,
    category: category,
    startedOn: startedOn,
    billingAnchor: billingAnchor,
    catalogId: catalogId,
    websiteDomain: websiteDomain,
    customColor: customColor,
    customGlyph: customGlyph,
    status: status,
    pausedOn: pausedOn,
    pauseHistory: pauseHistory,
    priceHistory: history,
    endedOn: endedOn,
    reminder: reminder,
    notes: notes,
    createdAt: createdAt,
  );

  /// A copy with the given fields replaced. Use [pause]/[resume] to change
  /// status so pause history stays consistent.
  Subscription copyWith({
    String? name,
    String? plan,
    int? priceMinor,
    String? currencyCode,
    BillingCycle? billingCycle,
    SubscriptionCategory? category,
    DateTime? startedOn,
    DateTime? billingAnchor,
    SubscriptionStatus? status,
    DateTime? pausedOn,
    ReminderPreference? reminder,
    String? notes,
    String? websiteDomain,
  }) {
    return Subscription(
      id: id,
      name: name ?? this.name,
      plan: plan ?? this.plan,
      priceMinor: priceMinor ?? this.priceMinor,
      currencyCode: currencyCode ?? this.currencyCode,
      billingCycle: billingCycle ?? this.billingCycle,
      category: category ?? this.category,
      startedOn: startedOn ?? this.startedOn,
      billingAnchor: billingAnchor ?? this.billingAnchor,
      catalogId: catalogId,
      websiteDomain: websiteDomain ?? this.websiteDomain,
      customColor: customColor,
      customGlyph: customGlyph,
      status: status ?? this.status,
      pausedOn: pausedOn ?? this.pausedOn,
      pauseHistory: pauseHistory,
      priceHistory: priceHistory,
      endedOn: endedOn,
      reminder: reminder ?? this.reminder,
      notes: notes ?? this.notes,
      createdAt: createdAt,
    );
  }

  /// Value equality over every field, so state management notices edits,
  /// pauses and resumes of the same subscription. Use [id] for identity.
  @override
  bool operator ==(Object other) =>
      other is Subscription &&
      other.id == id &&
      other.name == name &&
      other.plan == plan &&
      other.priceMinor == priceMinor &&
      other.currencyCode == currencyCode &&
      other.billingCycle == billingCycle &&
      other.category == category &&
      other.startedOn == startedOn &&
      other.billingAnchor == billingAnchor &&
      other.catalogId == catalogId &&
      other.websiteDomain == websiteDomain &&
      other.customColor == customColor &&
      other.customGlyph == customGlyph &&
      other.status == status &&
      other.pausedOn == pausedOn &&
      listEquals(other.pauseHistory, pauseHistory) &&
      listEquals(other.priceHistory, priceHistory) &&
      other.endedOn == endedOn &&
      other.reminder == reminder &&
      other.notes == notes &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hashAll([
    id,
    name,
    plan,
    priceMinor,
    currencyCode,
    billingCycle,
    category,
    startedOn,
    billingAnchor,
    catalogId,
    websiteDomain,
    customColor,
    customGlyph,
    status,
    pausedOn,
    Object.hashAll(pauseHistory),
    Object.hashAll(priceHistory),
    endedOn,
    reminder,
    notes,
    createdAt,
  ]);

  @override
  String toString() =>
      'Subscription($id, $name, $priceMinor $currencyCode/$billingCycle)';
}
