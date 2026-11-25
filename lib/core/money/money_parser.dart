import 'currency.dart';
import 'money.dart';

/// Result of parsing user-entered money.
sealed class MoneyParseResult {
  const MoneyParseResult();
}

final class ParsedMoney extends MoneyParseResult {
  const ParsedMoney(this.money);
  final Money money;
}

final class MoneyParseError extends MoneyParseResult {
  const MoneyParseError(this.message);
  final String message;
}

/// Parses amounts typed by the user into exact minor units, without going
/// through floating point.
///
/// Accepts `199`, `199.5`, `199,50`, `1 299.00`, `1,299.00` and `1.299,00`.
/// The last `.` or `,` followed by at most the currency's decimal digits is
/// the decimal separator; other separators and spaces are grouping.
abstract final class MoneyParser {
  /// Largest accepted amount in major units, to catch typos.
  static const int maxMajorUnits = 1000000;

  static MoneyParseResult parse(String input, String currencyCode) {
    final currency = Currency.of(currencyCode);
    final text = input.trim().replaceAll(RegExp(r'[\s  ]'), '');
    if (text.isEmpty) return const MoneyParseError('Enter an amount');
    if (text.startsWith('-')) {
      return const MoneyParseError('Amount cannot be negative');
    }
    if (!RegExp(r'^[\d.,]+$').hasMatch(text)) {
      return const MoneyParseError('Use digits only, e.g. 12.99');
    }

    final lastSeparator = text.lastIndexOf(RegExp('[.,]'));
    var whole = text;
    var fraction = '';
    if (lastSeparator != -1) {
      final tail = text.substring(lastSeparator + 1);
      final isDecimal =
          tail.length <= currency.decimalDigits &&
          // "1,299" with two-decimal currencies is grouping, not 1.299.
          !(tail.length == 3 && currency.decimalDigits < 3);
      if (isDecimal && currency.decimalDigits > 0) {
        whole = text.substring(0, lastSeparator);
        fraction = tail;
      } else if (tail.length != 3) {
        return MoneyParseError(
          currency.decimalDigits == 0
              ? '${currency.code} has no decimals'
              : 'Use at most ${currency.decimalDigits} decimals',
        );
      }
    }

    final digits = whole.replaceAll(RegExp('[.,]'), '');
    if (digits.isEmpty && fraction.isEmpty) {
      return const MoneyParseError('Enter an amount');
    }
    final major = int.tryParse(digits.isEmpty ? '0' : digits);
    if (major == null || major > maxMajorUnits) {
      return const MoneyParseError('Amount is too large');
    }
    final minorFraction = int.parse(
      fraction.padRight(currency.decimalDigits, '0').isEmpty
          ? '0'
          : fraction.padRight(currency.decimalDigits, '0'),
    );
    final minor = major * currency.minorPerMajor + minorFraction;
    if (minor == 0) {
      return const MoneyParseError('Amount must be greater than zero');
    }
    return ParsedMoney(Money(minor, currency.code));
  }

  /// Formats minor units for an input field (no symbol, no grouping),
  /// e.g. `19900` NOK → `199.00`.
  static String toInput(Money money) {
    final digits = money.currency.decimalDigits;
    if (digits == 0) return '${money.minorUnits}';
    final major = money.minorUnits ~/ money.currency.minorPerMajor;
    final minor = (money.minorUnits % money.currency.minorPerMajor)
        .toString()
        .padLeft(digits, '0');
    return '$major.$minor';
  }
}
