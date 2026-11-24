import 'package:flutter/widgets.dart';

import '../../../core/theme/theme.dart';
import 'base_button.dart';

/// Visual variants of [PrimaryButton].
enum PrimaryButtonVariant {
  /// Midnight fill with white label. Default on light backgrounds.
  midnight,

  /// Yellow fill with midnight label. Use on dark surfaces or for the single
  /// most important CTA on a screen.
  accent,
}

/// High-emphasis pill button.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isExpanded = true,
    this.size = ButtonSize.regular,
    this.variant = PrimaryButtonVariant.midnight,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isExpanded;
  final ButtonSize size;
  final PrimaryButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    final isAccent = variant == PrimaryButtonVariant.accent;

    return BaseButton(
      label: label,
      onPressed: onPressed,
      icon: icon,
      isLoading: isLoading,
      isExpanded: isExpanded,
      size: size,
      backgroundColor: isAccent ? AppColors.yellow : AppColors.midnight,
      foregroundColor: isAccent ? AppColors.textOnAccent : AppColors.textOnDark,
      shadows: isAccent ? AppShadows.none : AppShadows.button,
    );
  }
}
