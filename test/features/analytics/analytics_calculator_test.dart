import 'package:billfern/core/money/currency_converter.dart';
import 'package:billfern/core/money/exchange_rate_repository.dart';
import 'package:billfern/core/money/exchange_rates.dart';
import 'package:billfern/core/money/money.dart';
import 'package:billfern/features/analytics/domain/analytics_calculator.dart';
import 'package:billfern/features/analytics/domain/analytics_models.dart';
import 'package:billfern/features/analytics/domain/payment_record.dart';
import 'package:billfern/features/dashboard/domain/spending_calculator.dart';
import 'package:billfern/shared/models/billing_cycle.dart';
import 'package:billfern/shared/models/subscription.dart';
import 'package:billfern/shared/models/subscription_category.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime today = DateTime(2026, 11, 24);

MoneyConverter _converter({String target = 'USD', ExchangeRateState? state}) =>
    MoneyConverter(
      targetCurrency: target,
      rateState:
          state ??
          RatesAvailable(MockExchangeRateSource(asOf: today).snapshot()),
    );

Subscription _sub(
  String id,
  int priceMinor, {
  String currency = 'USD',
  BillingCycle cycle = BillingCycle.monthly,
  SubscriptionCategory category = SubscriptionCategory.productivity,
  DateTime? startedOn,
  DateTime? anchor,
  String? catalogId,
  List<PriceRevision> priceHistory = const [],
  DateTime? pausedOn,
  List<PausePeriod> pauseHistory = const [],
  DateTime? endedOn,
}) => Subscription(
  id: id,
  name: id,
  plan: '',
  priceMinor: priceMinor,
  currencyCode: currency,
  billingCycle: cycle,
  category: category,
  startedOn: startedOn ?? DateTime(2026, 1, 1),
  billingAnchor: anchor,
  catalogId: catalogId,
  priceHistory: priceHistory,
  status: pausedOn == null
      ? SubscriptionStatus.active
      : SubscriptionStatus.paused,
  pausedOn: pausedOn,
  pauseHistory: pauseHistory,
  endedOn: endedOn,
);

Money usd(int minor) => Money(minor, 'USD');

SpendingTrend _trend(
  List<Subscription> subs, {
  TrendPeriod period = TrendPeriod.sixMonths,
  MoneyConverter? converter,
}) => AnalyticsCalculator.trend(subs, today, converter ?? _converter(), period);

Money? _month(SpendingTrend trend, int month) =>
    trend.points.firstWhere((p) => p.month.month == month).estimated;

