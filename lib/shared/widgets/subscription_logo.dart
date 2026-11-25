import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/theme.dart';
import '../models/subscription.dart';
import '../models/subscription_branding.dart';
import '../models/subscription_catalog_item.dart';
import '../providers/catalog_providers.dart';

/// Size variants of [SubscriptionLogo].
enum SubscriptionLogoSize {
  small(AppSizes.subscriptionIconSm),
  medium(AppSizes.subscriptionIconMd),
  large(AppSizes.subscriptionIconLg);

  const SubscriptionLogoSize(this.dimension);

  final double dimension;
}

/// Container shape of [SubscriptionLogo].
enum SubscriptionLogoShape { circle, squircle }

/// Background and foreground colours of a logo tile for a brand colour.
@immutable
class LogoTileColors {
  const LogoTileColors({required this.background, required this.foreground});

  /// Picks colours so the mark stays legible:
  /// - very light brands (e.g. neon green) sit on a solid brand tile with a
  ///   midnight mark;
  /// - near-black brands sit on a neutral grey tile in their own colour;
  /// - everything else is the brand colour on a soft tint of itself.
  factory LogoTileColors.forBrand(Color brand) {
    final contrastOnWhite = contrastRatio(brand, AppColors.surface);
    if (contrastOnWhite < _minMarkContrast) {
      return LogoTileColors(background: brand, foreground: AppColors.midnight);
    }
    if (brand.computeLuminance() < _nearBlackLuminance) {
      return LogoTileColors(
        background: AppColors.logoTileNeutral,
        foreground: brand,
      );
    }
    return LogoTileColors(
      background: Color.alphaBlend(
        brand.withValues(alpha: _tintAlpha),
        AppColors.surface,
      ),
      foreground: brand,
    );
  }

  final Color background;
  final Color foreground;

  static const double _minMarkContrast = 1.6;
  static const double _nearBlackLuminance = 0.03;
  static const double _tintAlpha = 0.13;

  /// WCAG contrast ratio between two colours (1–21).
  static double contrastRatio(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final lighter = la > lb ? la : lb;
    final darker = la > lb ? lb : la;
    return (lighter + 0.05) / (darker + 0.05);
  }
}

/// A subscription service's logo inside a consistent tile.
///
/// Draws whatever [SubscriptionBranding.logo] resolved to (bundled SVG,
/// raster asset, glyph or initials) and falls back to
/// [SubscriptionBranding.fallback] if an asset fails to load. Logos keep their
/// aspect ratio and are decorative by default; set [semanticLabel] when the
/// logo stands alone.
class SubscriptionLogo extends StatelessWidget {
  const SubscriptionLogo({
    super.key,
    required this.branding,
    this.size = SubscriptionLogoSize.medium,
    this.shape = SubscriptionLogoShape.circle,
    this.semanticLabel,
  });

  final SubscriptionBranding branding;
  final SubscriptionLogoSize size;
  final SubscriptionLogoShape shape;
  final String? semanticLabel;

  static const double _markScale = 0.48;
  static const double _monogramScale = 0.36;

  @override
  Widget build(BuildContext context) {
    final dimension = size.dimension;
    final colors = LogoTileColors.forBrand(branding.color);

    final tile = Container(
      width: dimension,
      height: dimension,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.background,
        shape: shape == SubscriptionLogoShape.circle
            ? BoxShape.circle
            : BoxShape.rectangle,
        borderRadius: shape == SubscriptionLogoShape.squircle
            ? BorderRadius.circular(dimension * AppRadius.iconTileRatio)
            : null,
      ),
      child: _LogoMark(
        source: branding.logo,
        fallback: branding.fallback,
        color: colors.foreground,
        markSize: dimension * _markScale,
        monogramSize: dimension * _monogramScale,
      ),
    );

    final label = semanticLabel;
    if (label == null) return ExcludeSemantics(child: tile);
    return Semantics(
      container: true,
      image: true,
      label: label,
      child: ExcludeSemantics(child: tile),
    );
  }
}

class _LogoMark extends StatelessWidget {
  const _LogoMark({
    required this.source,
    required this.fallback,
    required this.color,
    required this.markSize,
    required this.monogramSize,
  });

  final LogoSource source;
  final LogoSource? fallback;
  final Color color;
  final double markSize;
  final double monogramSize;

  @override
  Widget build(BuildContext context) {
    Widget fallbackMark(BuildContext context, Object error, StackTrace? _) {
      final fallback = this.fallback;
      if (fallback == null || fallback is SvgAssetLogo) {
        return const SizedBox.shrink();
      }
      return _LogoMark(
        source: fallback,
        fallback: null,
        color: color,
        markSize: markSize,
        monogramSize: monogramSize,
      );
    }

    return switch (source) {
      SvgAssetLogo(:final assetPath) => SvgPicture.asset(
        assetPath,
        width: markSize,
        height: markSize,
        fit: BoxFit.contain,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        errorBuilder: fallbackMark,
      ),
      RasterAssetLogo(:final assetPath) => Image.asset(
        assetPath,
        width: markSize,
        height: markSize,
        fit: BoxFit.contain,
        errorBuilder: fallbackMark,
      ),
      // No remote provider ships yet; draw the fallback so nothing hits the
      // network.
      RemoteLogo() => fallbackMark(context, StateError('remote'), null),
      GlyphLogo(:final icon) => Icon(icon, size: markSize, color: color),
      InitialsLogo(:final initials) => Text(
        initials,
        maxLines: 1,
        textScaler: TextScaler.noScaling,
        style: AppTypography.monogram.copyWith(
          fontSize: monogramSize,
          color: color,
        ),
      ),
    };
  }
}

/// [SubscriptionLogo] for a user subscription, resolved through the catalog.
class UserSubscriptionLogo extends ConsumerWidget {
  const UserSubscriptionLogo({
    super.key,
    required this.subscription,
    this.size = SubscriptionLogoSize.medium,
    this.shape = SubscriptionLogoShape.circle,
  });

  final Subscription subscription;
  final SubscriptionLogoSize size;
  final SubscriptionLogoShape shape;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SubscriptionLogo(
      branding: ref.watch(subscriptionBrandingProvider(subscription)),
      size: size,
      shape: shape,
    );
  }
}

/// [SubscriptionLogo] for a catalog service (search results, browse grid).
class CatalogServiceLogo extends ConsumerWidget {
  const CatalogServiceLogo({
    super.key,
    required this.item,
    this.size = SubscriptionLogoSize.medium,
    this.shape = SubscriptionLogoShape.circle,
  });

  final SubscriptionCatalogItem item;
  final SubscriptionLogoSize size;
  final SubscriptionLogoShape shape;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SubscriptionLogo(
      branding: ref.watch(catalogItemBrandingProvider(item)),
      size: size,
      shape: shape,
    );
  }
}
