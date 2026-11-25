import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's preferred display currency.
abstract interface class CurrencyPreferenceStore {
  /// The saved ISO code, or `null` when the user never chose one.
  String? read();

  Future<void> write(String currencyCode);

  Future<void> clear();
}

/// Non-persistent store, used by default and in tests.
class InMemoryCurrencyPreferenceStore implements CurrencyPreferenceStore {
  InMemoryCurrencyPreferenceStore([this._code]);

  String? _code;

  @override
  String? read() => _code;

  @override
  Future<void> write(String currencyCode) async => _code = currencyCode;

  @override
  Future<void> clear() async => _code = null;
}

/// Device-local store backed by `shared_preferences`.
///
/// Uses a [SharedPreferencesWithCache] so reads are synchronous after the
/// one-time async creation in `main`.
class SharedPreferencesCurrencyPreferenceStore
    implements CurrencyPreferenceStore {
  const SharedPreferencesCurrencyPreferenceStore(this._preferences);

  static const String key = 'preferred_currency';

  /// Keys this store reads, for [SharedPreferencesWithCacheOptions].
  static const Set<String> keys = {key};

  final SharedPreferencesWithCache _preferences;

  @override
  String? read() => _preferences.getString(key);

  @override
  Future<void> write(String currencyCode) =>
      _preferences.setString(key, currencyCode);

  @override
  Future<void> clear() => _preferences.remove(key);
}