void main() {
  group('monthly and yearly totals', () {
    test('sums each month and the period, with an average', () {
      final trend = _trend([_sub('a', 1000), _sub('b', 500)]);
      expect(trend.points, hasLength(6));
      expect(trend.points.last.isCurrent, isTrue);
      expect(trend.points.first.month, DateTime(2026, 6));
      for (final point in trend.points) {
        expect(point.estimated, usd(1500));
        expect(point.billedCount, 2);
      }
      expect(trend.periodTotal, usd(9000));
      expect(trend.monthlyAverage, usd(1500));
      expect(trend.highest!.estimated, usd(1500));
      expect(trend.isEstimate, isFalse);
    });

    test('yearly cycles count their monthly equivalent', () {
      final trend = _trend([_sub('y', 12000, cycle: BillingCycle.yearly)]);
      expect(trend.points.last.estimated, usd(1000));
    });

    test('year to date is estimated; next 12 months are projected', () {
      final subs = [_sub('a', 1000, startedOn: DateTime(2026, 8, 10))];
      final converter = _converter();
      final summary = SpendingCalculator.summary(subs, today, converter);
      final yearly = AnalyticsCalculator.yearly(
        subs,
        today,
        converter,
        summary,
      );
      expect(yearly.year, 2026);
      expect(yearly.yearToDate, usd(4000)); // Aug–Nov
      expect(yearly.monthsCounted, 4);
      expect(yearly.isPartialYear, isTrue);
      expect(yearly.projectedNext12Months, usd(12000));
      expect(yearly.projectedNext12Months, summary.projectedYearly);
    });
  });

  group('history is never invented', () {
    test('months before tracking began have no data, not zero', () {
      final trend = _trend([_sub('a', 1000, startedOn: DateTime(2026, 9, 15))]);
      expect(_month(trend, 6), isNull);
      expect(_month(trend, 8), isNull);
      expect(_month(trend, 9), usd(1000));
      expect(trend.monthsWithData, 3);
      expect(trend.periodTotal, usd(3000));
      expect(trend.monthlyAverage, usd(1000));
      expect(trend.trackingSince, DateTime(2026, 9, 15));
    });

    test('a single tracked month is insufficient history', () {
      final trend = _trend([_sub('a', 1000, startedOn: today)]);
      expect(trend.monthsWithData, 1);
      expect(trend.hasEnoughHistory, isFalse);
      expect(trend.periodComparison.kind, ComparisonKind.noBaseline);
    });

    test('no subscriptions means no data at all', () {
      final trend = _trend(const []);
      expect(trend.monthsWithData, 0);
      expect(trend.monthlyAverage, isNull);
      expect(trend.trackingSince, isNull);
      expect(trend.points.every((p) => p.estimated == null), isTrue);
    });

    test('confirmed spending stays zero until payments are recorded', () {
      final trend = _trend([_sub('a', 1000)]);
      expect(trend.points.every((p) => p.confirmed.isZero), isTrue);
    });

    test('recorded payments are reported as confirmed', () {
      final trend = AnalyticsCalculator.trend(
        [_sub('a', 1000)],
        today,
        _converter(),
        TrendPeriod.threeMonths,
        payments: [
          PaymentRecord(
            id: 'p1',
            subscriptionId: 'a',
            paidOn: DateTime(2026, 10, 3),
            amount: const Money(10800, 'NOK'),
            source: PaymentRecordSource.manual,
          ),
        ],
      );
      expect(trend.points[1].confirmed, usd(1000));
      expect(trend.points[2].confirmed.isZero, isTrue);
    });
  });

  group('period comparisons', () {
    test('compares with the preceding period when it has history', () {
      final subs = [
        _sub(
          'a',
          1200,
          priceHistory: [
            PriceRevision(
              until: DateTime(2026, 9, 1),
              priceMinor: 1000,
              currencyCode: 'USD',
              billingCycle: BillingCycle.monthly,
            ),
          ],
        ),
      ];
      // Sep–Nov at 12.00 versus Jun–Aug at 10.00.
      final trend = _trend(subs, period: TrendPeriod.threeMonths);
      expect(trend.periodTotal, usd(3600));
      expect(trend.periodComparison.previous, usd(3000));
      expect(trend.periodComparison.kind, ComparisonKind.increase);
      expect(trend.periodComparison.percent, closeTo(20, 0.001));
    });

    test('no baseline when the preceding period predates tracking', () {
      final trend = _trend([_sub('a', 1000)], period: TrendPeriod.twelveMonths);
      expect(trend.periodComparison.kind, ComparisonKind.noBaseline);
      expect(trend.periodComparison.percent, isNull);
      expect(trend.periodComparison.change, isNull);
    });

    test('against a zero month there is no percentage', () {
      // Paused for all of October, resumed in November.
      final subs = [
        _sub(
          'a',
          1000,
          pauseHistory: [
            PausePeriod(
              from: DateTime(2026, 10, 1),
              until: DateTime(2026, 11, 2),
            ),
          ],
        ),
      ];
      final converter = _converter();
      final summary = SpendingCalculator.summary(subs, today, converter);
      final overview = AnalyticsCalculator.overview(subs, today, summary);
      expect(summary.previousMonthTotal.isZero, isTrue);
      expect(overview.monthOverMonth.kind, ComparisonKind.fromZero);
      expect(overview.monthOverMonth.percent, isNull);
      expect(overview.monthOverMonth.change, usd(1000));
    });

    test('decreases, unchanged and month-by-month comparisons', () {
      expect(
        PeriodComparison.between(usd(800), usd(1000)).percent,
        closeTo(-20, 0.001),
      );
      expect(
        PeriodComparison.between(usd(800), usd(1000)).kind,
        ComparisonKind.decrease,
      );
      expect(
        PeriodComparison.between(usd(0), usd(0)).kind,
        ComparisonKind.unchanged,
      );
      final trend = _trend([_sub('a', 1000, startedOn: DateTime(2026, 10, 2))]);
      expect(trend.monthComparison(4).kind, ComparisonKind.noBaseline); // Oct
      expect(trend.monthComparison(5).kind, ComparisonKind.unchanged); // Nov
    });

    test('this month versus last month has no baseline for new users', () {
      final subs = [_sub('a', 1000, startedOn: today)];
      final summary = SpendingCalculator.summary(subs, today, _converter());
      final overview = AnalyticsCalculator.overview(subs, today, summary);
      expect(overview.monthOverMonth.kind, ComparisonKind.noBaseline);
    });
  });

  group('historical revisions', () {
    test('price changes never rewrite earlier months', () {
      final sub = _sub(
        'a',
        1500,
        priceHistory: [
          PriceRevision(
            until: DateTime(2026, 7, 10),
            priceMinor: 800,
            currencyCode: 'USD',
            billingCycle: BillingCycle.monthly,
          ),
        ],
      );
      final trend = _trend([sub]);
      expect(_month(trend, 6), usd(800));
      expect(_month(trend, 7), usd(1500));
      expect(_month(trend, 11), usd(1500));
    });

    test('billing-cycle and currency changes keep their old terms', () {
      final sub = _sub(
        'a',
        1500,
        priceHistory: [
          PriceRevision(
            until: DateTime(2026, 8, 5),
            priceMinor: 12000,
            currencyCode: 'USD',
            billingCycle: BillingCycle.yearly,
          ),
          PriceRevision(
            until: DateTime(2026, 10, 1),
            priceMinor: 10800,
            currencyCode: 'NOK',
            billingCycle: BillingCycle.monthly,
          ),
        ],
      );
      final trend = _trend([sub]);
      expect(_month(trend, 7), usd(1000)); // 120.00 a year
      expect(_month(trend, 8), usd(1000)); // NOK 108 ≈ $10
      expect(_month(trend, 9), usd(1000));
      expect(_month(trend, 10), usd(1500));
      expect(trend.isEstimate, isTrue);
    });

    test('revisedFrom records old terms once per day', () {
      final original = _sub('a', 1000);
      final edited = original
          .copyWith(priceMinor: 1200)
          .revisedFrom(original, today);
      expect(edited.priceHistory, [
        PriceRevision(
          until: today,
          priceMinor: 1000,
          currencyCode: 'USD',
          billingCycle: BillingCycle.monthly,
        ),
      ]);
      // A second change the same day keeps the pre-today terms.
      final again = edited
          .copyWith(priceMinor: 1400)
          .revisedFrom(edited, today);
      expect(again.priceHistory, edited.priceHistory);
      // Non-price edits record nothing.
      final renamed = original.copyWith(name: 'b').revisedFrom(original, today);
      expect(renamed.priceHistory, isEmpty);
      // A subscription added today has no earlier terms to keep.
      final fresh = _sub('n', 1000, startedOn: today);
      expect(
        fresh.copyWith(priceMinor: 900).revisedFrom(fresh, today).priceHistory,
        isEmpty,
      );
    });
  });

  group('pause, resume and deletion history', () {
    test('paused months stay excluded after resuming', () {
      final sub = _sub(
        'a',
        1000,
        pauseHistory: [
          PausePeriod(from: DateTime(2026, 7, 15), until: DateTime(2026, 9, 3)),
        ],
      );
      final trend = _trend([sub]);
      expect(_month(trend, 6), usd(1000));
      expect(_month(trend, 7), usd(0));
      expect(_month(trend, 8), usd(0));
      expect(_month(trend, 9), usd(1000));
    });

    test('a current pause removes only the current month', () {
      final sub = _sub('a', 1000, pausedOn: DateTime(2026, 11, 10));
      final trend = _trend([sub]);
      expect(_month(trend, 10), usd(1000));
      expect(_month(trend, 11), usd(0));
    });

    test('removed subscriptions keep counting in earlier months', () {
      final ended = _sub('a', 1000).end(DateTime(2026, 11, 20));
      expect(ended.isActive, isFalse);
      expect(ended.isEnded, isTrue);
      final trend = _trend([ended, _sub('b', 500)]);
      expect(_month(trend, 10), usd(1500));
      expect(_month(trend, 11), usd(500));
      final summary = SpendingCalculator.summary(
        [ended, _sub('b', 500)],
        today,
        _converter(),
      );
      expect(summary.previousMonthTotal, usd(1500));
      expect(summary.activeCount, 1);
      expect(summary.pausedCount, 0);
    });

    test('ended subscriptions cannot be resumed or projected', () {
      final ended = _sub(
        'a',
        1000,
        pausedOn: DateTime(2026, 10, 1),
      ).end(DateTime(2026, 11, 1));
      expect(ended.resume(today), ended);
      expect(ended.isPaused, isFalse);
      expect(ended.billingDatesBetween(today, DateTime(2027, 6, 1)), isEmpty);
    });
  });

  group('mixed currencies and exchange rates', () {
    test('converts each subscription, then sums', () {
      final subs = [
        _sub('nok', 10800, currency: 'NOK'),
        _sub('eur', 920, currency: 'EUR'),
        _sub('usd', 1000),
      ];
      final trend = _trend(subs);
      expect(trend.points.last.estimated, usd(3000));
      expect(trend.isEstimate, isTrue);
      expect(trend.excludedCount, 0);
    });

    test('missing rates exclude and report, never mix currencies', () {
      final subs = [_sub('nok', 10800, currency: 'NOK'), _sub('usd', 1000)];
      final trend = _trend(
        subs,
        converter: _converter(state: const RatesUnavailable('offline')),
      );
      expect(trend.points.last.estimated, usd(1000));
      expect(trend.points.last.billedCount, 1);
      expect(trend.excludedCount, 1);
      expect(trend.missingCurrencies, {'NOK'});
    });

    test('stale rates still convert and are flagged', () {
      final converter = _converter(
        state: RatesAvailable(
          MockExchangeRateSource(asOf: today).snapshot(),
          isStale: true,
        ),
      );
      final trend = _trend([
        _sub('nok', 10800, currency: 'NOK'),
      ], converter: converter);
      expect(trend.points.last.estimated, usd(1000));
      expect(converter.ratesAreStale, isTrue);
      expect(trend.isEstimate, isTrue);
    });

    test('totals follow the display currency', () {
      final trend = _trend([
        _sub('usd', 1000),
      ], converter: _converter(target: 'NOK'));
      expect(trend.points.last.estimated, const Money(10800, 'NOK'));
    });
  });

  group('upcoming payments', () {
    test('counts every payment in 7, 30 and 90 days', () {
      final windows = AnalyticsCalculator.upcoming(
        [
          _sub('weekly', 500, cycle: BillingCycle.weekly, anchor: today),
          _sub('monthly', 1000, anchor: DateTime(2026, 11, 30)),
        ],
        today,
        _converter(),
      );
      expect([for (final w in windows) w.days], [7, 30, 90]);
      // Weekly: Nov 24 and Dec 1 (inclusive); monthly: Nov 30.
      expect(windows[0].count, 3);
      expect(windows[0].total.total, usd(2000));
      // 30 days → Dec 24: 5 weekly + Nov 30.
      expect(windows[1].count, 6);
      // 90 days → Feb 22: 13 weekly + Nov 30, Dec 30, Jan 30.
      expect(windows[2].count, 16);
      expect(windows[2].payments.first.daysUntil, 0);
    });

    test('custom intervals', () {
      final every2Weeks = _sub(
        'a',
        500,
        cycle: const BillingCycle.custom(2, BillingUnit.week),
        anchor: DateTime(2026, 11, 20),
      );
      final windows = AnalyticsCalculator.upcoming(
        [every2Weeks],
        today,
        _converter(),
      );
      expect(
        [for (final p in windows[2].payments) p.date],
        [
          DateTime(2026, 12, 4),
          DateTime(2026, 12, 18),
          DateTime(2027, 1, 1),
          DateTime(2027, 1, 15),
          DateTime(2027, 1, 29),
          DateTime(2027, 2, 12),
        ],
      );
      final every10Days = _sub(
        'b',
        500,
        cycle: const BillingCycle.custom(10, BillingUnit.day),
        anchor: DateTime(2026, 11, 1),
      );
      expect(every10Days.billingDatesBetween(today, DateTime(2026, 12, 31)), [
        DateTime(2026, 12, 1),
        DateTime(2026, 12, 11),
        DateTime(2026, 12, 21),
        DateTime(2026, 12, 31),
      ]);
    });

    test('month-end anchors return to the 31st when possible', () {
      final sub = _sub('a', 1000, anchor: DateTime(2026, 1, 31));
      expect(
        sub.billingDatesBetween(DateTime(2026, 2, 1), DateTime(2026, 5, 31)),
        [
          DateTime(2026, 2, 28),
          DateTime(2026, 3, 31),
          DateTime(2026, 4, 30),
          DateTime(2026, 5, 31),
        ],
      );
    });

    test('leap-day yearly plans bill on Feb 28 outside leap years', () {
      final sub = _sub(
        'a',
        1000,
        cycle: BillingCycle.yearly,
        startedOn: DateTime(2024, 2, 29),
        anchor: DateTime(2024, 2, 29),
      );
      expect(
        sub.billingDatesBetween(DateTime(2025, 1, 1), DateTime(2028, 12, 31)),
        [
          DateTime(2025, 2, 28),
          DateTime(2026, 2, 28),
          DateTime(2027, 2, 28),
          DateTime(2028, 2, 29),
        ],
      );
    });

    test('paused and ended subscriptions are not projected', () {
      final windows = AnalyticsCalculator.upcoming(
        [
          _sub('p', 1000, pausedOn: DateTime(2026, 11, 1)),
          _sub('e', 1000).end(DateTime(2026, 11, 1)),
        ],
        today,
        _converter(),
      );
      expect(windows.every((w) => w.count == 0), isTrue);
      expect(windows.last.total.total, usd(0));
    });

    test('projected totals convert and report missing rates', () {
      final subs = [
        _sub('nok', 10800, currency: 'NOK', anchor: DateTime(2026, 11, 26)),
        _sub('usd', 1000, anchor: DateTime(2026, 11, 27)),
      ];
      final converted = AnalyticsCalculator.upcoming(subs, today, _converter());
      expect(converted[0].total.total, usd(2000));
      expect(converted[0].total.isConverted, isTrue);
      final missing = AnalyticsCalculator.upcoming(
        subs,
        today,
        _converter(state: const RatesUnavailable('offline')),
      );
      expect(missing[0].count, 2);
      expect(missing[0].total.total, usd(1000));
      expect(missing[0].total.missingCurrencies, {'NOK'});
    });
  });

  group('categories', () {
    test('members of a slice, and of "Other"', () {
      final categories = SubscriptionCategory.values.take(7).toList();
      final subs = [
        for (var i = 0; i < categories.length; i++)
          _sub('s$i', 1000 * (8 - i), category: categories[i]),
      ];
      final converter = _converter();
      final breakdown = SpendingCalculator.categoryBreakdown(subs, converter);
      expect(breakdown, hasLength(5));
      expect(breakdown.fold(0, (sum, s) => sum + s.percent), 100);

      final first = AnalyticsCalculator.categoryMembers(
        subs,
        breakdown,
        categories.first,
        converter,
      );
      expect([for (final m in first) m.subscription.id], ['s0']);

      final other = AnalyticsCalculator.categoryMembers(
        subs,
        breakdown,
        null,
        converter,
      );
      expect([for (final m in other) m.subscription.id], ['s4', 's5', 's6']);
      expect(
        Money.sum(other.map((m) => m.monthly), 'USD'),
        breakdown.last.total,
      );
    });
  });
}
