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

  /// Equivalent monthly cost of a [priceCents] charge, rounded to the cent.
  int monthlyCents(int priceCents) => (priceCents / months).round();

  /// Total cost over twelve months of a [priceCents] charge.
  int annualCents(int priceCents) => priceCents * (12 ~/ months);
}
