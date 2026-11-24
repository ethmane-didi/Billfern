import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_labels.dart';
import '../../../../shared/models/subscription.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../shared/widgets/subscription_logo.dart';
import '../providers/dashboard_providers.dart';

/// The most recently added subscriptions as list rows.
class RecentlyAddedSection extends ConsumerWidget {
  const RecentlyAddedSection({
    super.key,
    required this.onViewAll,
    required this.onSubscriptionTap,
  });

  final VoidCallback onViewAll;
  final ValueChanged<Subscription> onSubscriptionTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subs = ref.watch(recentlyAddedSubscriptionsProvider);
    final summary = ref.watch(spendingSummaryProvider);
    final counts = summary.pausedCount == 0
        ? '${summary.activeCount} active'
        : '${summary.activeCount} active · ${summary.pausedCount} paused';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'Recently added',
          subtitle: counts,
          actionLabel: 'View all',
          onAction: onViewAll,
        ),
        const SizedBox(height: AppSpacing.sm),
        for (var i = 0; i < subs.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.sm),
          _SubscriptionRow(
            subscription: subs[i],
            onTap: () => onSubscriptionTap(subs[i]),
          ),
        ],
      ],
    );
  }
}

class _SubscriptionRow extends StatelessWidget {
  const _SubscriptionRow({required this.subscription, required this.onTap});

  final Subscription subscription;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sub = subscription;
    final price =
        '${CurrencyFormatter.formatCents(sub.priceCents)}/${sub.billingCycle.shortLabel}';
    final detail = sub.isActive
        ? 'Added ${DateLabels.shortDate(sub.startedOn)} · $price'
        : 'Paused · $price';

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      borderRadius: AppRadius.lgAll,
      onTap: onTap,
      semanticLabel: '${sub.name}, ${sub.plan}, $detail',
      child: Row(
        children: [
          UserSubscriptionLogo(
            subscription: sub,
            shape: SubscriptionLogoShape.squircle,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${sub.name} · ${sub.plan}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleSmall,
                ),
                const SizedBox(height: AppSpacing.xxs / 2),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          if (!sub.isActive)
            const _PausedTag()
          else
            const Icon(
              LucideIcons.chevronRight,
              size: AppSizes.iconMd,
              color: AppColors.textMuted,
            ),
        ],
      ),
    );
  }
}

class _PausedTag extends StatelessWidget {
  const _PausedTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs / 2,
      ),
      decoration: const BoxDecoration(
        color: AppColors.lavender,
        borderRadius: AppRadius.pillAll,
      ),
      child: Text('Paused', style: AppTypography.caption),
    );
  }
}
