import 'package:flutter/widgets.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/subscription_icon.dart';

/// Temporary view data for the Phase 1 component preview. Superseded by the
/// shared `Subscription` model in Phase 2.
@immutable
class PreviewRenewal {
  const PreviewRenewal({
    required this.name,
    required this.plan,
    required this.amount,
    required this.dueLabel,
    required this.brandColor,
    required this.foregroundColor,
  });

  final String name;
  final String plan;
  final double amount;
  final String dueLabel;
  final Color brandColor;
  final Color foregroundColor;
}

class PreviewRenewalTile extends StatelessWidget {
  const PreviewRenewalTile({super.key, required this.renewal});

  final PreviewRenewal renewal;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        borderRadius: AppRadius.lgAll,
        child: Row(
          children: [
            SubscriptionIcon(
              name: renewal.name,
              backgroundColor: renewal.brandColor,
              foregroundColor: renewal.foregroundColor,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    renewal.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.xxs / 2),
                  Text(
                    '${renewal.plan} · ${renewal.dueLabel}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              CurrencyFormatter.format(renewal.amount),
              style: AppTypography.amountSmall,
            ),
          ],
        ),
      ),
    );
  }
}
