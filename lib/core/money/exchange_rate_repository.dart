import 'exchange_rates.dart';

/// Fetches exchange rates from somewhere (a future API, or mock data).
abstract interface class ExchangeRateSource {
  Future<ExchangeRates> fetchLatest();
}

/// Stores the last good rates so the app works offline.
abstract interface class ExchangeRateCache {
  ExchangeRates? read();
  Future<void> write(ExchangeRates rates);
}

/// Non-persistent cache, optionally pre-filled.
class InMemoryExchangeRateCache implements ExchangeRateCache {
  InMemoryExchangeRateCache([this._rates]);

  ExchangeRates? _rates;

  @override
  ExchangeRates? read() => _rates;

  @override
  Future<void> write(ExchangeRates rates) async => _rates = rates;
}

/// **Development only.** Deterministic, hand-picked rates (units per USD).
/// They approximate real rates but must never be shown as live rates.
class MockExchangeRateSource implements ExchangeRateSource {
  const MockExchangeRateSource({required this.asOf});

  final DateTime asOf;

  static const Map<String, num> unitsPerUsd = {
    'EUR': 0.92,
    'NOK': 10.80,
    'GBP': 0.79,
    'SEK': 10.50,
    'DKK': 6.86,
    'CHF': 0.88,
    'CAD': 1.37,
    'AUD': 1.52,
  };

  ExchangeRates snapshot() => ExchangeRates(
    baseCurrency: 'USD',
    rates: unitsPerUsd,
    asOf: asOf,
    source: 'Mock rates',
    isMock: true,
  );

  @override
  Future<ExchangeRates> fetchLatest() async => snapshot();
}

/// Combines a [source] and a [cache] into an [ExchangeRateState], tracking
/// staleness against [now].
class ExchangeRateRepository {
  const ExchangeRateRepository({
    required this.source,
    required this.cache,
    required this.now,
    this.staleAfter = const Duration(hours: 24),
  });

  final ExchangeRateSource source;
  final ExchangeRateCache cache;
  final DateTime Function() now;
  final Duration staleAfter;

  /// State from the cache alone (synchronous; used at startup).
  ExchangeRateState cachedState() {
    final cached = cache.read();
    if (cached == null) {
      return const RatesUnavailable('Exchange rates have not been loaded yet.');
    }
    return RatesAvailable(cached, isStale: isStale(cached));
  }

  /// Fetches fresh rates and caches them. On failure, falls back to cached
  /// rates (flagged stale when old) or [RatesUnavailable].
  Future<ExchangeRateState> refresh() async {
    try {
      final latest = await source.fetchLatest();
      await cache.write(latest);
      return RatesAvailable(latest, isStale: isStale(latest));
    } on Object {
      final cached = cache.read();
      if (cached == null) {
        return const RatesUnavailable('Exchange rates are unavailable.');
      }
      return RatesAvailable(cached, isStale: isStale(cached));
    }
  }

  bool isStale(ExchangeRates rates) =>
      now().difference(rates.asOf) > staleAfter;
}
