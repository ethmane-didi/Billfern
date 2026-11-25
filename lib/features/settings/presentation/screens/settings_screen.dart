import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/money/currency.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/theme.dart';
import '../../../../shared/providers/currency_providers.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/billfern_logo.dart';
import '../../../../shared/widgets/pressable_scale.dart';

/// Settings destination. Currency is configurable; reminders, account and
/// premium plans follow in later phases.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = Currency.of(ref.watch(preferredCurrencyProvider));
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          AppSpacing.md,
          AppSpacing.screenHorizontal,
          bottomInset + AppSpacing.xl,
        ),
        children: [
          Semantics(
            container: true,
            header: true,
            child: Text('Settings', style: AppTypography.headlineMedium),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('PREFERENCES', style: AppTypography.labelSmall),
          const SizedBox(height: AppSpacing.xs),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            borderRadius: AppRadius.lgAll,
            child: _SettingsRow(
              icon: LucideIcons.coins,
              title: 'Display currency',
              value: '${currency.code} · ${currency.name}',
              onTap: () => context.go(AppRoutes.currency),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('ABOUT', style: AppTypography.labelSmall),
          const SizedBox(height: AppSpacing.xs),
          const _AboutCard(),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Reminders, account and premium plans are coming soon.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      label: '$title, $value',
      excludeSemantics: true,
      child: PressableScale(
        onPressed: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: AppSizes.subscriptionIconSm,
                height: AppSizes.subscriptionIconSm,
                decoration: const BoxDecoration(
                  color: AppColors.lavender,
                  borderRadius: AppRadius.smAll,
                ),
                child: Icon(
                  icon,
                  size: AppSizes.iconSm,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTypography.titleSmall),
                    Text(
                      value,
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
        ),
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const BillfernLogo(
                size: AppSizes.brandMarkAbout,
                excludeFromSemantics: true,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      container: true,
                      header: true,
                      child: Text(
                        AppConstants.appName,
                        style: AppTypography.titleLarge,
                      ),
                    ),
                    Text(
                      AppConstants.tagline,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Track every subscription, see what renews next and what you '
            'spend each month. Your data is stored on this device.',
            style: AppTypography.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Service logos are trademarks of their respective owners, shown '
            'only to identify each service (via Simple Icons). Exchange rates '
            'are development mock rates.',
            style: AppTypography.caption,
          ),
        ],
      ),
    );
  }
}
