import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/theme.dart';
import '../../../../shared/providers/subscription_providers.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/buttons/secondary_button.dart';
import '../../../../shared/widgets/currency_selector.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/fade_slide_in.dart';
import '../../../../shared/widgets/sample_data_banner.dart';
import '../../../../shared/widgets/section_header.dart';
import '../providers/analytics_providers.dart';
import '../widgets/analytics_overview.dart';
import '../widgets/category_breakdown_list.dart';
import '../widgets/smart_suggestions_section.dart';
import '../widgets/spending_summaries_card.dart';
import '../widgets/spending_trend_chart_card.dart';
import '../widgets/upcoming_payments_card.dart';

/// Analytics destination: overview, interactive trend, monthly and yearly
/// summaries, categories, upcoming payments and smart suggestions.
///
/// Historical figures are **estimated** from recorded schedules; future
/// ones are **projected**. Every figure derives from the same providers as
/// the dashboard, so the two screens always agree.
class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasData = ref.watch(hasAnalyticsDataProvider);
    final hasCurrent = ref.watch(subscriptionsProvider).isNotEmpty;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    void add() => context.push(AppRoutes.addSubscription);
    void openDetails(String id) =>
        context.go(AppRoutes.subscriptionDetails(id));

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

          final sections = <Widget>[
            padded(const _AnalyticsHeader()),
            const SizedBox(height: AppSpacing.sm),
            padded(const SampleDataBanner()),
            const SizedBox(height: AppSpacing.md),
            if (!hasData)
              padded(_EmptyAnalytics(onAdd: add))
            else ...[
              padded(const AnalyticsOverviewSection()),
              const SizedBox(height: AppSpacing.xl),
              padded(const SpendingTrendChartCard()),
              const SizedBox(height: AppSpacing.md),
              padded(const SpendingSummariesCard()),
              const SizedBox(height: AppSpacing.xxl),
              padded(
                const SectionHeader(
                  title: 'Category breakdown',
                  subtitle: 'Share of this month · tap to see subscriptions',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              padded(CategoryBreakdownList(onSubscriptionTap: openDetails)),
              const SizedBox(height: AppSpacing.xxl),
              padded(const SectionHeader(title: 'Upcoming payments')),
              const SizedBox(height: AppSpacing.sm),
              padded(UpcomingPaymentsCard(onSubscriptionTap: openDetails)),
              const SizedBox(height: AppSpacing.xxl),
              padded(
                const SectionHeader(
                  title: 'Smart suggestions',
                  subtitle:
                      'Rule-based tips from your subscription list, not AI '
                      'analysis. Billfern can\'t see how often you use a '
                      'service.',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              padded(SmartSuggestionsSection(onSubscriptionTap: openDetails)),
              if (!hasCurrent) ...[
                const SizedBox(height: AppSpacing.xl),
                padded(
                  PrimaryButton(
                    label: 'Add subscription',
                    icon: LucideIcons.plus,
                    onPressed: add,
                  ),
                ),
              ],
            ],
          ];

          return ListView(
            padding: EdgeInsets.only(
              top: AppSpacing.xs,
              bottom: bottomInset + AppSpacing.xl,
            ),
            children: [
              for (var i = 0; i < sections.length; i++)
                FadeSlideIn(index: i ~/ 3, child: sections[i]),
            ],
          );
        },
      ),
    );
  }
}

class _AnalyticsHeader extends StatelessWidget {
  const _AnalyticsHeader();

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSizes.minTapTarget),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              container: true,
              header: true,
              child: Text(
                'Analytics',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.headlineMedium,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          const CurrencySelector(),
        ],
      ),
    );
  }
}

class _EmptyAnalytics extends ConsumerWidget {
  const _EmptyAnalytics({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return EmptyStateCard(
      icon: LucideIcons.chartSpline,
      title: 'No spending to analyse yet',
      message:
          'Add a subscription to see trends, categories, upcoming payments '
          'and savings suggestions. History builds up month by month from '
          'when you start tracking.',
      actions: [
        PrimaryButton(
          label: 'Add subscription',
          icon: LucideIcons.plus,
          onPressed: onAdd,
        ),
        SecondaryButton(
          label: 'Explore sample data',
          icon: LucideIcons.flaskConical,
          onPressed: () =>
              ref.read(dataModeProvider.notifier).set(DataMode.sample),
        ),
      ],
    );
  }
}
