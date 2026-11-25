import 'currency.dart';
import 'exchange_rates.dart';
import 'money.dart';

/// Converts money between currencies using an [ExchangeRates] snapshot.
///
/// This is the only place amounts change currency. Conversion uses exact
/// integer arithmetic on minor units and rounds half away from zero once,
/// at the end, to the target currency's precision.
abstract final class CurrencyConverter {
  /// Converts [amount] into [targetCurrency], or returns `null` when either
  /// currency has no rate. Same-currency amounts are returned unchanged.
  static Money? convert(
    Money amount,
    String targetCurrency,
    ExchangeRates rates,
  ) {
    final target = targetCurrency.toUpperCase();
    if (amount.currencyCode == target) return amount;

    final fromRate = rates.rateMicros(amount.currencyCode);
    final toRate = rates.rateMicros(target);
    if (fromRate == null || toRate == null) return null;

    final from = amount.currency;
    final to = Currency.of(target);

    // target = amount / fromRate * toRate, rescaled between precisions.
    final numerator =
        BigInt.from(amount.minorUnits) *
        BigInt.from(toRate) *
        BigInt.from(to.minorPerMajor);
    final denominator = BigInt.from(fromRate) * BigInt.from(from.minorPerMajor);
    return Money(_divideRoundHalfAwayFromZero(numerator, denominator), target);
  }

  static int _divideRoundHalfAwayFromZero(
    BigInt numerator,
    BigInt denominator,
  ) {
    final negative = numerator.isNegative != denominator.isNegative;
    final n = numerator.abs();
    final d = denominator.abs();
    final rounded = (n * BigInt.two + d) ~/ (d * BigInt.two);
    return (negative ? -rounded : rounded).toInt();
  }
}

/// Converts amounts into one display currency with the current rates, and
/// records whether any conversion happened (so totals can be labelled as
/// estimates).
class MoneyConverter {
  const MoneyConverter({required this.targetCurrency, required this.rateState});

  /// ISO code totals are expressed in.
  final String targetCurrency;

  final ExchangeRateState rateState;

  /// [amount] in [targetCurrency], or `null` if no rate is available.
  Money? convert(Money amount) {
    if (amount.currencyCode == targetCurrency) return amount;
    final rates = rateState.rates;
    if (rates == null) return null;
    return CurrencyConverter.convert(amount, targetCurrency, rates);
  }

  bool get usesMockRates => rateState.rates?.isMock ?? false;

  bool get ratesAreStale =>
      rateState is RatesAvailable && (rateState as RatesAvailable).isStale;
}
