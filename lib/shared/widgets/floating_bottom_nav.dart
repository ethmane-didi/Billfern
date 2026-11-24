import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../core/theme/theme.dart';
import 'pressable_scale.dart';

/// A destination shown in [FloatingBottomNav].
@immutable
class FloatingNavItem {
  const FloatingNavItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// Floating, pill-shaped midnight navigation bar.
///
/// The selected destination expands into a yellow pill showing its label;
/// the others collapse to icons. The bar handles its own safe-area inset, so
/// place it directly in `Scaffold.bottomNavigationBar` with `extendBody`.
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

  static const EdgeInsets _barPadding = EdgeInsets.all(AppSpacing.xs);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.xs,
          AppSpacing.xl,
          AppSpacing.xs,
        ),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSizes.navBarMaxWidth,
            ),
            child: Container(
              height: AppSizes.navBarHeight,
              padding: _barPadding,
              decoration: const BoxDecoration(
                color: AppColors.midnight,
                borderRadius: AppRadius.pillAll,
                boxShadow: AppShadows.floating,
              ),
              child: Semantics(
                container: true,
                explicitChildNodes: true,
                child: LayoutBuilder(builder: _buildItems),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItems(BuildContext context, BoxConstraints constraints) {
    const collapsedWidth = AppSizes.navItemSize;
    final availableForSelected =
        constraints.maxWidth - collapsedWidth * (items.length - 1);
    final selectedWidth = math.max(
      collapsedWidth,
      math.min(availableForSelected, AppSizes.navSelectedMaxWidth),
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var index = 0; index < items.length; index++)
          _NavItem(
            item: items[index],
            isSelected: index == currentIndex,
            width: index == currentIndex ? selectedWidth : collapsedWidth,
            onTap: () => onSelected(index),
          ),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.item,
    required this.isSelected,
    required this.width,
    required this.onTap,
  });

  final FloatingNavItem item;
  final bool isSelected;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = isSelected
        ? AppColors.textOnAccent
        : AppColors.navInactive;

    return Semantics(
      button: true,
      selected: isSelected,
      label: item.label,
      excludeSemantics: true,
      child: PressableScale(
        onPressed: onTap,
        child: AnimatedContainer(
          duration: AppMotion.medium,
          curve: AppMotion.emphasized,
          width: width,
          height: AppSizes.navItemSize,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.yellow : AppColors.transparent,
            borderRadius: AppRadius.pillAll,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item.icon, size: AppSizes.iconMd, color: foreground),
              if (isSelected)
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.xs),
                    child: Text(
                      item.label,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.fade,
                      style: AppTypography.labelMedium.copyWith(
                        color: foreground,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
