import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_destination.dart';
import '../../../../core/theme/theme.dart';
import '../../../../shared/widgets/coming_soon.dart';
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
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    void goTo(AppDestination destination) => context.go(destination.path);
    void comingSoon(String message) => showComingSoon(context, message);

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
                onAddSubscription: () =>
                    comingSoon('Adding subscriptions is coming soon.'),
                onNotifications: () =>
                    comingSoon('Renewal reminders are coming soon.'),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            padded(const SpendingOverview()),
            const SizedBox(height: AppSpacing.xxl),
            UpcomingRenewalsSection(
              padding: horizontal,
              onViewAll: () => goTo(AppDestination.subscriptions),
              onRenewalTap: (renewal) => comingSoon(
                '${renewal.subscription.name} details are coming soon.',
              ),
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
                onSubscriptionTap: (sub) =>
                    comingSoon('${sub.name} details are coming soon.'),
              ),
            ),
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
