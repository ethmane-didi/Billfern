import 'dart:ui';

import 'package:billfern/core/money/currency.dart';
import 'package:billfern/core/money/currency_converter.dart';
import 'package:billfern/core/money/exchange_rate_repository.dart';
import 'package:billfern/core/money/exchange_rates.dart';
import 'package:billfern/core/money/locale_currency.dart';
import 'package:billfern/core/money/money.dart';
import 'package:flutter_test/flutter_test.dart';

final _rates = ExchangeRates(
  baseCurrency: 'USD',
  rates: const {'NOK': 10.80, 'EUR': 0.92, 'JPY': 150},
  asOf: DateTime(2026, 11, 24),
  source: 'Test',
);

void main() {
  group('Currency', () {
    test('lists the nine supported currencies', () {
      expect(Currency.supported.map((c) => c.code), [
        'USD',
        'EUR',
        'NOK',
        'GBP',
        'SEK',
        'DKK',
        'CHF',
        'CAD',
        'AUD',
      ]);
      expect(Currency.supported.every((c) => c.decimalDigits == 2), isTrue);
    });

    test('derives other ISO 4217 currencies from intl', () {
      final jpy = Currency.of('jpy');
      expect(jpy.code, 'JPY');
      expect(jpy.decimalDigits, 0);
      expect(jpy.minorPerMajor, 1);
      expect(Currency.isSupported('JPY'), isFalse);
    });
  });

  group('Money', () {
    test('adds and subtracts within one currency', () {
      expect(
        const Money(1050, 'USD') + const Money(250, 'USD'),
        const Money(1300, 'USD'),
      );
      expect(
        const Money(1050, 'USD') - const Money(2000, 'USD'),
        const Money(-950, 'USD'),
      );
    });

    test('never combines different currencies directly', () {
      expect(
        () => const Money(100, 'USD') + const Money(100, 'NOK'),
        throwsA(isA<CurrencyMismatchError>()),
      );
      expect(
        () => Money.sum(const [Money(1, 'USD'), Money(1, 'EUR')], 'USD'),
        throwsA(isA<CurrencyMismatchError>()),
      );
      expect(
        () => const Money(1, 'USD').compareTo(const Money(1, 'EUR')),
        throwsA(isA<CurrencyMismatchError>()),
      );
    });

    test('rounds half away from zero', () {
      expect(Money.fromMajor(15.495, 'USD'), const Money(1550, 'USD'));
      expect(Money.fromMajor(-0.005, 'USD'), const Money(-1, 'USD'));
      expect(
        const Money(8388, 'USD').divideRounded(12),
        const Money(699, 'USD'),
      );
      expect(
        const Money(1001, 'USD').divideRounded(12),
        const Money(83, 'USD'),
      );
      expect(
        const Money(1002, 'USD').divideRounded(12),
        const Money(84, 'USD'),
      );
    });

    test('respects currency precision', () {
      expect(Money.fromMajor(1500.4, 'JPY'), const Money(1500, 'JPY'));
      expect(const Money(19900, 'NOK').majorUnits, 199.0);
    });
  });

  group('CurrencyConverter', () {
    test('returns same-currency amounts unchanged', () {
      const amount = Money(19900, 'NOK');
      expect(CurrencyConverter.convert(amount, 'NOK', _rates), same(amount));
    });

    test('converts through the base currency', () {
      expect(
        CurrencyConverter.convert(const Money(10000, 'USD'), 'NOK', _rates),
        const Money(108000, 'NOK'),
      );
      expect(
        CurrencyConverter.convert(const Money(19900, 'NOK'), 'USD', _rates),
        const Money(1843, 'USD'), // 18.4259… → 18.43
      );
      expect(
        CurrencyConverter.convert(const Money(1500, 'EUR'), 'NOK', _rates),
        const Money(17609, 'NOK'), // 15 / 0.92 × 10.8 = 176.087 → 176.09
      );
    });

    test('rescales between precisions', () {
      expect(
        CurrencyConverter.convert(const Money(1000, 'USD'), 'JPY', _rates),
        const Money(1500, 'JPY'),
      );
      expect(
        CurrencyConverter.convert(const Money(1500, 'JPY'), 'USD', _rates),
        const Money(1000, 'USD'),
      );
    });

    test('rounds exact halves away from zero', () {
      final rates = ExchangeRates(
        baseCurrency: 'USD',
        rates: const {'EUR': 0.5},
        asOf: DateTime(2026),
        source: 'Test',
      );
      // 1 cent × 0.5 = 0.5 cent → 1 cent; −1 → −1.
      expect(
        CurrencyConverter.convert(const Money(1, 'USD'), 'EUR', rates),
        const Money(1, 'EUR'),
      );
      expect(
        CurrencyConverter.convert(const Money(-1, 'USD'), 'EUR', rates),
        const Money(-1, 'EUR'),
      );
    });

    test('returns null when a rate is missing', () {
      expect(
        CurrencyConverter.convert(const Money(100, 'GBP'), 'USD', _rates),
        isNull,
      );
      expect(
        CurrencyConverter.convert(const Money(100, 'USD'), 'GBP', _rates),
        isNull,
      );
    });

    test('handles large amounts without overflow', () {
      final rates = ExchangeRates(
        baseCurrency: 'USD',
        rates: const {'IDR': 16000},
        asOf: DateTime(2026),
        source: 'Test',
      );
      expect(
        CurrencyConverter.convert(
          const Money(100000000000, 'USD'),
          'IDR',
          rates,
        ),
        // intl formats IDR with zero decimals.
        const Money(16000000000000, 'IDR'),
      );
    });
  });

  group('MoneyConverter', () {
    test('converts with available rates and reports mock usage', () {
      final converter = MoneyConverter(
        targetCurrency: 'USD',
        rateState: RatesAvailable(
          MockExchangeRateSource(asOf: _asOf).snapshot(),
        ),
      );
      expect(converter.usesMockRates, isTrue);
      expect(converter.ratesAreStale, isFalse);
      expect(converter.convert(const Money(19900, 'NOK')), isNotNull);
    });

    test('only same-currency amounts survive unavailable rates', () {
      const converter = MoneyConverter(
        targetCurrency: 'USD',
        rateState: RatesUnavailable('offline'),
      );
      expect(
        converter.convert(const Money(500, 'USD')),
        const Money(500, 'USD'),
      );
      expect(converter.convert(const Money(500, 'NOK')), isNull);
    });
  });

  group('ExchangeRateRepository', () {
    ExchangeRateRepository repo(
      ExchangeRateSource source,
      ExchangeRateCache cache,
    ) => ExchangeRateRepository(
      source: source,
      cache: cache,
      now: () => DateTime(2026, 11, 24, 12),
    );

    test('is unavailable before any rates are cached', () {
      final r = repo(
        MockExchangeRateSource(asOf: _asOf),
        InMemoryExchangeRateCache(),
      );
      expect(r.cachedState(), isA<RatesUnavailable>());
    });

    test('refresh caches fresh rates', () async {
      final cache = InMemoryExchangeRateCache();
      final r = repo(MockExchangeRateSource(asOf: _asOf), cache);
      final state = await r.refresh();
      expect(state, isA<RatesAvailable>());
      expect((state as RatesAvailable).isStale, isFalse);
      expect(cache.read(), isNotNull);
    });

    test('marks rates older than 24 hours as stale', () {
      final old = ExchangeRates(
        baseCurrency: 'USD',
        rates: const {'NOK': 10.8},
        asOf: DateTime(2026, 11, 20),
        source: 'Cached',
      );
      final state = repo(
        MockExchangeRateSource(asOf: _asOf),
        InMemoryExchangeRateCache(old),
      ).cachedState();
      expect((state as RatesAvailable).isStale, isTrue);
    });

    test('a failed refresh without cache is unavailable', () async {
      final state = await repo(
        _Failing(),
        InMemoryExchangeRateCache(),
      ).refresh();
      expect(state, isA<RatesUnavailable>());
    });
  });

  group('LocaleCurrency', () {
    test('suggests the regional currency', () {
      expect(LocaleCurrency.suggest(const Locale('en', 'US')).code, 'USD');
      expect(LocaleCurrency.suggest(const Locale('nb', 'NO')).code, 'NOK');
      expect(LocaleCurrency.suggest(const Locale('sv', 'SE')).code, 'SEK');
      expect(LocaleCurrency.suggest(const Locale('da', 'DK')).code, 'DKK');
      expect(LocaleCurrency.suggest(const Locale('en', 'GB')).code, 'GBP');
      expect(LocaleCurrency.suggest(const Locale('de', 'CH')).code, 'CHF');
      expect(LocaleCurrency.suggest(const Locale('fr', 'CA')).code, 'CAD');
      expect(LocaleCurrency.suggest(const Locale('en', 'AU')).code, 'AUD');
    });

    test('maps euro-area countries to EUR', () {
      for (final country in ['DE', 'FR', 'ES', 'IT', 'NL', 'FI', 'IE']) {
        expect(LocaleCurrency.suggest(Locale('xx', country)).code, 'EUR');
      }
    });

    test('uses the language when the region is missing', () {
      expect(LocaleCurrency.suggest(const Locale('nb')).code, 'NOK');
      expect(LocaleCurrency.suggest(const Locale('sv')).code, 'SEK');
    });

    test('falls back to USD for unsupported regions', () {
      expect(LocaleCurrency.suggest(const Locale('ja', 'JP')).code, 'USD');
      expect(LocaleCurrency.suggest(const Locale('en')).code, 'USD');
    });
  });
}

final DateTime _asOf = DateTime(2026, 11, 24);

class _Failing implements ExchangeRateSource {
  @override
  Future<ExchangeRates> fetchLatest() => Future.error(StateError('offline'));
}
