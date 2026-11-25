import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/analytics/presentation/screens/analytics_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/onboarding/domain/onboarding_step.dart';
import '../../features/onboarding/presentation/providers/onboarding_providers.dart';
import '../../features/onboarding/presentation/screens/welcome_screen.dart';
import '../../features/settings/presentation/screens/currency_preference_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/subscriptions/presentation/screens/add_subscription_screen.dart';
import '../../features/subscriptions/presentation/screens/subscription_details_screen.dart';
import '../../features/subscriptions/presentation/screens/subscription_form_screen.dart';
import '../../features/subscriptions/presentation/screens/subscriptions_screen.dart';
import 'app_destination.dart';
import 'app_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Application router. Exposed through Riverpod so redirects react to
/// onboarding (and, later, authentication) state.
final appRouterProvider = Provider<GoRouter>((ref) {
  // Re-runs redirects when onboarding completes or is reset.
  final onboardingDone = ValueNotifier<bool>(
    ref.read(onboardingCompletedProvider),
  );
  ref.listen(
    onboardingCompletedProvider,
    (_, done) => onboardingDone.value = done,
  );

  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppDestination.home.path,
    refreshListenable: onboardingDone,
    redirect: (context, state) {
      final inOnboarding = OnboardingStep.isOnboardingLocation(
        state.matchedLocation,
      );
      if (!onboardingDone.value && !inOnboarding) {
        return OnboardingStep.first.path;
      }
      if (onboardingDone.value && inOnboarding) {
        return AppDestination.home.path;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: OnboardingStep.welcome.path,
        builder: (context, state) => const WelcomeScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          _branch(AppDestination.home, const DashboardScreen()),
          _branch(
            AppDestination.subscriptions,
            const SubscriptionsScreen(),
            routes: _subscriptionRoutes,
          ),
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
  ref.onDispose(() {
    router.dispose();
    onboardingDone.dispose();
  });
  return router;
});

/// Add and edit flows open full-screen above the shell (root navigator) so
/// the floating navigation never covers form actions; details stay inside
/// the Subscriptions tab. `add` is declared before `:id` so it is not
/// mistaken for an id.
final List<RouteBase> _subscriptionRoutes = [
  GoRoute(
    path: 'add',
    parentNavigatorKey: _rootNavigatorKey,
    builder: (context, state) => const AddSubscriptionScreen(),
    routes: [
      GoRoute(
        path: 'custom',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SubscriptionFormScreen.custom(),
      ),
      GoRoute(
        path: 'service/:catalogId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => SubscriptionFormScreen.catalog(
          catalogId: state.pathParameters['catalogId']!,
        ),
      ),
    ],
  ),
  GoRoute(
    path: ':id',
    builder: (context, state) =>
        SubscriptionDetailsScreen(subscriptionId: state.pathParameters['id']!),
    routes: [
      GoRoute(
        path: 'edit',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => SubscriptionFormScreen.edit(
          subscriptionId: state.pathParameters['id']!,
        ),
      ),
    ],
  ),
];

/// Paths of routes nested under the top-level destinations.
abstract final class AppRoutes {
  static const String currencySegment = 'currency';
  static const String currencyName = 'currencyPreference';

  /// Currency preference screen, pushed inside the Settings tab.
  static const String currency = '/settings/$currencySegment';

  /// Catalog picker of the add flow.
  static const String addSubscription = '/subscriptions/add';

  /// Form for a subscription that is not in the catalog.
  static const String addCustomSubscription = '/subscriptions/add/custom';

  /// Form pre-filled from catalog service [catalogId].
  static String addCatalogSubscription(String catalogId) =>
      '/subscriptions/add/service/${Uri.encodeComponent(catalogId)}';

  static String subscriptionDetails(String id) =>
      '/subscriptions/${Uri.encodeComponent(id)}';

  static String editSubscription(String id) =>
      '/subscriptions/${Uri.encodeComponent(id)}/edit';
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
