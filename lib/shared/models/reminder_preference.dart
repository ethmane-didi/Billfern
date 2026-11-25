/// When to remind the user before a renewal.
///
/// Stored with each subscription; notification scheduling arrives in a
/// later phase. The enum [name] is the persisted key — never rename values.
enum ReminderPreference {
  none('No reminder', null),
  sameDay('On the renewal day', 0),
  oneDayBefore('1 day before', 1),
  threeDaysBefore('3 days before', 3),
  oneWeekBefore('1 week before', 7);

  const ReminderPreference(this.label, this.daysBefore);

  final String label;

  /// Days before the renewal to remind, or `null` for no reminder.
  final int? daysBefore;

  static ReminderPreference fromName(Object? name) => values.firstWhere(
    (value) => value.name == name,
    orElse: () => oneDayBefore,
  );
}
