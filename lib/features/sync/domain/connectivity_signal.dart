/// Network connectivity changes, used only as a **hint** that sync may now
/// succeed.
///
/// `true` means the device has a network interface (Wi-Fi, mobile data,
/// ethernet …), never that Supabase is reachable: captive portals, dead
/// links and server outages still fail, and the sync engine's timeouts,
/// backoff and durable outbox handle that.
abstract interface class ConnectivitySignal {
  /// Emits whenever connectivity changes (may also emit the current state
  /// when listened to). Listening must be cheap; cancel when not needed.
  Stream<bool> get changes;
}

/// No connectivity information (tests, local-only builds): never emits.
final class NoConnectivitySignal implements ConnectivitySignal {
  const NoConnectivitySignal();

  @override
  Stream<bool> get changes => const Stream.empty();
}
