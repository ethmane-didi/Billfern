import '../../../core/money/currency_converter.dart';
import '../../../core/money/money.dart';
import '../../../core/utils/date_math.dart';
import '../../../shared/models/subscription.dart';
import '../../../shared/models/subscription_category.dart';
import '../../dashboard/domain/dashboard_models.dart';
import '../../dashboard/domain/spending_calculator.dart';
import 'analytics_models.dart';
import 'payment_record.dart';

/// Pure analytics calculations.
///
/// Every monthly figure comes from [SpendingCalculator.totalForMonth] (the
/// same function behind the dashboard), so both screens always agree.
/// History is **estimated** from recorded schedules, price revisions,
/// pauses and removals; months before the first recorded subscription have
/// no data and are never shown as zero spending.
abstract final class AnalyticsCalculator {
  /// Projection windows offered by the upcoming payments card.
  static const List<int> upcomingWindows = [7, 30, 90];

  /// Start date of the earliest subscription in [history], or `null`.
  static DateTime? trackingSince(Iterable<Subscription> history) {
    DateTime? earliest;
    for (final sub in history) {
      final start = DateMath.dateOnly(sub.startedOn);
      if (earliest == null || start.isBefore(earliest)) earliest = start;
    }
    return earliest;
  }

  /// Whether the month starting at [month] has recorded history.
  static bool hasHistory(DateTime month, DateTime? since) =>
      since != null &&
      !DateMath.monthStart(month).isBefore(DateMath.monthStart(since));

  /// Spending trend for [period], ending with the month containing [today].
  ///
  /// [history] must include ended subscriptions. [payments] are confirmed
  /// payment records (none exist yet).
  static SpendingTrend trend(
    Iterable<Subscription> history,
    DateTime today,
    MoneyConverter converter,
    TrendPeriod period, {
    Iterable<PaymentRecord> payments = const [],
  }) {
    final target = converter.targetCurrency;
    final since = trackingSince(history);
    final current = DateMath.monthStart(today);
    final points = <TrendPoint>[];
    final missing = <String>{};
    var excluded = 0;
    var converted = false;
    var periodTotal = Money.zero(target);

    for (var offset = period.months - 1; offset >= 0; offset--) {
      final month = DateMath.addMonths(current, -offset);
      final has = hasHistory(month, since);
      Money? estimated;
      var billed = 0;
      if (has) {
        final total = SpendingCalculator.totalForMonth(
          history,
          month,
          converter,
        );
        estimated = total.total;
        periodTotal += total.total;
        missing.addAll(total.missingCurrencies);
        if (total.excludedCount > excluded) excluded = total.excludedCount;
        converted = converted || total.isConverted;
        billed = history.where((sub) => sub.isBilledInMonth(month)).length;
      }
      points.add(
        TrendPoint(
          month: month,
          estimated: estimated,
          confirmed: confirmedForMonth(payments, month, converter),
          billedCount: billed - _excludedIn(history, month, converter),
          isCurrent: offset == 0,
        ),
      );
    }

    // The preceding period counts only when all of it has history.
    final previousStart = DateMath.addMonths(current, -(2 * period.months - 1));
    Money? previousTotal;
    if (hasHistory(previousStart, since)) {
      previousTotal = Money.zero(target);
      for (
        var offset = 2 * period.months - 1;
        offset >= period.months;
        offset--
      ) {
        previousTotal =
            previousTotal! +
            SpendingCalculator.totalForMonth(
              history,
              DateMath.addMonths(current, -offset),
              converter,
            ).total;
      }
    }

    return SpendingTrend(
      period: period,
      points: points,
      periodTotal: periodTotal,
      periodComparison: PeriodComparison.between(periodTotal, previousTotal),
      trackingSince: since,
      isEstimate: converted,
      excludedCount: excluded,
      missingCurrencies: missing,
    );
  }

  static int _excludedIn(
    Iterable<Subscription> history,
    DateTime month,
    MoneyConverter converter,
  ) => history
      .where(
        (sub) =>
            sub.isBilledInMonth(month) &&
            converter.convert(sub.monthlyCostForMonth(month)) == null,
      )
      .length;

