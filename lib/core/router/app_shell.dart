import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/floating_bottom_nav.dart';
import '../../shared/widgets/gradient_scaffold.dart';
import 'app_destination.dart';

/// Persistent chrome around the top-level destinations: gradient background
/// plus the floating bottom navigation.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static final List<FloatingNavItem> _navItems = [
    for (final destination in AppDestination.values)
      FloatingNavItem(icon: destination.icon, label: destination.label),
  ];

  void _onDestinationSelected(int index) {
    navigationShell.goBranch(
      index,
      // Tapping the active tab again pops it back to its root.
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: FloatingBottomNav(
        items: _navItems,
        currentIndex: navigationShell.currentIndex,
        onSelected: _onDestinationSelected,
      ),
    );
  }
}
