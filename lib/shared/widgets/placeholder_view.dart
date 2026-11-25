import 'package:flutter/widgets.dart';

import '../../core/theme/theme.dart';
import 'app_card.dart';

/// Friendly "coming soon" state for destinations that are not built yet.
class PlaceholderView extends StatelessWidget {
  const PlaceholderView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: AppSpacing.screenPadding,
          child: AppCard(
            padding: AppSpacing.cardPaddingLarge,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: AppSizes.illustrationTile,
                  height: AppSizes.illustrationTile,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.lavender,
                    borderRadius: AppRadius.lgAll,
                  ),
                  child: Icon(
                    icon,
                    size: AppSizes.iconXl,
                    color: AppColors.textPrimary,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
