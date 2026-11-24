import 'dart:ui';

import 'package:billfern/shared/providers/clock_provider.dart';
import 'package:billfern/shared/providers/currency_providers.dart';
import 'package:flutter_riverpod/misc.dart';

/// Fixed "now" used by tests: Tuesday 24 November 2026, 09:00.
final DateTime fixedNow = DateTime(2026, 11, 24, 9);

/// Provider overrides pinning the clock to [fixedNow].
final List<Override> fixedClockOverrides = [
  clockProvider.overrideWithValue(() => fixedNow),
];

/// Deterministic app environment: fixed clock and an `en_US` device, so the
/// suggested (and default) display currency is USD.
final List<Override> appTestOverrides = [
  ...fixedClockOverrides,
  deviceLocaleProvider.overrideWithValue(const Locale('en', 'US')),
];
