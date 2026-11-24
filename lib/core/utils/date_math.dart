/// Calendar arithmetic on local dates.
///
/// All helpers ignore the time of day. Day differences are computed in UTC so
/// daylight-saving transitions never produce off-by-one results.
abstract final class DateMath {
  /// [date] with the time component removed.
  static DateTime dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  /// First day of [date]'s month.
  static DateTime monthStart(DateTime date) => DateTime(date.year, date.month);

  /// Adds [months] calendar months, clamping the day to the target month's
  /// length (Jan 31 + 1 month → Feb 28/29).
  static DateTime addMonths(DateTime date, int months) {
    final monthIndex = date.year * 12 + (date.month - 1) + months;
    final year = monthIndex ~/ 12;
    final month = monthIndex % 12 + 1;
    final day = date.day.clamp(1, daysInMonth(year, month));
    return DateTime(year, month, day);
  }

  /// Number of days in [month] of [year].
  static int daysInMonth(int year, int month) =>
      DateTime.utc(year, month + 1, 0).day;

  /// Whole calendar days from [from] to [to] (negative when [to] is earlier).
  static int daysBetween(DateTime from, DateTime to) {
    final start = DateTime.utc(from.year, from.month, from.day);
    final end = DateTime.utc(to.year, to.month, to.day);
    return end.difference(start).inDays;
  }

  /// Whole calendar months from [from] to [to], ignoring the day.
  static int monthsBetween(DateTime from, DateTime to) =>
      (to.year - from.year) * 12 + (to.month - from.month);
}
