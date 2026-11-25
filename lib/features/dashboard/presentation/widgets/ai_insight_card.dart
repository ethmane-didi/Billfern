import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../domain/dashboard_models.dart';
import '../providers/dashboard_providers.dart';

/// "Smart tip" card previewing a savings recommendation.
///
/// Tips currently come from `MockSavingsInsightEngine` (local rules on sample
/// data), not real AI analysis; the "Sample data" tag and semantics say so.
class AiInsightCard extends ConsumerWidget {
  const AiInsightCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insight = ref.watch(savingsInsightProvider);
    final title = insight?.title ?? 'No savings found right now';
    final message =
        (insight == null ? null : describeInsight(insight)) ??
        'No overlapping subscriptions found. New tips will appear here.';

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: onTap,
      semanticLabel: 'Smart tip, based on sample data. $title. $message',
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
            child: const Icon(
              LucideIcons.lightbulb,
              size: AppSizes.iconLg,
              color: AppColors.yellow,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.titleSmall),
                const SizedBox(height: AppSpacing.xxs),
                Text(message, style: AppTypography.bodySmall),
                const SizedBox(height: AppSpacing.xs),
                const _SampleTag(),
              ],
            ),
          ),
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
      ),
    );
  }
}

/// User-facing wording of [insight], with the savings formatted in the
/// display currency ("about" when converted from another currency).
String describeInsight(SavingsInsight insight) {
  final names = [for (final sub in insight.subscriptions) sub.name];
  final joined = names.length == 2
      ? 'both ${names[0]} and ${names[1]}'
      : '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
  final savings = CurrencyFormatter.format(insight.annualSavings);
  return 'You pay for $joined. Keeping just ${insight.keep.name} could save '
      'you ${insight.isEstimate ? 'about ' : ''}$savings a year.';
}

class _SampleTag extends StatelessWidget {
  const _SampleTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs / 2,
      ),
      decoration: const BoxDecoration(
        color: AppColors.lavender,
        borderRadius: AppRadius.pillAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            LucideIcons.sparkles,
            size: AppSizes.iconXs,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: AppSpacing.xxs),
          Flexible(
            child: Text(
              'Smart tip · Sample data',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption,
            ),
          ),
        ],
      ),
    );
  }
}
