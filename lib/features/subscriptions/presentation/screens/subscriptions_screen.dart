import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/providers/clock_provider.dart';
import '../../../../shared/providers/currency_providers.dart';
import '../../../../shared/providers/subscription_providers.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/buttons/secondary_button.dart';
import '../../../../shared/widgets/choice_pill.dart';
import '../../../../shared/widgets/conversion_note.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/pressable_scale.dart';
import '../../../../shared/widgets/sample_data_banner.dart';
import '../../../../shared/widgets/screen_header.dart';
import '../../../../shared/widgets/search_field.dart';
import '../../../dashboard/presentation/providers/dashboard_providers.dart';
import '../../domain/subscription_list_query.dart';
import '../providers/subscription_list_providers.dart';
import '../widgets/subscription_list_tile.dart';

/// Subscriptions destination: totals, search, filters, sorting and the list.
class SubscriptionsScreen extends ConsumerWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(subscriptionsProvider);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    void add() => context.go(AppRoutes.addSubscription);

    return SafeArea(
      bottom: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final inset = math.max(
            AppSpacing.screenHorizontal,
            (constraints.maxWidth - AppSizes.contentMaxWidth) / 2,
          );
          final horizontal = EdgeInsets.symmetric(horizontal: inset);
          Widget padded(Widget child) =>
              Padding(padding: horizontal, child: child);

          final children = <Widget>[
            padded(
              ScreenHeader(
                title: 'Subscriptions',
                trailing: CircleIconButton(
                  icon: LucideIcons.plus,
                  label: 'Add subscription',
                  filled: true,
                  onPressed: add,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            padded(const SampleDataBanner()),
            const SizedBox(height: AppSpacing.sm),
            if (all.isEmpty)
              padded(
                EmptyStateCard(
                  icon: LucideIcons.inbox,
                  title: 'No subscriptions yet',
                  message:
                      'Add the services you pay for to see totals, renewals '
                      'and savings in one place.',
                  actions: [
                    PrimaryButton(
                      label: 'Add subscription',
                      icon: LucideIcons.plus,
                      onPressed: add,
                    ),
                    SecondaryButton(
                      label: 'Explore sample data',
                      icon: LucideIcons.flaskConical,
                      onPressed: () => ref
                          .read(dataModeProvider.notifier)
                          .set(DataMode.sample),
                    ),
                  ],
                ),
              )
            else ...[
              padded(const _SummaryCard()),
              const SizedBox(height: AppSpacing.lg),
              padded(
                SearchField(
                  hint: 'Search subscriptions…',
                  initialValue: ref.read(subscriptionListQueryProvider).text,
                  onChanged: ref
                      .read(subscriptionListQueryProvider.notifier)
                      .setText,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              _StatusFilters(padding: horizontal),
              _CategoryFilters(padding: horizontal),
              padded(const _ResultsHeader()),
              const SizedBox(height: AppSpacing.xs),
              ..._results(context, ref, horizontal),
            ],
          ];

          return ListView(
            padding: EdgeInsets.only(
              top: AppSpacing.md,
              bottom: bottomInset + AppSpacing.xl,
            ),
            children: children,
          );
        },
      ),
    );
  }

  List<Widget> _results(
    BuildContext context,
    WidgetRef ref,
    EdgeInsets horizontal,
  ) {
    final results = ref.watch(filteredSubscriptionsProvider);
    final converter = ref.watch(moneyConverterProvider);
    final today = ref.watch(todayProvider);

    if (results.isEmpty) {
      return [
        Padding(
          padding: horizontal,
          child: EmptyStateCard(
            icon: LucideIcons.searchX,
            title: 'No matches',
            message: 'Try another search or clear the filters.',
            actions: [
              SecondaryButton(
                label: 'Clear filters',
                onPressed: ref
                    .read(subscriptionListQueryProvider.notifier)
                    .clearFilters,
              ),
            ],
          ),
        ),
      ];
    }

    return [
      for (final sub in results)
        Padding(
          padding: horizontal.copyWith(bottom: AppSpacing.sm),
          child: SubscriptionListTile(
            key: ValueKey(sub.id),
            subscription: sub,
            today: today,
            convertedMonthly: sub.currencyCode == converter.targetCurrency
                ? null
                : converter.convert(sub.monthlyCost),
            onTap: () => context.go(AppRoutes.subscriptionDetails(sub.id)),
          ),
        ),
    ];
  }
}

class _SummaryCard extends ConsumerWidget {
  const _SummaryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(spendingSummaryProvider);
    final converter = ref.watch(moneyConverterProvider);
    final approx = summary.isEstimate ? '≈ ' : '';
    final total = CurrencyFormatter.format(summary.monthlyTotal);
    final yearly = CurrencyFormatter.format(
      summary.projectedYearly,
      showDecimals: false,
    );

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monthly spending',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Semantics(
            container: true,
            label:
                'Monthly spending, ${summary.isEstimate ? 'about ' : ''}$total',
            excludeSemantics: true,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '$approx$total',
                maxLines: 1,
                style: AppTypography.amountLarge,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${summary.activeCount} active · ${summary.pausedCount} paused · '
            '$approx$yearly a year',
            style: AppTypography.bodySmall,
          ),
          const SizedBox(height: AppSpacing.xxs),
          ConversionNote(
            isEstimate: summary.isEstimate,
            usesMockRates: converter.usesMockRates,
            ratesAreStale: converter.ratesAreStale,
            excludedCount: summary.excludedCount,
            missingCurrencies: summary.missingCurrencies,
          ),
        ],
      ),
    );
  }
}

