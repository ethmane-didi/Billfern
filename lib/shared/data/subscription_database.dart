import 'package:sembast/sembast.dart';

import 'subscription_codec.dart';
import 'subscription_repository.dart';

/// Opens the local database and migrates stored records.
///
/// Database versions follow [SubscriptionCodec.schemaVersion]. Migrations
/// only ever **rewrite** decodable records in the current format; a record
/// that cannot be decoded is left untouched on disk (and skipped by
/// [SembastSubscriptionRepository]), so no user data is ever deleted.
abstract final class SubscriptionDatabase {
  static const int version = SubscriptionCodec.schemaVersion;

  static Future<Database> open(DatabaseFactory factory, String path) {
    return factory.openDatabase(
      path,
      version: version,
      onVersionChanged: (db, oldVersion, newVersion) async {
        // A brand-new database (version 0) has nothing to migrate.
        if (oldVersion == 0 || oldVersion >= newVersion) return;
        await migrate(db);
      },
    );
  }

  /// Rewrites every decodable record in the current schema. Version 1 → 2
  /// adds empty `priceHistory` and a null `endedOn`; field values are
  /// otherwise preserved.
  static Future<void> migrate(DatabaseClient db) async {
    final store = SembastSubscriptionRepository.store;
    final records = await store.find(db);
    for (final record in records) {
      try {
        final subscription = SubscriptionCodec.fromMap(record.value);
        await store
            .record(record.key)
            .put(db, SubscriptionCodec.toMap(subscription));
      } on FormatException {
        // Keep unreadable records exactly as they are.
      }
    }
  }
}
