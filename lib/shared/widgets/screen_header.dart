import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/theme.dart';
import 'pressable_scale.dart';

/// Circular translucent icon button (48 px tap target), used for back and
/// header actions.
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.filled = false,
  });

  final IconData icon;

  /// Accessibility label, e.g. "Back".
  final String label;
  final VoidCallback onPressed;

  /// Midnight fill for the primary action (e.g. add).
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      label: label,
      excludeSemantics: true,
      child: PressableScale(
        onPressed: onPressed,
        child: Container(
          width: AppSizes.minTapTarget,
          height: AppSizes.minTapTarget,
          decoration: BoxDecoration(
            color: filled ? AppColors.midnight : AppColors.surfaceTranslucent,
            shape: BoxShape.circle,
            border: filled ? null : Border.all(color: AppColors.surface),
          ),
          child: Icon(
            icon,
            size: AppSizes.iconMd,
            color: filled ? AppColors.textOnDark : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

/// Title row for pushed screens: optional back button, centred-left title
/// and an optional trailing action.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.onBack,
    this.trailing,
  });

  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final onBack = this.onBack;
    final trailing = this.trailing;
    return Row(
      children: [
        if (onBack != null) ...[
          CircleIconButton(
            icon: LucideIcons.chevronLeft,
            label: 'Back',
            onPressed: onBack,
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
        Expanded(
          child: Semantics(
            container: true,
            header: true,
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: onBack == null
                  ? AppTypography.headlineMedium
                  : AppTypography.sectionTitle,
            ),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: AppSpacing.xs),
          trailing,
        ],
      ],
    );
  }
}
