import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/router/app_destination.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/theme.dart';
import '../../../../shared/models/subscription_catalog_item.dart';
import '../../../../shared/models/subscription_category.dart';
import '../../../../shared/providers/catalog_providers.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/buttons/secondary_button.dart';
import '../../../../shared/widgets/choice_pill.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/gradient_scaffold.dart';
import '../../../../shared/widgets/pressable_scale.dart';
import '../../../../shared/widgets/screen_header.dart';
import '../../../../shared/widgets/search_field.dart';
import '../../../../shared/widgets/subscription_logo.dart';

/// First step of adding a subscription: pick a catalog service (search,
/// browse popular, filter by category) or create a custom one.
class AddSubscriptionScreen extends ConsumerStatefulWidget {
  const AddSubscriptionScreen({super.key});

  @override
  ConsumerState<AddSubscriptionScreen> createState() =>
      _AddSubscriptionScreenState();
}

class _AddSubscriptionScreenState extends ConsumerState<AddSubscriptionScreen> {
  @override
  void initState() {
    super.initState();
    // Start every visit with a fresh search.
    Future.microtask(() {
      if (mounted) ref.read(catalogQueryProvider.notifier).clear();
    });
  }

  void _close() => context.canPop()
      ? context.pop()
      : context.go(AppDestination.subscriptions.path);

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(catalogQueryProvider);
    final results = ref.watch(catalogSearchResultsProvider);
    final isBrowsing = query.text.trim().isEmpty && query.category == null;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return GradientScaffold(
      body: SafeArea(
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

            return ListView(
              padding: EdgeInsets.only(
                top: AppSpacing.xs,
                bottom: bottomInset + AppSpacing.xl,
              ),
              children: [
                padded(ScreenHeader(title: 'Add subscription', onBack: _close)),
                const SizedBox(height: AppSpacing.md),
                padded(
                  SearchField(
                    hint: 'Search 80+ services…',
                    onChanged: ref.read(catalogQueryProvider.notifier).setText,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                ChoicePillRow(
                  padding: horizontal,
                  children: [
                    ChoicePill(
                      label: 'All',
                      selected: query.category == null,
                      onSelected: () => ref
                          .read(catalogQueryProvider.notifier)
                          .setCategory(null),
                    ),
                    for (final category in SubscriptionCategory.values)
                      ChoicePill(
                        label: category.label,
                        icon: category.icon,
                        selected: category == query.category,
                        onSelected: () => ref
                            .read(catalogQueryProvider.notifier)
                            .setCategory(category),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                padded(
                  _CustomServiceCard(
                    onTap: () => context.push(AppRoutes.addCustomSubscription),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                ...results.when(
                  loading: () => [
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.xl),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  ],
                  error: (error, _) => [
                    padded(
                      const EmptyStateCard(
                        icon: LucideIcons.triangleAlert,
                        title: 'Catalog unavailable',
                        message: 'You can still create a custom subscription.',
                      ),
                    ),
                  ],
                  data: (items) => [
                    padded(
                      Semantics(
                        container: true,
                        header: true,
                        child: Text(
                          isBrowsing ? 'Popular' : 'Results (${items.length})',
                          style: AppTypography.sectionTitle,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (items.isEmpty)
                      padded(
                        EmptyStateCard(
                          icon: LucideIcons.searchX,
                          title: 'Not in the catalog',
                          message:
                              'Create a custom subscription with any name, '
                              'price and website.',
                          actions: [
                            SecondaryButton(
                              label: 'Create custom subscription',
                              icon: LucideIcons.plus,
                              onPressed: () =>
                                  context.push(AppRoutes.addCustomSubscription),
                            ),
                          ],
                        ),
                      )
                    else if (isBrowsing)
                      padded(_PopularGrid(items: items, onSelect: _select))
                    else
                      for (final item in items)
                        Padding(
                          padding: horizontal.copyWith(bottom: AppSpacing.xs),
                          child: _ServiceRow(
                            key: ValueKey(item.id),
                            item: item,
                            onTap: () => _select(item),
                          ),
                        ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _select(SubscriptionCatalogItem item) =>
      context.push(AppRoutes.addCatalogSubscription(item.id));
}

class _CustomServiceCard extends StatelessWidget {
  const _CustomServiceCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      borderRadius: AppRadius.lgAll,
      onTap: onTap,
      semanticLabel: 'Create custom subscription',
      child: Row(
        children: [
          Container(
            width: AppSizes.subscriptionIconMd,
            height: AppSizes.subscriptionIconMd,
            decoration: const BoxDecoration(
              color: AppColors.midnight,
              borderRadius: AppRadius.mdAll,
            ),
            child: const Icon(
              LucideIcons.plus,
              size: AppSizes.iconMd,
              color: AppColors.textOnDark,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create custom subscription',
                  style: AppTypography.titleSmall,
                ),
                Text(
                  'Any service, gym, utility or membership',
                  style: AppTypography.bodySmall,
                ),
              ],
            ),
          ),
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

class _PopularGrid extends StatelessWidget {
  const _PopularGrid({required this.items, required this.onSelect});

  final List<SubscriptionCatalogItem> items;
  final ValueChanged<SubscriptionCatalogItem> onSelect;

  static const int _columns = 3;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width =
            (constraints.maxWidth - AppSpacing.sm * (_columns - 1)) / _columns;
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: Semantics(
                  container: true,
                  button: true,
                  label: item.name,
                  excludeSemantics: true,
                  child: PressableScale(
                    onPressed: () => onSelect(item),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.md,
                        horizontal: AppSpacing.xs,
                      ),
                      decoration: const BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: AppRadius.lgAll,
                        boxShadow: AppShadows.card,
                      ),
                      child: Column(
                        children: [
                          CatalogServiceLogo(item: item),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: AppTypography.labelMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({super.key, required this.item, required this.onTap});

  final SubscriptionCatalogItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      borderRadius: AppRadius.lgAll,
      onTap: onTap,
      semanticLabel: '${item.name}, ${item.category.label}',
      child: Row(
        children: [
          CatalogServiceLogo(item: item),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleSmall,
                ),
                Text(
                  '${item.category.label} · ${item.domain}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall,
                ),
              ],
            ),
          ),
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
