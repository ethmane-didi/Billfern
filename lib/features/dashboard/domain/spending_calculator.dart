import '../../../core/utils/date_math.dart';
import '../../../shared/models/subscription.dart';
import '../../../shared/models/subscription_category.dart';
import 'dashboard_models.dart';

/// Pure spending calculations. Every figure on the dashboard is derived here
/// from the same subscription list, so the hero total, chart, categories and
/// renewals always agree.
abstract final class SpendingCalculator {
  /// Sum of monthly-equivalent costs of the subscriptions billed in the month
  /// starting at [month].
  static int totalForMonth(Iterable<Subscription> subs, DateTime month) {
    final monthStart = DateMath.monthStart(month);
    return subs
        .where((sub) => sub.isBilledInMonth(monthStart))
        .fold(0, (sum, sub) => sum + sub.monthlyCostCents);
  }

  /// Monthly totals for the [months] calendar months ending with the month
  /// containing [today], oldest first.
  static List<MonthlySpend> monthlyHistory(
    Iterable<Subscription> subs,
    DateTime today, {
    int months = 6,
  }) {
    assert(months > 0);
    final current = DateMath.monthStart(today);
    return [
      for (var offset = months - 1; offset >= 0; offset--)
        () {
          final month = DateMath.addMonths(current, -offset);
          return MonthlySpend(
            month: month,
            totalCents: totalForMonth(subs, month),
            isCurrent: offset == 0,
          );
        }(),
    ];
  }

  /// Headline figures for the month containing [today].
  static SpendingSummary summary(Iterable<Subscription> subs, DateTime today) {
    final active = subs.where((sub) => sub.isActive).toList();
    final current = DateMath.monthStart(today);
    return SpendingSummary(
      monthlyTotalCents: totalForMonth(subs, current),
      previousMonthTotalCents: totalForMonth(
        subs,
        DateMath.addMonths(current, -1),
      ),
      projectedYearlyCents: active.fold(
        0,
        (sum, sub) => sum + sub.annualCostCents,
      ),
      activeCount: active.length,
      pausedCount: subs.length - active.length,
    );
  }

  /// Share of active monthly spending per category, largest first.
  ///
  /// When there are more than [maxSlices] categories, the smallest are merged
  /// into a single "Other" slice so the chart stays legible.
  static List<CategorySpend> categoryBreakdown(
    Iterable<Subscription> subs, {
    int maxSlices = 5,
  }) {
    assert(maxSlices >= 2);
    final totals = <SubscriptionCategory, int>{};
    final counts = <SubscriptionCategory, int>{};
    for (final sub in subs.where((sub) => sub.isActive)) {
      totals.update(
        sub.category,
        (value) => value + sub.monthlyCostCents,
        ifAbsent: () => sub.monthlyCostCents,
      );
      counts.update(sub.category, (value) => value + 1, ifAbsent: () => 1);
    }

    final sorted = totals.entries.toList()
      ..sort((a, b) {
        final byAmount = b.value.compareTo(a.value);
        return byAmount != 0 ? byAmount : a.key.index.compareTo(b.key.index);
      });

    final slices = <({SubscriptionCategory? category, int cents, int count})>[
      for (final entry in sorted.take(
        sorted.length > maxSlices ? maxSlices - 1 : sorted.length,
      ))
        (category: entry.key, cents: entry.value, count: counts[entry.key]!),
    ];
    if (sorted.length > maxSlices) {
      final rest = sorted.skip(maxSlices - 1);
      slices.add((
        category: null,
        cents: rest.fold(0, (sum, entry) => sum + entry.value),
        count: rest.fold(0, (sum, entry) => sum + counts[entry.key]!),
      ));
    }

    final percents = wholePercentages([for (final s in slices) s.cents]);
    return [
      for (var i = 0; i < slices.length; i++)
        CategorySpend(
          category: slices[i].category,
          totalCents: slices[i].cents,
          percent: percents[i],
          subscriptionCount: slices[i].count,
        ),
    ];
  }

  /// Active renewals due within [withinDays] of [today], soonest first.
  static List<UpcomingRenewal> upcomingRenewals(
    Iterable<Subscription> subs,
    DateTime today, {
    int withinDays = 30,
  }) {
    final renewals = <UpcomingRenewal>[];
    for (final sub in subs) {
      final date = sub.nextRenewal(today);
      if (date == null) continue;
      final daysUntil = DateMath.daysBetween(today, date);
      if (daysUntil <= withinDays) {
        renewals.add(
          UpcomingRenewal(subscription: sub, date: date, daysUntil: daysUntil),
        );
      }
    }
    renewals.sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      return byDate != 0
          ? byDate
          : a.subscription.name.compareTo(b.subscription.name);
    });
    return renewals;
  }

  /// Converts [values] into whole percentages that sum to exactly 100 using
  /// the largest-remainder method. Returns zeros when the total is zero.
  static List<int> wholePercentages(List<int> values) {
    final total = values.fold(0, (sum, value) => sum + value);
    if (total == 0) return List.filled(values.length, 0);

    final exact = [for (final value in values) value * 100 / total];
    final result = [for (final share in exact) share.floor()];
    var remaining = 100 - result.fold(0, (sum, value) => sum + value);

    final byRemainder = List.generate(values.length, (i) => i)
      ..sort((a, b) => (exact[b] - result[b]).compareTo(exact[a] - result[a]));
    for (final index in byRemainder) {
      if (remaining == 0) break;
      result[index]++;
      remaining--;
    }
    return result;
  }
}
