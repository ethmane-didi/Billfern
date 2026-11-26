import 'sync_models.dart';

/// The cloud side of synchronization. Implemented by
/// `SupabaseSyncRemote` (PostgreSQL RPCs protected by Row Level Security)
/// and by in-memory fakes in tests.
///
/// Contract:
/// - [push] is **idempotent** per `opId`: delivering the same operation
///   twice applies it once and returns the original result.
/// - [push] is **version-checked**: it applies only when `baseVersion`
///   matches the server version (`null` = the record must not exist yet),
///   otherwise it returns [PushConflict]. Deleted records stay as
///   tombstones and are never resurrected by an outdated device.
/// - [pull] returns changes after an opaque `cursor` (`null` = from the
///   start), in server change order, never skipping changes from
///   transactions that were still in progress.
abstract interface class SyncRemote {
  Future<PushResult> push({
    required String opId,
    required String subscriptionId,
    required OutboxKind kind,
    required int? baseVersion,
    Map<String, Object?>? payload,
  });

  Future<PullPage> pull({required String? cursor, required int limit});

  /// The user's profile, or `null` when none exists yet.
  Future<RemoteProfile?> fetchProfile();

  /// Saves the display currency and returns the stored profile.
  Future<RemoteProfile> saveProfile({required String displayCurrency});
}
