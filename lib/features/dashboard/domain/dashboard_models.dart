import 'package:flutter/painting.dart';
import 'package:flutter/foundation.dart';

import '../../../core/theme/theme.dart';
import '../../../shared/models/subscription.dart';
import '../../../shared/models/subscription_category.dart';

/// Headline figures for the current month. All amounts are in cents.
@immutable
class SpendingSummary {
  const SpendingSummary({
    required this.monthlyTotalCents,
    required this.previousMonthTotalCents,
    required this.projectedYearlyCents,
    required this.activeCount,
    required this.pausedCount,
  });

  final int monthlyTotalCents;
  final int previousMonthTotalCents;

  /// Twelve-month cost of the currently active subscriptions.
  final int projectedYearlyCents;

  final int activeCount;
  final int pausedCount;

  int get changeCents => monthlyTotalCents - previousMonthTotalCents;

  /// Change versus last month in percent; 0 when there is no baseline.
  double get changePercent => previousMonthTotalCents == 0
      ? 0
      : changeCents / previousMonthTotalCents * 100;
}

/// Spending for one calendar month.
@immutable
class MonthlySpend {
  const MonthlySpend({
    required this.month,
    required this.totalCents,
    required this.isCurrent,
  });

  /// First day of the month.
  final DateTime month;
  final int totalCents;
  final bool isCurrent;
}

/// One slice of the category breakdown. [category] is `null` for the
/// aggregated "Other" slice.
@immutable
class CategorySpend {
  const CategorySpend({
    required this.category,
    required this.totalCents,
    required this.percent,
    required this.subscriptionCount,
  });

  final SubscriptionCategory? category;
  final int totalCents;

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
  });

  final Subscription subscription;
  final DateTime date;
  final int daysUntil;

  /// Amount charged on [date], in cents.
  int get amountCents => subscription.priceCents;
}

/// A savings recommendation shown in the AI insight card.
@immutable
class SavingsInsight {
  const SavingsInsight({
    required this.title,
    required this.message,
    required this.annualSavingsCents,
    required this.subscriptions,
  });

  final String title;
  final String message;
  final int annualSavingsCents;

  /// Subscriptions the insight is about, most relevant first.
  final List<Subscription> subscriptions;
}
