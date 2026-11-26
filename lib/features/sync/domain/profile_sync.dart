import 'package:flutter/foundation.dart';

import 'sync_models.dart';

/// What was last agreed between this device and the cloud profile.
@immutable
class SyncedProfile {
  const SyncedProfile({required this.currency, required this.remoteUpdatedAt});

  final String currency;

  /// The server's `updated_at` at that time (compared for equality only).
  final String remoteUpdatedAt;

  Map<String, Object?> toMap() => {
    'currency': currency,
    'remoteUpdatedAt': remoteUpdatedAt,
  };

  static SyncedProfile? fromMap(Object? value) {
    if (value is! Map) return null;
    final currency = value['currency'];
    final updatedAt = value['remoteUpdatedAt'];
    if (currency is! String || updatedAt is! String) return null;
    return SyncedProfile(currency: currency, remoteUpdatedAt: updatedAt);
  }
}

/// The action needed to bring the display currency in line.
sealed class ProfileSyncAction {
  const ProfileSyncAction();
}

/// Upload this device's currency.
final class PushCurrency extends ProfileSyncAction {
  const PushCurrency(this.currency);
  final String currency;
}

/// Apply the cloud currency on this device.
final class ApplyCurrency extends ProfileSyncAction {
  const ApplyCurrency(this.currency, this.remote);
  final String currency;
  final RemoteProfile remote;
}

/// Already in agreement; only record [remote] as the new baseline.
final class RecordBaseline extends ProfileSyncAction {
  const RecordBaseline(this.remote);
  final RemoteProfile remote;
}

/// Two-way synchronization of the preferred display currency.
///
/// Change detection compares against the last synced state, never device
/// clocks: the local side changed when the current currency differs from the
/// last synced currency; the cloud side changed when the server timestamp
/// differs from the last synced timestamp.
///
/// - No cloud profile yet → upload.
/// - First sync on this device for the account → the account's currency is
///   adopted (so a new device matches the user's other devices).
/// - Only one side changed → that side wins.
/// - Both changed → the cloud wins (server-ordered and deterministic). This
///   is a display preference only; it never changes stored amounts.
abstract final class ProfileSyncPolicy {
  static ProfileSyncAction decide({
    required String localCurrency,
    required SyncedProfile? synced,
    required RemoteProfile? remote,
  }) {
    final remoteCurrency = remote?.displayCurrency;
    if (remote == null || remoteCurrency == null) {
      return PushCurrency(localCurrency);
    }
    if (synced == null) {
      return remoteCurrency == localCurrency
          ? RecordBaseline(remote)
          : ApplyCurrency(remoteCurrency, remote);
    }
    final localChanged = localCurrency != synced.currency;
    final remoteChanged = remote.updatedAt != synced.remoteUpdatedAt;
    if (remoteChanged) {
      return remoteCurrency == localCurrency
          ? RecordBaseline(remote)
          : ApplyCurrency(remoteCurrency, remote);
    }
    if (localChanged) return PushCurrency(localCurrency);
    return RecordBaseline(remote);
  }
}
