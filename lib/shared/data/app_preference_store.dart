import 'package:shared_preferences/shared_preferences.dart';

/// Small key–value settings store (display currency, data mode, …).
///
/// Collections such as subscriptions never go here — they live in the
/// local database.
abstract interface class AppPreferenceStore {
  String? read(String key);
  Future<void> write(String key, String value);
  Future<void> remove(String key);
}

/// Non-persistent store, used by default and in tests.
class InMemoryAppPreferenceStore implements AppPreferenceStore {
  InMemoryAppPreferenceStore([Map<String, String>? initial])
    : _values = {...?initial};

  final Map<String, String> _values;

  @override
  String? read(String key) => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> remove(String key) async => _values.remove(key);
}

/// Device-local store backed by [SharedPreferencesWithCache] (synchronous
/// reads after the one-time async creation in `main`).
class SharedPreferencesAppStore implements AppPreferenceStore {
  const SharedPreferencesAppStore(this._preferences);

  final SharedPreferencesWithCache _preferences;

  @override
  String? read(String key) => _preferences.getString(key);

  @override
  Future<void> write(String key, String value) =>
      _preferences.setString(key, value);

  @override
  Future<void> remove(String key) => _preferences.remove(key);
}

/// Keys used with [AppPreferenceStore]; also the cache allow-list.
abstract final class PreferenceKeys {
  static const String dataMode = 'data_mode';
  static const Set<String> all = {dataMode};
}
