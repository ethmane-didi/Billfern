import '../../../core/money/currency_converter.dart';
import '../../../core/money/money.dart';
import '../../../core/utils/date_math.dart';
import '../../../shared/models/subscription.dart';
import '../../../shared/models/subscription_category.dart';
import 'dashboard_models.dart';

/// Pure spending calculations. Every dashboard figure is derived here from
/// the same subscription list and the same [MoneyConverter], so the hero
/// total, chart, categories, renewals and insights always agree.
///
/// Amounts are converted **per subscription** into the display currency and
/// then summed; amounts in different currencies are never added directly.
/// Subscriptions whose currency has no rate are excluded and reported.
abstract final class SpendingCalculator {
  /// Converts and sums [amountOf] for each subscription.
  static ConvertedTotal convertedSum(
    Iterable<Subscription> subs,
    Money Function(Subscription) amountOf,
    MoneyConverter converter,
  ) {
    var total = Money.zero(converter.targetCurrency);
    final missing = <String>{};
    var excluded = 0;
    var converted = false;
    for (final sub in subs) {
      final original = amountOf(sub);
      final value = converter.convert(original);
      if (value == null) {
        missing.add(original.currencyCode);
        excluded++;
        continue;
      }
      if (original.currencyCode != converter.targetCurrency) converted = true;
      total += value;
    }
    return ConvertedTotal(
      total: total,
      missingCurrencies: missing,
      excludedCount: excluded,
      isConverted: converted,
    );
  }

  /// Estimated monthly-equivalent spending of the subscriptions billed in
  /// the month starting at [month], each at the price that applied that
  /// month (see [Subscription.monthlyCostForMonth]). Pass ended
  /// subscriptions too, so removing one never rewrites past months.
  static ConvertedTotal totalForMonth(
    Iterable<Subscription> subs,
    DateTime month,
    MoneyConverter converter,
  ) {
    final monthStart = DateMath.monthStart(month);
    return convertedSum(
      subs.where((sub) => sub.isBilledInMonth(monthStart)),
      (sub) => sub.monthlyCostForMonth(monthStart),
      converter,
    );
  }

  /// Monthly totals for the [months] calendar months ending with the month
  /// containing [today], oldest first.
  static List<MonthlySpend> monthlyHistory(
    Iterable<Subscription> subs,
    DateTime today,
    MoneyConverter converter, {
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
            total: totalForMonth(subs, month, converter).total,
            isCurrent: offset == 0,
          );
        }(),
    ];
  }

  /// Headline figures for the month containing [today]. [subs] may include
  /// ended subscriptions (they only affect earlier months).
  static SpendingSummary summary(
    Iterable<Subscription> subs,
    DateTime today,
    MoneyConverter converter,
  ) {
    final active = subs.where((sub) => sub.isActive).toList();
    final current = DateMath.monthStart(today);
    final thisMonth = totalForMonth(subs, current, converter);
    final lastMonth = totalForMonth(
      subs,
      DateMath.addMonths(current, -1),
      converter,
    );
    final yearly = convertedSum(active, (sub) => sub.annualCost, converter);
    return SpendingSummary(
      monthlyTotal: thisMonth.total,
      previousMonthTotal: lastMonth.total,
      projectedYearly: yearly.total,
      activeCount: active.length,
      pausedCount: subs.where((sub) => sub.isPaused).length,
      isEstimate: thisMonth.isConverted || yearly.isConverted,
      excludedCount: thisMonth.excludedCount,
      missingCurrencies: {
        ...thisMonth.missingCurrencies,
        ...yearly.missingCurrencies,
      },
    );
  }

  /// Share of active monthly spending per category, largest first.
  ///
  /// When there are more than [maxSlices] categories, the smallest are merged
  /// into a single "Other" slice so the chart stays legible.
  static List<CategorySpend> categoryBreakdown(
    Iterable<Subscription> subs,
    MoneyConverter converter, {
    int maxSlices = 5,
  }) {
    assert(maxSlices >= 2);
    final target = converter.targetCurrency;
    final totals = <SubscriptionCategory, Money>{};
    final counts = <SubscriptionCategory, int>{};
    for (final sub in subs.where((sub) => sub.isActive)) {
      final monthly = converter.convert(sub.monthlyCost);
      if (monthly == null) continue;
      totals[sub.category] =
          (totals[sub.category] ?? Money.zero(target)) + monthly;
      counts.update(sub.category, (value) => value + 1, ifAbsent: () => 1);
    }

    final sorted = totals.entries.toList()
      ..sort((a, b) {
        final byAmount = b.value.compareTo(a.value);
        return byAmount != 0 ? byAmount : a.key.index.compareTo(b.key.index);
      });

    final keep = sorted.length > maxSlices ? maxSlices - 1 : sorted.length;
    final slices = <({SubscriptionCategory? category, Money total, int count})>[
      for (final entry in sorted.take(keep))
        (category: entry.key, total: entry.value, count: counts[entry.key]!),
    ];
    if (sorted.length > maxSlices) {
      final rest = sorted.skip(keep);
      slices.add((
        category: null,
        total: Money.sum(rest.map((entry) => entry.value), target),
        count: rest.fold(0, (sum, entry) => sum + counts[entry.key]!),
      ));
    }

    final percents = wholePercentages([
      for (final slice in slices) slice.total.minorUnits,
    ]);
    return [
      for (var i = 0; i < slices.length; i++)
        CategorySpend(
          category: slices[i].category,
          total: slices[i].total,
          percent: percents[i],
          subscriptionCount: slices[i].count,
        ),
    ];
  }

  /// Active renewals due within [withinDays] of [today], soonest first.
  static List<UpcomingRenewal> upcomingRenewals(
    Iterable<Subscription> subs,
    DateTime today,
    MoneyConverter converter, {
    int withinDays = 30,
  }) {
    final renewals = <UpcomingRenewal>[];
    for (final sub in subs) {
      final date = sub.nextRenewal(today);
      if (date == null) continue;
      final daysUntil = DateMath.daysBetween(today, date);
      if (daysUntil <= withinDays) {
        renewals.add(
          UpcomingRenewal(
            subscription: sub,
            date: date,
            daysUntil: daysUntil,
            convertedAmount: converter.convert(sub.price),
          ),
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

  /// Every projected payment of charging subscriptions from [today] to
  /// [withinDays] days later (both inclusive), soonest first. Unlike
  /// [upcomingRenewals], a subscription can appear several times (a weekly
  /// plan has about 13 payments in 90 days). Paused and ended subscriptions
  /// are not projected.
  static List<ProjectedPayment> projectedPayments(
    Iterable<Subscription> subs,
    DateTime today,
    MoneyConverter converter, {
    required int withinDays,
  }) {
    final from = DateMath.dateOnly(today);
    final to = DateTime(from.year, from.month, from.day + withinDays);
    final payments = <ProjectedPayment>[
      for (final sub in subs)
        for (final date in sub.billingDatesBetween(from, to))
          ProjectedPayment(
            subscription: sub,
            date: date,
            daysUntil: DateMath.daysBetween(from, date),
            convertedAmount: converter.convert(sub.price),
          ),
    ];
    payments.sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      return byDate != 0
          ? byDate
          : a.subscription.name.compareTo(b.subscription.name);
    });
    return payments;
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
