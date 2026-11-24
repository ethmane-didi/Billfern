import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/money/exchange_rates.dart';
import '../../../../core/router/app_destination.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/utils/date_labels.dart';
import '../../../../shared/providers/currency_providers.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/buttons/secondary_button.dart';
import '../../../../shared/widgets/currency_selector.dart';
import '../../../../shared/widgets/pressable_scale.dart';

/// Lets the user choose the display currency for totals. Subscription prices
/// keep their own currencies; only conversion changes.
class CurrencyPreferenceScreen extends ConsumerWidget {
  const CurrencyPreferenceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(preferredCurrencyProvider);
    final suggested = ref.watch(suggestedCurrencyProvider);
    final notifier = ref.read(preferredCurrencyProvider.notifier);
    final rateState = ref.watch(exchangeRatesProvider);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          AppSpacing.xs,
          AppSpacing.screenHorizontal,
          bottomInset + AppSpacing.xl,
        ),
        children: [
          Row(
            children: [
              _BackButton(
                onPressed: () => context.canPop()
                    ? context.pop()
                    : context.go(AppDestination.settings.path),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Semantics(
                  container: true,
                  header: true,
                  child: Text('Currency', style: AppTypography.sectionTitle),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Totals, charts and insights are shown in this currency. '
            'Each subscription keeps the currency you are charged in.',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xxs,
            ),
            child: CurrencyOptionList(
              selectedCode: selected,
              suggestedCode: suggested.code,
              onSelected: notifier.select,
            ),
          ),
          if (selected != suggested.code) ...[
            const SizedBox(height: AppSpacing.md),
            SecondaryButton(
              label: 'Use suggested (${suggested.code})',
              icon: LucideIcons.mapPin,
              onPressed: notifier.useSuggested,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          _RatesInfo(state: rateState),
        ],
      ),
    );
  }
}

class _RatesInfo extends StatelessWidget {
  const _RatesInfo({required this.state});

  final ExchangeRateState state;

  @override
  Widget build(BuildContext context) {
    final text = switch (state) {
      RatesAvailable(:final rates, :final isStale) =>
        '${rates.isMock ? 'Development mock rates' : rates.source} · as of '
            '${DateLabels.shortDate(rates.asOf)}'
            '${isStale ? ' · may be outdated' : ''}. '
            'Converted totals are estimates.',
      RatesUnavailable(:final reason) =>
        '$reason Totals only include subscriptions in your display currency.',
    };

    return AppCard(
      color: AppColors.lavender,
      shadows: AppShadows.none,
      padding: const EdgeInsets.all(AppSpacing.md),
      borderRadius: AppRadius.lgAll,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            LucideIcons.info,
            size: AppSizes.iconSm,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(child: Text(text, style: AppTypography.bodySmall)),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      label: 'Back',
      excludeSemantics: true,
      child: PressableScale(
        onPressed: onPressed,
        child: Container(
          width: AppSizes.minTapTarget,
          height: AppSizes.minTapTarget,
          decoration: BoxDecoration(
            color: AppColors.surfaceTranslucent,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.surface),
          ),
          child: const Icon(
            LucideIcons.chevronLeft,
            size: AppSizes.iconMd,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
