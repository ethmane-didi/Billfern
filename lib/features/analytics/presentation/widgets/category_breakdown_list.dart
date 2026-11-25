import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/models/subscription_category.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/pressable_scale.dart';
import '../../../../shared/widgets/subscription_logo.dart';
import '../../../dashboard/domain/dashboard_models.dart';
import '../../../dashboard/presentation/providers/dashboard_providers.dart';
import '../providers/analytics_providers.dart';

/// Category rows from the dashboard's breakdown (same totals and
/// percentages): icon, name, monthly spend, active count and a circular
/// share indicator. Tapping a row reveals its contributing subscriptions.
class CategoryBreakdownList extends ConsumerStatefulWidget {
  const CategoryBreakdownList({super.key, required this.onSubscriptionTap});

  final ValueChanged<String> onSubscriptionTap;

  @override
  ConsumerState<CategoryBreakdownList> createState() =>
      _CategoryBreakdownListState();
}

class _CategoryBreakdownListState extends ConsumerState<CategoryBreakdownList> {
  /// Selected slice key: a category name, `other`, or `null` for none.
  String? _selected;

  static String _key(CategorySpend slice) => slice.category?.name ?? 'other';

  @override
  Widget build(BuildContext context) {
    final slices = ref.watch(categoryBreakdownProvider);
    if (slices.isEmpty) {
      return AppCard(
        child: Text(
          'No active subscriptions this month. Paused subscriptions are not '
          'included.',
          style: AppTypography.bodySmall,
        ),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < slices.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.sm),
          _CategoryRow(
            slice: slices[i],
            selected: _key(slices[i]) == _selected,
            onTap: () => setState(
              () => _selected = _key(slices[i]) == _selected
                  ? null
                  : _key(slices[i]),
            ),
            onSubscriptionTap: widget.onSubscriptionTap,
          ),
        ],
      ],
    );
  }
}

class _CategoryRow extends ConsumerWidget {
  const _CategoryRow({
    required this.slice,
    required this.selected,
    required this.onTap,
    required this.onSubscriptionTap,
  });

  final CategorySpend slice;
  final bool selected;
  final VoidCallback onTap;
  final ValueChanged<String> onSubscriptionTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = CurrencyFormatter.format(slice.total);
    final count = slice.subscriptionCount;
    final countLabel = '$count active';
    final icon = slice.category?.icon ?? LucideIcons.layoutGrid;

    return AppCard(
      padding: EdgeInsets.zero,
      borderRadius: AppRadius.lgAll,
      child: Column(
        children: [
          Semantics(
            container: true,
            button: true,
            selected: selected,
            label:
                '${slice.label}, $total a month, ${slice.percent} percent of '
                'spending, $countLabel',
            hint: selected ? 'Hide subscriptions' : 'Show subscriptions',
            excludeSemantics: true,
            child: PressableScale(
              onPressed: onTap,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Container(
                      width: AppSizes.categoryTile,
                      height: AppSizes.categoryTile,
                      decoration: BoxDecoration(
                        color: slice.color.withValues(
                          alpha: AppColors.seriesTintAlpha,
                        ),
                        borderRadius: AppRadius.mdAll,
                      ),
                      child: Icon(
                        icon,
                        size: AppSizes.iconMd,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            slice.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodySmall,
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              total,
                              maxLines: 1,
                              style: AppTypography.statValue,
                            ),
                          ),
                          Text(
                            '$countLabel · per month',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    _ProgressRing(percent: slice.percent, color: slice.color),
                    const SizedBox(width: AppSpacing.xxs),
                    AnimatedRotation(
                      turns: selected ? 0.5 : 0,
                      duration: AppMotion.medium,
                      child: const Icon(
                        LucideIcons.chevronDown,
                        size: AppSizes.iconSm,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: AppMotion.medium,
            curve: AppMotion.standard,
            alignment: Alignment.topCenter,
            child: selected
                ? _Members(
                    category: slice.category,
                    onSubscriptionTap: onSubscriptionTap,
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _Members extends ConsumerWidget {
  const _Members({required this.category, required this.onSubscriptionTap});

  final SubscriptionCategory? category;
  final ValueChanged<String> onSubscriptionTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(categoryMembersProvider(category));
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Column(
        children: [
          Container(height: AppSizes.hairline, color: AppColors.border),
          for (final member in members)
            Semantics(
              container: true,
              button: true,
              label:
                  '${member.subscription.name}, '
                  '${CurrencyFormatter.format(member.monthly)} a month',
              excludeSemantics: true,
              child: PressableScale(
                onPressed: () => onSubscriptionTap(member.subscription.id),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: AppSizes.minTapTarget,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xs,
                    ),
                    child: Row(
                      children: [
                        UserSubscriptionLogo(
                          subscription: member.subscription,
                          size: SubscriptionLogoSize.small,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            member.subscription.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.titleSmall,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          '${CurrencyFormatter.format(member.monthly)}/mo',
                          style: AppTypography.labelMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Circular share indicator with the percentage in the middle.
class _ProgressRing extends StatelessWidget {
  const _ProgressRing({required this.percent, required this.color});

  final int percent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: AppSizes.progressRing,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: percent / 100),
          duration: AppMotion.slow,
          curve: AppMotion.emphasized,
          builder: (context, value, child) => CustomPaint(
            painter: _RingPainter(value: value, color: color),
            child: child,
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xs),
                child: Text('$percent%', style: AppTypography.labelMedium),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = AppSizes.progressRingStroke;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final track = Paint()
      ..color = AppColors.lavender
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(rect, 0, math.pi * 2, false, track);
    if (value <= 0) return;
    final arc = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * value, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color;
}
