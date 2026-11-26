import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../shared/data/local_store.dart';
import '../../../../shared/providers/local_store_providers.dart';
import '../../../../shared/providers/subscription_providers.dart';
import '../../data/auth_repository.dart';
import '../../domain/auth_models.dart';
import '../../domain/guest_migration.dart';

/// Build-time backend configuration. `main` overrides it.
final supabaseConfigProvider = Provider<SupabaseConfig>(
  (ref) => SupabaseConfig.none,
);

/// Authentication backend. `main` overrides it with the Supabase
/// implementation when configured; local-only otherwise.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => const LocalOnlyAuthRepository(),
);

/// Authentication state, and the local-store switches that go with it:
/// signing in shows that account's database, signing out (or an expired
/// session) shows the guest database. Account data stays isolated in its
/// own file and is never deleted by signing out.
class AuthController extends Notifier<AuthStatus> {
  StreamSubscription<AuthChange>? _subscription;

  AuthRepository get _repository => ref.read(authRepositoryProvider);

  @override
  AuthStatus build() {
    final repository = ref.watch(authRepositoryProvider);
    if (!repository.isConfigured) return const AuthUnavailable();
    _subscription = repository.changes.listen(_onChange);
    ref.onDispose(() => _subscription?.cancel());
    final user = repository.currentUser;
    return user == null ? const SignedOut() : SignedIn(user);
  }

  void _onChange(AuthChange change) {
    final user = change.user;
    if (user != null) {
      final current = state;
      if (current is SignedIn && current.user == user) return;
      state = SignedIn(user);
      unawaited(_switchTo(LocalIdentity.account(user.id)));
    } else if (state is SignedIn) {
      state = SignedOut(sessionExpired: change.sessionExpired);
      unawaited(_switchTo(LocalIdentity.guest));
    }
  }

  Future<void> _switchTo(LocalIdentity identity) async {
    await ref.read(activeLocalStoreProvider.notifier).switchTo(identity);
    ref.read(subscriptionsProvider.notifier).reload();
  }

  /// Emails a one-time code.
  Future<void> requestCode(String email, {required bool createAccount}) =>
      _repository.requestEmailCode(email, createAccount: createAccount);

  /// Verifies the code, opens the account's local database and signs in.
  Future<AccountUser> verifyCode(String email, String code) async {
    final user = await _repository.verifyEmailCode(email, code);
    await _switchTo(LocalIdentity.account(user.id));
    state = SignedIn(user);
    return user;
  }

  /// Signs out on this device. Pending changes stay in the account's
  /// database and are sent after the next sign-in.
  Future<void> signOut() async {
    await _repository.signOut();
    state = const SignedOut();
    await _switchTo(LocalIdentity.guest);
  }

  /// Permanently deletes the account (server function), then erases the
  /// account's local database on this device.
  Future<void> deleteAccount() async {
    final current = state;
    if (current is! SignedIn) return;
    await _repository.deleteAccount();
    state = const SignedOut();
    await ref
        .read(activeLocalStoreProvider.notifier)
        .destroy(LocalIdentity.account(current.user.id));
    await _switchTo(LocalIdentity.guest);
  }

  /// Erases this device's copy of the current identity's data.
  ///
  /// Guest: permanently deletes local subscriptions and their history.
  /// Account: deletes the local cache, pending changes and sync state; the
  /// cloud copy is untouched and downloads again on the next sync.
  Future<void> eraseThisDevice() async {
    final controller = ref.read(activeLocalStoreProvider.notifier);
    final identity = controller.identity;
    await controller.destroy(identity);
    if (!identity.isGuest) await controller.switchTo(identity);
    ref.read(subscriptionsProvider.notifier).reload();
    ref.invalidate(guestMigrationProvider);
  }

  /// Clears the "session expired" notice.
  void acknowledgeExpiry() {
    if (state case SignedOut(sessionExpired: true)) {
      state = const SignedOut();
    }
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthStatus>(
  AuthController.new,
);

/// The signed-in user, if any.
final currentAccountProvider = Provider<AccountUser?>((ref) {
  final status = ref.watch(authControllerProvider);
  return status is SignedIn ? status.user : null;
});

// ---- Guest-data migration ----------------------------------------------

/// Whether the signed-in account needs the user's decision about existing
/// guest data, with a summary for the consent screen.
sealed class GuestMigrationState {
  const GuestMigrationState();
}

final class NoGuestMigration extends GuestMigrationState {
  const NoGuestMigration();
}

final class GuestMigrationNeeded extends GuestMigrationState {
  const GuestMigrationNeeded(this.summary);

  final GuestDataSummary summary;
}

class GuestMigrationController extends AsyncNotifier<GuestMigrationState> {
  static const _service = GuestMigrationService();

  @override
  Future<GuestMigrationState> build() async {
    final account = ref.watch(activeLocalStoreProvider);
    if (account == null || account.identity.isGuest) {
      return const NoGuestMigration();
    }
    if (await _service.decisionFor(account) != null) {
      return const NoGuestMigration();
    }
    final summary = await _withGuest(
      (guest) async => _service.summarize(guest, account),
    );
    if (summary == null || summary.isEmpty) return const NoGuestMigration();
    return GuestMigrationNeeded(summary);
  }

  Future<T?> _withGuest<T>(Future<T> Function(LocalStore guest) action) async {
    final opener = ref.read(localStoreOpenerProvider);
    if (opener == null) return null;
    final guest = await opener.open(LocalIdentity.guest);
    try {
      return await action(guest);
    } finally {
      await guest.close();
    }
  }

  /// Uploads (merges) guest subscriptions into the account after consent.
  Future<int> merge() async {
    final account = ref.read(activeLocalStoreProvider);
    if (account == null || account.identity.isGuest) return 0;
    final copied =
        await _withGuest(
          (guest) => _service.merge(guest: guest, account: account),
        ) ??
        0;
    ref.read(subscriptionsProvider.notifier).reload();
    state = const AsyncData(NoGuestMigration());
    return copied;
  }

  /// Keeps guest data on this device only.
  Future<void> decline() async {
    final account = ref.read(activeLocalStoreProvider);
    if (account == null || account.identity.isGuest) return;
    await _service.decline(account);
    state = const AsyncData(NoGuestMigration());
  }
}

final guestMigrationProvider =
    AsyncNotifierProvider<GuestMigrationController, GuestMigrationState>(
      GuestMigrationController.new,
    );
