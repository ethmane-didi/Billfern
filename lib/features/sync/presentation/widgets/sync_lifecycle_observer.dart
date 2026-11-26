import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/sync_providers.dart';

/// Keeps synchronization active for the whole app and syncs when the app
/// returns to the foreground (which also covers reconnecting after offline
/// use). Does nothing when cloud sync is unavailable.
class SyncLifecycleObserver extends ConsumerStatefulWidget {
  const SyncLifecycleObserver({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SyncLifecycleObserver> createState() =>
      _SyncLifecycleObserverState();
}

class _SyncLifecycleObserverState extends ConsumerState<SyncLifecycleObserver> {
  late final AppLifecycleListener _listener;

  @override
  void initState() {
    super.initState();
    _listener = AppLifecycleListener(
      onResume: () => ref.read(syncControllerProvider.notifier).sync(),
    );
  }

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watching keeps the controller (and its automatic triggers) alive.
    ref.watch(syncControllerProvider);
    return widget.child;
  }
}
