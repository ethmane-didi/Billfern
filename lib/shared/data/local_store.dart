import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sembast/sembast.dart';

import '../../features/sync/data/sync_store.dart';
import 'subscription_database.dart';
import 'subscription_repository.dart';

/// Whose data a local database holds.
///
/// Every identity has its **own database file**, so signing in, signing out
/// or switching accounts can never show or upload another identity's
/// subscriptions or pending operations.
@immutable
class LocalIdentity {
  const LocalIdentity._(this.userId);

  /// The local-only (guest) identity. Uses the original `billfern.db`, so
  /// existing installs keep their data.
  static const LocalIdentity guest = LocalIdentity._(null);

  /// A signed-in account ([userId] is the Supabase user UUID).
  factory LocalIdentity.account(String userId) {
    if (!RegExp(r'^[0-9a-fA-F-]{8,64}$').hasMatch(userId)) {
      throw ArgumentError.value(userId, 'userId', 'Not a valid user id');
    }
    return LocalIdentity._(userId.toLowerCase());
  }

  final String? userId;

  bool get isGuest => userId == null;

  /// File name inside the app documents directory.
  String get databaseFileName =>
      isGuest ? 'billfern.db' : 'billfern_account_$userId.db';

  @override
  bool operator ==(Object other) =>
      other is LocalIdentity && other.userId == userId;

  @override
  int get hashCode => userId.hashCode;

  @override
  String toString() =>
      isGuest ? 'LocalIdentity.guest' : 'LocalIdentity(account)';
}

/// An opened local database for one [identity]: subscriptions, plus sync
/// state for accounts.
class LocalStore {
  LocalStore({
    required this.identity,
    required this.database,
    required this.subscriptions,
    this.sync,
  });

  final LocalIdentity identity;
  final Database database;
  final SembastSubscriptionRepository subscriptions;

  /// Outbox, versions, cursor and conflicts. `null` for the guest store.
  final SyncStore? sync;

  Future<void> close() => database.close();
}

/// Opens, and permanently erases, identity-scoped local databases.
abstract interface class LocalStoreOpener {
  Future<LocalStore> open(LocalIdentity identity);

  /// Deletes the identity's database file (account deletion, local reset).
  Future<void> destroy(LocalIdentity identity);
}

/// Opens databases from [factory] inside [directory].
class SembastLocalStoreOpener implements LocalStoreOpener {
  SembastLocalStoreOpener(this.factory, this.directory, {this.clock});

  final DatabaseFactory factory;
  final String directory;
  final DateTime Function()? clock;

  String pathFor(LocalIdentity identity) =>
      '$directory${Platform.pathSeparator}${identity.databaseFileName}';

  @override
  Future<LocalStore> open(LocalIdentity identity) async {
    final database = await SubscriptionDatabase.open(
      factory,
      pathFor(identity),
    );
    final sync = identity.isGuest ? null : SyncStore(database, clock: clock);
    final subscriptions = await SembastSubscriptionRepository.open(
      database,
      recorder: sync,
    );
    return LocalStore(
      identity: identity,
      database: database,
      subscriptions: subscriptions,
      sync: sync,
    );
  }

  @override
  Future<void> destroy(LocalIdentity identity) =>
      factory.deleteDatabase(pathFor(identity));
}
