import 'package:flutter/foundation.dart';

import '../../core/money/money.dart';
import '../../core/utils/date_math.dart';

/// Unit of a billing interval.
enum BillingUnit {
  day('day', 'days', 'd'),
  week('week', 'weeks', 'wk'),
  month('month', 'months', 'mo'),
  year('year', 'years', 'yr');

  const BillingUnit(this.singular, this.plural, this.short);

  final String singular;
  final String plural;
  final String short;
}

/// The presets offered in the form, plus [custom].
enum BillingCycleKind { weekly, monthly, quarterly, yearly, custom }

/// How often a subscription charges: every [count] [unit]s.
///
/// Presets cover the common cases ([weekly], [monthly], [quarterly],
/// [yearly]); [BillingCycle.custom] supports any interval such as "every
/// 2 weeks" or "every 6 months".
@immutable
class BillingCycle {
  const BillingCycle._(this.count, this.unit);

  /// Every [count] [unit]s. [count] must be between 1 and [maxCount].
  const BillingCycle.custom(this.count, this.unit)
    : assert(count >= 1 && count <= maxCount, 'Invalid billing interval.');

  static const BillingCycle weekly = BillingCycle._(1, BillingUnit.week);
  static const BillingCycle monthly = BillingCycle._(1, BillingUnit.month);
  static const BillingCycle quarterly = BillingCycle._(3, BillingUnit.month);
  static const BillingCycle yearly = BillingCycle._(1, BillingUnit.year);

  static const List<BillingCycle> presets = [
    weekly,
    monthly,
    quarterly,
    yearly,
  ];

  static const int maxCount = 365;

  final int count;
  final BillingUnit unit;

  BillingCycleKind get kind {
    if (this == weekly) return BillingCycleKind.weekly;
    if (this == monthly) return BillingCycleKind.monthly;
    if (this == quarterly) return BillingCycleKind.quarterly;
    if (this == yearly) return BillingCycleKind.yearly;
    return BillingCycleKind.custom;
  }

  /// "Monthly", "Every 2 weeks", …
  String get label => switch (kind) {
    BillingCycleKind.weekly => 'Weekly',
    BillingCycleKind.monthly => 'Monthly',
    BillingCycleKind.quarterly => 'Quarterly',
    BillingCycleKind.yearly => 'Yearly',
    BillingCycleKind.custom =>
      count == 1 ? 'Every ${unit.singular}' : 'Every $count ${unit.plural}',
  };

  /// Suffix after a price: "mo", "yr", "qtr", "2 wk".
  String get shortLabel => switch (kind) {
    BillingCycleKind.quarterly => 'qtr',
    BillingCycleKind.custom when count > 1 => '$count ${unit.short}',
    _ => unit.short,
  };

  /// Billing periods per year as an exact fraction (numerator, denominator).
  /// Days use 365 per year and weeks 52.
  ({int numerator, int denominator}) get _periodsPerYear => switch (unit) {
    BillingUnit.day => (numerator: 365, denominator: count),
    BillingUnit.week => (numerator: 52, denominator: count),
    BillingUnit.month => (numerator: 12, denominator: count),
    BillingUnit.year => (numerator: 1, denominator: count),
  };

  /// Equivalent monthly cost of a [price] charge, in the same currency,
  /// rounded half away from zero.
  Money monthlyCost(Money price) {
    final perYear = _periodsPerYear;
    return price.scaleRounded(perYear.numerator, perYear.denominator * 12);
  }

  /// Cost over twelve months of a [price] charge, in the same currency.
  Money annualCost(Money price) {
    final perYear = _periodsPerYear;
    return price.scaleRounded(perYear.numerator, perYear.denominator);
  }

  /// The date [periods] billing periods after [anchor]. Month-based cycles
  /// keep the anchor's day, clamped to short months.
  DateTime advance(DateTime anchor, int periods) {
    final date = DateMath.dateOnly(anchor);
    return switch (unit) {
      BillingUnit.day => DateTime(
        date.year,
        date.month,
        date.day + count * periods,
      ),
      BillingUnit.week => DateTime(
        date.year,
        date.month,
        date.day + 7 * count * periods,
      ),
      BillingUnit.month => DateMath.addMonths(date, count * periods),
      BillingUnit.year => DateMath.addMonths(date, 12 * count * periods),
    };
  }

  /// Rough number of whole periods between [from] and [to], used as a
  /// starting point when searching for renewal dates.
  int approximatePeriodsBetween(DateTime from, DateTime to) => switch (unit) {
    BillingUnit.day => DateMath.daysBetween(from, to) ~/ count,
    BillingUnit.week => DateMath.daysBetween(from, to) ~/ (7 * count),
    BillingUnit.month => DateMath.monthsBetween(from, to) ~/ count,
    BillingUnit.year => DateMath.monthsBetween(from, to) ~/ (12 * count),
  };

  Map<String, Object> toJson() => {'count': count, 'unit': unit.name};

  /// Parses [toJson] output; returns [monthly] for malformed input.
  static BillingCycle fromJson(Object? json) {
    if (json is! Map) return monthly;
    final count = json['count'];
    final unit = BillingUnit.values.where((u) => u.name == json['unit']);
    if (count is! int || count < 1 || count > maxCount || unit.isEmpty) {
      return monthly;
    }
    return BillingCycle._(count, unit.first);
  }

  @override
  bool operator ==(Object other) =>
      other is BillingCycle && other.count == count && other.unit == unit;

  @override
  int get hashCode => Object.hash(count, unit);

  @override
  String toString() => 'BillingCycle($count ${unit.name})';
}
