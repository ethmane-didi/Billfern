import '../../../core/money/money.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_labels.dart';
import '../../../shared/models/subscription.dart';
import '../../../shared/models/subscription_category.dart';
import '../domain/analytics_models.dart';

/// User-facing wording for analytics figures. Kept out of widgets so the
/// rules (no percentages against zero, no claims about usage) are testable.
abstract final class AnalyticsCopy {
  /// Short badge text, e.g. "+12.0% vs last month", "New vs last month",
  /// "No earlier data".
  static String comparisonBadge(
    PeriodComparison comparison, {
    String baseline = 'last month',
  }) => switch (comparison.kind) {
    ComparisonKind.noBaseline => 'No earlier data',
    ComparisonKind.fromZero => 'New vs $baseline',
    ComparisonKind.unchanged => 'Same as $baseline',
    ComparisonKind.increase || ComparisonKind.decrease =>
      '${CurrencyFormatter.signedPercent(comparison.percent!)} vs $baseline',
  };

  /// Screen-reader version of [comparisonBadge].
  static String comparisonSemantics(
    PeriodComparison comparison, {
    String baseline = 'last month',
  }) {
    final change = comparison.change;
    return switch (comparison.kind) {
      ComparisonKind.noBaseline => 'No earlier data to compare with',
      ComparisonKind.fromZero =>
        'Up ${CurrencyFormatter.format(change!)} from nothing $baseline',
      ComparisonKind.unchanged => 'Unchanged from $baseline',
      ComparisonKind.increase =>
        'Up ${comparison.percent!.abs().toStringAsFixed(1)} percent, '
            '${CurrencyFormatter.format(change!)} more than $baseline',
      ComparisonKind.decrease =>
        'Down ${comparison.percent!.abs().toStringAsFixed(1)} percent, '
            '${CurrencyFormatter.format(change!.abs())} less than $baseline',
    };
  }

  /// "≈ " for converted (estimated) amounts.
  static String approx(bool isEstimate) => isEstimate ? '≈ ' : '';

  /// Month label for the trend: "This month" or "October".
  static String monthTitle(TrendPoint point) =>
      point.isCurrent ? 'This month' : DateLabels.month(point.month);

  /// Accessible description of the whole chart.
  static String trendSemantics(SpendingTrend trend) {
    final months = [
      for (final point in trend.points)
        '${DateLabels.month(point.month)} '
            '${point.estimated == null ? 'no data' : CurrencyFormatter.format(point.estimated!)}',
    ].join(', ');
    return 'Estimated monthly spending, last ${trend.period.label}: $months';
  }

  /// "5 payments" / "1 payment".
  static String paymentCount(int count) =>
      '$count ${count == 1 ? 'payment' : 'payments'}';

  /// Title of a smart suggestion.
  static String suggestionTitle(SmartSuggestion s) => switch (s.kind) {
    SuggestionKind.duplicateService =>
      '${s.subscriptions.first.name} tracked ${s.subscriptions.length} times',
    SuggestionKind.overlappingServices =>
      '${s.subscriptions.length} ${_categoryNoun(s)}',
    SuggestionKind.annualRenewal =>
      '${s.subscriptions.first.name} renews ${DateLabels.shortDate(s.date!)}',
    SuggestionKind.largestSubscription =>
      '${s.subscriptions.first.name} is your largest subscription',
  };

  /// Body text of a smart suggestion. Never claims a service is unused or
  /// unnecessary: Billfern has no usage data.
  static String suggestionMessage(SmartSuggestion s) {
    final monthly = _money(s.monthlySavings, s.isEstimate);
    final yearly = _money(s.yearlySavings, s.isEstimate);
    final first = s.subscriptions.first;
    return switch (s.kind) {
      SuggestionKind.duplicateService =>
        'You may have separate accounts on purpose. If one is no longer '
            'needed, cancelling it would save $monthly a month ($yearly a '
            'year).',
      SuggestionKind.overlappingServices =>
        'You pay for ${_names(s.subscriptions)}. If you don\'t need them '
            'all, keeping only ${s.keep!.name} would save at least $monthly '
            'a month ($yearly a year).',
      SuggestionKind.annualRenewal =>
        'A yearly charge of ${CurrencyFormatter.format(first.price)} is '
            'coming up. If you plan to stop, cancelling before it renews '
            'saves $yearly.',
      SuggestionKind.largestSubscription =>
        'It makes up ${s.sharePercent}% of your monthly spending '
            '($monthly a month, $yearly a year). Worth checking that the '
            'plan still fits.',
    };
  }

  static String _money(Money amount, bool isEstimate) =>
      '${approx(isEstimate)}${CurrencyFormatter.format(amount)}';

  static String _categoryNoun(SmartSuggestion s) => switch (s.category) {
    SubscriptionCategory.music => 'music services',
    SubscriptionCategory.entertainment => 'streaming services',
    SubscriptionCategory.cloudStorage => 'cloud storage services',
    final category? => '${category.label.toLowerCase()} services',
    null => 'similar services',
  };

  static String _names(List<Subscription> subs) {
    final names = [for (final sub in subs) sub.name];
    if (names.length <= 1) return names.join();
    return '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
  }
}
