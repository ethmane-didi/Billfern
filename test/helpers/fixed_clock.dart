import 'package:billfern/shared/providers/clock_provider.dart';
import 'package:flutter_riverpod/misc.dart';

/// Fixed "now" used by tests: Tuesday 24 November 2026, 09:00.
final DateTime fixedNow = DateTime(2026, 11, 24, 9);

/// Provider overrides pinning the clock to [fixedNow].
final List<Override> fixedClockOverrides = [
  clockProvider.overrideWithValue(() => fixedNow),
];
