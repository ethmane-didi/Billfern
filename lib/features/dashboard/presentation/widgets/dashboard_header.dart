import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/theme.dart';
import '../../../../shared/providers/user_provider.dart';
import '../../../../shared/widgets/pressable_scale.dart';
import '../providers/dashboard_providers.dart';

/// Brand mark and wordmark, with add, notifications and avatar on the right.
class DashboardHeader extends ConsumerWidget {
  const DashboardHeader({
    super.key,
    required this.onAddSubscription,
    required this.onNotifications,
  });

  final VoidCallback onAddSubscription;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final dueSoon = ref.watch(dueSoonRenewalsProvider).length;
    final notificationsLabel = dueSoon > 0
        ? 'Notifications, $dueSoon '
              '${dueSoon == 1 ? 'renewal' : 'renewals'} due soon'
        : 'Notifications';

    return Row(
      children: [
        const Expanded(child: _Wordmark()),
        const SizedBox(width: AppSpacing.xs),
        _HeaderButton(
          label: 'Add subscription',
          icon: LucideIcons.plus,
          filled: true,
          onPressed: onAddSubscription,
        ),
        _HeaderButton(
          label: notificationsLabel,
          icon: LucideIcons.bell,
          showDot: dueSoon > 0,
          onPressed: onNotifications,
        ),
        const SizedBox(width: AppSpacing.xxs),
        _Avatar(initials: user.initials),
      ],
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      header: true,
      label: AppConstants.appName,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: AppSizes.subscriptionIconSm,
            height: AppSizes.subscriptionIconSm,
            decoration: const BoxDecoration(
              gradient: AppGradients.accent,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              LucideIcons.leaf,
              size: AppSizes.iconMd,
              color: AppColors.textOnAccent,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              AppConstants.appName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.titleLarge,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.filled = false,
    this.showDot = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool filled;
  final bool showDot;

  static const double _filledSize =
      AppSizes.buttonHeightCompact - AppSpacing.xxs;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      label: label,
      excludeSemantics: true,
      child: PressableScale(
        onPressed: onPressed,
        child: SizedBox.square(
          dimension: AppSizes.minTapTarget,
          child: Center(
            child: Container(
              width: _filledSize,
              height: _filledSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: filled ? AppColors.midnight : AppColors.transparent,
                shape: BoxShape.circle,
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    icon,
                    size: AppSizes.iconMd,
                    color: filled
                        ? AppColors.textOnDark
                        : AppColors.textPrimary,
                  ),
                  if (showDot)
                    Positioned(
                      top: -AppSpacing.xxs / 2,
                      right: -AppSpacing.xxs / 2,
                      child: Container(
                        width: AppSizes.badgeDot,
                        height: AppSizes.badgeDot,
                        decoration: BoxDecoration(
                          color: AppColors.danger,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.cream,
                            width: AppSizes.hairline * 1.5,
                          ),
                        ),
                      ),
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

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: AppSizes.avatar,
        height: AppSizes.avatar,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: AppGradients.midnight,
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.surface,
            width: AppSizes.hairline * 2,
          ),
          boxShadow: AppShadows.card,
        ),
        child: Text(
          initials,
          textScaler: TextScaler.noScaling,
          style: AppTypography.monogram.copyWith(color: AppColors.textOnDark),
        ),
      ),
    );
  }
}
