import 'dart:async';

import '../domain/auth_models.dart';

/// An authentication change reported by the backend.
class AuthChange {
  const AuthChange(this.user, {this.sessionExpired = false});

  final AccountUser? user;

  /// The session ended without the user signing out.
  final bool sessionExpired;
}

/// Optional email-code authentication.
///
/// Billfern uses **email one-time codes** (OTP): the user types the
/// numeric code from the email (6–10 digits; Supabase currently sends 8),
/// which verifies the address. The code is passed on unchanged as a string. No deep links or
/// redirect URLs are needed. Sign in with Apple and Google can be added as
/// further methods on this interface once provider credentials exist.
abstract interface class AuthRepository {
  /// Whether a backend is configured. When `false`, every method throws
  /// [AuthFailure] with [AuthFailureKind.notConfigured].
  bool get isConfigured;

  /// The restored or current session's user, if any.
  AccountUser? get currentUser;

  /// Sign-in, sign-out and session-expiry events.
  Stream<AuthChange> get changes;

  /// Emails a one-time code. [createAccount] allows creating a new account
  /// for an unknown email; otherwise only existing accounts can sign in.
  Future<void> requestEmailCode(String email, {required bool createAccount});

  /// Verifies the code and starts a session.
  Future<AccountUser> verifyEmailCode(String email, String code);

  /// Ends the session on this device.
  Future<void> signOut();

  /// Permanently deletes the account through the trusted server function.
  Future<void> deleteAccount();
}

/// Used when no backend is configured: Billfern stays local-only.
class LocalOnlyAuthRepository implements AuthRepository {
  const LocalOnlyAuthRepository();

  static const _failure = AuthFailure(AuthFailureKind.notConfigured);

  @override
  bool get isConfigured => false;

  @override
  AccountUser? get currentUser => null;

  @override
  Stream<AuthChange> get changes => const Stream.empty();

  @override
  Future<void> requestEmailCode(String email, {required bool createAccount}) =>
      Future.error(_failure);

  @override
  Future<AccountUser> verifyEmailCode(String email, String code) =>
      Future.error(_failure);

  @override
  Future<void> signOut() async {}

  @override
  Future<void> deleteAccount() => Future.error(_failure);
}
