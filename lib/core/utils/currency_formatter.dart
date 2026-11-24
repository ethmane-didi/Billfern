import 'package:intl/intl.dart';

import '../constants/app_constants.dart';

/// Formatting helpers for money and percentages.
abstract final class CurrencyFormatter {
  /// Formats [amount] as currency, e.g. `$248.97`.
  static String format(
    num amount, {
    String currencyCode = AppConstants.defaultCurrencyCode,
    int decimalDigits = 2,
  }) {
    return NumberFormat.simpleCurrency(
      name: currencyCode,
      decimalDigits: decimalDigits,
    ).format(amount);
  }

  /// Converts integer minor units (cents) to a major-unit amount.
  ///
  /// Billfern stores money as integer cents so sums never accumulate
  /// floating-point error; convert only at the presentation boundary.
  static double fromCents(int cents) => cents / 100;

  /// Formats integer minor units, e.g. `24897` → `$248.97`.
  static String formatCents(
    int cents, {
    String currencyCode = AppConstants.defaultCurrencyCode,
    int decimalDigits = 2,
  }) {
    return format(
      fromCents(cents),
      currencyCode: currencyCode,
      decimalDigits: decimalDigits,
    );
  }

  /// Splits a formatted amount into its whole and fractional parts so they
  /// can be styled independently, e.g. `$248` and `.97`.
  static ({String whole, String fraction}) split(
    num amount, {
    String currencyCode = AppConstants.defaultCurrencyCode,
  }) {
    final formatter = NumberFormat.simpleCurrency(name: currencyCode);
    final formatted = formatter.format(amount);
    final separatorIndex = formatted.lastIndexOf(formatter.symbols.DECIMAL_SEP);
    if (separatorIndex == -1) {
      return (whole: formatted, fraction: '');
    }
    return (
      whole: formatted.substring(0, separatorIndex),
      fraction: formatted.substring(separatorIndex),
    );
  }

  /// Formats a percentage change with an explicit sign, e.g. `+4.5%` or
  /// `−8.2%`.
  static String signedPercent(double value, {int decimalDigits = 1}) {
    final magnitude = value.abs().toStringAsFixed(decimalDigits);
    if (value > 0) return '+$magnitude%';
    if (value < 0) return '−$magnitude%';
    return '$magnitude%';
  }
}
