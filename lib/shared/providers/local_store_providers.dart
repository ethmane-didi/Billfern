import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local_store.dart';

/// Opens identity-scoped databases. `main` overrides this with the
/// file-backed opener; tests use an in-memory sembast factory.
final localStoreOpenerProvider = Provider<LocalStoreOpener?>((ref) => null);

/// The store opened in `main` before the first frame (guest, or the
/// account whose session was restored). `null` in widget tests, where the
/// in-memory personal repository is used instead.
final initialLocalStoreProvider = Provider<LocalStore?>((ref) => null);

/// The local store of the current identity.
///
/// Switching identity opens the new database first, then swaps it in and
/// closes the old one, so the UI never sees another identity's data.
class LocalStoreController extends Notifier<LocalStore?> {
  @override
  LocalStore? build() => ref.watch(initialLocalStoreProvider);

  LocalIdentity get identity => state?.identity ?? LocalIdentity.guest;

  Future<void> _queue = Future.value();

  /// Runs [action] after every earlier switch has finished, so identity
  /// changes never interleave.
  Future<void> _serialized(Future<void> Function() action) {
    final next = _queue.then((_) => action());
    _queue = next.catchError((Object _) {});
    return next;
  }

  /// Switches to [identity]'s database (no-op when already active).
  Future<void> switchTo(LocalIdentity identity) =>
      _serialized(() => _switchTo(identity));

  Future<void> _switchTo(LocalIdentity identity) async {
    final current = state;
    if (current != null && current.identity == identity) return;
    final opener = ref.read(localStoreOpenerProvider);
    if (opener == null) return;
    final next = await opener.open(identity);
    state = next;
    await current?.close();
  }

  /// Permanently erases [identity]'s local database. When it is the active
  /// store, a fresh guest store takes its place.
  Future<void> destroy(LocalIdentity identity) =>
      _serialized(() => _destroy(identity));

  Future<void> _destroy(LocalIdentity identity) async {
    final opener = ref.read(localStoreOpenerProvider);
    if (opener == null) return;
    final current = state;
    if (current != null && current.identity == identity) {
      await current.close();
      await opener.destroy(identity);
      state = await opener.open(LocalIdentity.guest);
    } else {
      await opener.destroy(identity);
    }
  }
}

final activeLocalStoreProvider =
    NotifierProvider<LocalStoreController, LocalStore?>(
      LocalStoreController.new,
    );
