import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_labels.dart';
import '../../../../shared/providers/currency_providers.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/choice_pill.dart';
import '../../../../shared/widgets/conversion_note.dart';
import '../../../../shared/widgets/pressable_scale.dart';
import '../../../../shared/widgets/subscription_logo.dart';
import '../../../dashboard/domain/dashboard_models.dart';
import '../../domain/payment_record.dart';
import '../analytics_copy.dart';
import '../providers/analytics_providers.dart';
import 'analytics_parts.dart';

/// Projected payments for the next 7, 30 or 90 days: how many and their
/// combined estimated cost, plus the soonest few.
class UpcomingPaymentsCard extends ConsumerStatefulWidget {
  const UpcomingPaymentsCard({super.key, required this.onSubscriptionTap});

  final ValueChanged<String> onSubscriptionTap;

  /// Payments listed before "and N more".
  static const int visiblePayments = 4;

  @override
  ConsumerState<UpcomingPaymentsCard> createState() =>
      _UpcomingPaymentsCardState();
}

class _UpcomingPaymentsCardState extends ConsumerState<UpcomingPaymentsCard> {
  int _windowIndex = 1;

  @override
  Widget build(BuildContext context) {
    final windows = ref.watch(upcomingPaymentsProvider);
    final converter = ref.watch(moneyConverterProvider);
    final window = windows[_windowIndex.clamp(0, windows.length - 1)];
    final total = window.total;
    final approx = AnalyticsCopy.approx(total.isConverted);
    final shown = window.payments.take(UpcomingPaymentsCard.visiblePayments);
    final more = window.count - shown.length;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Expected charges', style: AppTypography.bodySmall),
              ),
              const BasisTag(basis: SpendingBasis.projected),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ChoicePillRow(
            children: [
              for (var i = 0; i < windows.length; i++)
                ChoicePill(
                  label: '${windows[i].days} days',
                  selected: i == _windowIndex,
                  onSelected: () => setState(() => _windowIndex = i),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Semantics(
            container: true,
            liveRegion: true,
            label:
                'Next ${window.days} days: '
                '${AnalyticsCopy.paymentCount(window.count)}, '
                '${total.isConverted ? 'about ' : ''}'
                '${CurrencyFormatter.format(total.total)} in total',
            excludeSemantics: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '$approx${CurrencyFormatter.format(total.total)}',
                      maxLines: 1,
                      style: AppTypography.amountMedium,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  AnalyticsCopy.paymentCount(window.count),
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          ConversionNote(
            isEstimate: total.isConverted,
            usesMockRates: converter.usesMockRates,
            ratesAreStale: converter.ratesAreStale,
            excludedCount: total.excludedCount,
            missingCurrencies: total.missingCurrencies,
          ),
          const SizedBox(height: AppSpacing.xs),
          if (window.payments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Text(
                'No payments expected in the next ${window.days} days.',
                style: AppTypography.bodySmall,
              ),
            )
          else
            for (final payment in shown)
              _PaymentRow(
                payment: payment,
                onTap: () => widget.onSubscriptionTap(payment.subscription.id),
              ),
          if (more > 0)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxs),
              child: Text(
                'and $more more',
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Based on active billing schedules. Paused subscriptions are '
            'not projected.',
            style: AppTypography.caption,
          ),
        ],
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.payment, required this.onTap});

  final ProjectedPayment payment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sub = payment.subscription;
    final amount = CurrencyFormatter.format(payment.amount);
    final when =
        '${DateLabels.shortDate(payment.date)} · '
        '${DateLabels.relativeDays(payment.daysUntil)}';
    return Semantics(
      container: true,
      button: true,
      label: '${sub.name}, $amount, ${DateLabels.shortDate(payment.date)}',
      excludeSemantics: true,
      child: PressableScale(
        onPressed: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.minTapTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              children: [
                UserSubscriptionLogo(
                  subscription: sub,
                  size: SubscriptionLogoSize.small,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sub.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleSmall,
                      ),
                      Text(
                        when,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(amount, style: AppTypography.labelLarge),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
