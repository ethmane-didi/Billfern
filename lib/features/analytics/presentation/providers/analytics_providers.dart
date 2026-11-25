import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/models/subscription_category.dart';
import '../../../../shared/providers/clock_provider.dart';
import '../../../../shared/providers/currency_providers.dart';
import '../../../../shared/providers/subscription_providers.dart';
import '../../../dashboard/presentation/providers/dashboard_providers.dart';
import '../../domain/analytics_calculator.dart';
import '../../domain/analytics_models.dart';
import '../../domain/payment_record.dart';
import '../../domain/smart_suggestion_engine.dart';

// Every provider here derives from `subscriptionsProvider` /
// `subscriptionHistoryProvider` and `moneyConverterProvider`, so Analytics
// updates after any add, edit, pause, resume, delete or currency change.

/// Confirmed payments. None exist until manual confirmation or bank sync is
/// built; override this provider then.
final paymentRecordRepositoryProvider = Provider<PaymentRecordRepository>(
  (ref) => const NoPaymentRecordRepository(),
);

final paymentRecordsProvider = Provider<List<PaymentRecord>>(
  (ref) => ref.watch(paymentRecordRepositoryProvider).fetchAll(),
);

/// Selected trend window (3, 6 or 12 months).
class TrendPeriodNotifier extends Notifier<TrendPeriod> {
  @override
  TrendPeriod build() => TrendPeriod.sixMonths;

  void select(TrendPeriod period) => state = period;
}

final trendPeriodProvider = NotifierProvider<TrendPeriodNotifier, TrendPeriod>(
  TrendPeriodNotifier.new,
);

/// Whether there is anything to analyse (current or removed subscriptions).
final hasAnalyticsDataProvider = Provider<bool>(
  (ref) => ref.watch(subscriptionHistoryProvider).isNotEmpty,
);

/// Current month and month-over-month comparison, built on the dashboard's
/// [spendingSummaryProvider] so both screens show the same figures.
final analyticsOverviewProvider = Provider<AnalyticsOverview>((ref) {
  return AnalyticsCalculator.overview(
    ref.watch(subscriptionHistoryProvider),
    ref.watch(todayProvider),
    ref.watch(spendingSummaryProvider),
  );
});

/// Estimated spending trend for any window.
final spendingTrendForPeriodProvider =
    Provider.family<SpendingTrend, TrendPeriod>((ref, period) {
      return AnalyticsCalculator.trend(
        ref.watch(subscriptionHistoryProvider),
        ref.watch(todayProvider),
        ref.watch(moneyConverterProvider),
        period,
        payments: ref.watch(paymentRecordsProvider),
      );
    });

/// Trend for the selected [trendPeriodProvider] window.
final spendingTrendProvider = Provider<SpendingTrend>((ref) {
  return ref.watch(
    spendingTrendForPeriodProvider(ref.watch(trendPeriodProvider)),
  );
});

final yearlySpendingSummaryProvider = Provider<YearlySpendingSummary>((ref) {
  return AnalyticsCalculator.yearly(
    ref.watch(subscriptionHistoryProvider),
    ref.watch(todayProvider),
    ref.watch(moneyConverterProvider),
    ref.watch(spendingSummaryProvider),
  );
});

/// Projected payments for the next 7, 30 and 90 days.
final upcomingPaymentsProvider = Provider<List<UpcomingPaymentsWindow>>((ref) {
  return AnalyticsCalculator.upcoming(
    ref.watch(subscriptionsProvider),
    ref.watch(todayProvider),
    ref.watch(moneyConverterProvider),
  );
});

/// Subscriptions behind one slice of the dashboard's category breakdown
/// (`null` = "Other").
final categoryMembersProvider =
    Provider.family<List<CategoryMember>, SubscriptionCategory?>((
      ref,
      category,
    ) {
      return AnalyticsCalculator.categoryMembers(
        ref.watch(subscriptionsProvider),
        ref.watch(categoryBreakdownProvider),
        category,
        ref.watch(moneyConverterProvider),
      );
    });

/// Rule-based today; an AI-backed engine can replace it in a later phase.
final smartSuggestionEngineProvider = Provider<SmartSuggestionEngine>(
  (ref) => const RuleBasedSuggestionEngine(),
);

final smartSuggestionsProvider = Provider<SmartSuggestions>((ref) {
  return ref
      .watch(smartSuggestionEngineProvider)
      .suggest(
        ref.watch(subscriptionsProvider),
        ref.watch(todayProvider),
        ref.watch(moneyConverterProvider),
      );
});
