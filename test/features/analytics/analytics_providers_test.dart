import 'package:billfern/core/money/money.dart';
import 'package:billfern/features/analytics/domain/analytics_models.dart';
import 'package:billfern/features/analytics/presentation/providers/analytics_providers.dart';
import 'package:billfern/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:billfern/shared/data/subscription_repository.dart';
import 'package:billfern/shared/models/billing_cycle.dart';
import 'package:billfern/shared/models/subscription.dart';
import 'package:billfern/shared/models/subscription_category.dart';
import 'package:billfern/shared/providers/currency_providers.dart';
import 'package:billfern/shared/providers/subscription_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fixed_clock.dart';

ProviderContainer _container({
  List<Subscription> seed = const [],
  DataMode mode = DataMode.personal,
}) {
  final container = ProviderContainer(
    overrides: [
      ...baseTestOverrides,
      ...preferenceOverrides(mode: mode),
      personalSubscriptionRepositoryProvider.overrideWithValue(
        InMemorySubscriptionRepository(seed),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Subscription _sub(
  String id,
  int priceMinor, {
  DateTime? startedOn,
  String currency = 'USD',
}) => Subscription(
  id: id,
  name: id,
  plan: '',
  priceMinor: priceMinor,
  currencyCode: currency,
  billingCycle: BillingCycle.monthly,
  category: SubscriptionCategory.productivity,
  startedOn: startedOn ?? DateTime(2026, 1, 1),
);

/// Dashboard and Analytics show the same figures.
void _expectConsistent(ProviderContainer c) {
  final summary = c.read(spendingSummaryProvider);
  final overview = c.read(analyticsOverviewProvider);
  final trend6 = c.read(spendingTrendForPeriodProvider(TrendPeriod.sixMonths));
  final history = c.read(spendingHistoryProvider);
  final categories = c.read(categoryBreakdownProvider);

  expect(overview.summary.monthlyTotal, summary.monthlyTotal);
  expect(trend6.points.last.estimated, summary.monthlyTotal);
  for (var i = 0; i < history.length; i++) {
    final point = trend6.points[i];
    if (point.hasData) expect(point.estimated, history[i].total);
  }
  if (categories.isNotEmpty) {
    expect(
      Money.sum(categories.map((s) => s.total), summary.currencyCode),
      summary.monthlyTotal,
    );
    expect(categories.fold(0, (sum, s) => sum + s.percent), 100);
  }
  for (final slice in categories) {
    final members = c.read(categoryMembersProvider(slice.category));
    expect(members, hasLength(slice.subscriptionCount));
    expect(
      Money.sum(members.map((m) => m.monthly), summary.currencyCode),
      slice.total,
    );
  }
  expect(
    c.read(upcomingPaymentsProvider).first.total.total,
    c.read(dueThisWeekProvider),
  );
  expect(
    c.read(yearlySpendingSummaryProvider).projectedNext12Months,
    summary.projectedYearly,
  );
}

void main() {
  test('sample data: Analytics agrees with the dashboard', () {
    final c = _container(mode: DataMode.sample);
    _expectConsistent(c);
    final trend = c.read(spendingTrendProvider);
    expect(trend.period, TrendPeriod.sixMonths);
    expect(trend.hasEnoughHistory, isTrue);
    expect(trend.isEstimate, isTrue); // EUR and NOK converted to USD
    expect(c.read(smartSuggestionsProvider).isEmpty, isFalse);
  });

  test('updates after add, edit, pause, resume, delete and currency', () async {
    final c = _container(seed: [_sub('a', 1000)]);
    final notifier = c.read(subscriptionsProvider.notifier);
    Money current() => c.read(spendingTrendProvider).points.last.estimated!;

    expect(current(), const Money(1000, 'USD'));

    await notifier.add(_sub('b', 500, startedOn: fixedNow));
    expect(current(), const Money(1500, 'USD'));
    _expectConsistent(c);

    await notifier.update(notifier.byId('a')!.copyWith(priceMinor: 2000));
    expect(current(), const Money(2500, 'USD'));
    // Last month keeps the old price.
    expect(
      c.read(spendingTrendProvider).points[4].estimated,
      const Money(1000, 'USD'),
    );
    expect(notifier.byId('a')!.priceHistory, hasLength(1));

    await notifier.pause('a');
    expect(current(), const Money(500, 'USD'));
    expect(
      c
          .read(upcomingPaymentsProvider)
          .last
          .payments
          .map((p) => p.subscription.id),
      isNot(contains('a')),
    );

    await notifier.resume('a');
    expect(current(), const Money(2500, 'USD'));

    await notifier.delete('a');
    expect(current(), const Money(500, 'USD'));
    expect(c.read(subscriptionsProvider).map((s) => s.id), ['b']);
    expect(c.read(endedSubscriptionsProvider).single.id, 'a');
    // October still includes the removed subscription.
    expect(
      c.read(spendingTrendProvider).points[4].estimated,
      const Money(1000, 'USD'),
    );
    expect(c.read(spendingSummaryProvider).previousMonthTotal.minorUnits, 1000);
    _expectConsistent(c);

    c.read(preferredCurrencyProvider.notifier).select('NOK');
    expect(current(), const Money(5400, 'NOK'));
    _expectConsistent(c);
  });

  test('deleting a subscription added this month leaves no history', () async {
    final c = _container();
    final notifier = c.read(subscriptionsProvider.notifier);
    await notifier.add(_sub('new', 1000, startedOn: fixedNow));
    await notifier.delete('new');
    expect(c.read(subscriptionHistoryProvider), isEmpty);
    expect(c.read(hasAnalyticsDataProvider), isFalse);
  });

  test('a new personal user has no invented history', () async {
    final c = _container();
    expect(c.read(hasAnalyticsDataProvider), isFalse);
    await c
        .read(subscriptionsProvider.notifier)
        .add(_sub('first', 1000, startedOn: fixedNow));
    final trend = c.read(spendingTrendProvider);
    expect(trend.monthsWithData, 1);
    expect(trend.hasEnoughHistory, isFalse);
    expect(trend.points.take(5).every((p) => p.estimated == null), isTrue);
    expect(
      c.read(analyticsOverviewProvider).monthOverMonth.kind,
      ComparisonKind.noBaseline,
    );
  });

  test('sample data stays isolated from personal data', () async {
    final personal = InMemorySubscriptionRepository([_sub('mine', 1000)]);
    final c = ProviderContainer(
      overrides: [
        ...baseTestOverrides,
        ...preferenceOverrides(mode: DataMode.sample),
        personalSubscriptionRepositoryProvider.overrideWithValue(personal),
      ],
    );
    addTearDown(c.dispose);

    final sampleIds = c.read(subscriptionHistoryProvider).map((s) => s.id);
    expect(sampleIds, isNot(contains('mine')));
    expect(sampleIds, contains('netflix'));

    // Deleting sample data never touches the personal repository.
    await c.read(subscriptionsProvider.notifier).delete('netflix');
    expect(personal.fetchAll().single.id, 'mine');
    expect(personal.fetchEnded(), isEmpty);

    await c.read(dataModeProvider.notifier).set(DataMode.personal);
    expect(c.read(subscriptionHistoryProvider).map((s) => s.id), ['mine']);
    expect(c.read(smartSuggestionsProvider).isEmpty, isTrue);
  });
}
