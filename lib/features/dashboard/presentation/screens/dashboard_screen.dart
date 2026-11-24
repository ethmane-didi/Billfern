import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_destination.dart';
import '../../../../core/theme/theme.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/buttons/secondary_button.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../shared/widgets/spending_summary_card.dart';
import '../widgets/preview_renewal_tile.dart';

/// Home destination.
///
/// Phase 1: showcases the shared design-system components so they can be
/// reviewed on device. Replaced by the full dashboard in Phase 2.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  static const List<PreviewRenewal> _previewRenewals = [
    PreviewRenewal(
      name: 'Netflix',
      plan: 'Standard',
      amount: 15.49,
      dueLabel: 'Renews tomorrow',
      brandColor: Color(0xFFE50914),
      foregroundColor: AppColors.textOnDark,
    ),
    PreviewRenewal(
      name: 'Spotify',
      plan: 'Premium Individual',
      amount: 11.99,
      dueLabel: 'Renews in 3 days',
      brandColor: Color(0xFF1ED760),
      foregroundColor: AppColors.textPrimary,
    ),
    PreviewRenewal(
      name: 'ChatGPT',
      plan: 'Plus',
      amount: 20.00,
      dueLabel: 'Renews in 6 days',
      brandColor: AppColors.lavender,
      foregroundColor: AppColors.textPrimary,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          AppSpacing.md,
          AppSpacing.screenHorizontal,
          bottomInset + AppSpacing.xl,
        ),
        children: [
          Text(AppConstants.appName, style: AppTypography.headlineLarge),
          const SizedBox(height: AppSpacing.xxs),
          Text(AppConstants.tagline, style: AppTypography.bodySmall),
          const SizedBox(height: AppSpacing.xl),
          const SpendingSummaryCard(
            amount: 248.97,
            changePercent: -8.2,
            activeCount: 12,
          ),
          const SizedBox(height: AppSpacing.xxl),
          const SectionHeader(
            title: 'Upcoming renewals',
            subtitle: 'Design system preview',
          ),
          const SizedBox(height: AppSpacing.md),
          for (final renewal in _previewRenewals) ...[
            PreviewRenewalTile(renewal: renewal),
            const SizedBox(height: AppSpacing.sm),
          ],
          const SizedBox(height: AppSpacing.xl),
          PrimaryButton(
            label: 'Add subscription',
            icon: LucideIcons.plus,
            onPressed: () => _showComingSoon(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          SecondaryButton(
            label: 'View analytics',
            icon: LucideIcons.chartPie,
            onPressed: () => context.go(AppDestination.analytics.path),
          ),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Adding subscriptions arrives soon.')),
      );
  }
}
