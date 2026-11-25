import 'package:flutter/widgets.dart';

import '../../core/theme/theme.dart';
import 'app_card.dart';

/// Friendly empty / no-results state with an icon tile, title, message and
/// optional actions (e.g. primary and secondary buttons).
class EmptyStateCard extends StatelessWidget {
  const EmptyStateCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actions = const [],
  });

  final IconData icon;
  final String title;
  final String message;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: AppSpacing.cardPaddingLarge,
      child: Column(
        children: [
          ExcludeSemantics(
            child: Container(
              width: AppSizes.illustrationTile,
              height: AppSizes.illustrationTile,
              decoration: const BoxDecoration(
                gradient: AppGradients.accent,
                borderRadius: AppRadius.lgAll,
              ),
              child: Icon(
                icon,
                size: AppSizes.iconXl,
                color: AppColors.textOnAccent,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Semantics(
            container: true,
            header: true,
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.titleLarge,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          for (var i = 0; i < actions.length; i++) ...[
            SizedBox(height: i == 0 ? AppSpacing.lg : AppSpacing.sm),
            actions[i],
          ],
        ],
      ),
    );
  }
}
