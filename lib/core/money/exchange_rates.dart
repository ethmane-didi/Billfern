import 'package:flutter/foundation.dart';

/// A snapshot of exchange rates relative to [baseCurrency].
///
/// Each rate says how many units of a currency equal one unit of the base
/// (e.g. base USD, `NOK: 10.80`). Rates are stored as integer millionths so
/// conversions are exact and deterministic.
@immutable
class ExchangeRates {
  ExchangeRates({
    required this.baseCurrency,
    required Map<String, num> rates,
    required this.asOf,
    required this.source,
    this.isMock = false,
  }) : _micros = {
         baseCurrency: _microsPerUnit,
         for (final entry in rates.entries)
           entry.key.toUpperCase(): (entry.value * _microsPerUnit).round(),
       } {
    assert(
      _micros.values.every((rate) => rate > 0),
      'Exchange rates must be positive.',
    );
  }

  static const int _microsPerUnit = 1000000;

  final String baseCurrency;

  /// When the rates were published (or fetched).
  final DateTime asOf;

  /// Human-readable origin, e.g. "Mock rates".
  final String source;

  /// Development-only rates; totals using them must be labelled estimates.
  final bool isMock;

  final Map<String, int> _micros;

  /// Currencies with a known rate, including the base.
  Set<String> get currencies => _micros.keys.toSet();

  bool supports(String currencyCode) =>
      _micros.containsKey(currencyCode.toUpperCase());

  /// Units of [currencyCode] per base unit, in millionths, or `null`.
  int? rateMicros(String currencyCode) => _micros[currencyCode.toUpperCase()];

  /// Units of [currencyCode] per base unit, or `null` when unknown.
  double? rate(String currencyCode) {
    final micros = rateMicros(currencyCode);
    return micros == null ? null : micros / _microsPerUnit;
  }
}

/// The app's current view of exchange rates.
sealed class ExchangeRateState {
  const ExchangeRateState();

  /// Rates to convert with, if any (possibly stale).
  ExchangeRates? get rates;
}

/// Rates are available. [isStale] means they are older than the freshness
/// window; conversions still work but the UI should say so.
final class RatesAvailable extends ExchangeRateState {
  const RatesAvailable(this.rates, {this.isStale = false});

  @override
  final ExchangeRates rates;
  final bool isStale;
}

/// No usable rates (never fetched, or fetching failed with nothing cached).
final class RatesUnavailable extends ExchangeRateState {
  const RatesUnavailable(this.reason);

  final String reason;

  @override
  ExchangeRates? get rates => null;
}
