import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/theme.dart';
import '../../../../shared/widgets/billfern_logo.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/buttons/secondary_button.dart';
import '../../../../shared/widgets/fade_slide_in.dart';
import '../../../../shared/widgets/gradient_scaffold.dart';
import '../providers/onboarding_providers.dart';

/// First-launch welcome: the Billfern logo, what the app does, and a choice
/// between starting fresh and exploring sample data.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  static const double _logoSize = 168;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboarding = ref.read(onboardingCompletedProvider.notifier);

    return GradientScaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final inset = math.max(
              AppSpacing.xl,
              (constraints.maxWidth - AppSizes.contentMaxWidth) / 2,
            );
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                inset,
                AppSpacing.xxl,
                inset,
                AppSpacing.xl,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - AppSpacing.xxl * 2,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    FadeSlideIn(
                      child: Column(
                        children: [
                          const BillfernLogo(size: _logoSize),
                          const SizedBox(height: AppSpacing.lg),
                          Semantics(
                            container: true,
                            header: true,
                            child: Text(
                              AppConstants.tagline,
                              textAlign: TextAlign.center,
                              style: AppTypography.headlineLarge,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'See every subscription, what renews next and what '
                            'you spend each month — in your currency.',
                            textAlign: TextAlign.center,
                            style: AppTypography.bodyLarge.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    const FadeSlideIn(index: 1, child: _Highlights()),
                    const SizedBox(height: AppSpacing.xxl),
                    FadeSlideIn(
                      index: 2,
                      child: Column(
                        children: [
                          PrimaryButton(
                            label: 'Get started',
                            icon: LucideIcons.arrowRight,
                            onPressed: onboarding.finish,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          SecondaryButton(
                            label: 'Explore with sample data',
                            icon: LucideIcons.flaskConical,
                            onPressed: () =>
                                onboarding.finish(withSampleData: true),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                LucideIcons.lock,
                                size: AppSizes.iconXs,
                                color: AppColors.textMuted,
                              ),
                              const SizedBox(width: AppSpacing.xxs),
                              Flexible(
                                child: Text(
                                  'Your data stays on this device.',
                                  style: AppTypography.caption,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Highlights extends StatelessWidget {
  const _Highlights();

  static const _items = [
    (LucideIcons.layoutGrid, 'All your subscriptions in one place'),
    (LucideIcons.calendarClock, 'Know what renews next'),
    (LucideIcons.coins, 'Totals in your own currency'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final (icon, text) in _items)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              children: [
                Container(
                  width: AppSizes.subscriptionIconSm,
                  height: AppSizes.subscriptionIconSm,
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceTranslucent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: AppSizes.iconSm,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(text, style: AppTypography.titleSmall)),
              ],
            ),
          ),
      ],
    );
  }
}
