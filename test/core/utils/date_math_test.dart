import 'package:billfern/core/utils/date_math.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DateMath.addMonths', () {
    test('clamps to the end of shorter months', () {
      expect(
        DateMath.addMonths(DateTime(2026, 1, 31), 1),
        DateTime(2026, 2, 28),
      );
      expect(
        DateMath.addMonths(DateTime(2028, 1, 31), 1),
        DateTime(2028, 2, 29),
      );
    });

    test('crosses year boundaries in both directions', () {
      expect(
        DateMath.addMonths(DateTime(2026, 11, 15), 3),
        DateTime(2027, 2, 15),
      );
      expect(
        DateMath.addMonths(DateTime(2026, 2, 15), -3),
        DateTime(2025, 11, 15),
      );
    });
  });

  test('daysBetween ignores time of day', () {
    expect(
      DateMath.daysBetween(
        DateTime(2026, 11, 24, 23),
        DateTime(2026, 11, 25, 1),
      ),
      1,
    );
    expect(
      DateMath.daysBetween(DateTime(2026, 11, 24), DateTime(2026, 11, 20)),
      -4,
    );
  });

  test('monthsBetween counts calendar months', () {
    expect(
      DateMath.monthsBetween(DateTime(2025, 12, 31), DateTime(2026, 1, 1)),
      1,
    );
  });
}
