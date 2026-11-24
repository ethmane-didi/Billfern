import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../pressable_scale.dart';

/// Height variants shared by all Billfern buttons.
enum ButtonSize {
  regular(AppSizes.buttonHeight),
  compact(AppSizes.buttonHeightCompact);

  const ButtonSize(this.height);

  final double height;
}

/// Pill-shaped button foundation used by [PrimaryButton] and
/// [SecondaryButton]. Prefer those wrappers in feature code.
class BaseButton extends StatelessWidget {
  const BaseButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.backgroundColor,
    required this.foregroundColor,
    this.icon,
    this.isLoading = false,
    this.isExpanded = true,
    this.size = ButtonSize.regular,
    this.border,
    this.shadows = AppShadows.none,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Color foregroundColor;
  final IconData? icon;
  final bool isLoading;

  /// Whether the button fills the available width.
  final bool isExpanded;
  final ButtonSize size;
  final BoxBorder? border;
  final List<BoxShadow> shadows;

  bool get _isEnabled => onPressed != null && !isLoading;

  @override
  Widget build(BuildContext context) {
    final textStyle =
        (size == ButtonSize.regular
                ? AppTypography.labelLarge
                : AppTypography.labelMedium)
            .copyWith(color: foregroundColor);

    return Semantics(
      button: true,
      enabled: _isEnabled,
      label: label,
      excludeSemantics: true,
      child: PressableScale(
        onPressed: _isEnabled ? onPressed : null,
        child: AnimatedOpacity(
          opacity: onPressed == null ? AppMotion.disabledOpacity : 1,
          duration: AppMotion.fast,
          child: AnimatedContainer(
            duration: AppMotion.medium,
            curve: AppMotion.standard,
            height: size.height,
            width: isExpanded ? double.infinity : null,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: AppRadius.pillAll,
              border: border,
              boxShadow: _isEnabled ? shadows : AppShadows.none,
            ),
            child: Center(
              widthFactor: isExpanded ? null : 1,
              child: AnimatedSwitcher(
                duration: AppMotion.fast,
                child: isLoading
                    ? _LoadingIndicator(color: foregroundColor)
                    : _ButtonLabel(
                        label: label,
                        icon: icon,
                        style: textStyle,
                        color: foregroundColor,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ButtonLabel extends StatelessWidget {
  const _ButtonLabel({
    required this.label,
    required this.style,
    required this.color,
    this.icon,
  });

  final String label;
  final TextStyle style;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: AppSizes.iconMd, color: color),
          const SizedBox(width: AppSpacing.xs),
        ],
        Flexible(
          child: Text(
            label,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: AppSizes.iconMd,
      child: CircularProgressIndicator(strokeWidth: 2, color: color),
    );
  }
}
