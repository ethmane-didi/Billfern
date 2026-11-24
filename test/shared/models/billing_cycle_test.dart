import 'package:billfern/core/money/money.dart';
import 'package:billfern/shared/models/billing_cycle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const price = Money(1200, 'USD'); // $12.00 per period

  group('cost equivalents', () {
    test('presets', () {
      expect(BillingCycle.monthly.monthlyCost(price), const Money(1200, 'USD'));
      expect(BillingCycle.monthly.annualCost(price), const Money(14400, 'USD'));
      expect(BillingCycle.yearly.monthlyCost(price), const Money(100, 'USD'));
      expect(BillingCycle.yearly.annualCost(price), const Money(1200, 'USD'));
      expect(
        BillingCycle.quarterly.monthlyCost(price),
        const Money(400, 'USD'),
      );
      expect(
        BillingCycle.quarterly.annualCost(price),
        const Money(4800, 'USD'),
      );
      // 52 weeks a year: 12 × 52 / 12 = 52.
      expect(BillingCycle.weekly.monthlyCost(price), const Money(5200, 'USD'));
      expect(BillingCycle.weekly.annualCost(price), const Money(62400, 'USD'));
    });

    test('custom intervals', () {
      const fortnightly = BillingCycle.custom(2, BillingUnit.week);
      expect(fortnightly.annualCost(price), const Money(31200, 'USD'));
      expect(fortnightly.monthlyCost(price), const Money(2600, 'USD'));

      const tenDays = BillingCycle.custom(10, BillingUnit.day);
      // 12 × 365 / 10 = 438.00 a year; / 12 = 36.50 a month.
      expect(tenDays.annualCost(price), const Money(43800, 'USD'));
      expect(tenDays.monthlyCost(price), const Money(3650, 'USD'));

      const biennial = BillingCycle.custom(2, BillingUnit.year);
      expect(biennial.annualCost(price), const Money(600, 'USD'));
      expect(biennial.monthlyCost(price), const Money(50, 'USD'));
    });

    test('rounds half away from zero in the price currency', () {
      // 9.99 weekly → 9.99 × 52 / 12 = 43.29 (43.29000…)
      expect(
        BillingCycle.weekly.monthlyCost(const Money(999, 'NOK')),
        const Money(4329, 'NOK'),
      );
      // 0.05 quarterly → 0.01666… → 0.02
      expect(
        BillingCycle.quarterly.monthlyCost(const Money(5, 'EUR')),
        const Money(2, 'EUR'),
      );
    });
  });

  test('labels', () {
    expect(BillingCycle.weekly.label, 'Weekly');
    expect(BillingCycle.quarterly.label, 'Quarterly');
    expect(BillingCycle.quarterly.shortLabel, 'qtr');
    expect(
      const BillingCycle.custom(2, BillingUnit.week).label,
      'Every 2 weeks',
    );
    expect(const BillingCycle.custom(2, BillingUnit.week).shortLabel, '2 wk');
    expect(const BillingCycle.custom(1, BillingUnit.day).label, 'Every day');
    expect(
      const BillingCycle.custom(3, BillingUnit.month),
      BillingCycle.quarterly,
    );
    expect(
      const BillingCycle.custom(3, BillingUnit.month).kind,
      BillingCycleKind.quarterly,
    );
  });

  test('advance keeps month ends and handles weeks and days', () {
    expect(
      BillingCycle.monthly.advance(DateTime(2026, 1, 31), 1),
      DateTime(2026, 2, 28),
    );
    expect(
      BillingCycle.quarterly.advance(DateTime(2026, 11, 30), 1),
      DateTime(2027, 2, 28),
    );
    expect(
      BillingCycle.weekly.advance(DateTime(2026, 12, 29), 1),
      DateTime(2027, 1, 5),
    );
    expect(
      const BillingCycle.custom(
        10,
        BillingUnit.day,
      ).advance(DateTime(2026, 3, 25), 1),
      DateTime(2026, 4, 4),
    );
  });

  test('JSON round-trip and malformed input', () {
    for (final cycle in [
      ...BillingCycle.presets,
      const BillingCycle.custom(6, BillingUnit.month),
    ]) {
      expect(BillingCycle.fromJson(cycle.toJson()), cycle);
    }
    expect(
      BillingCycle.fromJson({'count': 0, 'unit': 'week'}),
      BillingCycle.monthly,
    );
    expect(BillingCycle.fromJson('nonsense'), BillingCycle.monthly);
  });
}
