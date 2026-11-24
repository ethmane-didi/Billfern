import 'dart:ui';

import 'package:billfern/core/money/money.dart';
import 'package:billfern/core/utils/currency_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

/// Normalises non-breaking spaces so expectations stay readable.
String _fmt(Money money, {String? locale, bool showDecimals = true}) =>
    CurrencyFormatter.format(
      money,
      locale: locale,
      showDecimals: showDecimals,
    ).replaceAll(' ', ' ').replaceAll(' ', ' ');

void main() {
  tearDown(CurrencyFormatter.reset);

  group('format (en_US)', () {
    test('uses each currency symbol', () {
      expect(_fmt(const Money(24897, 'USD')), r'$248.97');
      expect(_fmt(const Money(1500, 'EUR')), '€15.00');
      expect(_fmt(const Money(1199, 'GBP')), '£11.99');
      expect(_fmt(const Money(19900, 'NOK')), 'kr 199.00');
      expect(_fmt(const Money(19900, 'SEK')), 'kr 199.00');
      expect(_fmt(const Money(19900, 'DKK')), 'kr 199.00');
      expect(_fmt(const Money(1500, 'CHF')), 'CHF 15.00');
      expect(_fmt(const Money(1500, 'CAD')), r'CA$15.00');
      expect(_fmt(const Money(1500, 'AUD')), r'A$15.00');
    });

    test('groups thousands and can hide decimals', () {
      expect(_fmt(const Money(298764, 'USD')), r'$2,987.64');
      expect(_fmt(const Money(298764, 'USD'), showDecimals: false), r'$2,988');
    });

    test('respects zero-decimal currencies', () {
      expect(_fmt(const Money(1500, 'JPY')), '¥1,500');
    });
  });

  group('locale-aware formatting', () {
    test('Norwegian places the symbol after the amount', () {
      expect(_fmt(const Money(123450, 'NOK'), locale: 'nb_NO'), '1 234,50 kr');
    });

    test('German uses comma decimals for euros', () {
      expect(_fmt(const Money(123450, 'EUR'), locale: 'de_DE'), '1.234,50 €');
    });

    test('configure follows the device locale', () {
      CurrencyFormatter.configure(const Locale('nb', 'NO'));
      expect(CurrencyFormatter.locale, startsWith('nb'));
      expect(_fmt(const Money(19900, 'NOK')), '199,00 kr');
    });

    test('unknown locales fall back gracefully', () {
      expect(
        CurrencyFormatter.resolveLocale(const Locale('xx', 'YY')),
        'en_US',
      );
    });
  });

  test('split separates the fraction for two-tone styling', () {
    final parts = CurrencyFormatter.split(const Money(24897, 'USD'));
    expect(parts.whole, r'$248');
    expect(parts.fraction, '.97');
  });

  test('signed formats changes', () {
    expect(CurrencyFormatter.signed(const Money(-999, 'USD')), r'−$9.99');
    expect(CurrencyFormatter.signed(const Money(999, 'USD')), r'+$9.99');
  });

  test('signedPercent adds explicit signs', () {
    expect(CurrencyFormatter.signedPercent(4.5), '+4.5%');
    expect(CurrencyFormatter.signedPercent(-8.2), '−8.2%');
    expect(CurrencyFormatter.signedPercent(0), '0.0%');
  });
}
