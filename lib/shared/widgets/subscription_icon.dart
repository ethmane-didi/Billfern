import 'package:flutter/widgets.dart';

import '../../core/theme/theme.dart';

/// Size variants of [SubscriptionIcon].
enum SubscriptionIconSize {
  small(AppSizes.subscriptionIconSm),
  medium(AppSizes.subscriptionIconMd),
  large(AppSizes.subscriptionIconLg);

  const SubscriptionIconSize(this.dimension);

  final double dimension;
}

/// Squircle tile representing a subscription service.
///
/// Shows [icon] when provided, otherwise a monogram derived from [name]
/// (e.g. "Apple Music" → "AM"). Brand logos are intentionally not bundled;
/// pass the service's brand color via [backgroundColor] instead.
///
/// The tile is decorative by default because it is almost always shown next
/// to the service name. Set [semanticLabel] when it stands alone.
class SubscriptionIcon extends StatelessWidget {
  const SubscriptionIcon({
    super.key,
    required this.name,
    this.icon,
    this.backgroundColor = AppColors.lavender,
    this.foregroundColor = AppColors.textPrimary,
    this.size = SubscriptionIconSize.medium,
    this.semanticLabel,
  });

  final String name;
  final IconData? icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final SubscriptionIconSize size;
  final String? semanticLabel;

  static const double _iconScale = 0.46;
  static const double _monogramScale = 0.36;

  /// Up to two uppercase initials derived from [name].
  static String monogramFor(String name) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    final initials = words.take(2).map((word) => word.characters.first);
    return initials.join().toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final dimension = size.dimension;

    final tile = Container(
      width: dimension,
      height: dimension,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(
          dimension * AppRadius.iconTileRatio,
        ),
      ),
      child: icon != null
          ? Icon(icon, size: dimension * _iconScale, color: foregroundColor)
          : Text(
              monogramFor(name),
              maxLines: 1,
              textScaler: TextScaler.noScaling,
              style: AppTypography.monogram.copyWith(
                fontSize: dimension * _monogramScale,
                color: foregroundColor,
              ),
            ),
    );

    final label = semanticLabel;
    if (label == null) return ExcludeSemantics(child: tile);
    return Semantics(
      label: label,
      image: true,
      child: ExcludeSemantics(child: tile),
    );
  }
}
