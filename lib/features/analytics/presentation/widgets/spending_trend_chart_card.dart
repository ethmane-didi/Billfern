import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_labels.dart';
import '../../../../shared/providers/currency_providers.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/choice_pill.dart';
import '../../../../shared/widgets/conversion_note.dart';
import '../../../../shared/widgets/pressable_scale.dart';
import '../../domain/analytics_models.dart';
import '../../domain/payment_record.dart';
import '../analytics_copy.dart';
import '../providers/analytics_providers.dart';
import 'analytics_parts.dart';

/// Interactive estimated-spending trend: 3/6/12-month windows, a yellow
/// area chart with tooltips, the selected month's details and a comparison
/// with the preceding period. Months before tracking began have no data and
/// are left blank, never drawn as zero.
class SpendingTrendChartCard extends ConsumerStatefulWidget {
  const SpendingTrendChartCard({super.key});

  @override
  ConsumerState<SpendingTrendChartCard> createState() =>
      _SpendingTrendChartCardState();
}

class _SpendingTrendChartCardState
    extends ConsumerState<SpendingTrendChartCard> {
  /// Selected month index; `null` follows the current month.
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final trend = ref.watch(spendingTrendProvider);
    final period = ref.watch(trendPeriodProvider);
    final converter = ref.watch(moneyConverterProvider);
    final firstWithData = trend.points.indexWhere((p) => p.hasData);
    final last = trend.points.length - 1;
    final int selected = (_selected ?? last).clamp(
      math.max(firstWithData, 0),
      last,
    );

    void select(int index) => setState(() => _selected = index);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      container: true,
                      header: true,
                      child: Text(
                        'Spending trend',
                        style: AppTypography.cardTitle,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'Monthly cost from your subscription schedules',
                      style: AppTypography.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              const BasisTag(basis: SpendingBasis.estimated),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ChoicePillRow(
            children: [
              for (final option in TrendPeriod.values)
                ChoicePill(
                  label: option.shortLabel,
                  selected: option == period,
                  onSelected: () {
                    ref.read(trendPeriodProvider.notifier).select(option);
                    setState(() => _selected = null);
                  },
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (!trend.hasEnoughHistory)
            _InsufficientHistory(trend: trend)
          else ...[
            _SelectedMonth(
              trend: trend,
              index: selected,
              canGoBack: selected > firstWithData,
              canGoForward: selected < last,
              onStep: (delta) => select(selected + delta),
            ),
            const SizedBox(height: AppSpacing.md),
            _TrendChart(trend: trend, selected: selected, onSelect: select),
            const SizedBox(height: AppSpacing.md),
            _PeriodSummary(trend: trend),
          ],
          const SizedBox(height: AppSpacing.sm),
          _Footnote(trend: trend, selected: trend.points[selected]),
          ConversionNote(
            isEstimate: trend.isEstimate,
            usesMockRates: converter.usesMockRates,
            ratesAreStale: converter.ratesAreStale,
            excludedCount: trend.excludedCount,
            missingCurrencies: trend.missingCurrencies,
          ),
        ],
      ),
    );
  }
}

class _SelectedMonth extends StatelessWidget {
  const _SelectedMonth({
    required this.trend,
    required this.index,
    required this.canGoBack,
    required this.canGoForward,
    required this.onStep,
  });

  final SpendingTrend trend;
  final int index;
  final bool canGoBack;
  final bool canGoForward;
  final ValueChanged<int> onStep;

