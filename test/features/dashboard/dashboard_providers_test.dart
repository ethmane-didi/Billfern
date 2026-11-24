import 'package:billfern/features/dashboard/domain/spending_calculator.dart';
import 'package:billfern/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:billfern/shared/data/subscription_repository.dart';
import 'package:billfern/shared/models/subscription.dart';
import 'package:billfern/shared/models/subscription_category.dart';
import 'package:billfern/shared/providers/clock_provider.dart';
import 'package:billfern/shared/providers/subscription_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fixed_clock.dart';

class _FixedRepository implements SubscriptionRepository {
  const _FixedRepository(this.subscriptions);

  final List<Subscription> subscriptions;

  @override
  List<Subscription> fetchAll() => subscriptions;
}

class _DuplicatingRepository implements SubscriptionRepository {
  const _DuplicatingRepository(this.inner);

  final SubscriptionRepository inner;

  @override
  List<Subscription> fetchAll() => [...inner.fetchAll(), ...inner.fetchAll()];
}

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(overrides: fixedClockOverrides);
  });
  tearDown(() => container.dispose());

  test('subscriptions are unique by id and linked to the catalog', () {
    final subs = container.read(subscriptionsProvider);
    expect(subs.map((s) => s.id).toSet(), hasLength(subs.length));
    expect(subs.every((s) => s.catalogId != null), isTrue);
  });

  test('several subscriptions may share a catalog service', () {
    final today = container.read(todayProvider);
    final personal = container
        .read(subscriptionsProvider)
        .firstWhere((s) => s.id == 'notion');
    final business = Subscription(
      id: 'notion-business',
      name: 'Notion',
      plan: 'Business',
      priceCents: 2000,
      billingCycle: personal.billingCycle,
      category: personal.category,
      startedOn: today,
      catalogId: 'notion',
    );
    final shared = ProviderContainer(
      overrides: [
        ...fixedClockOverrides,
        subscriptionRepositoryProvider.overrideWithValue(
          _FixedRepository([personal, business]),
        ),
      ],
    );
    addTearDown(shared.dispose);
    expect(shared.read(subscriptionsProvider), hasLength(2));
    expect(
      shared.read(spendingSummaryProvider).monthlyTotalCents,
      personal.monthlyCostCents + business.monthlyCostCents,
    );
  });

  test('duplicate records from the repository are dropped', () {
    final dupes = ProviderContainer(
      overrides: [
        ...fixedClockOverrides,
        subscriptionRepositoryProvider.overrideWith(
          (ref) => _DuplicatingRepository(
            MockSubscriptionRepository(today: ref.watch(todayProvider)),
          ),
        ),
      ],
    );
    addTearDown(dupes.dispose);
    expect(
      dupes.read(subscriptionsProvider),
      hasLength(container.read(subscriptionsProvider).length),
    );
  });

  group('summary', () {
    test('matches the mock data', () {
      final summary = container.read(spendingSummaryProvider);
      expect(summary.activeCount, 11);
      expect(summary.pausedCount, 1);
      expect(summary.monthlyTotalCents, 12342);
      // Disney+ was paused this month, so last month was higher.
      expect(summary.previousMonthTotalCents, 12342 + 999);
      expect(summary.changePercent, closeTo(-7.49, 0.01));
      expect(summary.projectedYearlyCents, 148104);
    });

    test('monthly total equals the sum of active monthly costs', () {
      final active = container.read(activeSubscriptionsProvider);
      expect(
        container.read(spendingSummaryProvider).monthlyTotalCents,
        active.fold(0, (sum, s) => sum + s.monthlyCostCents),
      );
    });
  });

  test('history ends with the current month and agrees with the summary', () {
    final history = container.read(spendingHistoryProvider);
    final summary = container.read(spendingSummaryProvider);
    expect(history, hasLength(dashboardHistoryMonths));
    expect(history.last.isCurrent, isTrue);
    expect(history.where((m) => m.isCurrent), hasLength(1));
    expect(history.last.month, DateTime(2026, 11));
    expect(history.last.totalCents, summary.monthlyTotalCents);
    expect(
      history[history.length - 2].totalCents,
      summary.previousMonthTotalCents,
    );
  });

  group('category breakdown', () {
    test('slices sum to the monthly total and to 100 percent', () {
      final slices = container.read(categoryBreakdownProvider);
      final summary = container.read(spendingSummaryProvider);
      expect(
        slices.fold(0, (sum, s) => sum + s.totalCents),
        summary.monthlyTotalCents,
      );
      expect(slices.fold(0, (sum, s) => sum + s.percent), 100);
      expect(
        slices.fold(0, (sum, s) => sum + s.subscriptionCount),
        summary.activeCount,
      );
    });

    test('is sorted by amount and groups the tail into Other', () {
      final slices = container.read(categoryBreakdownProvider);
      expect(slices, hasLength(5));
      expect(slices.first.category, SubscriptionCategory.entertainment);
      expect(slices.last.category, isNull);
      expect(slices.last.label, 'Other');
      for (var i = 1; i < slices.length - 1; i++) {
        expect(
          slices[i].totalCents,
          lessThanOrEqualTo(slices[i - 1].totalCents),
        );
      }
    });
  });

  test('wholePercentages always sums to 100', () {
    expect(SpendingCalculator.wholePercentages([1, 1, 1]), [34, 33, 33]);
    expect(SpendingCalculator.wholePercentages([0, 0]), [0, 0]);
    expect(
      SpendingCalculator.wholePercentages([2948, 2499, 2298, 2000, 2597])
          .reduce((a, b) => a + b),
      100,
    );
  });

  test('upcoming renewals are active, sorted and within 30 days', () {
    final renewals = container.read(upcomingRenewalsProvider);
    expect(renewals, isNotEmpty);
    for (var i = 0; i < renewals.length; i++) {
      final renewal = renewals[i];
      expect(renewal.subscription.isActive, isTrue);
      expect(renewal.daysUntil, inInclusiveRange(0, 30));
      if (i > 0) {
        expect(renewal.date.isBefore(renewals[i - 1].date), isFalse);
      }
    }
    expect(
      renewals.map((r) => r.subscription.id),
      isNot(contains('disney-plus')),
    );
  });

  test('due this week sums renewals within seven days', () {
    final expected = container
        .read(upcomingRenewalsProvider)
        .where((r) => r.daysUntil <= 7)
        .fold(0, (sum, r) => sum + r.amountCents);
    expect(container.read(dueThisWeekCentsProvider), expected);
  });

  test('mock AI insight flags overlapping music services', () {
    final insight = container.read(savingsInsightProvider);
    expect(insight, isNotNull);
    expect(insight!.subscriptions.map((s) => s.id), ['spotify', 'apple-music']);
    expect(insight.annualSavingsCents, 13188);
    expect(insight.message, contains(r'$131.88'));
  });

  test('greeting follows the time of day', () {
    expect(container.read(greetingProvider), 'Good morning');
    final evening = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(() => DateTime(2026, 11, 24, 20)),
      ],
    );
    addTearDown(evening.dispose);
    expect(evening.read(greetingProvider), 'Good evening');
  });
}
