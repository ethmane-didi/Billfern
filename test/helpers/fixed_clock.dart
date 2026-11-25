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

/// Fixed clock and an `en_US` device (display currency USD). Combine with
/// [preferenceOverrides] (or override the preference store yourself).
final List<Override> baseTestOverrides = [
  ...fixedClockOverrides,
  deviceLocaleProvider.overrideWithValue(const Locale('en', 'US')),
];

/// A fresh in-memory settings store per container: [mode] data and,
/// unless [onboarded] is false, onboarding already completed.
List<Override> preferenceOverrides({
  DataMode mode = DataMode.personal,
  bool onboarded = true,
}) => [
  appPreferenceStoreProvider.overrideWith(
    (ref) => InMemoryAppPreferenceStore({
      PreferenceKeys.dataMode: mode.name,
      if (onboarded) PreferenceKeys.onboardingCompleted: 'true',
    }),
  ),
];

/// An onboarded user with no subscriptions yet.
final List<Override> emptyAppTestOverrides = [
  ...baseTestOverrides,
  ...preferenceOverrides(),
];

/// An onboarded user viewing the mixed-currency **sample** data.
final List<Override> appTestOverrides = [
  ...baseTestOverrides,
  ...preferenceOverrides(mode: DataMode.sample),
];
