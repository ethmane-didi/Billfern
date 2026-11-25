import 'package:billfern/core/money/currency_converter.dart';
import 'package:billfern/core/money/exchange_rate_repository.dart';
import 'package:billfern/core/money/exchange_rates.dart';
import 'package:billfern/core/money/money.dart';
import 'package:billfern/core/utils/currency_formatter.dart';
import 'package:billfern/features/analytics/domain/analytics_models.dart';
import 'package:billfern/features/analytics/domain/smart_suggestion_engine.dart';
import 'package:billfern/features/analytics/presentation/analytics_copy.dart';
import 'package:billfern/shared/models/billing_cycle.dart';
import 'package:billfern/shared/models/subscription.dart';
import 'package:billfern/shared/models/subscription_category.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime today = DateTime(2026, 11, 24);

final MoneyConverter converter = MoneyConverter(
  targetCurrency: 'USD',
  rateState: RatesAvailable(MockExchangeRateSource(asOf: today).snapshot()),
);

Subscription _sub(
  String name,
  int priceMinor, {
  String? catalogId,
  String currency = 'USD',
  SubscriptionCategory category = SubscriptionCategory.productivity,
  BillingCycle cycle = BillingCycle.monthly,
  DateTime? anchor,
  DateTime? pausedOn,
  String? id,
}) => Subscription(
  id: id ?? name,
  name: name,
  plan: '',
  priceMinor: priceMinor,
  currencyCode: currency,
  billingCycle: cycle,
  category: category,
  startedOn: DateTime(2026, 1, 1),
  billingAnchor: anchor,
  catalogId: catalogId,
  status: pausedOn == null
      ? SubscriptionStatus.active
      : SubscriptionStatus.paused,
  pausedOn: pausedOn,
);

SmartSuggestions _suggest(List<Subscription> subs) =>
    const RuleBasedSuggestionEngine().suggest(subs, today, converter);

Iterable<SmartSuggestion> _ofKind(SmartSuggestions s, SuggestionKind kind) =>
    s.items.where((item) => item.kind == kind);

