import 'package:flutter/foundation.dart';

/// Supabase connection settings, supplied at **build time**:
///
/// ```bash
/// flutter run --dart-define-from-file=config/supabase.json
/// ```
///
/// Only the project URL and the **publishable** (public client) key belong
/// here. Service-role keys, database passwords and admin tokens must never
/// be compiled into the app. When either value is missing Billfern runs in
/// local-only mode.
@immutable
class SupabaseConfig {
  const SupabaseConfig({required this.url, required this.publishableKey});

  /// Values from `--dart-define` / `--dart-define-from-file`.
  factory SupabaseConfig.fromEnvironment() => const SupabaseConfig(
    url: String.fromEnvironment('SUPABASE_URL'),
    publishableKey: String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
  );

  /// A configuration with no backend (local-only mode).
  static const SupabaseConfig none = SupabaseConfig(
    url: '',
    publishableKey: '',
  );

  final String url;
  final String publishableKey;

  /// Whether a plausible backend is configured. Placeholder values from the
  /// example file count as not configured.
  bool get isConfigured {
    final uri = Uri.tryParse(url.trim());
    final key = publishableKey.trim();
    return uri != null &&
        uri.hasScheme &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty &&
        !uri.host.contains('your-project') &&
        key.isNotEmpty &&
        !key.startsWith('sb_publishable_your');
  }
}
