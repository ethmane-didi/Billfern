import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Top-level destinations shown in the floating bottom navigation.
///
/// The declaration order defines both the tab order and the branch index in
/// the router's `StatefulShellRoute`.
enum AppDestination {
  home(path: '/', label: 'Home', icon: LucideIcons.house),
  subscriptions(
    path: '/subscriptions',
    label: 'Subscriptions',
    icon: LucideIcons.layoutGrid,
  ),
  analytics(path: '/analytics', label: 'Analytics', icon: LucideIcons.chartPie),
  settings(path: '/settings', label: 'Settings', icon: LucideIcons.settings);

  const AppDestination({
    required this.path,
    required this.label,
    required this.icon,
  });

  final String path;
  final String label;
  final IconData icon;
}
