import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/utils/currency_formatter.dart';
import 'shared/data/app_preference_store.dart';
import 'shared/data/currency_preference_store.dart';
import 'shared/data/subscription_repository.dart';
import 'shared/providers/currency_providers.dart';
import 'shared/providers/subscription_providers.dart';

/// File name of the local database inside the app documents directory.
const String databaseFileName = 'billfern.db';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Numbers (grouping, decimal separator, symbol position) follow the device.
  CurrencyFormatter.configure(PlatformDispatcher.instance.locale);

  // Small settings: loaded once so reads are synchronous afterwards.
  final preferences = await SharedPreferencesWithCache.create(
    cacheOptions: SharedPreferencesWithCacheOptions(
      allowList: {
        ...SharedPreferencesCurrencyPreferenceStore.keys,
        ...PreferenceKeys.all,
      },
    ),
  );

  // The user's subscriptions: one record each in a local sembast database.
  final documents = await getApplicationDocumentsDirectory();
  final database = await databaseFactoryIo.openDatabase(
    '${documents.path}/$databaseFileName',
  );
  final subscriptions = await SembastSubscriptionRepository.open(database);

  runApp(
    ProviderScope(
      overrides: [
        currencyPreferenceStoreProvider.overrideWithValue(
          SharedPreferencesCurrencyPreferenceStore(preferences),
        ),
        appPreferenceStoreProvider.overrideWithValue(
          SharedPreferencesAppStore(preferences),
        ),
        personalSubscriptionRepositoryProvider.overrideWithValue(subscriptions),
      ],
      child: const BillfernApp(),
    ),
  );
}
