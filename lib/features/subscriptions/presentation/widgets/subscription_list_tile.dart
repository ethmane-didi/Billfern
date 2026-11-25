import 'package:flutter/widgets.dart';

import '../../../../core/money/money.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_labels.dart';
import '../../../../shared/models/subscription.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/subscription_logo.dart';

/// A subscription row: logo, name and plan, next renewal (or pause date),
/// and the price in its **original** currency and billing cycle, with a
/// converted monthly hint when the currency differs from the display one.
class SubscriptionListTile extends StatelessWidget {
  const SubscriptionListTile({
    super.key,
    required this.subscription,
    required this.today,
    required this.convertedMonthly,
    required this.onTap,
  });

  final Subscription subscription;
  final DateTime today;

  /// Monthly equivalent in the display currency, or `null` when the
  /// subscription is already in that currency or no rate is available.
  final Money? convertedMonthly;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sub = subscription;
    final price = CurrencyFormatter.format(sub.price);
    final renewal = sub.nextRenewal(today);
    final schedule = renewal == null
        ? 'Paused since ${DateLabels.shortDate(sub.pausedOn ?? today)}'
        : 'Renews ${DateLabels.shortDate(renewal)}';
    final title = sub.plan.isEmpty ? sub.name : '${sub.name} · ${sub.plan}';
    final converted = convertedMonthly;
    final hint = converted == null
        ? null
        : '≈ ${CurrencyFormatter.format(converted)}/mo';

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      borderRadius: AppRadius.lgAll,
      onTap: onTap,
      semanticLabel:
          '$title, $price ${sub.billingCycle.label.toLowerCase()}'
          '${hint == null ? '' : ', about ${CurrencyFormatter.format(converted!)} per month'}'
          ', $schedule',
      child: Opacity(
        opacity: sub.isActive ? 1 : 0.65,
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
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.xxs / 2),
                  Text(
                    schedule,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSizes.priceColumnMaxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: price, style: AppTypography.amountSmall),
                        TextSpan(
                          text: '/${sub.billingCycle.shortLabel}',
                          style: AppTypography.caption,
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (hint != null)
                    Text(
                      hint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption,
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
