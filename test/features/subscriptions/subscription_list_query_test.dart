import 'package:billfern/core/money/currency_converter.dart';
import 'package:billfern/core/money/exchange_rate_repository.dart';
import 'package:billfern/core/money/exchange_rates.dart';
import 'package:billfern/features/subscriptions/domain/subscription_list_query.dart';
import 'package:billfern/shared/models/billing_cycle.dart';
import 'package:billfern/shared/models/subscription.dart';
import 'package:billfern/shared/models/subscription_category.dart';
import 'package:flutter_test/flutter_test.dart';

final _today = DateTime(2026, 11, 24);

Subscription _sub(
  String id,
  String name, {
  int price = 1000,
  String currency = 'USD',
  BillingCycle cycle = BillingCycle.monthly,
  SubscriptionCategory category = SubscriptionCategory.entertainment,
  DateTime? anchor,
  bool paused = false,
  String plan = '',
  String? notes,
}) => Subscription(
  id: id,
  name: name,
  plan: plan,
  priceMinor: price,
  currencyCode: currency,
  billingCycle: cycle,
  category: category,
  startedOn: DateTime(2026),
  billingAnchor: anchor ?? DateTime(2026, 12, 1),
  status: paused ? SubscriptionStatus.paused : SubscriptionStatus.active,
  pausedOn: paused ? DateTime(2026, 11, 1) : null,
  notes: notes,
);

final _subs = [
  _sub(
    'spotify',
    'Spotify',
    price: 1199,
    category: SubscriptionCategory.music,
    anchor: DateTime(2026, 12, 22),
  ),
  // 199 NOK ≈ $18.43 — more than Spotify once converted.
  _sub(
    'viaplay',
    'Viaplay',
    price: 19900,
    currency: 'NOK',
    anchor: DateTime(2026, 12, 3),
    notes: 'Shared with Kari',
  ),
  // 120 USD yearly = $10.00/month.
  _sub(
    'adobe',
    'Adobe Lightroom',
    price: 12000,
    cycle: BillingCycle.yearly,
    category: SubscriptionCategory.design,
    anchor: DateTime(2026, 11, 30),
  ),
  _sub('disney', 'Disney+', price: 999, paused: true, plan: 'Basic'),
  // No exchange rate for JPY in the mock rates.
  _sub(
    'crunchy',
    'Crunchyroll',
    price: 1500,
    currency: 'JPY',
    anchor: DateTime(2026, 11, 26),
  ),
];

final _converter = MoneyConverter(
  targetCurrency: 'USD',
  rateState: RatesAvailable(MockExchangeRateSource(asOf: _today).snapshot()),
);

List<String> _ids(SubscriptionListQuery query) => query
    .apply(_subs, converter: _converter, today: _today)
    .map((s) => s.id)
    .toList();

void main() {
  test('defaults to next renewal, paused last', () {
    expect(_ids(const SubscriptionListQuery()), [
      'crunchy',
      'adobe',
      'viaplay',
      'spotify',
      'disney',
    ]);
  });

  test('sorts by name', () {
    expect(_ids(const SubscriptionListQuery(sort: SubscriptionSort.name)), [
      'adobe',
      'crunchy',
      'disney',
      'spotify',
      'viaplay',
    ]);
  });

  test('sorts by converted monthly price; unconvertible last', () {
    expect(
      _ids(const SubscriptionListQuery(sort: SubscriptionSort.priceHighToLow)),
      ['viaplay', 'spotify', 'adobe', 'disney', 'crunchy'],
    );
    expect(
      _ids(const SubscriptionListQuery(sort: SubscriptionSort.priceLowToHigh)),
      ['disney', 'adobe', 'spotify', 'viaplay', 'crunchy'],
    );
  });

  test('filters by status', () {
    expect(_ids(const SubscriptionListQuery(status: StatusFilter.paused)), [
      'disney',
    ]);
    expect(
      _ids(const SubscriptionListQuery(status: StatusFilter.active)),
      isNot(contains('disney')),
    );
  });

  test('filters by category', () {
    expect(
      _ids(const SubscriptionListQuery(category: SubscriptionCategory.music)),
      ['spotify'],
    );
  });

  test('searches name, plan, category and notes', () {
    expect(_ids(const SubscriptionListQuery(text: 'spot')), ['spotify']);
    expect(_ids(const SubscriptionListQuery(text: 'basic')), ['disney']);
    expect(_ids(const SubscriptionListQuery(text: 'design')), ['adobe']);
    expect(_ids(const SubscriptionListQuery(text: 'kari')), ['viaplay']);
    expect(_ids(const SubscriptionListQuery(text: 'DISNEY+')), ['disney']);
    expect(_ids(const SubscriptionListQuery(text: 'zzz')), isEmpty);
  });

  test('combines search, status and category', () {
    expect(
      _ids(
        const SubscriptionListQuery(
          text: 'a',
          status: StatusFilter.active,
          category: SubscriptionCategory.entertainment,
        ),
      ),
      ['crunchy', 'viaplay'],
    );
  });

  test('hasFilters and copyWith', () {
    expect(const SubscriptionListQuery().hasFilters, isFalse);
    const query = SubscriptionListQuery(category: SubscriptionCategory.music);
    expect(query.hasFilters, isTrue);
    expect(query.copyWith(clearCategory: true).category, isNull);
  });
}
