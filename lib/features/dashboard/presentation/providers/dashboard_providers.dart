import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/models/subscription.dart';
import '../../../../shared/providers/clock_provider.dart';
import '../../../../shared/providers/subscription_providers.dart';
import '../../domain/dashboard_models.dart';
import '../../domain/savings_insight_engine.dart';
import '../../domain/spending_calculator.dart';

/// Number of months shown in the spending trend chart.
const int dashboardHistoryMonths = 6;

/// Renewals due within this many days count as "due soon" (notification dot).
const int dueSoonDays = 3;

/// Time-of-day greeting, e.g. "Good morning".
final greetingProvider = Provider<String>((ref) {
  final hour = ref.watch(clockProvider)().hour;
  if (hour < 5) return 'Good evening';
  if (hour < 12) return 'Good morning';
  if (hour < 18) return 'Good afternoon';
  return 'Good evening';
});

final spendingSummaryProvider = Provider<SpendingSummary>((ref) {
  return SpendingCalculator.summary(
    ref.watch(subscriptionsProvider),
    ref.watch(todayProvider),
  );
});

final spendingHistoryProvider = Provider<List<MonthlySpend>>((ref) {
  return SpendingCalculator.monthlyHistory(
    ref.watch(subscriptionsProvider),
    ref.watch(todayProvider),
    months: dashboardHistoryMonths,
  );
});

final categoryBreakdownProvider = Provider<List<CategorySpend>>((ref) {
  return SpendingCalculator.categoryBreakdown(ref.watch(subscriptionsProvider));
});

final upcomingRenewalsProvider = Provider<List<UpcomingRenewal>>((ref) {
  return SpendingCalculator.upcomingRenewals(
    ref.watch(subscriptionsProvider),
    ref.watch(todayProvider),
  );
});

/// Renewals due within [dueSoonDays].
final dueSoonRenewalsProvider = Provider<List<UpcomingRenewal>>((ref) {
  return [
    for (final renewal in ref.watch(upcomingRenewalsProvider))
      if (renewal.daysUntil <= dueSoonDays) renewal,
  ];
});

/// Total charged by renewals in the next seven days, in cents.
final dueThisWeekCentsProvider = Provider<int>((ref) {
  return ref
      .watch(upcomingRenewalsProvider)
      .where((renewal) => renewal.daysUntil <= 7)
      .fold(0, (sum, renewal) => sum + renewal.amountCents);
});

/// Number of rows in the dashboard's "Recently added" list.
const int recentlyAddedCount = 4;

/// Most recently started subscriptions, newest first.
final recentlyAddedSubscriptionsProvider = Provider<List<Subscription>>((ref) {
  final subs = [...ref.watch(subscriptionsProvider)]
    ..sort((a, b) {
      final byDate = b.startedOn.compareTo(a.startedOn);
      return byDate != 0 ? byDate : a.name.compareTo(b.name);
    });
  return List.unmodifiable(subs.take(recentlyAddedCount));
});

/// Mock engine today; swap for the OpenAI-backed engine later.
final savingsInsightEngineProvider = Provider<SavingsInsightEngine>(
  (ref) => const MockSavingsInsightEngine(),
);

final savingsInsightProvider = Provider<SavingsInsight?>((ref) {
  return ref
      .watch(savingsInsightEngineProvider)
      .topInsight(ref.watch(subscriptionsProvider));
});
