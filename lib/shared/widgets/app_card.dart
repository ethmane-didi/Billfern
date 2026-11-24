import 'package:flutter/widgets.dart';

import '../../core/theme/theme.dart';
import 'pressable_scale.dart';

/// Rounded white surface with a soft shadow — the base container for
/// Billfern content.
///
/// Pass [gradient] for tinted or dark hero cards. When [onTap] is provided the
/// card becomes a pressable button and [semanticLabel] describes it.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = AppSpacing.cardPadding,
    this.color = AppColors.surface,
    this.gradient,
    this.borderRadius = AppRadius.xlAll,
    this.shadows = AppShadows.card,
    this.border,
    this.clipBehavior = Clip.none,
    this.onTap,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Gradient? gradient;
  final BorderRadius borderRadius;
  final List<BoxShadow> shadows;
  final BoxBorder? border;
  final Clip clipBehavior;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      clipBehavior: clipBehavior,
      decoration: BoxDecoration(
        color: gradient == null ? color : null,
        gradient: gradient,
        borderRadius: borderRadius,
        boxShadow: shadows,
        border: border,
      ),
      child: child,
    );

    if (onTap == null) return card;

    return Semantics(
      button: true,
      label: semanticLabel,
      child: PressableScale(onPressed: onTap, child: card),
    );
  }
}
