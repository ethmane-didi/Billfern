import '../../core/money/money.dart';

/// How often a subscription charges.
enum BillingCycle {
  monthly(months: 1, shortLabel: 'mo', label: 'Monthly'),
  yearly(months: 12, shortLabel: 'yr', label: 'Yearly');

  const BillingCycle({
    required this.months,
    required this.shortLabel,
    required this.label,
  });

  /// Length of one billing period in calendar months.
  final int months;

  /// Suffix used after a price, e.g. "/mo".
  final String shortLabel;

  final String label;

  /// Equivalent monthly cost of a [price] charge, rounded to the minor unit
  /// in the same currency.
  Money monthlyCost(Money price) => price.divideRounded(months);

  /// Total cost over twelve months of a [price] charge.
  Money annualCost(Money price) => price * (12 ~/ months);
}
