import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/money/money.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_labels.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../domain/payment_record.dart';
import '../analytics_copy.dart';
import '../providers/analytics_providers.dart';
import 'analytics_parts.dart';

/// Monthly and yearly summaries, each labelled estimated (from history) or
/// projected (from active schedules).
class SpendingSummariesCard extends ConsumerWidget {
  const SpendingSummariesCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(analyticsOverviewProvider).summary;
    final trend = ref.watch(spendingTrendProvider);
    final yearly = ref.watch(yearlySpendingSummaryProvider);
    final average = trend.monthlyAverage;
    final since = trend.trackingSince;

    String money(bool estimate, Money amount) =>
        '${AnalyticsCopy.approx(estimate)}${CurrencyFormatter.format(amount)}';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _GroupTitle(title: 'Monthly'),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AnalyticsMetric(
                  label: 'This month',
                  value: money(summary.isEstimate, summary.monthlyTotal),
                  caption: SpendingBasis.estimated.label,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AnalyticsMetric(
                  label: 'Average · ${trend.period.label}',
                  value: average == null
                      ? '—'
                      : money(trend.isEstimate, average),
                  caption: trend.monthsWithData < trend.period.months
                      ? 'Over ${trend.monthsWithData} tracked '
                            '${trend.monthsWithData == 1 ? 'month' : 'months'}'
                      : SpendingBasis.estimated.label,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const _GroupTitle(title: 'Yearly'),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AnalyticsMetric(
                  label: '${yearly.year} so far',
                  value: money(yearly.isEstimate, yearly.yearToDate),
                  caption: yearly.isPartialYear && since != null
                      ? 'Estimated · since ${DateLabels.shortMonth(since)}'
                      : SpendingBasis.estimated.label,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AnalyticsMetric(
                  label: 'Next 12 months',
                  value: money(
                    summary.isEstimate,
                    yearly.projectedNext12Months,
                  ),
                  caption: '${SpendingBasis.projected.label} · active plans',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      header: true,
      child: Text(title.toUpperCase(), style: AppTypography.labelSmall),
    );
  }
}
