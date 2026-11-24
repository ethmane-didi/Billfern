import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money/currency.dart';
import '../../core/money/currency_converter.dart';
import '../../core/money/exchange_rate_repository.dart';
import '../../core/money/exchange_rates.dart';
import '../../core/money/locale_currency.dart';
import '../data/currency_preference_store.dart';
import 'clock_provider.dart';

/// The device locale. Override in tests.
final deviceLocaleProvider = Provider<Locale>(
  (ref) => PlatformDispatcher.instance.locale,
);

/// Display currency suggested from the device locale.
final suggestedCurrencyProvider = Provider<Currency>(
  (ref) => LocaleCurrency.suggest(ref.watch(deviceLocaleProvider)),
);

/// Where the preferred currency is saved. `main` overrides this with the
/// `shared_preferences` store; the default keeps tests hermetic.
final currencyPreferenceStoreProvider = Provider<CurrencyPreferenceStore>(
  (ref) => InMemoryCurrencyPreferenceStore(),
);

/// The user's preferred display currency (ISO code): the saved choice, or
/// the locale suggestion until they pick one. Changing it never touches
/// subscription prices — only how totals are converted and shown.
class PreferredCurrencyNotifier extends Notifier<String> {
  @override
  String build() {
    final saved = ref.watch(currencyPreferenceStoreProvider).read();
    if (saved != null && Currency.isSupported(saved)) return saved;
    return ref.watch(suggestedCurrencyProvider).code;
  }

  /// Whether the current value is an explicit user choice.
  bool get isExplicit =>
      ref.read(currencyPreferenceStoreProvider).read() != null;

  Future<void> select(String currencyCode) async {
    final code = Currency.of(currencyCode).code;
    state = code;
    await ref.read(currencyPreferenceStoreProvider).write(code);
  }

  /// Forgets the choice and follows the locale suggestion again.
  Future<void> useSuggested() async {
    await ref.read(currencyPreferenceStoreProvider).clear();
    state = ref.read(suggestedCurrencyProvider).code;
  }
}

final preferredCurrencyProvider =
    NotifierProvider<PreferredCurrencyNotifier, String>(
      PreferredCurrencyNotifier.new,
    );

/// Where rates come from. Development uses deterministic mock rates; swap
/// this for an API-backed source later.
final exchangeRateSourceProvider = Provider<ExchangeRateSource>(
  (ref) => MockExchangeRateSource(asOf: ref.watch(todayProvider)),
);

/// Last known rates. In development it starts pre-filled with the mock
/// snapshot so the app works synchronously and offline.
final exchangeRateCacheProvider = Provider<ExchangeRateCache>((ref) {
  final source = ref.watch(exchangeRateSourceProvider);
  return InMemoryExchangeRateCache(
    source is MockExchangeRateSource ? source.snapshot() : null,
  );
});

final exchangeRateRepositoryProvider = Provider<ExchangeRateRepository>(
  (ref) => ExchangeRateRepository(
    source: ref.watch(exchangeRateSourceProvider),
    cache: ref.watch(exchangeRateCacheProvider),
    now: ref.watch(clockProvider),
  ),
);

/// Current exchange-rate state (available, stale or unavailable).
class ExchangeRatesNotifier extends Notifier<ExchangeRateState> {
  @override
  ExchangeRateState build() =>
      ref.watch(exchangeRateRepositoryProvider).cachedState();

  /// Fetches fresh rates; keeps cached ones (flagged stale) on failure.
  Future<void> refresh() async {
    state = await ref.read(exchangeRateRepositoryProvider).refresh();
  }
}

final exchangeRatesProvider =
    NotifierProvider<ExchangeRatesNotifier, ExchangeRateState>(
      ExchangeRatesNotifier.new,
    );

/// Converts amounts into the preferred display currency. Every total, chart
/// and insight goes through this one converter.
final moneyConverterProvider = Provider<MoneyConverter>(
  (ref) => MoneyConverter(
    targetCurrency: ref.watch(preferredCurrencyProvider),
    rateState: ref.watch(exchangeRatesProvider),
  ),
);
