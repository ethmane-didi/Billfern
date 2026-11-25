import 'package:intl/intl.dart';

/// Human-readable date labels.
abstract final class DateLabels {
  /// "Today", "Tomorrow" or "In 5 days".
  static String relativeDays(int days) {
    if (days <= 0) return 'Today';
    if (days == 1) return 'Tomorrow';
    return 'In $days days';
  }

  /// Short calendar date, e.g. "Nov 27".
  static String shortDate(DateTime date) => DateFormat.MMMd().format(date);

  /// Abbreviated month, e.g. "Nov".
  static String shortMonth(DateTime date) => DateFormat.MMM().format(date);

  /// Full month name, e.g. "November".
  static String month(DateTime date) => DateFormat.MMMM().format(date);

  /// Header date, e.g. "Tuesday, Nov 24".
  static String weekdayDate(DateTime date) =>
      DateFormat('EEEE, MMM d').format(date);
}
