import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../domain/dashboard_models.dart';
import '../providers/dashboard_providers.dart';

/// "Where your money goes": thick rounded donut with a hatched "Other" slice
/// and a legend of percentages.
class CategoryBreakdownCard extends ConsumerWidget {
  const CategoryBreakdownCard({super.key});

  /// Below this card content width the legend stacks under the donut.
  static const double _stackBreakpoint = 290;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slices = ref.watch(categoryBreakdownProvider);
    final totalCents = ref.watch(spendingSummaryProvider).monthlyTotalCents;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  container: true,
                  header: true,
                  child: Text(
                    'Where your money goes',
                    style: AppTypography.titleMedium,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              const _PeriodPill(label: 'This month'),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          LayoutBuilder(
            builder: (context, constraints) {
              final donut = _Donut(slices: slices, totalCents: totalCents);
              final legend = _Legend(slices: slices);
              if (constraints.maxWidth < _stackBreakpoint) {
                return Column(
                  children: [
                    donut,
                    const SizedBox(height: AppSpacing.lg),
                    legend,
                  ],
                );
              }
              return Row(
                children: [
                  donut,
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(child: legend),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PeriodPill extends StatelessWidget {
  const _PeriodPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.badgePadding,
      decoration: BoxDecoration(
        borderRadius: AppRadius.pillAll,
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Text(label, style: AppTypography.caption),
    );
  }
}

class _Donut extends StatelessWidget {
  const _Donut({required this.slices, required this.totalCents});

  final List<CategorySpend> slices;
  final int totalCents;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: AppSizes.donutSize,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : AppMotion.slow * 2,
          curve: AppMotion.emphasized,
          builder: (context, progress, child) => CustomPaint(
            painter: _DonutPainter(slices: slices, progress: progress),
            child: child,
          ),
          child: Padding(
            padding: const EdgeInsets.all(
              AppSizes.donutThickness + AppSpacing.xs,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    CurrencyFormatter.formatCents(totalCents),
                    maxLines: 1,
                    style: AppTypography.amountMedium,
                  ),
                ),
                Text('Total', maxLines: 1, style: AppTypography.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints donut arcs with round caps and gaps; the "Other" slice
/// ([CategorySpend.category] == null) is drawn as diagonal hatching.
class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.slices, required this.progress});

  final List<CategorySpend> slices;
  final double progress;

  static const double _gapRadians = 0.16;

  @override
  void paint(Canvas canvas, Size size) {
    const thickness = AppSizes.donutThickness;
    final radius = (math.min(size.width, size.height) - thickness) / 2;
    final center = size.center(Offset.zero);
    final rect = Rect.fromCircle(center: center, radius: radius);
    final total = slices.fold(0, (sum, s) => sum + s.totalCents);
    if (total == 0) return;

    final gap = slices.length > 1 ? _gapRadians : 0.0;
    final sweepAvailable = 2 * math.pi * progress - gap * slices.length;
    var start = -math.pi / 2 + gap / 2;

    for (final slice in slices) {
      final sweep = math.max(0.0, sweepAvailable * slice.totalCents / total);
      if (sweep > 0) {
        if (slice.category == null) {
          _paintHatched(canvas, center, radius, start, sweep, thickness);
        } else {
          canvas.drawArc(
            rect,
            start,
            sweep,
            false,
            Paint()
              ..color = slice.color
              ..style = PaintingStyle.stroke
              ..strokeWidth = thickness
              ..strokeCap = StrokeCap.round,
          );
        }
      }
      start += sweep + gap;
    }
  }

  void _paintHatched(
    Canvas canvas,
    Offset center,
    double radius,
    double start,
    double sweep,
    double thickness,
  ) {
    final outer = radius + thickness / 2;
    final inner = radius - thickness / 2;
    final path = Path()
      ..arcTo(
        Rect.fromCircle(center: center, radius: outer),
        start,
        sweep,
        true,
      )
      ..arcTo(
        Rect.fromCircle(center: center, radius: inner),
        start + sweep,
        -sweep,
        false,
      )
      ..close();

    canvas.drawPath(path, Paint()..color = AppColors.logoTileNeutral);
    canvas.save();
    canvas.clipPath(path);
    final hatch = Paint()
      ..color = AppColors.chartHatch
      ..strokeWidth = AppSizes.hairline * 1.5;
    const step = AppSpacing.xxs + 1;
    for (var x = -outer * 2; x < outer * 2; x += step) {
      canvas.drawLine(
        center + Offset(x, -outer),
        center + Offset(x + outer * 2, outer),
        hatch,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DonutPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.slices != slices;
}

class _Legend extends StatelessWidget {
  const _Legend({required this.slices});

  final List<CategorySpend> slices;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < slices.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.sm),
          _LegendRow(slice: slices[i]),
        ],
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.slice});

  final CategorySpend slice;

  @override
  Widget build(BuildContext context) {
    final amount = CurrencyFormatter.formatCents(slice.totalCents);
    return Semantics(
      container: true,
      label: '${slice.label}, ${slice.percent} percent, $amount per month',
      excludeSemantics: true,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: AppSizes.legendBar,
              decoration: BoxDecoration(
                color: slice.category == null
                    ? AppColors.chartHatch
                    : slice.color,
                borderRadius: AppRadius.pillAll,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${slice.percent}%', style: AppTypography.statValue),
                  Text(
                    slice.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall,
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
