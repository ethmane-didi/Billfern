import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/theme.dart';
import '../providers/subscription_providers.dart';
import 'pressable_scale.dart';

/// Shown while the app displays sample subscriptions, so demo figures are
/// never mistaken for the user's own data. Renders nothing otherwise.
class SampleDataBanner extends ConsumerWidget {
  const SampleDataBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(dataModeProvider) != DataMode.sample) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xxs,
        AppSpacing.xxs,
        AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: AppColors.yellowSoft,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.yellow),
      ),
      child: Row(
        children: [
          const Icon(
            LucideIcons.flaskConical,
            size: AppSizes.iconSm,
            color: AppColors.textPrimary,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              'Sample data · changes are not saved',
              style: AppTypography.labelMedium,
            ),
          ),
          Semantics(
            container: true,
            button: true,
            label: 'Exit sample data',
            excludeSemantics: true,
            child: PressableScale(
              onPressed: () =>
                  ref.read(dataModeProvider.notifier).set(DataMode.personal),
              child: SizedBox(
                height: AppSizes.minTapTarget,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  child: Center(
                    child: Text(
                      'Exit',
                      style: AppTypography.labelLarge.copyWith(
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
