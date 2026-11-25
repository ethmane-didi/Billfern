import 'package:flutter/widgets.dart';

import '../../core/theme/theme.dart';
import 'pressable_scale.dart';

/// Selectable pill used for filters and option groups. Selected pills are
/// midnight with white text (as in the reference's "All 8" tab).
class ChoicePill extends StatelessWidget {
  const ChoicePill({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AppColors.textOnDark : AppColors.textPrimary;
    final icon = this.icon;
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: PressableScale(
        onPressed: onSelected,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.minTapTarget),
          child: Center(
            widthFactor: 1,
            child: AnimatedContainer(
              duration: AppMotion.fast,
              curve: AppMotion.standard,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs + 2,
              ),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.midnight
                    : AppColors.surfaceTranslucent,
                borderRadius: AppRadius.pillAll,
                border: Border.all(
                  color: selected ? AppColors.midnight : AppColors.surface,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: AppSizes.iconSm, color: foreground),
                    const SizedBox(width: AppSpacing.xxs),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelMedium.copyWith(
                        color: foreground,
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

/// Horizontally scrolling row of [ChoicePill]s that bleeds to the screen
/// edges; [padding] insets the first and last pill.
class ChoicePillRow extends StatelessWidget {
  const ChoicePillRow({
    super.key,
    required this.children,
    this.padding = EdgeInsets.zero,
  });

  final List<Widget> children;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.xs),
            children[i],
          ],
        ],
      ),
    );
  }
}
