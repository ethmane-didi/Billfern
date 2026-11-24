import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/router/app_destination.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_labels.dart';
import '../../../../core/utils/date_math.dart';
import '../../../../shared/models/billing_cycle.dart';
import '../../../../shared/models/subscription.dart';
import '../../../../shared/providers/clock_provider.dart';
import '../../../../shared/providers/currency_providers.dart';
import '../../../../shared/providers/subscription_providers.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/buttons/base_button.dart';
import '../../../../shared/widgets/buttons/secondary_button.dart';
import '../../../../shared/widgets/coming_soon.dart';
import '../../../../shared/widgets/confirmation_sheet.dart';
import '../../../../shared/widgets/conversion_note.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/screen_header.dart';
import '../../../../shared/widgets/subscription_logo.dart';

/// Everything about one subscription, with edit, pause/resume and delete.
class SubscriptionDetailsScreen extends ConsumerWidget {
  const SubscriptionDetailsScreen({super.key, required this.subscriptionId});

  final String subscriptionId;

  void _back(BuildContext context) => context.canPop()
      ? context.pop()
      : context.go(AppDestination.subscriptions.path);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sub = ref.watch(subscriptionByIdProvider(subscriptionId));
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return SafeArea(
      bottom: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final inset = math.max(
            AppSpacing.screenHorizontal,
            (constraints.maxWidth - AppSizes.contentMaxWidth) / 2,
          );
          return ListView(
            padding: EdgeInsets.fromLTRB(
              inset,
              AppSpacing.xs,
              inset,
              bottomInset + AppSpacing.xl,
            ),
            children: [
              ScreenHeader(
                title: sub?.name ?? 'Subscription',
                onBack: () => _back(context),
                trailing: sub == null
                    ? null
                    : CircleIconButton(
                        icon: LucideIcons.pencil,
                        label: 'Edit ${sub.name}',
                        onPressed: () =>
                            context.push(AppRoutes.editSubscription(sub.id)),
                      ),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (sub == null)
                const EmptyStateCard(
                  icon: LucideIcons.searchX,
                  title: 'Subscription not found',
                  message: 'It may have been deleted.',
                )
              else ...[
                _Hero(subscription: sub),
                const SizedBox(height: AppSpacing.md),
                _Facts(subscription: sub),
                const SizedBox(height: AppSpacing.xl),
                _Actions(subscription: sub, onDeleted: () => _back(context)),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Hero extends ConsumerWidget {
  const _Hero({required this.subscription});

  final Subscription subscription;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sub = subscription;
    final converter = ref.watch(moneyConverterProvider);
    final foreign = sub.currencyCode != converter.targetCurrency;
    final monthly = foreign
        ? converter.convert(sub.monthlyCost)
        : sub.monthlyCost;
    final annual = foreign ? converter.convert(sub.annualCost) : sub.annualCost;
    final approx = foreign ? '≈ ' : '';
    final price = CurrencyFormatter.format(sub.price);

    String? estimates;
    if (monthly != null && annual != null) {
      final showMonthly =
          foreign || sub.billingCycle.kind != BillingCycleKind.monthly;
      estimates = [
        if (showMonthly)
          '$approx${CurrencyFormatter.format(monthly)} per month',
        '$approx${CurrencyFormatter.format(annual)} per year',
      ].join(' · ');
    }

    return AppCard(
      padding: AppSpacing.cardPaddingLarge,
      child: Column(
        children: [
          UserSubscriptionLogo(
            subscription: sub,
            size: SubscriptionLogoSize.large,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            sub.plan.isEmpty ? sub.category.label : sub.plan,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          _StatusPill(isActive: sub.isActive),
          const SizedBox(height: AppSpacing.md),
          Semantics(
            container: true,
            label: '$price ${sub.billingCycle.label.toLowerCase()}',
            excludeSemantics: true,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: price, style: AppTypography.amountLarge),
                    TextSpan(
                      text: '  ${sub.billingCycle.label}',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                maxLines: 1,
              ),
            ),
          ),
          if (estimates != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              estimates,
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall,
            ),
          ],
          if (foreign) ...[
            const SizedBox(height: AppSpacing.xxs),
            ConversionNote(
              isEstimate: monthly != null,
              usesMockRates: converter.usesMockRates,
              ratesAreStale: converter.ratesAreStale,
              excludedCount: monthly == null ? 1 : 0,
              missingCurrencies: monthly == null
                  ? {sub.currencyCode}
                  : const {},
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.badgePadding,
      decoration: BoxDecoration(
        color: isActive ? AppColors.mintSoft : AppColors.lavender,
        borderRadius: AppRadius.pillAll,
      ),
      child: Text(
        isActive ? 'Active' : 'Paused',
        style: AppTypography.labelMedium.copyWith(
          color: isActive ? AppColors.successStrong : AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _Facts extends ConsumerWidget {
  const _Facts({required this.subscription});

  final Subscription subscription;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sub = subscription;
    final today = ref.watch(todayProvider);
    final renewal = sub.nextRenewal(today);
    final notes = sub.notes;

    final rows = <(IconData, String, String)>[
      if (renewal != null)
        (
          LucideIcons.calendarDays,
          'Next renewal',
          '${DateLabels.weekdayDate(renewal)} · '
              '${DateLabels.relativeDays(DateMath.daysBetween(today, renewal))}',
        )
      else
        (
          LucideIcons.pause,
          'Paused since',
          DateLabels.weekdayDate(sub.pausedOn ?? today),
        ),
      (LucideIcons.repeat, 'Billing cycle', sub.billingCycle.label),
      (
        LucideIcons.wallet,
        'Charged in',
        '${sub.price.currency.name} (${sub.currencyCode})',
      ),
      (sub.category.icon, 'Category', sub.category.label),
      (LucideIcons.bell, 'Reminder', sub.reminder.label),
      if (sub.websiteDomain != null)
        (LucideIcons.globe, 'Website', sub.websiteDomain!),
      (LucideIcons.calendarPlus, 'Added', DateLabels.shortDate(sub.addedOn)),
    ];

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xxs,
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(),
            _FactRow(icon: rows[i].$1, label: rows[i].$2, value: rows[i].$3),
          ],
          if (notes != null) ...[
            const Divider(),
            _FactRow(
              icon: LucideIcons.stickyNote,
              label: 'Notes',
              value: notes,
            ),
          ],
        ],
      ),
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: AppSizes.iconMd, color: AppColors.textMuted),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTypography.caption),
                  Text(value, style: AppTypography.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Actions extends ConsumerWidget {
  const _Actions({required this.subscription, required this.onDeleted});

  final Subscription subscription;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sub = subscription;
    final notifier = ref.read(subscriptionsProvider.notifier);

    Future<void> delete() async {
      final confirmed = await showConfirmationSheet(
        context,
        title: 'Delete ${sub.name}?',
        message:
            'This removes the subscription and its history from Billfern. '
            'It does not cancel the service with the provider.',
        confirmLabel: 'Delete subscription',
        destructive: true,
      );
      if (!confirmed) return;
      await notifier.delete(sub.id);
      if (!context.mounted) return;
      onDeleted();
      showComingSoon(context, '${sub.name} deleted.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SecondaryButton(
          label: sub.isActive ? 'Pause subscription' : 'Resume subscription',
          icon: sub.isActive ? LucideIcons.pause : LucideIcons.play,
          onPressed: () async {
            if (sub.isActive) {
              await notifier.pause(sub.id);
            } else {
              await notifier.resume(sub.id);
            }
          },
        ),
        if (sub.isActive) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Paused subscriptions stop counting towards future spending; '
            'past months stay in your history.',
            textAlign: TextAlign.center,
            style: AppTypography.caption,
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        BaseButton(
          label: 'Delete subscription',
          icon: LucideIcons.trash2,
          onPressed: delete,
          backgroundColor: AppColors.dangerSoft,
          foregroundColor: AppColors.dangerStrong,
        ),
      ],
    );
  }
}
