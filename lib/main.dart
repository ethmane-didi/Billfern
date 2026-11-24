import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/utils/currency_formatter.dart';
import 'shared/data/currency_preference_store.dart';
import 'shared/providers/currency_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Numbers (grouping, decimal separator, symbol position) follow the device.
  CurrencyFormatter.configure(PlatformDispatcher.instance.locale);

  // Load local preferences once so reads are synchronous afterwards.
  final preferences = await SharedPreferencesWithCache.create(
    cacheOptions: const SharedPreferencesWithCacheOptions(
      allowList: SharedPreferencesCurrencyPreferenceStore.keys,
    ),
  );

  runApp(
    ProviderScope(
      overrides: [
        currencyPreferenceStoreProvider.overrideWithValue(
          SharedPreferencesCurrencyPreferenceStore(preferences),
        ),
      ],
      child: const BillfernApp(),
    ),
  );
}
