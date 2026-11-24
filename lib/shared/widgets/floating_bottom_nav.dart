import 'package:flutter/widgets.dart';

import '../../core/theme/theme.dart';
import 'pressable_scale.dart';

/// A destination shown in [FloatingBottomNav].
@immutable
class FloatingNavItem {
  const FloatingNavItem({required this.icon, required this.label});

  final IconData icon;

  /// Read by screen readers; not drawn.
  final String label;
}

/// Compact floating white pill with icon-only destinations.
///
/// The selected destination is a filled midnight circle with a white icon.
/// Labels are exposed through semantics (with the selected state) rather than
/// drawn. The bar handles its own safe-area inset, so place it directly in
/// `Scaffold.bottomNavigationBar` with `extendBody`.
class FloatingBottomNav extends StatelessWidget {
  const FloatingBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelected,
  }) : assert(items.length >= 2, 'Provide at least two destinations.'),
       assert(currentIndex >= 0 && currentIndex < items.length);

  final List<FloatingNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  static const double _barPadding =
      (AppSizes.navBarHeight - AppSizes.navItemSize) / 2;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xs),
        child: Center(
          heightFactor: 1,
          child: Container(
            height: AppSizes.navBarHeight,
            padding: const EdgeInsets.all(_barPadding),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.pillAll,
              border: Border.all(color: AppColors.border),
              boxShadow: AppShadows.floating,
            ),
            child: Semantics(
              container: true,
              explicitChildNodes: true,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var index = 0; index < items.length; index++) ...[
                    if (index > 0) const SizedBox(width: AppSizes.navItemGap),
                    _NavItem(
                      item: items[index],
                      isSelected: index == currentIndex,
                      onTap: () => onSelected(index),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final FloatingNavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      selected: isSelected,
      label: item.label,
      excludeSemantics: true,
      child: PressableScale(
        onPressed: onTap,
        child: AnimatedContainer(
          duration: AppMotion.medium,
          curve: AppMotion.emphasized,
          width: AppSizes.navItemSize,
          height: AppSizes.navItemSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.midnight : AppColors.transparent,
            shape: BoxShape.circle,
          ),
          child: Icon(
            item.icon,
            size: AppSizes.iconMd,
            color: isSelected ? AppColors.textOnDark : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
