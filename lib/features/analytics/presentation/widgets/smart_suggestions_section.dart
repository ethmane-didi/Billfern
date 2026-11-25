import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../domain/analytics_models.dart';
import '../analytics_copy.dart';
import '../providers/analytics_providers.dart';

/// Local, rule-based savings suggestions, clearly labelled as such (not AI
/// analysis; no usage data).
class SmartSuggestionsSection extends ConsumerWidget {
  const SmartSuggestionsSection({super.key, required this.onSubscriptionTap});

  final ValueChanged<String> onSubscriptionTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestions = ref.watch(smartSuggestionsProvider);
    if (suggestions.isEmpty) {
      return const _SuggestionTile(
        icon: LucideIcons.sparkles,
        title: 'No suggestions right now',
        message:
            'Nothing in your subscription list stands out. New suggestions '
            'appear as your subscriptions change.',
      );
    }
    final approx = AnalyticsCopy.approx(suggestions.isEstimate);
    final monthly = CurrencyFormatter.format(suggestions.monthlyPotential);
    final yearly = CurrencyFormatter.format(suggestions.yearlyPotential);

    return Column(
      children: [
        AppCard(
          gradient: AppGradients.mint,
          semanticLabel:
              'Potential savings if you acted on every suggestion: up to '
              '${suggestions.isEstimate ? 'about ' : ''}$monthly a month, '
              '$yearly a year',
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Potential savings',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Up to $approx$monthly/mo',
                        maxLines: 1,
                        style: AppTypography.amountSmall,
                      ),
                    ),
                    Text(
                      '$approx$yearly a year if you acted on every suggestion',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        for (final suggestion in suggestions.items) ...[
          const SizedBox(height: AppSpacing.sm),
          _SuggestionTile(
            icon: _icon(suggestion.kind),
            title: AnalyticsCopy.suggestionTitle(suggestion),
            message: AnalyticsCopy.suggestionMessage(suggestion),
            onTap: () => onSubscriptionTap(
              (suggestion.cancel.isNotEmpty
                      ? suggestion.cancel.first
                      : suggestion.subscriptions.first)
                  .id,
            ),
          ),
        ],
      ],
    );
  }

  static IconData _icon(SuggestionKind kind) => switch (kind) {
    SuggestionKind.duplicateService => LucideIcons.copy,
    SuggestionKind.overlappingServices => LucideIcons.layers,
    SuggestionKind.annualRenewal => LucideIcons.calendarClock,
    SuggestionKind.largestSubscription => LucideIcons.chartPie,
  };
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({
    required this.icon,
    required this.title,
    required this.message,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: onTap,
      semanticLabel: 'Smart suggestion. $title. $message',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: AppSizes.insightTile,
            height: AppSizes.insightTile,
            decoration: const BoxDecoration(
              color: AppColors.midnight,
              borderRadius: AppRadius.mdAll,
            ),
            child: Icon(icon, size: AppSizes.iconLg, color: AppColors.yellow),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.titleSmall),
                const SizedBox(height: AppSpacing.xxs),
                Text(message, style: AppTypography.bodySmall),
              ],
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: AppSpacing.xs),
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.md),
              child: Icon(
                LucideIcons.chevronRight,
                size: AppSizes.iconMd,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
