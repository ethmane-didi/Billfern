import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/providers/user_provider.dart';
import '../providers/dashboard_providers.dart';

/// Hero figure on the gradient: greeting, total monthly spending, the yearly
/// projection, and three stat chips (active count, change vs last month,
/// due this week).
class SpendingOverview extends ConsumerWidget {
  const SpendingOverview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(spendingSummaryProvider);
    final greeting = ref.watch(greetingProvider);
    final user = ref.watch(currentUserProvider);
    final dueThisWeek = ref.watch(dueThisWeekCentsProvider);

    final total = CurrencyFormatter.formatCents(summary.monthlyTotalCents);
    final yearly = CurrencyFormatter.formatCents(
      summary.projectedYearlyCents,
      decimalDigits: 0,
    );
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
          label: 'Total monthly spending, $total',
          excludeSemantics: true,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(total, maxLines: 1, style: AppTypography.amountHero),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Total monthly spending · $yearly a year',
          textAlign: TextAlign.center,
          style: AppTypography.bodyMedium.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: AppSpacing.xl),
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
                value: CurrencyFormatter.formatCents(dueThisWeek),
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
