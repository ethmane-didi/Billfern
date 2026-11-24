import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

/// An ISO 4217 currency.
///
/// [supported] lists the currencies Billfern offers in pickers, with curated
/// display symbols. Any other ISO code still works through [Currency.of],
/// which derives the symbol and decimal precision from `intl`'s data, so new
/// currencies only need an entry in [supported] to appear in the UI.
@immutable
class Currency {
  const Currency({
    required this.code,
    required this.name,
    required this.symbol,
    required this.decimalDigits,
  });

  /// Upper-case ISO 4217 code, e.g. `NOK`.
  final String code;

  /// English display name, e.g. "Norwegian Krone".
  final String name;

  /// Display symbol. Unambiguous where it matters ("CA$", "A$").
  final String symbol;

  /// Number of minor-unit digits (2 for USD, 0 for JPY).
  final int decimalDigits;

  static const Currency usd = Currency(
    code: 'USD',
    name: 'US Dollar',
    symbol: r'$',
    decimalDigits: 2,
  );
  static const Currency eur = Currency(
    code: 'EUR',
    name: 'Euro',
    symbol: '€',
    decimalDigits: 2,
  );
  static const Currency nok = Currency(
    code: 'NOK',
    name: 'Norwegian Krone',
    symbol: 'kr',
    decimalDigits: 2,
  );
  static const Currency gbp = Currency(
    code: 'GBP',
    name: 'British Pound',
    symbol: '£',
    decimalDigits: 2,
  );
  static const Currency sek = Currency(
    code: 'SEK',
    name: 'Swedish Krona',
    symbol: 'kr',
    decimalDigits: 2,
  );
  static const Currency dkk = Currency(
    code: 'DKK',
    name: 'Danish Krone',
    symbol: 'kr',
    decimalDigits: 2,
  );
  static const Currency chf = Currency(
    code: 'CHF',
    name: 'Swiss Franc',
    symbol: 'CHF',
    decimalDigits: 2,
  );
  static const Currency cad = Currency(
    code: 'CAD',
    name: 'Canadian Dollar',
    symbol: r'CA$',
    decimalDigits: 2,
  );
  static const Currency aud = Currency(
    code: 'AUD',
    name: 'Australian Dollar',
    symbol: r'A$',
    decimalDigits: 2,
  );

  /// Currencies offered in the app, in picker order.
  static const List<Currency> supported = [
    usd,
    eur,
    nok,
    gbp,
    sek,
    dkk,
    chf,
    cad,
    aud,
  ];

  /// Used when nothing better is known.
  static const Currency fallback = usd;

  static final Map<String, Currency> _cache = {
    for (final currency in supported) currency.code: currency,
  };

  /// Whether [code] is offered in the app's currency pickers.
  static bool isSupported(String code) =>
      supported.any((currency) => currency.code == code.toUpperCase());

  /// Looks up [code], deriving unknown ISO 4217 currencies from `intl`.
  static Currency of(String code) {
    final normalized = code.trim().toUpperCase();
    return _cache.putIfAbsent(normalized, () {
      final format = NumberFormat.simpleCurrency(name: normalized);
      return Currency(
        code: normalized,
        name: normalized,
        symbol: format.currencySymbol,
        decimalDigits: format.decimalDigits ?? 2,
      );
    });
  }

  /// `10^decimalDigits`: minor units per major unit.
  int get minorPerMajor {
    var factor = 1;
    for (var i = 0; i < decimalDigits; i++) {
      factor *= 10;
    }
    return factor;
  }

  @override
  bool operator ==(Object other) => other is Currency && other.code == code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => code;
}
