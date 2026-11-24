import 'package:flutter/widgets.dart';

import '../../../core/theme/theme.dart';
import 'base_button.dart';

/// Medium-emphasis pill button: white surface with a hairline border.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isExpanded = true,
    this.size = ButtonSize.regular,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isExpanded;
  final ButtonSize size;

  @override
  Widget build(BuildContext context) {
    return BaseButton(
      label: label,
      onPressed: onPressed,
      icon: icon,
      isLoading: isLoading,
      isExpanded: isExpanded,
      size: size,
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.textPrimary,
      border: Border.all(color: AppColors.border, width: AppSizes.hairline),
    );
  }
}
