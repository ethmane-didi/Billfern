import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The current time. Override in tests for deterministic dates.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Today's date (no time component), read once from [clockProvider].
final todayProvider = Provider<DateTime>((ref) {
  final now = ref.watch(clockProvider)();
  return DateTime(now.year, now.month, now.day);
});
