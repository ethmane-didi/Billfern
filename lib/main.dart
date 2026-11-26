import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show Supabase, FlutterAuthClientOptions;

import 'app.dart';
import 'core/config/supabase_config.dart';
import 'core/network/timeout_http_client.dart';
import 'core/utils/currency_formatter.dart';
import 'features/account/data/auth_repository.dart';
import 'features/account/data/supabase_auth_repository.dart';
import 'features/account/presentation/providers/account_providers.dart';
import 'features/sync/data/connectivity_plus_signal.dart';
import 'features/sync/data/supabase_sync_remote.dart';
import 'features/sync/domain/sync_remote.dart';
import 'features/sync/presentation/providers/sync_providers.dart';
import 'shared/data/app_preference_store.dart';
import 'shared/data/currency_preference_store.dart';
import 'shared/data/local_store.dart';
import 'shared/providers/currency_providers.dart';
import 'shared/providers/local_store_providers.dart';
import 'shared/providers/subscription_providers.dart';

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

  // Optional backend. Without configuration (or if initialisation fails)
  // Billfern runs fully local-only.
  final config = SupabaseConfig.fromEnvironment();
  AuthRepository auth = const LocalOnlyAuthRepository();
  SyncRemote? remote;
  if (config.isConfigured) {
    try {
      await Supabase.initialize(
        url: config.url,
        publishableKey: config.publishableKey,
        // Time-limited requests: a request (or shared token refresh) that
        // hangs when the network drops must not block sync after reconnecting.
        httpClient: TimeoutHttpClient(http.Client()),
        authOptions: const FlutterAuthClientOptions(
          localStorage: SecureSessionStorage(),
          // Email codes are typed in; no deep-link callbacks are used.
          detectSessionInUri: false,
        ),
      );
      final client = Supabase.instance.client;
      auth = SupabaseAuthRepository(client);
      remote = SupabaseSyncRemote(client);
    } on Object catch (error) {
      // Never log configuration values or tokens.
      debugPrint('Cloud sync unavailable (${error.runtimeType}); local-only.');
    }
  }

  // Each identity has its own database file; open the one for the restored
  // session (or the guest database).
  final documents = await getApplicationDocumentsDirectory();
  final opener = SembastLocalStoreOpener(databaseFactoryIo, documents.path);
  final userId = auth.currentUser?.id;
  final initialStore = await opener.open(
    userId == null ? LocalIdentity.guest : LocalIdentity.account(userId),
  );

  runApp(
    ProviderScope(
      overrides: [
        currencyPreferenceStoreProvider.overrideWithValue(
          SharedPreferencesCurrencyPreferenceStore(preferences),
        ),
        appPreferenceStoreProvider.overrideWithValue(
          SharedPreferencesAppStore(preferences),
        ),
        supabaseConfigProvider.overrideWithValue(config),
        authRepositoryProvider.overrideWithValue(auth),
        syncRemoteProvider.overrideWithValue(remote),
        // Connectivity is only watched when cloud sync is possible (and
        // only while signed in; see SyncController).
        if (remote != null)
          connectivitySignalProvider.overrideWithValue(
            ConnectivityPlusSignal(),
          ),
        localStoreOpenerProvider.overrideWithValue(opener),
        initialLocalStoreProvider.overrideWithValue(initialStore),
      ],
      child: const BillfernApp(),
    ),
  );
}
