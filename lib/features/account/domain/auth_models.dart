import 'package:flutter/foundation.dart';

/// A signed-in Billfern account. Only the id and email are kept; Billfern
/// collects no other personal information.
@immutable
class AccountUser {
  const AccountUser({required this.id, required this.email});

  /// Supabase user UUID.
  final String id;
  final String email;

  @override
  bool operator ==(Object other) =>
      other is AccountUser && other.id == id && other.email == email;

  @override
  int get hashCode => Object.hash(id, email);
}

/// Authentication state.
sealed class AuthStatus {
  const AuthStatus();
}

/// This build has no backend configured: local-only, no accounts.
final class AuthUnavailable extends AuthStatus {
  const AuthUnavailable();
}

/// Using Billfern without an account (the default).
final class SignedOut extends AuthStatus {
  const SignedOut({this.sessionExpired = false});

  /// The previous session ended unexpectedly (e.g. revoked or expired
  /// refresh token); the user should sign in again. Local data is kept.
  final bool sessionExpired;
}

final class SignedIn extends AuthStatus {
  const SignedIn(this.user);

  final AccountUser user;
}

/// Why an authentication request failed. Messages shown to the user come
/// from [AuthFailureKind.message]; raw server text is never displayed or
/// logged.
enum AuthFailureKind {
  invalidEmail('Enter a valid email address.'),
  invalidCode('That code is incorrect or has expired. Request a new one.'),
  rateLimited('Too many attempts. Please wait a minute and try again.'),
  accountNotFound('No account uses that email. Create an account instead.'),
  signupsDisabled('New accounts are not available right now.'),
  offline('You appear to be offline. Check your connection and try again.'),
  notConfigured('Accounts are not available in this version of Billfern.'),
  unknown('Something went wrong. Please try again.');

  const AuthFailureKind(this.message);

  final String message;
}

class AuthFailure implements Exception {
  const AuthFailure(this.kind);

  final AuthFailureKind kind;

  String get message => kind.message;

  @override
  String toString() => 'AuthFailure(${kind.name})';
}

/// Basic email check before contacting the server.
bool isPlausibleEmail(String value) {
  final email = value.trim();
  return email.length <= 254 &&
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$').hasMatch(email);
}

/// Email one-time codes: numeric, 6 to 10 digits (the length is set in the
/// Supabase project; it currently sends 8). Codes are always kept as
/// strings, so leading zeros are preserved.
abstract final class OtpCode {
  static const int minLength = 6;
  static const int maxLength = 10;

  static final RegExp _valid = RegExp('^\\d{$minLength,$maxLength}\$');
  static final RegExp _separators = RegExp(r'[\s\-]');
  static final RegExp _allDigits = RegExp(r'^\d*$');
  static final RegExp _candidate = RegExp(
    '(?<!\\d)\\d{$minLength,$maxLength}(?!\\d)',
  );

  /// Whether [value] (trimmed) is a well-formed code.
  static bool isPlausible(String value) => _valid.hasMatch(value.trim());

  /// Turns typed or pasted text into the code it contains.
  ///
  /// Spaces and hyphens are ignored ("0123 4567" → "01234567"). When the
  /// text contains other characters (e.g. a pasted email line such as
  /// "Your code: 01234567"), the single 6–10 digit number in it is used.
  /// Otherwise the digits are kept, up to [maxLength].
  static String normalize(String text) {
    final compact = text.replaceAll(_separators, '');
    if (!_allDigits.hasMatch(compact)) {
      final candidates = _candidate.allMatches(compact).toList();
      if (candidates.length == 1) return candidates.single.group(0)!;
    }
    final digits = compact.replaceAll(RegExp(r'\D'), '');
    return digits.length > maxLength ? digits.substring(0, maxLength) : digits;
  }
}

/// Whether [value] is a well-formed email one-time code (6–10 digits).
bool isPlausibleCode(String value) => OtpCode.isPlausible(value);
