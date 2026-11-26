import 'dart:async';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import '../domain/auth_models.dart';
import 'auth_repository.dart';

/// Email one-time-code authentication with Supabase Auth.
///
/// Sessions are persisted by [SecureSessionStorage] (iOS Keychain / Android
/// Keystore), never in plain preferences. Tokens, emails and server
/// messages are never logged.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client) {
    _subscription = _client.auth.onAuthStateChange.listen(
      _onAuthState,
      onError: (_) {},
    );
  }

  final supa.SupabaseClient _client;
  final _changes = StreamController<AuthChange>.broadcast();
  StreamSubscription<supa.AuthState>? _subscription;
  bool _signingOut = false;

  /// Edge Function that deletes the caller's account.
  static const String deleteAccountFunction = 'delete-account';
  static const String deleteConfirmation = 'DELETE MY ACCOUNT';

  @override
  bool get isConfigured => true;

  @override
  AccountUser? get currentUser => _toUser(_client.auth.currentUser);

  @override
  Stream<AuthChange> get changes => _changes.stream;

  void _onAuthState(supa.AuthState state) {
    switch (state.event) {
      case supa.AuthChangeEvent.signedIn:
      case supa.AuthChangeEvent.tokenRefreshed:
      case supa.AuthChangeEvent.userUpdated:
        final user = _toUser(state.session?.user);
        if (user != null) _changes.add(AuthChange(user));
      case supa.AuthChangeEvent.signedOut:
        _changes.add(AuthChange(null, sessionExpired: !_signingOut));
      default:
        break;
    }
  }

  static AccountUser? _toUser(supa.User? user) {
    if (user == null) return null;
    return AccountUser(id: user.id, email: user.email ?? '');
  }

  @override
  Future<void> requestEmailCode(
    String email, {
    required bool createAccount,
  }) async {
    if (!isPlausibleEmail(email)) {
      throw const AuthFailure(AuthFailureKind.invalidEmail);
    }
    await _guard(
      () => _client.auth.signInWithOtp(
        email: email.trim(),
        shouldCreateUser: createAccount,
      ),
    );
  }

  @override
  Future<AccountUser> verifyEmailCode(String email, String code) async {
    if (!isPlausibleCode(code)) {
      throw const AuthFailure(AuthFailureKind.invalidCode);
    }
    final response = await _guard(
      () => _client.auth.verifyOTP(
        email: email.trim(),
        token: code.trim(),
        type: supa.OtpType.email,
      ),
    );
    final user = _toUser(response.user ?? response.session?.user);
    if (user == null) throw const AuthFailure(AuthFailureKind.invalidCode);
    return user;
  }

  @override
  Future<void> signOut() async {
    _signingOut = true;
    try {
      // Local scope: ends this device's session even when offline.
      await _client.auth.signOut(scope: supa.SignOutScope.local);
    } on Object {
      // The local session is removed regardless of network errors.
    } finally {
      _signingOut = false;
    }
  }

  @override
  Future<void> deleteAccount() async {
    final response = await _guard(
      () => _client.functions.invoke(
        deleteAccountFunction,
        body: {'confirm': deleteConfirmation},
      ),
    );
    if (response.status != 200) {
      throw const AuthFailure(AuthFailureKind.unknown);
    }
    await signOut();
  }

  Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on AuthFailure {
      rethrow;
    } on supa.AuthException catch (error) {
      throw AuthFailure(classify(error.code, error.statusCode));
    } on supa.FunctionException {
      throw const AuthFailure(AuthFailureKind.unknown);
    } on SocketException {
      throw const AuthFailure(AuthFailureKind.offline);
    } on TimeoutException {
      throw const AuthFailure(AuthFailureKind.offline);
    }
  }

  /// Maps Supabase Auth error codes to user-facing failures.
  static AuthFailureKind classify(String? code, String? statusCode) {
    switch (code) {
      case 'otp_expired':
      case 'invalid_credentials':
      case 'bad_jwt':
        return AuthFailureKind.invalidCode;
      case 'over_email_send_rate_limit':
      case 'over_request_rate_limit':
        return AuthFailureKind.rateLimited;
      case 'otp_disabled':
      case 'user_not_found':
        return AuthFailureKind.accountNotFound;
      case 'signup_disabled':
        return AuthFailureKind.signupsDisabled;
      case 'email_address_invalid':
      case 'validation_failed':
        return AuthFailureKind.invalidEmail;
    }
    if (statusCode == '429') return AuthFailureKind.rateLimited;
    if (statusCode == null) return AuthFailureKind.offline;
    return AuthFailureKind.unknown;
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _changes.close();
  }
}

/// Persists the Supabase session in the platform's secure storage.
class SecureSessionStorage extends supa.LocalStorage {
  const SecureSessionStorage({this.storage = const FlutterSecureStorage()});

  final FlutterSecureStorage storage;

  static const String key = 'billfern_supabase_session';

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() => storage.containsKey(key: key);

  @override
  Future<String?> accessToken() => storage.read(key: key);

  @override
  Future<void> persistSession(String persistSessionString) =>
      storage.write(key: key, value: persistSessionString);

  @override
  Future<void> removePersistedSession() => storage.delete(key: key);
}
