import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/router/app_destination.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/theme.dart';
import '../../../../shared/providers/subscription_providers.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/buttons/secondary_button.dart';
import '../../../../shared/widgets/coming_soon.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/sample_data_banner.dart';
import '../../../../shared/widgets/fade_slide_in.dart';
import '../../../../shared/widgets/section_header.dart';
import '../widgets/ai_insight_card.dart';
import '../widgets/category_breakdown_card.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/recently_added_section.dart';
import '../widgets/spending_overview.dart';
import '../widgets/spending_trend_card.dart';
import '../widgets/upcoming_renewals_section.dart';

/// Home destination: spending overview, renewals, insights and analytics.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasSubscriptions = ref.watch(subscriptionsProvider).isNotEmpty;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    void goTo(AppDestination destination) => context.go(destination.path);
    void comingSoon(String message) => showComingSoon(context, message);
    void add() => context.push(AppRoutes.addSubscription);
    void openDetails(String id) =>
        context.go(AppRoutes.subscriptionDetails(id));

    return SafeArea(
      bottom: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Centre content on wide screens; keep the standard inset on phones.
          final inset = math.max(
            AppSpacing.screenHorizontal,
            (constraints.maxWidth - AppSizes.contentMaxWidth) / 2,
          );
          final horizontal = EdgeInsets.symmetric(horizontal: inset);
          Widget padded(Widget child) =>
              Padding(padding: horizontal, child: child);

          final sections = <Widget>[
            padded(
              DashboardHeader(
                onAddSubscription: add,
                onNotifications: () =>
                    comingSoon('Renewal reminders are coming soon.'),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            padded(const SampleDataBanner()),
            const SizedBox(height: AppSpacing.md),
            if (!hasSubscriptions)
              padded(
                EmptyStateCard(
                  icon: LucideIcons.sprout,
                  title: 'Start tracking',
                  message:
                      'Add your first subscription to see monthly spending, '
                      'renewals and savings tips.',
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
              padded(const SpendingOverview()),
              const SizedBox(height: AppSpacing.xxl),
              UpcomingRenewalsSection(
                padding: horizontal,
                onViewAll: () => goTo(AppDestination.subscriptions),
                onRenewalTap: (renewal) => openDetails(renewal.subscription.id),
              ),
              const SizedBox(height: AppSpacing.lg),
              padded(const CategoryBreakdownCard()),
              const SizedBox(height: AppSpacing.md),
              padded(
                AiInsightCard(
                  onTap: () =>
                      comingSoon('Personalised savings tips are coming soon.'),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              padded(
                SectionHeader(
                  title: 'Spending trend',
                  actionLabel: 'Analytics',
                  onAction: () => goTo(AppDestination.analytics),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              padded(const SpendingTrendCard()),
              const SizedBox(height: AppSpacing.xxl),
              padded(
                RecentlyAddedSection(
                  onViewAll: () => goTo(AppDestination.subscriptions),
                  onSubscriptionTap: (sub) => openDetails(sub.id),
                ),
              ),
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
