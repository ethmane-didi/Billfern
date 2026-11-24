import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/money/currency.dart';
import '../../core/theme/theme.dart';
import '../providers/currency_providers.dart';
import 'pressable_scale.dart';

/// Selectable list of [Currency.supported], marking [selectedCode] and the
/// optional [suggestedCode].
class CurrencyOptionList extends StatelessWidget {
  const CurrencyOptionList({
    super.key,
    required this.selectedCode,
    required this.onSelected,
    this.suggestedCode,
  });

  final String selectedCode;
  final String? suggestedCode;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < Currency.supported.length; i++) ...[
          if (i > 0) const Divider(),
          _CurrencyOption(
            currency: Currency.supported[i],
            isSelected: Currency.supported[i].code == selectedCode,
            isSuggested: Currency.supported[i].code == suggestedCode,
            onTap: () => onSelected(Currency.supported[i].code),
          ),
        ],
      ],
    );
  }
}

class _CurrencyOption extends StatelessWidget {
  const _CurrencyOption({
    required this.currency,
    required this.isSelected,
    required this.isSuggested,
    required this.onTap,
  });

  final Currency currency;
  final bool isSelected;
  final bool isSuggested;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      selected: isSelected,
      label:
          '${currency.name}, ${currency.code}'
          '${isSuggested ? ', suggested for your region' : ''}',
      excludeSemantics: true,
      child: PressableScale(
        onPressed: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.minTapTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(
              children: [
                Container(
                  width: AppSizes.subscriptionIconMd,
                  height: AppSizes.subscriptionIconMd,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.midnight : AppColors.lavender,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    currency.symbol,
                    maxLines: 1,
                    textScaler: TextScaler.noScaling,
                    style: AppTypography.labelMedium.copyWith(
                      color: isSelected
                          ? AppColors.textOnDark
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(currency.code, style: AppTypography.titleSmall),
                      Text(
                        isSuggested
                            ? '${currency.name} · Suggested'
                            : currency.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(
                    LucideIcons.check,
                    size: AppSizes.iconMd,
                    color: AppColors.textPrimary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens a bottom sheet to pick a display currency. Returns the chosen code,
/// or `null` when dismissed.
Future<String?> showCurrencyPicker(
  BuildContext context, {
  required String selectedCode,
  String? suggestedCode,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          0,
          AppSpacing.screenHorizontal,
          AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              container: true,
              header: true,
              child: Text(
                'Display currency',
                style: AppTypography.sectionTitle,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Totals are converted into this currency. Each subscription '
              'keeps its original currency.',
              style: AppTypography.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            CurrencyOptionList(
              selectedCode: selectedCode,
              suggestedCode: suggestedCode,
              onSelected: (code) => Navigator.of(context).pop(code),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Compact pill showing the preferred display currency; tapping it opens
/// [showCurrencyPicker] and saves the choice.
class CurrencySelector extends ConsumerWidget {
  const CurrencySelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = Currency.of(ref.watch(preferredCurrencyProvider));

    Future<void> pick() async {
      final code = await showCurrencyPicker(
        context,
        selectedCode: currency.code,
        suggestedCode: ref.read(suggestedCurrencyProvider).code,
      );
      if (code != null) {
        await ref.read(preferredCurrencyProvider.notifier).select(code);
      }
    }

    return Semantics(
      container: true,
      button: true,
      label: 'Display currency, ${currency.name}. Change',
      excludeSemantics: true,
      child: PressableScale(
        onPressed: pick,
        child: SizedBox(
          height: AppSizes.minTapTarget,
          child: Center(
            child: Container(
              padding: AppSpacing.badgePadding,
              decoration: BoxDecoration(
                color: AppColors.surfaceTranslucent,
                borderRadius: AppRadius.pillAll,
                border: Border.all(color: AppColors.surface),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(currency.code, style: AppTypography.labelMedium),
                  const SizedBox(width: AppSpacing.xxs),
                  const Icon(
                    LucideIcons.chevronDown,
                    size: AppSizes.iconSm,
                    color: AppColors.textPrimary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
