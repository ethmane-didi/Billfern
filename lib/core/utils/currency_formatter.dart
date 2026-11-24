import 'dart:ui';

import 'package:intl/intl.dart';

import '../money/money.dart';

/// Locale-aware formatting for [Money] and percentages.
///
/// Every amount carries its own currency, so there is no default currency
/// here. The number locale (grouping, decimal separator, symbol position) is
/// set once at startup from the device via [configure]; tests use `en_US`.
abstract final class CurrencyFormatter {
  static String _locale = 'en_US';

  /// The `intl` locale used for numbers, e.g. `nb_NO`.
  static String get locale => _locale;

  /// Uses [deviceLocale] for number formatting when `intl` knows it.
  static void configure(Locale deviceLocale) {
    _locale = resolveLocale(deviceLocale);
  }

  /// Restores the default (`en_US`). Intended for tests.
  static void reset() => _locale = 'en_US';

  /// The closest `intl` number locale for [locale], or `en_US`.
  static String resolveLocale(Locale locale) {
    final candidate = Intl.canonicalizedLocale(locale.toString());
    return NumberFormat.localeExists(candidate)
        ? candidate
        : (NumberFormat.localeExists(locale.languageCode)
              ? locale.languageCode
              : 'en_US');
  }

  /// Formats [money], e.g. `$248.97`, `199,00 kr` (nb_NO) or `kr 199.00`
  /// (en_US). Set [showDecimals] to false for whole-unit summaries.
  static String format(
    Money money, {
    bool showDecimals = true,
    String? locale,
  }) {
    final currency = money.currency;
    final digits = showDecimals ? currency.decimalDigits : 0;
    final formatted = NumberFormat.currency(
      locale: locale ?? _locale,
      name: currency.code,
      symbol: currency.symbol,
      decimalDigits: digits,
    ).format(money.majorUnits);
    return _spaceAlphabeticSymbol(formatted, currency.symbol);
  }

  /// Splits a formatted amount at its decimal separator so the parts can be
  /// styled independently, e.g. `$248` + `.97` or `199` + `,00 kr`.
  static ({String whole, String fraction}) split(Money money) {
    final formatted = format(money);
    final separator = NumberFormat.decimalPattern(_locale).symbols.DECIMAL_SEP;
    if (money.currency.decimalDigits == 0) {
      return (whole: formatted, fraction: '');
    }
    final index = formatted.lastIndexOf(separator);
    if (index == -1) return (whole: formatted, fraction: '');
    return (
      whole: formatted.substring(0, index),
      fraction: formatted.substring(index),
    );
  }

  /// Formats a signed change, e.g. `+$9.99` or `−kr 12.00`.
  static String signed(Money money, {bool showDecimals = true}) {
    final magnitude = format(money.abs(), showDecimals: showDecimals);
    if (money.isNegative) return '−$magnitude';
    if (money.isZero) return magnitude;
    return '+$magnitude';
  }

  /// Formats a percentage change with an explicit sign, e.g. `+4.5%` or
  /// `−8.2%`.
  static String signedPercent(double value, {int decimalDigits = 1}) {
    final magnitude = value.abs().toStringAsFixed(decimalDigits);
    if (value > 0) return '+$magnitude%';
    if (value < 0) return '−$magnitude%';
    return '$magnitude%';
  }

  /// `intl` places symbols without spacing. When the letter side of a symbol
  /// touches the digits ("kr199", "199CHF") a non-breaking space keeps it
  /// readable; symbols ending in a sign ("CA$15") stay attached.
  static String _spaceAlphabeticSymbol(String formatted, String symbol) {
    const nbsp = '\u00A0';
    final index = formatted.indexOf(symbol);
    if (index == -1 || symbol.isEmpty) return formatted;
    final after = index + symbol.length;
    final letter = RegExp('[A-Za-z]');
    final digitOrSign = RegExp(r'[\d\-−]');

    if (letter.hasMatch(symbol[symbol.length - 1]) &&
        after < formatted.length &&
        digitOrSign.hasMatch(formatted[after])) {
      return '${formatted.substring(0, after)}$nbsp${formatted.substring(after)}';
    }
    if (letter.hasMatch(symbol[0]) &&
        index > 0 &&
        RegExp(r'\d').hasMatch(formatted[index - 1])) {
      return '${formatted.substring(0, index)}$nbsp${formatted.substring(index)}';
    }
    return formatted;
  }
}
