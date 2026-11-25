import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/theme.dart';

/// Spending category of a subscription or catalog service.
///
/// The enum [name] is the stable key used in
/// `assets/data/subscription_catalog.json`.
enum SubscriptionCategory {
  entertainment(
    label: 'Entertainment',
    icon: LucideIcons.tv,
    color: AppColors.chartYellow,
  ),
  music(
    label: 'Music',
    icon: LucideIcons.music,
    color: AppColors.chartMint,
    isInterchangeable: true,
  ),
  productivity(
    label: 'Productivity',
    icon: LucideIcons.briefcase,
    color: AppColors.chartMidnight,
  ),
  aiTools(label: 'AI tools', icon: LucideIcons.bot, color: AppColors.chartSky),
  design(
    label: 'Design',
    icon: LucideIcons.penTool,
    color: AppColors.chartViolet,
  ),
  cloudStorage(
    label: 'Cloud storage',
    icon: LucideIcons.cloud,
    color: AppColors.chartLavender,
    isInterchangeable: true,
  ),
  development(
    label: 'Development',
    icon: LucideIcons.code,
    color: AppColors.chartSlate,
  ),
  gaming(
    label: 'Gaming',
    icon: LucideIcons.gamepad2,
    color: AppColors.chartGreen,
  ),
  learning(
    label: 'Education',
    icon: LucideIcons.graduationCap,
    color: AppColors.chartPeach,
  ),
  health(
    label: 'Health & fitness',
    icon: LucideIcons.heartPulse,
    color: AppColors.chartRose,
  ),
  security(
    label: 'Security',
    icon: LucideIcons.shieldCheck,
    color: AppColors.chartSand,
  ),
  reading(
    label: 'Books & audio',
    icon: LucideIcons.bookOpen,
    color: AppColors.chartCoral,
  );

  const SubscriptionCategory({
    required this.label,
    required this.icon,
    required this.color,
    this.isInterchangeable = false,
  });

  final String label;
  final IconData icon;

  /// Series colour in charts and legends, and the fallback brand colour.
  final Color color;

  /// Whether services in this category usually overlap, so paying for more
  /// than one is a savings opportunity (e.g. two music streaming services).
  final bool isInterchangeable;

  /// Parses a catalog key, returning `null` for unknown values.
  static SubscriptionCategory? tryParse(String key) {
    for (final category in values) {
      if (category.name == key) return category;
    }
    return null;
  }
}
