import 'package:billfern/core/money/money.dart';
import 'package:billfern/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:billfern/shared/data/app_preference_store.dart';
import 'package:billfern/shared/data/subscription_repository.dart';
import 'package:billfern/shared/models/billing_cycle.dart';
import 'package:billfern/shared/models/subscription.dart';
import 'package:billfern/shared/models/subscription_category.dart';
import 'package:billfern/shared/providers/currency_providers.dart';
import 'package:billfern/shared/providers/subscription_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fixed_clock.dart';

Subscription _sub(
  String id, {
  int price = 1000,
  String currency = 'USD',
  DateTime? startedOn,
}) => Subscription(
  id: id,
  name: id,
  plan: '',
  priceMinor: price,
  currencyCode: currency,
  billingCycle: BillingCycle.monthly,
  category: SubscriptionCategory.productivity,
  startedOn: startedOn ?? DateTime(2026, 1, 15),
);

({
  ProviderContainer container,
  InMemorySubscriptionRepository personal,
  InMemoryAppPreferenceStore prefs,
})
_setup({
  DataMode mode = DataMode.personal,
  List<Subscription> seed = const [],
}) {
  final personal = InMemorySubscriptionRepository(seed);
  final prefs = InMemoryAppPreferenceStore({
    PreferenceKeys.dataMode: mode.name,
    PreferenceKeys.onboardingCompleted: 'true',
  });
  final container = ProviderContainer(
    overrides: [
      ...baseTestOverrides,
      personalSubscriptionRepositoryProvider.overrideWithValue(personal),
      appPreferenceStoreProvider.overrideWithValue(prefs),
    ],
  );
  addTearDown(container.dispose);
  return (container: container, personal: personal, prefs: prefs);
}

void main() {
  test('a fresh install starts empty in personal mode', () {
    final s = _setup();
    expect(s.container.read(dataModeProvider), DataMode.personal);
    expect(s.container.read(subscriptionsProvider), isEmpty);
    expect(
      s.container.read(spendingSummaryProvider).monthlyTotal,
      const Money(0, 'USD'),
    );
  });

  test('create, edit, pause, resume and delete update the dashboard', () async {
    final s = _setup();
    final c = s.container;
    final notifier = c.read(subscriptionsProvider.notifier);

    await notifier.add(_sub('a', price: 1000));
    await notifier.add(_sub('b', price: 19900, currency: 'NOK'));
    expect(c.read(subscriptionsProvider), hasLength(2));
    // $10.00 + 199 NOK (≈ $18.43 at mock rates).
    expect(
      c.read(spendingSummaryProvider).monthlyTotal,
      const Money(2843, 'USD'),
    );
    expect(c.read(spendingSummaryProvider).isEstimate, isTrue);
    expect(s.personal.fetchAll(), hasLength(2), reason: 'persisted');

    await notifier.update(_sub('a', price: 1500));
    expect(
      c.read(spendingSummaryProvider).monthlyTotal,
      const Money(3343, 'USD'),
    );

    await notifier.pause('b');
    expect(c.read(subscriptionByIdProvider('b'))!.isActive, isFalse);
    expect(
      c.read(spendingSummaryProvider).monthlyTotal,
      const Money(1500, 'USD'),
    );
    expect(c.read(spendingSummaryProvider).activeCount, 1);
    expect(c.read(spendingSummaryProvider).pausedCount, 1);

    await notifier.resume('b');
    expect(
      c.read(spendingSummaryProvider).monthlyTotal,
      const Money(3343, 'USD'),
    );

    await notifier.delete('a');
    expect(c.read(subscriptionByIdProvider('a')), isNull);
    expect(s.personal.fetchAll().map((x) => x.id), ['b']);
    expect(
      c.read(spendingSummaryProvider).monthlyTotal,
      const Money(1843, 'USD'),
    );
  });

  test('pausing keeps past months in the history chart', () async {
    final s = _setup(seed: [_sub('a', price: 1000)]);
    final c = s.container;
    final before = c.read(spendingHistoryProvider).map((m) => m.total).toList();

    await c.read(subscriptionsProvider.notifier).pause('a');
    final after = c.read(spendingHistoryProvider).map((m) => m.total).toList();

    expect(after.last, const Money(0, 'USD'), reason: 'this month excluded');
    expect(
      after.sublist(0, after.length - 1),
      before.sublist(0, before.length - 1),
      reason: 'previous months unchanged',
    );
  });

  test('multiple subscriptions to the same service are kept', () async {
    final s = _setup();
    final notifier = s.container.read(subscriptionsProvider.notifier);
    await notifier.add(_sub('notion-personal'));
    await notifier.add(_sub('notion-work'));
    expect(s.container.read(subscriptionsProvider), hasLength(2));
  });

  test('changing the display currency never changes stored prices', () async {
    final s = _setup(seed: [_sub('a', price: 19900, currency: 'NOK')]);
    await s.container.read(preferredCurrencyProvider.notifier).select('EUR');
    expect(s.personal.fetchAll().single.price, const Money(19900, 'NOK'));
    expect(
      s.container.read(spendingSummaryProvider).monthlyTotal.currencyCode,
      'EUR',
    );
  });

  group('sample data', () {
    test('is shown in sample mode without touching personal data', () async {
      final s = _setup(mode: DataMode.sample, seed: [_sub('mine')]);
      final c = s.container;
      expect(
        c.read(subscriptionsProvider).map((x) => x.id),
        contains('netflix'),
      );
      expect(
        c.read(subscriptionsProvider).map((x) => x.id),
        isNot(contains('mine')),
      );

      await c.read(subscriptionsProvider.notifier).delete('netflix');
      expect(s.personal.fetchAll().map((x) => x.id), ['mine']);
    });

    test('adding a real subscription leaves sample mode', () async {
      final s = _setup(mode: DataMode.sample);
      final c = s.container;
      await c.read(subscriptionsProvider.notifier).add(_sub('mine'));

      expect(c.read(dataModeProvider), DataMode.personal);
      expect(s.prefs.read(PreferenceKeys.dataMode), DataMode.personal.name);
      expect(c.read(subscriptionsProvider).map((x) => x.id), ['mine']);
      expect(s.personal.fetchAll().map((x) => x.id), ['mine']);
    });

    test('data mode persists', () async {
      final s = _setup();
      await s.container.read(dataModeProvider.notifier).set(DataMode.sample);
      expect(s.prefs.read(PreferenceKeys.dataMode), 'sample');
    });
  });

  test('generated ids are unique', () {
    final generate = _setup().container.read(subscriptionIdGeneratorProvider);
    final ids = {for (var i = 0; i < 200; i++) generate()};
    expect(ids, hasLength(200));
  });
}
