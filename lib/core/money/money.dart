import 'package:flutter/foundation.dart';

import 'currency.dart';

/// Thrown when amounts in different currencies are combined directly.
/// Convert first with `CurrencyConverter`.
class CurrencyMismatchError extends ArgumentError {
  CurrencyMismatchError(String a, String b)
    : super('Cannot combine $a and $b amounts without conversion.');
}

/// An amount of money in integer minor units of one currency.
///
/// Arithmetic is only defined between amounts of the same currency; mixing
/// currencies throws [CurrencyMismatchError].
@immutable
class Money implements Comparable<Money> {
  const Money(this.minorUnits, this.currencyCode);

  const Money.zero(this.currencyCode) : minorUnits = 0;

  /// Builds an amount from major units, rounding half away from zero to the
  /// currency's precision (e.g. `Money.fromMajor(15.495, 'USD')` → 15.50).
  factory Money.fromMajor(num major, String currencyCode) {
    final currency = Currency.of(currencyCode);
    return Money((major * currency.minorPerMajor).round(), currency.code);
  }

  /// Amount in the currency's smallest unit (cents, øre, …).
  final int minorUnits;

  /// ISO 4217 code.
  final String currencyCode;

  Currency get currency => Currency.of(currencyCode);

  /// Amount in major units. For display and charts only; never sum these.
  double get majorUnits => minorUnits / currency.minorPerMajor;

  bool get isZero => minorUnits == 0;
  bool get isNegative => minorUnits < 0;

  Money abs() => Money(minorUnits.abs(), currencyCode);

  Money operator -() => Money(-minorUnits, currencyCode);

  Money operator +(Money other) {
    _requireSameCurrency(other);
    return Money(minorUnits + other.minorUnits, currencyCode);
  }

  Money operator -(Money other) {
    _requireSameCurrency(other);
    return Money(minorUnits - other.minorUnits, currencyCode);
  }

  /// Multiplies by a whole number (e.g. 12 months).
  Money operator *(int factor) => Money(minorUnits * factor, currencyCode);

  /// Divides into whole minor units, rounding half away from zero.
  Money divideRounded(int divisor) =>
      Money((minorUnits / divisor).round(), currencyCode);

  /// Multiplies by `numerator / denominator` exactly, then rounds half away
  /// from zero to whole minor units (e.g. weekly → monthly: × 52 / 12).
  Money scaleRounded(int numerator, int denominator) {
    assert(denominator > 0);
    final product = BigInt.from(minorUnits) * BigInt.from(numerator);
    final d = BigInt.from(denominator);
    final rounded = (product.abs() * BigInt.two + d) ~/ (d * BigInt.two);
    return Money(
      (product.isNegative ? -rounded : rounded).toInt(),
      currencyCode,
    );
  }

  /// Sums [amounts], which must all be in [currencyCode].
  static Money sum(Iterable<Money> amounts, String currencyCode) =>
      amounts.fold(Money.zero(currencyCode), (total, amount) => total + amount);

  void _requireSameCurrency(Money other) {
    if (other.currencyCode != currencyCode) {
      throw CurrencyMismatchError(currencyCode, other.currencyCode);
    }
  }

  @override
  int compareTo(Money other) {
    _requireSameCurrency(other);
    return minorUnits.compareTo(other.minorUnits);
  }

  @override
  bool operator ==(Object other) =>
      other is Money &&
      other.minorUnits == minorUnits &&
      other.currencyCode == currencyCode;

  @override
  int get hashCode => Object.hash(minorUnits, currencyCode);

  @override
  String toString() => 'Money($minorUnits $currencyCode)';
}
