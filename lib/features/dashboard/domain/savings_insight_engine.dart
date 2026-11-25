import '../../../core/money/currency_converter.dart';
import '../../../core/money/money.dart';
import '../../../shared/models/subscription.dart';
import '../../../shared/models/subscription_category.dart';
import 'dashboard_models.dart';

/// Produces savings recommendations for the smart tip card.
abstract interface class SavingsInsightEngine {
  /// The single most valuable insight, or `null` when nothing stands out.
  SavingsInsight? topInsight(
    List<Subscription> subscriptions,
    MoneyConverter converter,
  );
}

/// **Mock** insight engine: deterministic rules standing in for the future
/// OpenAI-backed recommendations. No network calls are made.
///
/// Rule: when the user pays for more than one service in an interchangeable
/// category (e.g. two music services), suggest keeping the most expensive
/// one and cancelling the others. Costs are compared in the display
/// currency, so services billed in different currencies rank correctly.
class MockSavingsInsightEngine implements SavingsInsightEngine {
  const MockSavingsInsightEngine();

  @override
  SavingsInsight? topInsight(
    List<Subscription> subscriptions,
    MoneyConverter converter,
  ) {
    SavingsInsight? best;
    for (final category in SubscriptionCategory.values) {
      if (!category.isInterchangeable) continue;

      final priced = <({Subscription sub, Money annual})>[];
      for (final sub in subscriptions) {
        if (!sub.isActive || sub.category != category) continue;
        final annual = converter.convert(sub.annualCost);
        if (annual != null) priced.add((sub: sub, annual: annual));
      }
      if (priced.length < 2) continue;
      priced.sort((a, b) => b.annual.compareTo(a.annual));

      final cancel = priced.skip(1).toList();
      final savings = Money.sum(
        cancel.map((entry) => entry.annual),
        converter.targetCurrency,
      );
      if (best != null && savings.compareTo(best.annualSavings) <= 0) continue;

      best = SavingsInsight(
        category: category,
        keep: priced.first.sub,
        cancel: [for (final entry in cancel) entry.sub],
        annualSavings: savings,
        isEstimate: cancel.any(
          (entry) => entry.sub.currencyCode != converter.targetCurrency,
        ),
      );
    }
    return best;
  }
}
