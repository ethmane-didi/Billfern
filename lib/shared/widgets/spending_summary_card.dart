import 'package:flutter/material.dart';

import '../../core/money/money.dart';
import '../../core/theme/theme.dart';
import '../../core/utils/currency_formatter.dart';
import 'app_card.dart';
import 'trend_badge.dart';

/// Dark hero card summarising recurring spending for a period.
///
/// Shows the total in a bold split figure, the change versus the previous
/// period, the active subscription count and a projected yearly total.
///
/// The card only displays figures; callers compute them (see
/// `SpendingCalculator`) so every screen shows the same numbers.
class SpendingSummaryCard extends StatelessWidget {
  const SpendingSummaryCard({
    super.key,
    required this.amount,
    required this.changePercent,
    required this.activeCount,
    required this.projectedYearly,
    this.title = 'Monthly spending',
    this.comparisonLabel = 'vs last month',
    this.onTap,
  });

  /// Total spend for the period.
  final Money amount;

  /// Change versus the previous period, in percent. Negative = less spent.
  final double changePercent;

  final int activeCount;

  /// Twelve-month cost of the active subscriptions.
  final Money projectedYearly;

  final String title;
  final String comparisonLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      gradient: AppGradients.midnight,
      shadows: AppShadows.floating,
      padding: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      onTap: onTap,
      semanticLabel: title,
      child: Stack(
        children: [
          const Positioned(top: -90, right: -70, child: _AccentGlow()),
          Padding(
            padding: AppSpacing.cardPaddingLarge,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.textOnDarkMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _SplitAmount(amount: amount),
                const SizedBox(height: AppSpacing.md),
                TrendBadge(
                  changePercent: changePercent,
                  label: comparisonLabel,
                  onDark: true,
                ),
                const SizedBox(height: AppSpacing.xl),
                const Divider(color: AppColors.overlayOnDark),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: _Stat(
                        value: '$activeCount',
                        label: 'Active subscriptions',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _Stat(
                        value: CurrencyFormatter.format(
                          projectedYearly,
                          showDecimals: false,
                        ),
                        label: 'Projected yearly',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SplitAmount extends StatelessWidget {
  const _SplitAmount({required this.amount});

  final Money amount;

  @override
  Widget build(BuildContext context) {
    final parts = CurrencyFormatter.split(amount);

    return Semantics(
      label: CurrencyFormatter.format(amount),
      excludeSemantics: true,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: parts.whole,
                style: AppTypography.amountHero.copyWith(
                  color: AppColors.textOnDark,
                ),
              ),
              TextSpan(
                text: parts.fraction,
                style: AppTypography.amountMedium.copyWith(
                  color: AppColors.textOnDarkMuted,
                ),
              ),
            ],
          ),
          maxLines: 1,
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.amountMedium.copyWith(
              color: AppColors.textOnDark,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textOnDarkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccentGlow extends StatelessWidget {
  const _AccentGlow();

  static const double _size = 240;

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: SizedBox.square(
        dimension: _size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppGradients.glowYellowOnDark,
          ),
        ),
      ),
    );
  }
}
