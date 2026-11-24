import '../../../core/utils/currency_formatter.dart';
import '../../../shared/models/subscription.dart';
import '../../../shared/models/subscription_category.dart';
import 'dashboard_models.dart';

/// Produces savings recommendations for the AI insight card.
abstract interface class SavingsInsightEngine {
  /// The single most valuable insight, or `null` when nothing stands out.
  SavingsInsight? topInsight(List<Subscription> subscriptions);
}

/// **Mock** insight engine: deterministic rules standing in for the future
/// OpenAI-backed recommendations. No network calls are made.
///
/// Rule: when the user pays for more than one service in an interchangeable
/// category (e.g. two music services), suggest keeping the most expensive
/// one and cancelling the others.
class MockSavingsInsightEngine implements SavingsInsightEngine {
  const MockSavingsInsightEngine();

  @override
  SavingsInsight? topInsight(List<Subscription> subscriptions) {
    SavingsInsight? best;
    for (final category in SubscriptionCategory.values) {
      if (!category.isInterchangeable) continue;
      final overlapping =
          subscriptions
              .where((sub) => sub.isActive && sub.category == category)
              .toList()
            ..sort((a, b) => b.annualCostCents.compareTo(a.annualCostCents));
      if (overlapping.length < 2) continue;

      final cancellable = overlapping.skip(1).toList();
      final savings = cancellable.fold(
        0,
        (sum, sub) => sum + sub.annualCostCents,
      );
      if (best != null && savings <= best.annualSavingsCents) continue;

      best = SavingsInsight(
        title: 'Overlapping ${category.label.toLowerCase()} services',
        message:
            'You pay for ${_joinNames(overlapping)}. Keeping just '
            '${overlapping.first.name} could save you '
            '${CurrencyFormatter.formatCents(savings)} a year.',
        annualSavingsCents: savings,
        subscriptions: overlapping,
      );
    }
    return best;
  }

  static String _joinNames(List<Subscription> subs) {
    final names = [for (final sub in subs) sub.name];
    if (names.length == 2) return 'both ${names[0]} and ${names[1]}';
    return '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
  }
}
