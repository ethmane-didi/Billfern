import 'dart:ui';

import 'package:billfern/shared/data/currency_preference_store.dart';
import 'package:billfern/shared/providers/currency_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

ProviderContainer _container({
  Locale locale = const Locale('en', 'US'),
  CurrencyPreferenceStore? store,
}) {
  final container = ProviderContainer(
    overrides: [
      deviceLocaleProvider.overrideWithValue(locale),
      if (store != null)
        currencyPreferenceStoreProvider.overrideWithValue(store),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('preferred currency', () {
    test('defaults to the locale suggestion', () {
      expect(
        _container(locale: const Locale('nb', 'NO'))
            .read(preferredCurrencyProvider),
        'NOK',
      );
      expect(
        _container(locale: const Locale('de', 'DE'))
            .read(preferredCurrencyProvider),
        'EUR',
      );
    });

    test('a saved choice overrides the locale', () {
      final store = InMemoryCurrencyPreferenceStore('GBP');
      final c = _container(locale: const Locale('nb', 'NO'), store: store);
      expect(c.read(preferredCurrencyProvider), 'GBP');
      expect(c.read(preferredCurrencyProvider.notifier).isExplicit, isTrue);
    });

    test('ignores unsupported saved codes', () {
      final c = _container(store: InMemoryCurrencyPreferenceStore('XYZ'));
      expect(c.read(preferredCurrencyProvider), 'USD');
    });

    test('select updates state and persists', () async {
      final store = InMemoryCurrencyPreferenceStore();
      final c = _container(store: store);
      await c.read(preferredCurrencyProvider.notifier).select('sek');
      expect(c.read(preferredCurrencyProvider), 'SEK');
      expect(store.read(), 'SEK');

      // A new app session reads the saved value.
      expect(_container(store: store).read(preferredCurrencyProvider), 'SEK');
    });

    test('useSuggested clears the saved choice', () async {
      final store = InMemoryCurrencyPreferenceStore('CHF');
      final c = _container(locale: const Locale('da', 'DK'), store: store);
      await c.read(preferredCurrencyProvider.notifier).useSuggested();
      expect(c.read(preferredCurrencyProvider), 'DKK');
      expect(store.read(), isNull);
    });
  });

  group('SharedPreferencesCurrencyPreferenceStore', () {
    setUp(() {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
    });

    Future<SharedPreferencesWithCache> create() =>
        SharedPreferencesWithCache.create(
          cacheOptions: const SharedPreferencesWithCacheOptions(
            allowList: SharedPreferencesCurrencyPreferenceStore.keys,
          ),
        );

    test('persists across instances', () async {
      final first = SharedPreferencesCurrencyPreferenceStore(await create());
      expect(first.read(), isNull);
      await first.write('NOK');

      final second = SharedPreferencesCurrencyPreferenceStore(await create());
      expect(second.read(), 'NOK');

      await second.clear();
      expect(
        SharedPreferencesCurrencyPreferenceStore(await create()).read(),
        isNull,
      );
    });
  });
}
