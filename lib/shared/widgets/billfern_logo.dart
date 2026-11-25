import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/brand_assets.dart';
import '../../core/theme/theme.dart';

/// Billfern's official logo (mark + wordmark on its dark tile).
///
/// The aspect ratio and transparency of the source PNG are preserved, and the
/// image is decoded at the size it is shown (the source is 1254 px) to keep
/// memory use low. Not for third-party services — use `SubscriptionLogo`.
class BillfernLogo extends StatelessWidget {
  const BillfernLogo({
    super.key,
    required this.size,
    this.semanticLabel = '${AppConstants.appName} logo',
    this.excludeFromSemantics = false,
  });

  /// Width of the logo; height follows [BrandAssets.logoAspectRatio].
  final double size;

  final String semanticLabel;

  /// Set when the logo sits next to the visible app name.
  final bool excludeFromSemantics;

  @override
  Widget build(BuildContext context) {
    final height = size / BrandAssets.logoAspectRatio;
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    return Image.asset(
      BrandAssets.logo,
      width: size,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      cacheWidth: (size * pixelRatio).round(),
      semanticLabel: excludeFromSemantics ? null : semanticLabel,
      excludeFromSemantics: excludeFromSemantics,
      errorBuilder: (context, error, stackTrace) =>
          _LogoFallback(size: size, height: height),
    );
  }
}

/// Shown only if the brand asset is missing: a neutral tile with a leaf.
class _LogoFallback extends StatelessWidget {
  const _LogoFallback({required this.size, required this.height});

  final double size;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.midnight,
        borderRadius: BorderRadius.circular(size * AppRadius.iconTileRatio),
      ),
      child: Icon(LucideIcons.leaf, size: size * 0.5, color: AppColors.yellow),
    );
  }
}
