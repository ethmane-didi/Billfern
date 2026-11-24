import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/analytics/presentation/screens/analytics_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/settings/presentation/screens/currency_preference_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/subscriptions/presentation/screens/subscriptions_screen.dart';
import 'app_destination.dart';
import 'app_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Application router. Exposed through Riverpod so redirects can later react
/// to authentication and onboarding state.
final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppDestination.home.path,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          _branch(AppDestination.home, const DashboardScreen()),
          _branch(AppDestination.subscriptions, const SubscriptionsScreen()),
          _branch(AppDestination.analytics, const AnalyticsScreen()),
          _branch(
            AppDestination.settings,
            const SettingsScreen(),
            routes: [
              GoRoute(
                path: AppRoutes.currencySegment,
                name: AppRoutes.currencyName,
                builder: (context, state) => const CurrencyPreferenceScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

/// Paths of routes nested under the top-level destinations.
abstract final class AppRoutes {
  static const String currencySegment = 'currency';
  static const String currencyName = 'currencyPreference';

  /// Currency preference screen, pushed inside the Settings tab.
  static const String currency = '/settings/$currencySegment';
}

StatefulShellBranch _branch(
  AppDestination destination,
  Widget screen, {
  List<RouteBase> routes = const [],
}) {
  return StatefulShellBranch(
    routes: [
      GoRoute(
        path: destination.path,
        name: destination.name,
        pageBuilder: (context, state) => NoTransitionPage(child: screen),
        routes: routes,
      ),
    ],
  );
}
