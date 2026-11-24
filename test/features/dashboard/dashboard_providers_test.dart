import 'package:billfern/core/money/exchange_rate_repository.dart';
import 'package:billfern/core/money/exchange_rates.dart';
import 'package:billfern/core/money/money.dart';
import 'package:billfern/features/dashboard/domain/dashboard_models.dart';
import 'package:billfern/features/dashboard/domain/spending_calculator.dart';
import 'package:billfern/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:billfern/shared/data/subscription_repository.dart';
import 'package:billfern/shared/models/subscription.dart';
import 'package:billfern/shared/models/subscription_category.dart';
import 'package:billfern/shared/providers/clock_provider.dart';
import 'package:billfern/shared/providers/currency_providers.dart';
import 'package:billfern/shared/providers/subscription_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fixed_clock.dart';

class _DuplicatingRepository implements SubscriptionRepository {
  const _DuplicatingRepository(this.inner);

  final SubscriptionRepository inner;

  @override
  List<Subscription> fetchAll() => [...inner.fetchAll(), ...inner.fetchAll()];

  @override
  Future<void> save(Subscription subscription) => inner.save(subscription);

  @override
  Future<void> delete(String id) => inner.delete(id);
}

ProviderContainer _container([List<Override> overrides = const []]) {
  final container = ProviderContainer(
    overrides: [...appTestOverrides, ...overrides],
  );
  addTearDown(container.dispose);
  return container;
}

/// Asserts the hero, chart and category totals agree.
void _expectConsistent(ProviderContainer c) {
  final summary = c.read(spendingSummaryProvider);
  final history = c.read(spendingHistoryProvider);
  final slices = c.read(categoryBreakdownProvider);
  expect(history.last.total, summary.monthlyTotal);
  expect(history[history.length - 2].total, summary.previousMonthTotal);
  expect(
    Money.sum(slices.map((s) => s.total), summary.currencyCode),
    summary.monthlyTotal,
  );
  expect(slices.fold(0, (sum, s) => sum + s.percent), 100);
}

