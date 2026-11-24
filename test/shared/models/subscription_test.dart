import 'package:billfern/shared/models/billing_cycle.dart';
import 'package:billfern/shared/models/subscription.dart';
import 'package:billfern/shared/models/subscription_category.dart';
import 'package:flutter_test/flutter_test.dart';

Subscription _sub({
  int priceCents = 1000,
  BillingCycle cycle = BillingCycle.monthly,
  required DateTime startedOn,
  DateTime? pausedOn,
}) {
  return Subscription(
    id: 'test',
    name: 'Test',
    plan: 'Plan',
    priceCents: priceCents,
    billingCycle: cycle,
    category: SubscriptionCategory.productivity,
    startedOn: startedOn,
    status: pausedOn == null
        ? SubscriptionStatus.active
        : SubscriptionStatus.paused,
    pausedOn: pausedOn,
  );
}

void main() {
  group('costs', () {
    test('yearly plans convert to exact monthly and annual cents', () {
      final sub = _sub(
        priceCents: 11988,
        cycle: BillingCycle.yearly,
        startedOn: DateTime(2026),
      );
      expect(sub.monthlyCostCents, 999);
      expect(sub.annualCostCents, 11988);
    });

    test('monthly plans annualise by twelve', () {
      expect(_sub(startedOn: DateTime(2026)).annualCostCents, 12000);
    });
  });

  group('nextRenewal', () {
    final today = DateTime(2026, 11, 24);

    test('falls on the start day in the current month when still ahead', () {
      expect(
        _sub(startedOn: DateTime(2025, 3, 28)).nextRenewal(today),
        DateTime(2026, 11, 28),
      );
    });

    test('is today when the billing day is today', () {
      expect(
        _sub(startedOn: DateTime(2026, 6, 24)).nextRenewal(today),
        DateTime(2026, 11, 24),
      );
    });

    test('rolls into next month once the day has passed', () {
      expect(
        _sub(startedOn: DateTime(2026, 1, 3)).nextRenewal(today),
        DateTime(2026, 12, 3),
      );
    });

    test('is one full cycle after a start date of today', () {
      expect(_sub(startedOn: today).nextRenewal(today), DateTime(2026, 12, 24));
    });

    test('keeps the original day after short months', () {
      expect(
        _sub(startedOn: DateTime(2026, 1, 31))
            .nextRenewal(DateTime(2026, 3, 1)),
        DateTime(2026, 3, 31),
      );
    });

    test('handles yearly plans', () {
      expect(
        _sub(
          cycle: BillingCycle.yearly,
          startedOn: DateTime(2024, 12, 10),
        ).nextRenewal(today),
        DateTime(2026, 12, 10),
      );
    });

    test('is null for paused subscriptions', () {
      expect(
        _sub(
          startedOn: DateTime(2025),
          pausedOn: DateTime(2026, 11),
        ).nextRenewal(today),
        isNull,
      );
    });
  });

  test('isBilledInMonth respects start and pause dates', () {
    final sub = _sub(
      startedOn: DateTime(2026, 8, 20),
      pausedOn: DateTime(2026, 11, 5),
    );
    expect(sub.isBilledInMonth(DateTime(2026, 7)), isFalse);
    expect(sub.isBilledInMonth(DateTime(2026, 8)), isTrue);
    expect(sub.isBilledInMonth(DateTime(2026, 10)), isTrue);
    expect(sub.isBilledInMonth(DateTime(2026, 11)), isFalse);
  });
}
