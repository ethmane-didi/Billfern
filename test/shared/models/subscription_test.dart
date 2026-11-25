import 'package:billfern/core/money/money.dart';
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
    priceMinor: priceCents,
    currencyCode: 'USD',
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
      expect(sub.monthlyCost, const Money(999, 'USD'));
      expect(sub.annualCost, const Money(11988, 'USD'));
    });

    test('monthly plans annualise by twelve', () {
      expect(
        _sub(startedOn: DateTime(2026)).annualCost,
        const Money(12000, 'USD'),
      );
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

    test('a billing anchor of today renews today', () {
      expect(_sub(startedOn: today).nextRenewal(today), today);
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

  group('pause and resume', () {
    final sub = _sub(startedOn: DateTime(2026, 1, 15));

    test('pausing excludes this month but keeps earlier months', () {
      final paused = sub.pause(DateTime(2026, 11, 10));
      expect(paused.isActive, isFalse);
      expect(paused.pausedOn, DateTime(2026, 11, 10));
      expect(paused.nextRenewal(DateTime(2026, 11, 24)), isNull);
      expect(paused.isBilledInMonth(DateTime(2026, 10)), isTrue);
      expect(paused.isBilledInMonth(DateTime(2026, 11)), isFalse);
    });

    test('resuming records the pause and bills again', () {
      final resumed = sub
          .pause(DateTime(2026, 8, 20))
          .resume(DateTime(2026, 10, 5));
      expect(resumed.isActive, isTrue);
      expect(resumed.pausedOn, isNull);
      expect(resumed.pauseHistory, [
        PausePeriod(from: DateTime(2026, 8, 20), until: DateTime(2026, 10, 5)),
      ]);
      expect(resumed.isBilledInMonth(DateTime(2026, 7)), isTrue);
      expect(resumed.isBilledInMonth(DateTime(2026, 8)), isFalse);
      expect(resumed.isBilledInMonth(DateTime(2026, 9)), isFalse);
      expect(resumed.isBilledInMonth(DateTime(2026, 10)), isTrue);
      expect(
        resumed.nextRenewal(DateTime(2026, 11, 24)),
        DateTime(2026, 12, 15),
      );
    });

    test('pause and resume are idempotent', () {
      final today = DateTime(2026, 11, 24);
      expect(sub.resume(today), same(sub));
      final paused = sub.pause(today);
      expect(paused.pause(today), same(paused));
    });

    test('a same-day pause and resume leaves no history', () {
      final today = DateTime(2026, 11, 24);
      expect(sub.pause(today).resume(today).pauseHistory, isEmpty);
    });
  });
}
