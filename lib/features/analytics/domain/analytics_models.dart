import 'package:flutter/foundation.dart';

import '../../../core/money/money.dart';
import '../../../shared/models/subscription.dart';
import '../../../shared/models/subscription_category.dart';
import '../../dashboard/domain/dashboard_models.dart';

/// Length of the spending trend window.
enum TrendPeriod {
  threeMonths(3, '3M', '3 months'),
  sixMonths(6, '6M', '6 months'),
  twelveMonths(12, '12M', '12 months');

  const TrendPeriod(this.months, this.shortLabel, this.label);

  final int months;
  final String shortLabel;
  final String label;
}

/// How a figure compares with its baseline.
enum ComparisonKind {
  /// No earlier data to compare with (tracking started later).
  noBaseline,

  /// The baseline was zero and spending is now above zero; a percentage
  /// would be meaningless.
  fromZero,
  increase,
  decrease,
  unchanged,
}

/// [current] compared with [previous]. [previous] is `null` when there is
/// no recorded history for the baseline.
@immutable
class PeriodComparison {
  const PeriodComparison._(this.current, this.previous, this.kind);

  factory PeriodComparison.between(Money current, Money? previous) {
    if (previous == null) {
      return PeriodComparison._(current, null, ComparisonKind.noBaseline);
    }
    final diff = current.minorUnits - previous.minorUnits;
    final kind = switch (diff) {
      0 => ComparisonKind.unchanged,
      _ when previous.isZero => ComparisonKind.fromZero,
      > 0 => ComparisonKind.increase,
      _ => ComparisonKind.decrease,
    };
    return PeriodComparison._(current, previous, kind);
  }

  final Money current;
  final Money? previous;
  final ComparisonKind kind;

  /// `current - previous`, or `null` without a baseline.
  Money? get change {
    final previous = this.previous;
    return previous == null ? null : current - previous;
  }

  /// Change in percent, or `null` when there is no baseline or the baseline
  /// is zero (division by zero is never shown as a percentage).
  double? get percent {
    final previous = this.previous;
    if (previous == null || previous.isZero) return null;
    return (current.minorUnits - previous.minorUnits) /
        previous.minorUnits *
        100;
  }
}

/// Estimated spending for one calendar month.
@immutable
class TrendPoint {
  const TrendPoint({
    required this.month,
    required this.estimated,
    required this.confirmed,
    required this.billedCount,
    required this.isCurrent,
  });

  /// First day of the month.
  final DateTime month;

  /// Estimated spending, or `null` for months before tracking began, which
  /// have **no data** (never shown as zero spending).
  final Money? estimated;

  /// Sum of confirmed payments recorded for the month (zero until payment
  /// records exist).
  final Money confirmed;

  /// Subscriptions counted in [estimated].
  final int billedCount;

  final bool isCurrent;

  bool get hasData => estimated != null;
}

/// The spending trend over a [TrendPeriod].
@immutable
class SpendingTrend {
  const SpendingTrend({
    required this.period,
    required this.points,
    required this.periodTotal,
    required this.periodComparison,
    required this.trackingSince,
    this.isEstimate = false,
    this.excludedCount = 0,
    this.missingCurrencies = const {},
  });

  final TrendPeriod period;

  /// One point per month, oldest first, ending with the current month.
  final List<TrendPoint> points;

  /// Estimated total over the months that have data.
  final Money periodTotal;

  /// [periodTotal] versus the preceding period of the same length; no
  /// baseline unless that whole period has recorded history.
  final PeriodComparison periodComparison;

  /// Start of the earliest recorded subscription, or `null` without data.
  final DateTime? trackingSince;

  /// Whether any amount was converted from another currency.
  final bool isEstimate;

  /// Most subscriptions left out of any month for lack of a rate.
  final int excludedCount;
  final Set<String> missingCurrencies;

  List<TrendPoint> get pointsWithData => [
    for (final point in points)
      if (point.hasData) point,
  ];

  int get monthsWithData => pointsWithData.length;

  /// A trend needs at least two months of recorded history.
  bool get hasEnoughHistory => monthsWithData >= 2;

  /// Average over the months with data, or `null` without any.
  Money? get monthlyAverage =>
      monthsWithData == 0 ? null : periodTotal.divideRounded(monthsWithData);

  /// The month with the highest estimated spending.
  TrendPoint? get highest {
    TrendPoint? best;
    for (final point in pointsWithData) {
      if (best == null || point.estimated!.compareTo(best.estimated!) > 0) {
        best = point;
      }
    }
    return best;
  }

