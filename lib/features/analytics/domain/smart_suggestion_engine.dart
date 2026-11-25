import '../../../core/money/currency_converter.dart';
import '../../../core/money/money.dart';
import '../../../core/utils/date_math.dart';
import '../../../shared/models/billing_cycle.dart';
import '../../../shared/models/subscription.dart';
import '../../../shared/models/subscription_category.dart';
import '../../dashboard/domain/spending_calculator.dart';
import 'analytics_models.dart';

/// Produces savings suggestions for the Analytics screen.
abstract interface class SmartSuggestionEngine {
  SmartSuggestions suggest(
    List<Subscription> subscriptions,
    DateTime today,
    MoneyConverter converter,
  );
}

/// **Local, rule-based** suggestions (no network, no AI). They only look at
/// the subscription list: Billfern has no usage data, so the wording never
/// claims a service is unused, and overlaps are presented as worth checking,
/// never as unnecessary.
///
/// Rules:
/// - **Duplicate service**: the same catalog service (or name) tracked more
///   than once.
/// - **Overlapping services**: two or more music, video streaming or cloud
///   storage services. Savings assume keeping the most expensive one, so the
///   figure is the minimum saved by keeping only one.
/// - **Annual renewal**: a plan billed every six months or less often that
///   renews within [annualRenewalWindowDays].
/// - **Largest subscription**: the most expensive subscription when it takes
///   at least [largestShareThreshold]% of monthly spending (three or more
///   subscriptions).
class RuleBasedSuggestionEngine implements SmartSuggestionEngine {
  const RuleBasedSuggestionEngine();

  static const int annualRenewalWindowDays = 60;
  static const int largestShareThreshold = 10;
  static const int largestMinimumSubscriptions = 3;

  /// Categories where people often need only one service.
  static const Set<SubscriptionCategory> overlapCategories = {
    SubscriptionCategory.music,
    SubscriptionCategory.entertainment,
    SubscriptionCategory.cloudStorage,
  };

  @override
  SmartSuggestions suggest(
    List<Subscription> subscriptions,
    DateTime today,
    MoneyConverter converter,
  ) {
    final target = converter.targetCurrency;
    // Subscriptions without an exchange rate cannot be compared; skip them.
    final priced = <_Priced>[];
    for (final sub in subscriptions) {
      if (!sub.isActive) continue;
      final monthly = converter.convert(sub.monthlyCost);
      final annual = converter.convert(sub.annualCost);
      if (monthly == null || annual == null) continue;
      priced.add(_Priced(sub, monthly, annual, sub.currencyCode != target));
    }
    priced.sort(_Priced.byCostDescending);

    final items = <SmartSuggestion>[
      ..._duplicates(priced, target),
      ..._overlaps(priced, target),
      ..._annualRenewals(priced, today, target),
      ?_largest(priced, target),
    ];

    // Combined potential, counting each cancelled subscription once.
    final counted = <String, _Priced>{};
    for (final item in items) {
      for (final sub in item.cancel) {
        counted[sub.id] = priced.firstWhere((p) => p.sub.id == sub.id);
      }
    }
    return SmartSuggestions(
      items: items,
      monthlyPotential: Money.sum(counted.values.map((p) => p.monthly), target),
      yearlyPotential: Money.sum(counted.values.map((p) => p.annual), target),
      isEstimate: counted.values.any((p) => p.converted),
    );
  }

  static String _serviceKey(Subscription sub) =>
      sub.catalogId ?? 'name:${sub.name.trim().toLowerCase()}';

  Iterable<SmartSuggestion> _duplicates(
    List<_Priced> priced,
    String target,
  ) sync* {
    final groups = <String, List<_Priced>>{};
    for (final entry in priced) {
      (groups[_serviceKey(entry.sub)] ??= []).add(entry);
    }
    for (final group in groups.values) {
      if (group.length < 2) continue;
      yield _keepOne(SuggestionKind.duplicateService, group, target);
    }
  }

  Iterable<SmartSuggestion> _overlaps(
    List<_Priced> priced,
    String target,
  ) sync* {
    for (final category in overlapCategories) {
      final group = [
        for (final entry in priced)
          if (entry.sub.category == category) entry,
      ];
      final services = group.map((entry) => _serviceKey(entry.sub)).toSet();
      if (services.length < 2) continue;
      yield _keepOne(
        SuggestionKind.overlappingServices,
        group,
        target,
        category: category,
      );
    }
  }

  /// Keep the most expensive of [group] (sorted, most expensive first).
  SmartSuggestion _keepOne(
    SuggestionKind kind,
    List<_Priced> group,
    String target, {
    SubscriptionCategory? category,
  }) {
    final cancel = group.skip(1).toList();
    return SmartSuggestion(
      kind: kind,
      subscriptions: [for (final entry in group) entry.sub],
      keep: group.first.sub,
      cancel: [for (final entry in cancel) entry.sub],
      category: category,
      monthlySavings: Money.sum(cancel.map((e) => e.monthly), target),
      yearlySavings: Money.sum(cancel.map((e) => e.annual), target),
      isEstimate: cancel.any((entry) => entry.converted),
    );
  }

  /// Whether [cycle] bills every six months or less often.
  static bool isLongCycle(BillingCycle cycle) => switch (cycle.unit) {
    BillingUnit.year => true,
    BillingUnit.month => cycle.count >= 6,
    BillingUnit.week => cycle.count >= 26,
    BillingUnit.day => cycle.count >= 182,
  };

  Iterable<SmartSuggestion> _annualRenewals(
    List<_Priced> priced,
    DateTime today,
    String target,
  ) sync* {
    final due = <({_Priced entry, DateTime date})>[];
    for (final entry in priced) {
      if (!isLongCycle(entry.sub.billingCycle)) continue;
      final date = entry.sub.nextRenewal(today);
      if (date == null) continue;
      if (DateMath.daysBetween(today, date) > annualRenewalWindowDays) continue;
      due.add((entry: entry, date: date));
    }
    due.sort((a, b) => a.date.compareTo(b.date));
    for (final item in due) {
      yield SmartSuggestion(
        kind: SuggestionKind.annualRenewal,
        subscriptions: [item.entry.sub],
        cancel: [item.entry.sub],
        date: item.date,
        monthlySavings: item.entry.monthly,
        yearlySavings: item.entry.annual,
        isEstimate: item.entry.converted,
      );
    }
  }

  SmartSuggestion? _largest(List<_Priced> priced, String target) {
    if (priced.length < largestMinimumSubscriptions) return null;
    final shares = SpendingCalculator.wholePercentages([
      for (final entry in priced) entry.monthly.minorUnits,
    ]);
    final top = priced.first;
    if (shares.first < largestShareThreshold) return null;
    return SmartSuggestion(
      kind: SuggestionKind.largestSubscription,
      subscriptions: [top.sub],
      cancel: [top.sub],
      sharePercent: shares.first,
      monthlySavings: top.monthly,
      yearlySavings: top.annual,
      isEstimate: top.converted,
    );
  }
}

class _Priced {
  const _Priced(this.sub, this.monthly, this.annual, this.converted);

  final Subscription sub;
  final Money monthly;
  final Money annual;
  final bool converted;

  static int byCostDescending(_Priced a, _Priced b) {
    final byCost = b.monthly.compareTo(a.monthly);
    return byCost != 0 ? byCost : a.sub.name.compareTo(b.sub.name);
  }
}
