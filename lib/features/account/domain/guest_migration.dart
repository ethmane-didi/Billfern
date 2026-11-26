import 'package:flutter/foundation.dart';

import '../../../shared/data/local_store.dart';
import '../../sync/data/sync_store.dart';

/// What the guest (local-only) database holds, shown before asking for
/// consent to upload it.
@immutable
class GuestDataSummary {
  const GuestDataSummary({
    required this.currentCount,
    required this.endedCount,
    required this.accountHasData,
  });

  /// Subscriptions in the user's list.
  final int currentCount;

  /// Removed subscriptions kept for spending history.
  final int endedCount;

  /// Whether the account already holds subscriptions (from the cloud).
  final bool accountHasData;

  int get total => currentCount + endedCount;

  bool get isEmpty => total == 0;
}

/// The user's decision about their guest data for one account.
enum GuestMigrationDecision {
  /// Upload (merge) guest subscriptions into the account.
  merged,

  /// Keep guest data on this device only.
  declined,
}

/// Copies guest subscriptions into an account, with consent.
///
/// - Never reads sample data (sample mode is in memory, not in the guest
///   database).
/// - Preserves every field: ids, amounts, currencies, cycles, categories,
///   notes, renewal dates, pause periods, price revisions and archived
///   subscriptions.
/// - Never deduplicates by service name; only identical ids are skipped
///   (already copied), so the migration is resumable and idempotent.
/// - Never deletes guest data.
class GuestMigrationService {
  const GuestMigrationService();

  /// Summarises [guest] for the consent screen.
  GuestDataSummary summarize(LocalStore guest, LocalStore account) {
    final all = guest.subscriptions.fetchEverything();
    return GuestDataSummary(
      currentCount: all.where((s) => !s.isEnded).length,
      endedCount: all.where((s) => s.isEnded).length,
      accountHasData: account.subscriptions.fetchEverything().isNotEmpty,
    );
  }

  /// The decision recorded for [account], if any.
  Future<GuestMigrationDecision?> decisionFor(LocalStore account) async {
    final value = await account.sync?.readMeta(SyncStore.guestMigrationKey);
    if (value is! String) return null;
    return GuestMigrationDecision.values
        .where((d) => d.name == value)
        .firstOrNull;
  }

  Future<void> decline(LocalStore account) async {
    final sync = account.sync;
    if (sync == null) return;
    await sync.writeMeta(
      sync.database,
      SyncStore.guestMigrationKey,
      GuestMigrationDecision.declined.name,
    );
  }

  /// Copies every guest subscription not yet in [account]; each copy and its
  /// pending upload are committed together. Returns how many were copied.
  Future<int> merge({
    required LocalStore guest,
    required LocalStore account,
  }) async {
    final sync = account.sync;
    if (sync == null || account.identity.isGuest) {
      throw StateError('Guest data can only be merged into an account.');
    }
    var copied = 0;
    for (final subscription in guest.subscriptions.fetchEverything()) {
      if (account.subscriptions.find(subscription.id) != null) continue;
      await account.subscriptions.saveWith(subscription, (_) async {});
      copied++;
    }
    await sync.writeMeta(
      sync.database,
      SyncStore.guestMigrationKey,
      GuestMigrationDecision.merged.name,
    );
    return copied;
  }
}