  /// [points][index] versus the month before it, when both have data.
  PeriodComparison monthComparison(int index) {
    final point = points[index];
    final previous = index > 0 ? points[index - 1].estimated : null;
    return PeriodComparison.between(
      point.estimated ?? Money.zero(periodTotal.currencyCode),
      previous,
    );
  }
}

/// Current month figures plus a month-over-month comparison that knows
/// whether last month has any recorded history.
@immutable
class AnalyticsOverview {
  const AnalyticsOverview({
    required this.summary,
    required this.monthOverMonth,
  });

  /// The dashboard's figures, so both screens always agree.
  final SpendingSummary summary;
  final PeriodComparison monthOverMonth;
}

/// Calendar-year and forward-looking yearly figures.
@immutable
class YearlySpendingSummary {
  const YearlySpendingSummary({
    required this.year,
    required this.yearToDate,
    required this.monthsCounted,
    required this.throughMonth,
    required this.projectedNext12Months,
    required this.isEstimate,
  });

  final int year;

  /// Estimated spending from January (or the first tracked month) through
  /// the current month.
  final Money yearToDate;

  /// Months of [year] that have recorded history.
  final int monthsCounted;

  /// The current month (1–12); [yearToDate] runs through it.
  final int throughMonth;

  /// Twelve-month cost of the currently active subscriptions (projected).
  final Money projectedNext12Months;

  final bool isEstimate;

  /// Whether tracking began after January, so [yearToDate] covers only
  /// part of the year.
  bool get isPartialYear => monthsCounted < throughMonth;
}

/// Projected payments within the next [days] days.
@immutable
class UpcomingPaymentsWindow {
  const UpcomingPaymentsWindow({
    required this.days,
    required this.payments,
    required this.total,
  });

  final int days;

  /// Every expected payment, soonest first.
  final List<ProjectedPayment> payments;

  /// Combined cost in the display currency (projected).
  final ConvertedTotal total;

  int get count => payments.length;
}

/// A subscription contributing to a category slice.
@immutable
class CategoryMember {
  const CategoryMember({required this.subscription, required this.monthly});

  final Subscription subscription;

  /// Monthly-equivalent cost in the display currency.
  final Money monthly;
}

/// Kinds of rule-based suggestions.
enum SuggestionKind {
  /// The same service tracked more than once.
  duplicateService,

  /// Several services in a category where people often need only one
  /// (music, video streaming, cloud storage).
  overlappingServices,

  /// A yearly (or longer) plan renewing soon.
  annualRenewal,

  /// The subscription taking the largest share of monthly spending.
  largestSubscription,
}

/// A local, rule-based savings suggestion. It describes the user's
/// subscription list only: Billfern has no usage data, so a suggestion never
/// claims something is unused or unnecessary.
@immutable
class SmartSuggestion {
  const SmartSuggestion({
    required this.kind,
    required this.subscriptions,
    required this.cancel,
    required this.monthlySavings,
    required this.yearlySavings,
    required this.isEstimate,
    this.keep,
    this.category,
    this.date,
    this.sharePercent,
  });

  final SuggestionKind kind;

  /// Every subscription the suggestion is about, most expensive first.
  final List<Subscription> subscriptions;

  /// Subscriptions whose cancellation the savings figures assume.
  final List<Subscription> cancel;

  /// The subscription kept in the savings estimate (overlaps only).
  final Subscription? keep;

  final SubscriptionCategory? category;

  /// Renewal date ([SuggestionKind.annualRenewal]).
  final DateTime? date;

  /// Share of monthly spending ([SuggestionKind.largestSubscription]).
  final int? sharePercent;

  /// Potential savings from cancelling [cancel], in the display currency.
  final Money monthlySavings;
  final Money yearlySavings;

  /// Whether the savings include converted amounts.
  final bool isEstimate;
}

/// All suggestions plus the combined potential savings.
@immutable
class SmartSuggestions {
  const SmartSuggestions({
    required this.items,
    required this.monthlyPotential,
    required this.yearlyPotential,
    required this.isEstimate,
  });

  final List<SmartSuggestion> items;

  /// Savings if every suggested cancellation happened, counting each
  /// subscription once.
  final Money monthlyPotential;
  final Money yearlyPotential;
  final bool isEstimate;

  bool get isEmpty => items.isEmpty;
}
