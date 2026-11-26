import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/sync/presentation/widgets/sync_lifecycle_observer.dart';

/// Root widget: wires the theme and router together.
class BillfernApp extends ConsumerWidget {
  const BillfernApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      themeMode: ThemeMode.light,
      routerConfig: router,
      builder: (context, child) =>
          SyncLifecycleObserver(child: child ?? const SizedBox.shrink()),
    );
  }
}