  /// Sum of confirmed [payments] made in the month starting at [month], in
  /// the display currency. Payments without a rate are left out.
  static Money confirmedForMonth(
    Iterable<PaymentRecord> payments,
    DateTime month,
    MoneyConverter converter,
  ) {
    final start = DateMath.monthStart(month);
    final end = DateMath.addMonths(start, 1);
    var total = Money.zero(converter.targetCurrency);
    for (final payment in payments) {
      if (payment.paidOn.isBefore(start) || !payment.paidOn.isBefore(end)) {
        continue;
      }
      final value = converter.convert(payment.amount);
      if (value != null) total += value;
    }
    return total;
  }

  /// This month versus last month. Last month has no baseline unless it has
  /// recorded history.
  static AnalyticsOverview overview(
    Iterable<Subscription> history,
    DateTime today,
    SpendingSummary summary,
  ) {
    final previousMonth = DateMath.addMonths(DateMath.monthStart(today), -1);
    final hasBaseline = hasHistory(previousMonth, trackingSince(history));
    return AnalyticsOverview(
      summary: summary,
      monthOverMonth: PeriodComparison.between(
        summary.monthlyTotal,
        hasBaseline ? summary.previousMonthTotal : null,
      ),
    );
  }

  /// Year-to-date (estimated) and the next twelve months (projected).
  static YearlySpendingSummary yearly(
    Iterable<Subscription> history,
    DateTime today,
    MoneyConverter converter,
    SpendingSummary summary,
  ) {
    final since = trackingSince(history);
    var total = Money.zero(converter.targetCurrency);
    var counted = 0;
    var converted = summary.isEstimate;
    for (var month = 1; month <= today.month; month++) {
      final start = DateTime(today.year, month);
      if (!hasHistory(start, since)) continue;
      final monthTotal = SpendingCalculator.totalForMonth(
        history,
        start,
        converter,
      );
      total += monthTotal.total;
      converted = converted || monthTotal.isConverted;
      counted++;
    }
    return YearlySpendingSummary(
      year: today.year,
      yearToDate: total,
      monthsCounted: counted,
      throughMonth: today.month,
      projectedNext12Months: summary.projectedYearly,
      isEstimate: converted,
    );
  }

  /// Projected payments for each of [windows] days ahead.
  static List<UpcomingPaymentsWindow> upcoming(
    Iterable<Subscription> subs,
    DateTime today,
    MoneyConverter converter, {
    List<int> windows = upcomingWindows,
  }) {
    final longest = windows.fold(0, (max, days) => days > max ? days : max);
    final all = SpendingCalculator.projectedPayments(
      subs,
      today,
      converter,
      withinDays: longest,
    );
    return [
      for (final days in windows)
        () {
          final payments = [
            for (final payment in all)
              if (payment.daysUntil <= days) payment,
          ];
          return UpcomingPaymentsWindow(
            days: days,
            payments: payments,
            total: SpendingCalculator.convertedSum(
              payments.map((payment) => payment.subscription),
              (sub) => sub.price,
              converter,
            ),
          );
        }(),
    ];
  }

  /// Active subscriptions behind the slice of [breakdown] for [category]
  /// (`null` = the "Other" slice, which holds every category without its
  /// own slice), most expensive first. Subscriptions without a rate are left
  /// out, as in the breakdown.
  static List<CategoryMember> categoryMembers(
    Iterable<Subscription> subs,
    List<CategorySpend> breakdown,
    SubscriptionCategory? category,
    MoneyConverter converter,
  ) {
    final named = {
      for (final entry in breakdown)
        if (entry.category != null) entry.category!,
    };
    final members = <CategoryMember>[];
    for (final sub in subs) {
      if (!sub.isActive) continue;
      final matches = category == null
          ? !named.contains(sub.category)
          : sub.category == category;
      if (!matches) continue;
      final monthly = converter.convert(sub.monthlyCost);
      if (monthly == null) continue;
      members.add(CategoryMember(subscription: sub, monthly: monthly));
    }
    members.sort((a, b) {
      final byCost = b.monthly.compareTo(a.monthly);
      return byCost != 0
          ? byCost
          : a.subscription.name.compareTo(b.subscription.name);
    });
    return members;
  }
}