void main() {
  setUp(CurrencyFormatter.reset);

  test('multiple music services: keep the priciest, save the rest', () {
    final result = _suggest([
      _sub('Spotify', 1199, category: SubscriptionCategory.music),
      _sub('Apple Music', 1099, category: SubscriptionCategory.music),
    ]);
    final overlap = _ofKind(result, SuggestionKind.overlappingServices).single;
    expect(overlap.keep!.name, 'Spotify');
    expect([for (final s in overlap.cancel) s.name], ['Apple Music']);
    expect(overlap.monthlySavings, const Money(1099, 'USD'));
    expect(overlap.yearlySavings, const Money(13188, 'USD'));
    expect(AnalyticsCopy.suggestionTitle(overlap), '2 music services');
  });

  test('multiple streaming services compare across currencies', () {
    final result = _suggest([
      _sub('Netflix', 1549, category: SubscriptionCategory.entertainment),
      _sub(
        'Viaplay',
        19900,
        currency: 'NOK',
        category: SubscriptionCategory.entertainment,
      ),
    ]);
    final overlap = _ofKind(result, SuggestionKind.overlappingServices).single;
    expect(overlap.keep!.name, 'Viaplay'); // NOK 199 ≈ $18.43
    expect(overlap.monthlySavings, const Money(1549, 'USD'));
    expect(overlap.isEstimate, isFalse);
    expect(AnalyticsCopy.suggestionTitle(overlap), '2 streaming services');
  });

  test('the same service twice is a potential duplicate', () {
    final result = _suggest([
      _sub('Notion', 1000, catalogId: 'notion', id: 'n1'),
      _sub('Notion', 2000, catalogId: 'notion', id: 'n2'),
    ]);
    final duplicate = _ofKind(result, SuggestionKind.duplicateService).single;
    expect(duplicate.keep!.id, 'n2');
    expect(duplicate.monthlySavings, const Money(1000, 'USD'));
    expect(
      AnalyticsCopy.suggestionMessage(duplicate),
      contains('separate accounts on purpose'),
    );
  });

  test('annual renewals within 60 days are flagged with the date', () {
    final result = _suggest([
      _sub(
        'Lightroom',
        11988,
        cycle: BillingCycle.yearly,
        anchor: DateTime(2026, 12, 10),
      ),
      _sub(
        'Duolingo',
        8388,
        cycle: BillingCycle.yearly,
        anchor: DateTime(2027, 6, 1),
      ),
      _sub(
        'Half-yearly',
        6000,
        cycle: const BillingCycle.custom(6, BillingUnit.month),
        anchor: DateTime(2027, 1, 5),
      ),
    ]);
    final renewals = _ofKind(result, SuggestionKind.annualRenewal).toList();
    expect(
      [for (final r in renewals) r.subscriptions.single.name],
      ['Lightroom', 'Half-yearly'],
    );
    expect(renewals.first.date, DateTime(2026, 12, 10));
    expect(renewals.first.yearlySavings, const Money(11988, 'USD'));
    expect(renewals.first.monthlySavings, const Money(999, 'USD'));
  });

  test('largest subscription needs three subscriptions and a big share', () {
    expect(
      _ofKind(
        _suggest([_sub('A', 5000), _sub('B', 1000)]),
        SuggestionKind.largestSubscription,
      ),
      isEmpty,
    );
    final result = _suggest([_sub('A', 5000), _sub('B', 1000), _sub('C', 500)]);
    final largest = _ofKind(result, SuggestionKind.largestSubscription).single;
    expect(largest.subscriptions.single.name, 'A');
    expect(largest.sharePercent, 77);
    expect(largest.monthlySavings, const Money(5000, 'USD'));
  });

  test('paused subscriptions are never suggested', () {
    final result = _suggest([
      _sub('Spotify', 1199, category: SubscriptionCategory.music),
      _sub(
        'Tidal',
        1099,
        category: SubscriptionCategory.music,
        pausedOn: DateTime(2026, 11, 1),
      ),
    ]);
    expect(result.isEmpty, isTrue);
  });

  test('combined potential counts each subscription once', () {
    final result = _suggest([
      _sub(
        'Spotify',
        1199,
        catalogId: 'spotify',
        category: SubscriptionCategory.music,
        id: 's1',
      ),
      _sub(
        'Spotify',
        999,
        catalogId: 'spotify',
        category: SubscriptionCategory.music,
        id: 's2',
      ),
      _sub('Tidal', 1099, category: SubscriptionCategory.music),
    ]);
    // s2 appears in the duplicate and the overlap suggestion.
    expect(_ofKind(result, SuggestionKind.duplicateService), hasLength(1));
    expect(_ofKind(result, SuggestionKind.overlappingServices), hasLength(1));
    // Overlap cancels Tidal and s2; largest (Spotify s1, 36%) cancels s1.
    expect(result.monthlyPotential, const Money(1199 + 999 + 1099, 'USD'));
  });

  test('wording never claims usage or that something is unnecessary', () {
    final result = _suggest([
      _sub('Spotify', 1199, category: SubscriptionCategory.music),
      _sub('Apple Music', 1099, category: SubscriptionCategory.music),
      _sub('Notion', 1000, catalogId: 'notion', id: 'n1'),
      _sub('Notion', 1000, catalogId: 'notion', id: 'n2'),
      _sub(
        'Lightroom',
        11988,
        cycle: BillingCycle.yearly,
        anchor: DateTime(2026, 12, 10),
      ),
    ]);
    expect(result.items, isNotEmpty);
    for (final item in result.items) {
      final text =
          '${AnalyticsCopy.suggestionTitle(item)} '
                  '${AnalyticsCopy.suggestionMessage(item)}'
              .toLowerCase();
      for (final banned in [
        'unused',
        "haven't used",
        'not used',
        'unnecessary',
        "don't use",
        'ai ',
      ]) {
        expect(text, isNot(contains(banned)), reason: text);
      }
    }
  });
}
