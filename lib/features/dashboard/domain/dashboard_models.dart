import 'package:flutter/painting.dart';
import 'package:flutter/foundation.dart';

import '../../../core/money/money.dart';
import '../../../core/theme/theme.dart';
import '../../../shared/models/subscription.dart';
import '../../../shared/models/subscription_category.dart';

/// A sum of amounts converted into one display currency.
@immutable
class ConvertedTotal {
  const ConvertedTotal({
    required this.total,
    this.missingCurrencies = const {},
    this.excludedCount = 0,
    this.isConverted = false,
  });

  /// Sum of everything that could be converted, in the display currency.
  final Money total;

  /// Currencies that had no exchange rate.
  final Set<String> missingCurrencies;

  /// Number of items left out because their currency had no rate.
  final int excludedCount;

  /// Whether any amount was converted from another currency (an estimate).
  final bool isConverted;

  bool get isComplete => excludedCount == 0;
}

/// Headline figures for the current month, in the display currency.
@immutable
class SpendingSummary {
  const SpendingSummary({
    required this.monthlyTotal,
    required this.previousMonthTotal,
    required this.projectedYearly,
    required this.activeCount,
    required this.pausedCount,
    this.isEstimate = false,
    this.excludedCount = 0,
    this.missingCurrencies = const {},
  });

  final Money monthlyTotal;
  final Money previousMonthTotal;

  /// Twelve-month cost of the currently active subscriptions.
  final Money projectedYearly;

  final int activeCount;
  final int pausedCount;

  /// Whether totals include amounts converted from other currencies.
  final bool isEstimate;

  /// Active subscriptions left out of totals because no rate was available.
  final int excludedCount;
  final Set<String> missingCurrencies;

  String get currencyCode => monthlyTotal.currencyCode;

  Money get change => monthlyTotal - previousMonthTotal;

  /// Change versus last month in percent; 0 when there is no baseline.
  double get changePercent => previousMonthTotal.isZero
      ? 0
      : change.minorUnits / previousMonthTotal.minorUnits * 100;
}

/// Spending for one calendar month, in the display currency.
@immutable
class MonthlySpend {
  const MonthlySpend({
    required this.month,
    required this.total,
    required this.isCurrent,
  });

  /// First day of the month.
  final DateTime month;
  final Money total;
  final bool isCurrent;
}

/// One slice of the category breakdown. [category] is `null` for the
/// aggregated "Other" slice.
@immutable
class CategorySpend {
  const CategorySpend({
    required this.category,
    required this.total,
    required this.percent,
    required this.subscriptionCount,
  });

  final SubscriptionCategory? category;

  /// Monthly spend in the display currency.
  final Money total;

  /// Whole-number share of the monthly total. Shares across a breakdown
  /// always sum to exactly 100.
  final int percent;

  final int subscriptionCount;

  String get label => category?.label ?? 'Other';
  Color get color => category?.color ?? AppColors.chartOther;
}

/// A subscription's next billing date relative to today.
@immutable
class UpcomingRenewal {
  const UpcomingRenewal({
    required this.subscription,
    required this.date,
    required this.daysUntil,
    required this.convertedAmount,
  });

  final Subscription subscription;
  final DateTime date;
  final int daysUntil;

  /// Amount charged on [date], in the subscription's own currency.
  Money get amount => subscription.price;

  /// [amount] in the display currency, or `null` when no rate is available.
  final Money? convertedAmount;
}

/// One expected future payment (a **projection**, not a confirmed charge).
@immutable
class ProjectedPayment {
  const ProjectedPayment({
    required this.subscription,
    required this.date,
    required this.daysUntil,
    required this.convertedAmount,
  });

  final Subscription subscription;
  final DateTime date;
  final int daysUntil;

  /// Amount charged on [date], in the subscription's own currency.
  Money get amount => subscription.price;

  /// [amount] in the display currency, or `null` when no rate is available.
  final Money? convertedAmount;
}

/// A savings recommendation shown in the smart tip card. Presentation
/// builds the wording, so amounts are formatted in the user's locale.
@immutable
class SavingsInsight {
  const SavingsInsight({
    required this.category,
    required this.keep,
    required this.cancel,
    required this.annualSavings,
    required this.isEstimate,
  });

  final SubscriptionCategory category;

  /// The service worth keeping (the most expensive overlap).
  final Subscription keep;

  /// Overlapping services that could be cancelled.
  final List<Subscription> cancel;

  /// Yearly savings from cancelling [cancel], in the display currency.
  final Money annualSavings;

  /// Whether [annualSavings] includes converted amounts.
  final bool isEstimate;

  /// All subscriptions involved, most expensive first.
  List<Subscription> get subscriptions => [keep, ...cancel];

  String get title => 'Overlapping ${category.label.toLowerCase()} services';
}
