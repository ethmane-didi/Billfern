import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_labels.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/trend_badge.dart';
import '../../domain/dashboard_models.dart';
import '../providers/dashboard_providers.dart';

/// This month versus last month with a soft yellow area chart of recent
/// monthly spending; the current month is marked with a mint indicator.
class SpendingTrendCard extends ConsumerWidget {
  const SpendingTrendCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(spendingSummaryProvider);
    final history = ref.watch(spendingHistoryProvider);
    final total = CurrencyFormatter.formatCents(summary.monthlyTotalCents);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Semantics(
                  container: true,
                  label: 'This month, $total',
                  excludeSemantics: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'This month',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          total,
                          maxLines: 1,
                          style: AppTypography.amountMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              TrendBadge(changePercent: summary.changePercent),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          _ChangeLine(
            changeCents: summary.changeCents,
            previousCents: summary.previousMonthTotalCents,
          ),
          const SizedBox(height: AppSpacing.lg),
          _SpendingLineChart(history: history),
        ],
      ),
    );
  }
}

class _ChangeLine extends StatelessWidget {
  const _ChangeLine({required this.changeCents, required this.previousCents});

  final int changeCents;
  final int previousCents;

  @override
  Widget build(BuildContext context) {
    final amount = CurrencyFormatter.formatCents(changeCents.abs());
    final previous = CurrencyFormatter.formatCents(previousCents);
    final (text, color) = switch (changeCents) {
      < 0 => ('$amount less than last month', AppColors.successStrong),
      > 0 => ('$amount more than last month', AppColors.dangerStrong),
      _ => ('Same as last month', AppColors.textMuted),
    };
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: text,
            style: AppTypography.labelMedium.copyWith(color: color),
          ),
          TextSpan(text: '  ·  $previous', style: AppTypography.bodySmall),
        ],
      ),
    );
  }
}

class _SpendingLineChart extends StatelessWidget {
  const _SpendingLineChart({required this.history});

  final List<MonthlySpend> history;

  static const double _headroom = 1.25;
  static const double _floor = 0.6;
  static const double _curveSmoothness = 0.35;

  @override
  Widget build(BuildContext context) {
    final values = [for (final s in history) s.totalCents.toDouble()];
    final maxValue = values.fold(0.0, math.max);
    final minValue = values.fold(maxValue, math.min);
    final maxY = maxValue == 0 ? 1.0 : maxValue * _headroom;
    final minY = math.max(0.0, minValue * _floor);
    final currentIndex = history.indexWhere((s) => s.isCurrent);
    final description = history
        .map(
          (s) =>
              '${DateLabels.month(s.month)} ${CurrencyFormatter.formatCents(s.totalCents)}',
        )
        .join(', ');

    return Semantics(
      container: true,
      label: 'Monthly spending, last ${history.length} months: $description',
      excludeSemantics: true,
      child: SizedBox(
        height: AppSizes.lineChartHeight,
        child: LineChart(
          duration: AppMotion.slow,
          curve: AppMotion.emphasized,
          LineChartData(
            minX: 0,
            maxX: (history.length - 1).toDouble(),
            minY: minY,
            maxY: maxY,
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: (maxY - minY) / 3,
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
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => AppColors.midnight,
                tooltipBorderRadius: AppRadius.smAll,
                tooltipPadding: AppSpacing.badgePadding,
                getTooltipItems: (spots) => [
                  for (final spot in spots)
                    LineTooltipItem(
                      CurrencyFormatter.formatCents(
                        history[spot.x.toInt()].totalCents,
                      ),
                      AppTypography.labelMedium.copyWith(
                        color: AppColors.textOnDark,
                      ),
                    ),
                ],
              ),
            ),
            extraLinesData: ExtraLinesData(
              verticalLines: [
                if (currentIndex >= 0)
                  VerticalLine(
                    x: currentIndex.toDouble(),
                    color: AppColors.mint,
                    strokeWidth: AppSizes.hairline * 2,
                  ),
              ],
            ),
            lineBarsData: [
              LineChartBarData(
                spots: [
                  for (var i = 0; i < values.length; i++)
                    FlSpot(i.toDouble(), values[i]),
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
                      AppColors.yellow.withValues(alpha: 0.45),
                      AppColors.yellow.withValues(alpha: 0),
                    ],
                  ),
                ),
                dotData: FlDotData(
                  checkToShowDot: (spot, _) => spot.x.toInt() == currentIndex,
                  getDotPainter: (spot, percent, bar, index) =>
                      FlDotCirclePainter(
                        radius: AppSizes.chartDot,
                        color: AppColors.mint,
                        strokeWidth: AppSizes.lineWidth,
                        strokeColor: AppColors.surface,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _monthTitle(double value, TitleMeta meta) {
    final index = value.toInt();
    if (index < 0 || index >= history.length || value != index) {
      return const SizedBox.shrink();
    }
    final spend = history[index];
    return SideTitleWidget(
      meta: meta,
      child: Text(
        DateLabels.shortMonth(spend.month),
        style: AppTypography.caption.copyWith(
          color: spend.isCurrent ? AppColors.textPrimary : AppColors.textMuted,
        ),
      ),
    );
  }
}
