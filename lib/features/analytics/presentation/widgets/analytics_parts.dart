import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/theme.dart';
import '../../domain/analytics_models.dart';
import '../../domain/payment_record.dart';
import '../analytics_copy.dart';

/// Pill comparing a figure with its baseline. Spending going down is good
/// (mint), going up is bad (coral). Without a baseline, or against zero, no
/// percentage is shown.
class ComparisonBadge extends StatelessWidget {
  const ComparisonBadge({
    super.key,
    required this.comparison,
    this.baseline = 'last month',
  });

  final PeriodComparison comparison;
  final String baseline;

  @override
  Widget build(BuildContext context) {
    final (icon, foreground, background) = switch (comparison.kind) {
      ComparisonKind.decrease => (
        LucideIcons.trendingDown,
        AppColors.successStrong,
        AppColors.mintSoft,
      ),
      ComparisonKind.increase || ComparisonKind.fromZero => (
        LucideIcons.trendingUp,
        AppColors.dangerStrong,
        AppColors.dangerSoft,
      ),
      ComparisonKind.unchanged => (
        LucideIcons.minus,
        AppColors.textMuted,
        AppColors.lavender,
      ),
      ComparisonKind.noBaseline => (
        LucideIcons.history,
        AppColors.textMuted,
        AppColors.lavender,
      ),
    };
    return Semantics(
      container: true,
      label: AnalyticsCopy.comparisonSemantics(comparison, baseline: baseline),
      excludeSemantics: true,
      child: Container(
        padding: AppSpacing.badgePadding,
        decoration: BoxDecoration(
          color: background,
          borderRadius: AppRadius.pillAll,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: AppSizes.iconXs, color: foreground),
            const SizedBox(width: AppSpacing.xxs),
            Flexible(
              child: Text(
                AnalyticsCopy.comparisonBadge(comparison, baseline: baseline),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelMedium.copyWith(color: foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small tag naming how a figure was produced: estimated (history),
/// projected (future) or confirmed (recorded payments).
class BasisTag extends StatelessWidget {
  const BasisTag({super.key, required this.basis});

  final SpendingBasis basis;

  @override
  Widget build(BuildContext context) {
    final (icon, background) = switch (basis) {
      SpendingBasis.estimated => (LucideIcons.calculator, AppColors.lavender),
      SpendingBasis.projected => (LucideIcons.calendarClock, AppColors.cream),
      SpendingBasis.confirmed => (LucideIcons.circleCheck, AppColors.mintSoft),
    };
    return Semantics(
      container: true,
      label: '${basis.label} figures',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xxs / 2,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: AppRadius.pillAll,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: AppSizes.iconXs, color: AppColors.textMuted),
            const SizedBox(width: AppSpacing.xxs),
            Text(basis.label, style: AppTypography.caption),
          ],
        ),
      ),
    );
  }
}

/// Label above a figure, with an optional caption below. The amount scales
/// down rather than overflowing.
class AnalyticsMetric extends StatelessWidget {
  const AnalyticsMetric({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.semanticValue,
  });

  final String label;
  final String value;
  final String? caption;
  final String? semanticValue;

  @override
  Widget build(BuildContext context) {
    final caption = this.caption;
    return Semantics(
      container: true,
      label: [label, semanticValue ?? value, ?caption].join(', '),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodySmall,
          ),
          const SizedBox(height: AppSpacing.xxs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, maxLines: 1, style: AppTypography.statValue),
          ),
          if (caption != null) ...[
            const SizedBox(height: AppSpacing.xxs / 2),
            Text(
              caption,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption,
            ),
          ],
        ],
      ),
    );
  }
}