void main() {
  test('subscriptions are unique by id and linked to the catalog', () {
    final subs = _container().read(subscriptionsProvider);
    expect(subs.map((s) => s.id).toSet(), hasLength(subs.length));
    expect(subs.every((s) => s.catalogId != null), isTrue);
  });

  test('mock data mixes currencies', () {
    final codes = _container()
        .read(subscriptionsProvider)
        .map((s) => s.currencyCode)
        .toSet();
    expect(codes, containsAll(['USD', 'EUR', 'NOK']));
  });

  test('duplicate records from the repository are dropped', () {
    final c = _container([
      subscriptionRepositoryProvider.overrideWith(
        (ref) => _DuplicatingRepository(
          DemoSubscriptionRepository(today: ref.watch(todayProvider)),
        ),
      ),
    ]);
    expect(
      c.read(subscriptionsProvider),
      hasLength(_container().read(subscriptionsProvider).length),
    );
  });

  test('several subscriptions may share a catalog service', () {
    final c0 = _container();
    final personal = c0
        .read(subscriptionsProvider)
        .firstWhere((s) => s.id == 'notion');
    final business = Subscription(
      id: 'notion-business',
      name: 'Notion',
      plan: 'Business',
      priceMinor: 2000,
      currencyCode: 'USD',
      billingCycle: personal.billingCycle,
      category: personal.category,
      startedOn: c0.read(todayProvider),
      catalogId: 'notion',
    );
    final c = _container([
      subscriptionRepositoryProvider.overrideWithValue(
        InMemorySubscriptionRepository([personal, business]),
      ),
    ]);
    expect(c.read(subscriptionsProvider), hasLength(2));
    expect(
      c.read(spendingSummaryProvider).monthlyTotal,
      const Money(3000, 'USD'),
    );
  });

  group('summary in USD (mixed-currency mock data)', () {
    test('matches the mock data converted at mock rates', () {
      final summary = _container().read(spendingSummaryProvider);
      expect(summary.activeCount, 13);
      expect(summary.pausedCount, 1);
      expect(summary.monthlyTotal, const Money(16435, 'USD'));
      // Disney+ was paused this month, so last month was higher.
      expect(summary.previousMonthTotal, const Money(17434, 'USD'));
      expect(summary.change, const Money(-999, 'USD'));
      expect(summary.changePercent, closeTo(-5.73, 0.01));
      expect(summary.projectedYearly, const Money(197224, 'USD'));
      expect(summary.isEstimate, isTrue, reason: 'EUR and NOK converted');
      expect(summary.excludedCount, 0);
    });

    test('totals are consistent across hero, chart and categories', () {
      _expectConsistent(_container());
    });

    test('categories group the tail into Other', () {
      final slices = _container().read(categoryBreakdownProvider);
      expect(slices, hasLength(5));
      expect(slices.first.category, SubscriptionCategory.entertainment);
      expect(slices.first.total, const Money(4791, 'USD'));
      expect(slices.last.category, isNull);
    });
  });

  group('changing the preferred currency', () {
    test('converts every total but never the original prices', () {
      final c = _container();
      final before = {
        for (final s in c.read(subscriptionsProvider)) s.id: s.price,
      };

      c.read(preferredCurrencyProvider.notifier).select('NOK');

      final summary = c.read(spendingSummaryProvider);
      expect(summary.monthlyTotal, const Money(177501, 'NOK'));
      expect(summary.previousMonthTotal, const Money(188290, 'NOK'));
      expect(summary.projectedYearly, const Money(2130024, 'NOK'));
      expect(c.read(dueThisWeekProvider).currencyCode, 'NOK');
      _expectConsistent(c);

      final after = {
        for (final s in c.read(subscriptionsProvider)) s.id: s.price,
      };
      expect(after, before);
    });

    test('same-currency amounts are not converted', () {
      final c = _container();
      c.read(preferredCurrencyProvider.notifier).select('NOK');
      final storytel = c
          .read(upcomingRenewalsProvider)
          .firstWhere((r) => r.subscription.id == 'storytel');
      expect(storytel.amount, const Money(22900, 'NOK'));
      expect(storytel.convertedAmount, const Money(22900, 'NOK'));

      final reading = c
          .read(categoryBreakdownProvider)
          .firstWhere((s) => s.category == SubscriptionCategory.reading);
      expect(reading.total, const Money(22900, 'NOK'));
    });

    test('renewals keep their original currency', () {
      final renewals = _container().read(upcomingRenewalsProvider);
      final viaplay = renewals.firstWhere(
        (r) => r.subscription.id == 'viaplay',
      );
      expect(viaplay.amount, const Money(19900, 'NOK'));
      expect(viaplay.convertedAmount, const Money(1843, 'USD'));
    });
  });

  group('unavailable exchange rates', () {
    final noRates = [
      exchangeRateCacheProvider.overrideWithValue(InMemoryExchangeRateCache()),
    ];

    test('excludes foreign-currency subscriptions and reports them', () {
      final c = _container(noRates);
      expect(c.read(exchangeRatesProvider), isA<RatesUnavailable>());

      final summary = c.read(spendingSummaryProvider);
      // Only USD subscriptions remain: 16435 − Figma(1630) − Viaplay(1843)
      // − Storytel(2120).
      expect(summary.monthlyTotal, const Money(10842, 'USD'));
      expect(summary.excludedCount, 3);
      expect(summary.missingCurrencies, {'EUR', 'NOK'});
      expect(summary.isEstimate, isFalse);
      _expectConsistent(c);

      final viaplay = c
          .read(upcomingRenewalsProvider)
          .firstWhere((r) => r.subscription.id == 'viaplay');
      expect(viaplay.convertedAmount, isNull);
    });

    test('a refresh failure keeps cached rates and flags staleness', () async {
      final c = _container([
        exchangeRateSourceProvider.overrideWithValue(_FailingSource()),
        exchangeRateCacheProvider.overrideWithValue(
          InMemoryExchangeRateCache(
            ExchangeRates(
              baseCurrency: 'USD',
              rates: const {'NOK': 10.8, 'EUR': 0.92},
              asOf: fixedNow.subtract(const Duration(days: 3)),
              source: 'Cached',
            ),
          ),
        ),
      ]);
      await c.read(exchangeRatesProvider.notifier).refresh();
      final state = c.read(exchangeRatesProvider);
      expect(state, isA<RatesAvailable>());
      expect((state as RatesAvailable).isStale, isTrue);
      expect(c.read(moneyConverterProvider).ratesAreStale, isTrue);
      expect(c.read(spendingSummaryProvider).excludedCount, 0);
    });
  });

  test('wholePercentages always sums to 100', () {
    expect(SpendingCalculator.wholePercentages([1, 1, 1]), [34, 33, 33]);
    expect(SpendingCalculator.wholePercentages([0, 0]), [0, 0]);
  });

  test('upcoming renewals are active, sorted and within 30 days', () {
    final renewals = _container().read(upcomingRenewalsProvider);
    expect(renewals, isNotEmpty);
    for (var i = 0; i < renewals.length; i++) {
      expect(renewals[i].subscription.isActive, isTrue);
      expect(renewals[i].daysUntil, inInclusiveRange(0, 30));
      if (i > 0) {
        expect(renewals[i].date.isBefore(renewals[i - 1].date), isFalse);
      }
    }
    expect(
      renewals.map((r) => r.subscription.id),
      isNot(contains('disney-plus')),
    );
  });

  test('due this week sums converted renewals within seven days', () {
    final c = _container();
    final expected = Money.sum([
      for (final r in c.read(upcomingRenewalsProvider))
        if (r.daysUntil <= 7) r.convertedAmount!,
    ], 'USD');
    expect(c.read(dueThisWeekProvider), expected);
    expect(expected, const Money(3648, 'USD'));
  });

  group('mock savings insight', () {
    test('flags overlapping music services in the display currency', () {
      final insight = _container().read(savingsInsightProvider);
      expect(insight, isNotNull);
      expect(insight!.subscriptions.map((s) => s.id), [
        'spotify',
        'apple-music',
      ]);
      expect(insight.annualSavings, const Money(13188, 'USD'));
      expect(insight.isEstimate, isFalse);
    });

    test('converts savings when the display currency differs', () {
      final c = _container();
      c.read(preferredCurrencyProvider.notifier).select('NOK');
      final insight = c.read(savingsInsightProvider)!;
      expect(insight.annualSavings, const Money(142430, 'NOK'));
      expect(insight.isEstimate, isTrue);
    });
  });

  test('greeting follows the time of day', () {
    expect(_container().read(greetingProvider), 'Good morning');
    final evening = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(() => DateTime(2026, 11, 24, 20)),
      ],
    );
    addTearDown(evening.dispose);
    expect(evening.read(greetingProvider), 'Good evening');
  });

  test('ConvertedTotal reports completeness', () {
    const complete = ConvertedTotal(total: Money(1, 'USD'));
    expect(complete.isComplete, isTrue);
  });
}

class _FailingSource implements ExchangeRateSource {
  @override
  Future<ExchangeRates> fetchLatest() => Future.error(StateError('offline'));
}
