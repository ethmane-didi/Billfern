import 'package:flutter_test/flutter_test.dart';
import 'package:billfern/core/utils/currency_formatter.dart';

void main() {
  group('CurrencyFormatter', () {
    test('formats USD with two decimals by default', () {
      expect(CurrencyFormatter.format(248.97), r'$248.97');
      expect(CurrencyFormatter.format(1234.5), r'$1,234.50');
    });

    test('respects decimalDigits', () {
      expect(CurrencyFormatter.format(2987.64, decimalDigits: 0), r'$2,988');
    });

    test('splits whole and fractional parts', () {
      final parts = CurrencyFormatter.split(1248.97);
      expect(parts.whole, r'$1,248');
      expect(parts.fraction, '.97');
    });

    test('signs percentages', () {
      expect(CurrencyFormatter.signedPercent(4.5), '+4.5%');
      expect(CurrencyFormatter.signedPercent(-8.24), '−8.2%');
      expect(CurrencyFormatter.signedPercent(0), '0.0%');
    });
  });
}
