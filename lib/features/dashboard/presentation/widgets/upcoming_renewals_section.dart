import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_labels.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../shared/widgets/subscription_logo.dart';
import '../../domain/dashboard_models.dart';
import '../providers/dashboard_providers.dart';

/// Upcoming renewals as horizontally scrolling cards, two per screen width.
class UpcomingRenewalsSection extends ConsumerWidget {
  const UpcomingRenewalsSection({
    super.key,
    required this.padding,
    required this.onViewAll,
    required this.onRenewalTap,
    this.maxItems = 6,
  });

  /// Horizontal inset of the header and the first/last card.
  final EdgeInsets padding;
  final VoidCallback onViewAll;
  final ValueChanged<UpcomingRenewal> onRenewalTap;
  final int maxItems;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final renewals = ref
        .watch(upcomingRenewalsProvider)
        .take(maxItems)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: padding,
          child: SectionHeader(
            title: 'Upcoming renewals',
            actionLabel: 'View all',
            onAction: onViewAll,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (renewals.isEmpty)
          Padding(
            padding: padding,
            child: AppCard(
              child: Text(
                'No renewals in the next 30 days.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final available =
                  constraints.maxWidth - padding.horizontal - AppSpacing.sm;
              final cardWidth = math.max(
                AppSizes.renewalCardMinWidth,
                available / 2,
              );
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                padding: padding.copyWith(bottom: AppSpacing.sm),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < renewals.length; i++) ...[
                        if (i > 0) const SizedBox(width: AppSpacing.sm),
                        SizedBox(
                          width: cardWidth,
                          child: _RenewalCard(
                            renewal: renewals[i],
                            onTap: () => onRenewalTap(renewals[i]),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

class _RenewalCard extends StatelessWidget {
  const _RenewalCard({required this.renewal, required this.onTap});

  final UpcomingRenewal renewal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sub = renewal.subscription;
    final amount = CurrencyFormatter.formatCents(renewal.amountCents);
    final due = DateLabels.relativeDays(renewal.daysUntil);
    final date = DateLabels.shortDate(renewal.date);
    final isSoon = renewal.daysUntil <= dueSoonDays;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: onTap,
      semanticLabel:
          '${sub.name}, ${sub.plan}, $amount, renews ${due.toLowerCase()}, $date',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UserSubscriptionLogo(subscription: sub),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Align(
                  alignment: Alignment.topRight,
                  child: _PlanTag(label: sub.plan),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            sub.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.cardTitle,
          ),
          const Spacer(),
          const SizedBox(height: AppSpacing.xs),
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _Figure(
                    value: amount,
                    caption: '/${sub.billingCycle.shortLabel}',
                  ),
                ),
                Container(
                  width: AppSizes.hairline,
                  margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                  color: AppColors.borderStrong,
                ),
                Expanded(
                  child: _Figure(
                    value: due,
                    caption: date,
                    valueColor: isSoon
                        ? AppColors.dangerStrong
                        : AppColors.textPrimary,
                    valueStyle: AppTypography.labelMedium,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.value,
    required this.caption,
    this.valueColor = AppColors.textPrimary,
    this.valueStyle,
  });

  final String value;
  final String caption;
  final Color valueColor;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: (valueStyle ?? AppTypography.amountSmall).copyWith(
            color: valueColor,
          ),
        ),
        Text(
          caption,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.caption,
        ),
      ],
    );
  }
}

class _PlanTag extends StatelessWidget {
  const _PlanTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs + AppSpacing.xxs / 2,
        vertical: AppSpacing.xxs,
      ),
      decoration: const BoxDecoration(
        color: AppColors.midnight,
        borderRadius: AppRadius.pillAll,
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.caption.copyWith(color: AppColors.textOnDark),
      ),
    );
  }
}
