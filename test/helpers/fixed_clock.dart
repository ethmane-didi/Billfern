import 'dart:ui';

import 'package:billfern/shared/data/app_preference_store.dart';
import 'package:billfern/shared/providers/clock_provider.dart';
import 'package:billfern/shared/providers/currency_providers.dart';
import 'package:billfern/shared/providers/subscription_providers.dart';
import 'package:flutter_riverpod/misc.dart';

/// Fixed "now" used by tests: Tuesday 24 November 2026, 09:00.
final DateTime fixedNow = DateTime(2026, 11, 24, 9);

/// Provider overrides pinning the clock to [fixedNow].
final List<Override> fixedClockOverrides = [
  clockProvider.overrideWithValue(() => fixedNow),
];

/// Deterministic app environment for a first launch: fixed clock, an
/// `en_US` device (display currency USD) and no subscriptions yet.
final List<Override> emptyAppTestOverrides = [
  ...fixedClockOverrides,
  deviceLocaleProvider.overrideWithValue(const Locale('en', 'US')),
];

/// [emptyAppTestOverrides] showing the mixed-currency **sample** data. A
/// fresh in-memory preference store is created per container.
final List<Override> appTestOverrides = [
  ...emptyAppTestOverrides,
  appPreferenceStoreProvider.overrideWith(
    (ref) => InMemoryAppPreferenceStore({
      PreferenceKeys.dataMode: DataMode.sample.name,
    }),
  ),
];
