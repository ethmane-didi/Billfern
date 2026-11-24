import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/providers/currency_providers.dart';
import '../../../../shared/providers/user_provider.dart';
import '../../../../shared/widgets/conversion_note.dart';
import '../../../../shared/widgets/currency_selector.dart';
import '../providers/dashboard_providers.dart';

/// Hero figure on the gradient: greeting, total monthly spending in the
/// preferred currency (with a selector and an estimate note when amounts
/// were converted), the yearly projection, and three stat chips.
class SpendingOverview extends ConsumerWidget {
  const SpendingOverview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(spendingSummaryProvider);
    final greeting = ref.watch(greetingProvider);
    final user = ref.watch(currentUserProvider);
    final dueThisWeek = ref.watch(dueThisWeekProvider);
    final converter = ref.watch(moneyConverterProvider);

    final total = CurrencyFormatter.format(summary.monthlyTotal);
    final yearly = CurrencyFormatter.format(
      summary.projectedYearly,
      showDecimals: false,
    );
    final approx = summary.isEstimate ? '≈ ' : '';
    final change = summary.changePercent;

    return Column(
      children: [
        Semantics(
          container: true,
          header: true,
          child: Text(
            '$greeting, ${user.firstName}',
            textAlign: TextAlign.center,
            style: AppTypography.bodyLarge.copyWith(color: AppColors.textMuted),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Semantics(
          container: true,
          label:
              'Total monthly spending, ${summary.isEstimate ? 'about ' : ''}$total',
          excludeSemantics: true,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$approx$total',
              maxLines: 1,
              style: AppTypography.amountHero,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Total monthly spending · $approx$yearly a year',
          textAlign: TextAlign.center,
          style: AppTypography.bodyMedium.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: AppSpacing.xxs),
        const CurrencySelector(),
        ConversionNote(
          isEstimate: summary.isEstimate,
          usesMockRates: converter.usesMockRates,
          ratesAreStale: converter.ratesAreStale,
          excludedCount: summary.excludedCount,
          missingCurrencies: summary.missingCurrencies,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: _StatChip(
                icon: LucideIcons.circleCheck,
                caption: 'Active',
                value: '${summary.activeCount} active',
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: _StatChip(
                icon: change <= 0
                    ? LucideIcons.trendingDown
                    : LucideIcons.trendingUp,
                caption: 'Change',
                value: CurrencyFormatter.signedPercent(change),
                valueColor: change < 0
                    ? AppColors.successStrong
                    : (change > 0 ? AppColors.dangerStrong : null),
                semanticValue:
                    'versus last month, spending ${change < 0 ? 'down' : (change > 0 ? 'up' : 'unchanged')} '
                    '${change.abs().toStringAsFixed(1)} percent',
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: _StatChip(
                icon: LucideIcons.calendarClock,
                caption: 'This week',
                value: CurrencyFormatter.format(dueThisWeek),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.caption,
    required this.value,
    this.valueColor,
    this.semanticValue,
  });

  final IconData icon;
  final String caption;
  final String value;
  final Color? valueColor;
  final String? semanticValue;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$caption, ${semanticValue ?? value}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xs,
          AppSpacing.xs,
          AppSpacing.sm,
          AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceTranslucent,
          borderRadius: AppRadius.pillAll,
          border: Border.all(color: AppColors.surface),
        ),
        child: Row(
          children: [
            Container(
              width: AppSizes.statChipIcon,
              height: AppSizes.statChipIcon,
              decoration: const BoxDecoration(
                color: AppColors.lavender,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: AppSizes.iconSm,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption,
                  ),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelMedium.copyWith(
                      color: valueColor ?? AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
