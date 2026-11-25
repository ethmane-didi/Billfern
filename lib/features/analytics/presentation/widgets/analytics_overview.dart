import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/money/currency.dart';
import '../../../../core/money/exchange_rates.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/providers/currency_providers.dart';
import '../../../../shared/widgets/conversion_note.dart';
import '../../domain/payment_record.dart';
import '../analytics_copy.dart';
import '../providers/analytics_providers.dart';
import 'analytics_parts.dart';

/// Spending overview: this month's estimated spending (the same figure as
/// the dashboard), the change versus last month, projected yearly cost,
/// active and paused counts, the display currency and exchange-rate status.
class AnalyticsOverviewSection extends ConsumerWidget {
  const AnalyticsOverviewSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(analyticsOverviewProvider);
    final summary = overview.summary;
    final converter = ref.watch(moneyConverterProvider);
    final approx = AnalyticsCopy.approx(summary.isEstimate);
    final total = CurrencyFormatter.format(summary.monthlyTotal);
    final yearly = CurrencyFormatter.format(
      summary.projectedYearly,
      showDecimals: false,
    );

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                'Spent this month',
                textAlign: TextAlign.center,
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            const BasisTag(basis: SpendingBasis.estimated),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Semantics(
          container: true,
          label:
              'Estimated spending this month, '
              '${summary.isEstimate ? 'about ' : ''}$total',
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
        const SizedBox(height: AppSpacing.sm),
        ComparisonBadge(comparison: overview.monthOverMonth),
        const SizedBox(height: AppSpacing.sm),
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
              child: _OverviewChip(
                icon: LucideIcons.circleCheck,
                caption: 'Subscriptions',
                value:
                    '${summary.activeCount} active · '
                    '${summary.pausedCount} paused',
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: _OverviewChip(
                icon: LucideIcons.calendarRange,
                caption: 'Projected yearly',
                value: '$approx$yearly',
                semanticValue:
                    '${summary.isEstimate ? 'about ' : ''}$yearly, projected',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        const _RateStatusLine(),
      ],
    );
  }
}

class _OverviewChip extends StatelessWidget {
  const _OverviewChip({
    required this.icon,
    required this.caption,
    required this.value,
    this.semanticValue,
  });

  final IconData icon;
  final String caption;
  final String value;
  final String? semanticValue;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$caption, ${semanticValue ?? value}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceTranslucent,
          borderRadius: AppRadius.lgAll,
          border: Border.all(color: AppColors.surface),
        ),
        child: Row(
          children: [
            Icon(icon, size: AppSizes.iconSm, color: AppColors.textMuted),
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
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      maxLines: 1,
                      style: AppTypography.titleSmall,
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

/// "USD · US Dollar · Mock exchange rates (development)" and similar, so
/// rate quality is always visible on Analytics.
class _RateStatusLine extends ConsumerWidget {
  const _RateStatusLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = Currency.of(ref.watch(preferredCurrencyProvider));
    final state = ref.watch(exchangeRatesProvider);
    final (status, warning) = switch (state) {
      RatesUnavailable() => ('Exchange rates unavailable', true),
      RatesAvailable(isStale: true) => ('Exchange rates may be outdated', true),
      RatesAvailable(:final rates) when rates.isMock => (
        'Mock exchange rates (development)',
        false,
      ),
      RatesAvailable() => ('Exchange rates up to date', false),
    };
    final color = warning ? AppColors.dangerStrong : AppColors.textMuted;
    return Semantics(
      container: true,
      label: 'Display currency ${currency.name}. $status',
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            warning ? LucideIcons.triangleAlert : LucideIcons.arrowLeftRight,
            size: AppSizes.iconXs,
            color: color,
          ),
          const SizedBox(width: AppSpacing.xxs),
          Flexible(
            child: Text(
              '${currency.code} · $status',
              textAlign: TextAlign.center,
              style: AppTypography.caption.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
