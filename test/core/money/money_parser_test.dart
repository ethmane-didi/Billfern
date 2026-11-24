import 'package:billfern/core/money/money.dart';
import 'package:billfern/core/money/money_parser.dart';
import 'package:flutter_test/flutter_test.dart';

Money? _ok(String input, [String currency = 'USD']) =>
    switch (MoneyParser.parse(input, currency)) {
      ParsedMoney(:final money) => money,
      MoneyParseError() => null,
    };

String? _error(String input, [String currency = 'USD']) =>
    switch (MoneyParser.parse(input, currency)) {
      ParsedMoney() => null,
      MoneyParseError(:final message) => message,
    };

void main() {
  test('parses whole and decimal amounts exactly', () {
    expect(_ok('199'), const Money(19900, 'USD'));
    expect(_ok('15.49'), const Money(1549, 'USD'));
    expect(_ok('15.5'), const Money(1550, 'USD'));
    expect(_ok('0.10'), const Money(10, 'USD'));
    expect(_ok('199,00', 'NOK'), const Money(19900, 'NOK'));
    expect(_ok(' 12.99 '), const Money(1299, 'USD'));
  });

  test('understands grouping separators', () {
    expect(_ok('1,299.00'), const Money(129900, 'USD'));
    expect(_ok('1.299,00', 'EUR'), const Money(129900, 'EUR'));
    expect(_ok('1 299,50', 'SEK'), const Money(129950, 'SEK'));
    expect(_ok('1,299'), const Money(129900, 'USD'));
  });

  test('respects currency precision', () {
    expect(_ok('1500', 'JPY'), const Money(1500, 'JPY'));
    expect(_error('15.4999'), 'Use at most 2 decimals');
    // A three-digit tail is thousands grouping, as in many locales.
    expect(_ok('15.499'), const Money(1549900, 'USD'));
    expect(_error('15.5', 'JPY'), 'JPY has no decimals');
  });

  test('rejects invalid input', () {
    expect(_error(''), 'Enter an amount');
    expect(_error('-5'), 'Amount cannot be negative');
    expect(_error('12a'), 'Use digits only, e.g. 12.99');
    expect(_error('0'), 'Amount must be greater than zero');
    expect(_error('0.00'), 'Amount must be greater than zero');
    expect(_error('99999999'), 'Amount is too large');
  });

  test('toInput formats minor units for editing', () {
    expect(MoneyParser.toInput(const Money(19900, 'NOK')), '199.00');
    expect(MoneyParser.toInput(const Money(5, 'USD')), '0.05');
    expect(MoneyParser.toInput(const Money(1500, 'JPY')), '1500');
    expect(
      _ok(MoneyParser.toInput(const Money(1549, 'EUR')), 'EUR'),
      const Money(1549, 'EUR'),
    );
  });
}