class _StatusFilters extends ConsumerWidget {
  const _StatusFilters({required this.padding});

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(subscriptionListQueryProvider).status;
    final counts = ref.watch(statusCountsProvider);
    return ChoicePillRow(
      padding: padding,
      children: [
        for (final filter in StatusFilter.values)
          ChoicePill(
            label: '${filter.label} ${counts[filter] ?? 0}',
            selected: filter == selected,
            onSelected: () => ref
                .read(subscriptionListQueryProvider.notifier)
                .setStatus(filter),
          ),
      ],
    );
  }
}

class _CategoryFilters extends ConsumerWidget {
  const _CategoryFilters({required this.padding});

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(usedCategoriesProvider);
    if (categories.length < 2) return const SizedBox.shrink();
    final selected = ref.watch(subscriptionListQueryProvider).category;
    final notifier = ref.read(subscriptionListQueryProvider.notifier);
    return ChoicePillRow(
      padding: padding,
      children: [
        ChoicePill(
          label: 'All categories',
          selected: selected == null,
          onSelected: () => notifier.setCategory(null),
        ),
        for (final category in categories)
          ChoicePill(
            label: category.label,
            icon: category.icon,
            selected: category == selected,
            onSelected: () => notifier.setCategory(category),
          ),
      ],
    );
  }
}

class _ResultsHeader extends ConsumerWidget {
  const _ResultsHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(filteredSubscriptionsProvider).length;
    final sort = ref.watch(subscriptionListQueryProvider).sort;

    Future<void> pickSort() async {
      final chosen = await showModalBottomSheet<SubscriptionSort>(
        context: context,
        useSafeArea: true,
        builder: (context) => SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              0,
              AppSpacing.screenHorizontal,
              AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  container: true,
                  header: true,
                  child: Text('Sort by', style: AppTypography.sectionTitle),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  children: [
                    for (final option in SubscriptionSort.values)
                      ChoicePill(
                        label: option.label,
                        selected: option == sort,
                        onSelected: () => Navigator.of(context).pop(option),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      if (chosen != null) {
        ref.read(subscriptionListQueryProvider.notifier).setSort(chosen);
      }
    }

    return Row(
      children: [
        Expanded(
          child: Text(
            count == 1 ? '1 subscription' : '$count subscriptions',
            style: AppTypography.bodySmall,
          ),
        ),
        Semantics(
          container: true,
          button: true,
          label: 'Sort by ${sort.label}. Change',
          excludeSemantics: true,
          child: PressableScale(
            onPressed: pickSort,
            child: SizedBox(
              height: AppSizes.minTapTarget,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    LucideIcons.arrowUpDown,
                    size: AppSizes.iconSm,
                    color: AppColors.textPrimary,
                  ),
                  const SizedBox(width: AppSpacing.xxs),
                  Text(sort.label, style: AppTypography.labelMedium),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
