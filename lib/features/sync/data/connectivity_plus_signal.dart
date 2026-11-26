import 'package:connectivity_plus/connectivity_plus.dart';

import '../domain/connectivity_signal.dart';

/// [ConnectivitySignal] backed by `connectivity_plus` (NWPathMonitor on iOS,
/// ConnectivityManager on Android). Event-driven: no polling.
final class ConnectivityPlusSignal implements ConnectivitySignal {
  ConnectivityPlusSignal([Connectivity? connectivity])
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Stream<bool> get changes =>
      _connectivity.onConnectivityChanged.map(isOnline).distinct();

  /// Whether [results] include any network interface.
  static bool isOnline(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);
}