  @override
  Widget build(BuildContext context) {
    final point = trend.points[index];
    final amount = point.estimated;
    final approx = AnalyticsCopy.approx(trend.isEstimate);
    final value = amount == null
        ? 'No data'
        : '$approx${CurrencyFormatter.format(amount)}';
    final baseline = index > 0
        ? DateLabels.month(trend.points[index - 1].month)
        : 'last month';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                container: true,
                liveRegion: true,
                label:
                    '${AnalyticsCopy.monthTitle(point)}, estimated '
                    '${amount == null ? 'no data' : CurrencyFormatter.format(amount)}'
                    ', ${point.billedCount} '
                    '${point.billedCount == 1 ? 'subscription' : 'subscriptions'}',
                excludeSemantics: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${AnalyticsCopy.monthTitle(point)} · '
                      '${point.billedCount} '
                      '${point.billedCount == 1 ? 'subscription' : 'subscriptions'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall,
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        maxLines: 1,
                        style: AppTypography.amountMedium,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              ComparisonBadge(
                comparison: trend.monthComparison(index),
                baseline: baseline,
              ),
            ],
          ),
        ),
        _StepButton(
          icon: LucideIcons.chevronLeft,
          label: 'Previous month',
          enabled: canGoBack,
          onPressed: () => onStep(-1),
        ),
        const SizedBox(width: AppSpacing.xxs),
        _StepButton(
          icon: LucideIcons.chevronRight,
          label: 'Next month',
          enabled: canGoForward,
          onPressed: () => onStep(1),
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: PressableScale(
        onPressed: enabled ? onPressed : null,
        child: AnimatedOpacity(
          duration: AppMotion.fast,
          opacity: enabled ? 1 : AppMotion.disabledOpacity,
          child: Container(
            width: AppSizes.minTapTarget,
            height: AppSizes.minTapTarget,
            decoration: const BoxDecoration(
              color: AppColors.lavender,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: AppSizes.iconMd, color: AppColors.midnight),
          ),
        ),
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({
    required this.trend,
    required this.selected,
    required this.onSelect,
  });

  final SpendingTrend trend;
  final int selected;
  final ValueChanged<int> onSelect;

  static const double _headroom = 1.2;
  static const double _floor = 0.6;
  static const double _curveSmoothness = 0.3;
  static const double _fillAlpha = 0.4;

  @override
  Widget build(BuildContext context) {
    final points = trend.points;
    final values = [
      for (final point in trend.pointsWithData)
        point.estimated!.minorUnits.toDouble(),
    ];
    final maxValue = values.fold(0.0, math.max);
    final minValue = values.fold(maxValue, math.min);
    final maxY = maxValue == 0 ? 1.0 : maxValue * _headroom;
    final minY = math.max(0.0, minValue * _floor);

    return Semantics(
      container: true,
      label: AnalyticsCopy.trendSemantics(trend),
      excludeSemantics: true,
      child: SizedBox(
        height: AppSizes.analyticsChartHeight,
        child: LineChart(
          duration: AppMotion.slow,
          curve: AppMotion.emphasized,
          LineChartData(
            minX: 0,
            maxX: (points.length - 1).toDouble(),
            minY: minY,
            maxY: maxY,
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: math.max((maxY - minY) / 3, 1),
              getDrawingHorizontalLine: (_) => const FlLine(
                color: AppColors.border,
                strokeWidth: AppSizes.hairline,
              ),
            ),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              topTitles: const AxisTitles(),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 1,
                  reservedSize: AppSpacing.xxl,
                  getTitlesWidget: _monthTitle,
                ),
              ),
            ),
            lineTouchData: LineTouchData(
              touchCallback: (event, response) {
                final spots = response?.lineBarSpots;
                if (!event.isInterestedForInteractions ||
                    spots == null ||
                    spots.isEmpty) {
                  return;
                }
                final index = spots.first.x.toInt();
                if (index != selected && points[index].hasData) {
                  onSelect(index);
                }
              },
              getTouchedSpotIndicator: (bar, indexes) => [
                for (final _ in indexes)
                  TouchedSpotIndicatorData(
                    const FlLine(
                      color: AppColors.mint,
                      strokeWidth: AppSizes.hairline * 2,
                    ),
                    FlDotData(
                      getDotPainter: (spot, percent, bar, index) =>
                          _selectedDot(),
                    ),
                  ),
              ],
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => AppColors.midnight,
                tooltipBorderRadius: AppRadius.smAll,
                tooltipPadding: AppSpacing.badgePadding,
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                getTooltipItems: (spots) => [
                  for (final spot in spots)
                    LineTooltipItem(
                      '${DateLabels.shortMonth(points[spot.x.toInt()].month)} · '
                      '${AnalyticsCopy.approx(trend.isEstimate)}'
                      '${CurrencyFormatter.format(points[spot.x.toInt()].estimated!)}',
                      AppTypography.labelMedium.copyWith(
                        color: AppColors.textOnDark,
                      ),
                    ),
                ],
              ),
            ),
            extraLinesData: ExtraLinesData(
              verticalLines: [
                VerticalLine(
                  x: selected.toDouble(),
                  color: AppColors.mint,
                  strokeWidth: AppSizes.hairline * 2,
                ),
              ],
            ),
            lineBarsData: [
              LineChartBarData(
                spots: [
                  for (var i = 0; i < points.length; i++)
                    points[i].hasData
                        ? FlSpot(
                            i.toDouble(),
                            points[i].estimated!.minorUnits.toDouble(),
                          )
                        : FlSpot.nullSpot,
                ],
                isCurved: true,
                curveSmoothness: _curveSmoothness,
                preventCurveOverShooting: true,
                color: AppColors.yellow,
                barWidth: AppSizes.lineWidth,
                isStrokeCapRound: true,
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.yellow.withValues(alpha: _fillAlpha),
                      AppColors.yellow.withValues(alpha: 0),
                    ],
                  ),
                ),
                dotData: FlDotData(
                  checkToShowDot: (spot, _) => spot.x.toInt() == selected,
                  getDotPainter: (spot, percent, bar, index) => _selectedDot(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static FlDotPainter _selectedDot() => FlDotCirclePainter(
    radius: AppSizes.chartDot,
    color: AppColors.mint,
    strokeWidth: AppSizes.lineWidth,
    strokeColor: AppColors.surface,
  );

  Widget _monthTitle(double value, TitleMeta meta) {
    final index = value.toInt();
    final points = trend.points;
    if (index < 0 || index >= points.length || value != index) {
      return const SizedBox.shrink();
    }
    // Twelve labels do not fit on small phones; show every other one.
    if (points.length > 6 && index.isOdd && index != selected) {
      return const SizedBox.shrink();
    }
    final point = points[index];
    final color = index == selected
        ? AppColors.textPrimary
        : (point.hasData ? AppColors.textMuted : AppColors.secondaryText);
    return SideTitleWidget(
      meta: meta,
      child: Text(
        DateLabels.shortMonth(point.month),
        style: AppTypography.caption.copyWith(color: color),
      ),
    );
  }
}

/// Total, average and comparison for the selected window.
class _PeriodSummary extends StatelessWidget {
  const _PeriodSummary({required this.trend});

  final SpendingTrend trend;

  @override
  Widget build(BuildContext context) {
    final approx = AnalyticsCopy.approx(trend.isEstimate);
    final average = trend.monthlyAverage;
    final months = trend.monthsWithData;
    final monthsLabel = '$months ${months == 1 ? 'month' : 'months'}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AnalyticsMetric(
                label: 'Total · $monthsLabel',
                value: '$approx${CurrencyFormatter.format(trend.periodTotal)}',
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AnalyticsMetric(
                label: 'Average a month',
                value: average == null
                    ? '—'
                    : '$approx${CurrencyFormatter.format(average)}',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ComparisonBadge(
          comparison: trend.periodComparison,
          baseline: 'previous ${trend.period.label}',
        ),
      ],
    );
  }
}

/// Shown until there are at least two months of recorded history.
class _InsufficientHistory extends StatelessWidget {
  const _InsufficientHistory({required this.trend});

  final SpendingTrend trend;

  @override
  Widget build(BuildContext context) {
    final current = trend.points.last;
    final since = trend.trackingSince;
    final amount = current.estimated;
    return Container(
      width: double.infinity,
      padding: AppSpacing.cardPadding,
      decoration: const BoxDecoration(
        color: AppColors.yellowSoft,
        borderRadius: AppRadius.lgAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ExcludeSemantics(
            child: Icon(
              LucideIcons.chartSpline,
              size: AppSizes.iconLg,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Semantics(
            container: true,
            header: true,
            child: Text(
              'Your trend starts next month',
              style: AppTypography.titleSmall,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            '${since == null ? 'Tracking has not started yet.' : 'Tracking began in ${DateLabels.month(since)}.'} '
            'Trends need two months of history. Billfern never fills '
            'earlier months with made-up spending.',
            style: AppTypography.bodySmall,
          ),
          if (amount != null) ...[
            const SizedBox(height: AppSpacing.sm),
            AnalyticsMetric(
              label: 'This month so far',
              value:
                  '${AnalyticsCopy.approx(trend.isEstimate)}'
                  '${CurrencyFormatter.format(amount)}',
            ),
          ],
        ],
      ),
    );
  }
}

class _Footnote extends StatelessWidget {
  const _Footnote({required this.trend, required this.selected});

  final SpendingTrend trend;
  final TrendPoint selected;

  @override
  Widget build(BuildContext context) {
    final confirmed = selected.confirmed;
    final text = confirmed.isZero
        ? 'Estimated from your schedules, price changes and pauses. '
              'No confirmed payments recorded yet.'
        : 'Confirmed payments in ${DateLabels.month(selected.month)}: '
              '${CurrencyFormatter.format(confirmed)}.';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
      child: Text(text, style: AppTypography.caption),
    );
  }
}
