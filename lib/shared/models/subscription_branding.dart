import 'package:flutter/widgets.dart';

/// Where a subscription's logo comes from, in resolution priority order.
sealed class LogoSource {
  const LogoSource();
}

/// Bundled monochrome SVG brand mark (rendered in the brand colour).
final class SvgAssetLogo extends LogoSource {
  const SvgAssetLogo(this.assetPath);
  final String assetPath;
}

/// Bundled raster logo (PNG/WebP), rendered as-is.
final class RasterAssetLogo extends LogoSource {
  const RasterAssetLogo(this.assetPath);
  final String assetPath;
}

/// Logo fetched from a remote provider (e.g. Logo.dev). Not produced yet.
final class RemoteLogo extends LogoSource {
  const RemoteLogo(this.url);
  final Uri url;
}

/// A chosen or category icon.
final class GlyphLogo extends LogoSource {
  const GlyphLogo(this.icon);
  final IconData icon;
}

/// Coloured initials derived from the service name.
final class InitialsLogo extends LogoSource {
  const InitialsLogo(this.initials);
  final String initials;
}

/// Everything needed to draw a subscription's logo consistently.
@immutable
class SubscriptionBranding {
  const SubscriptionBranding({
    required this.name,
    required this.color,
    required this.logo,
    this.fallback,
  });

  /// Display name, used for semantics.
  final String name;

  /// Brand colour (or the category colour when no brand colour is known).
  final Color color;

  final LogoSource logo;

  /// Shown when [logo] is an asset or remote image that fails to load.
  final LogoSource? fallback;

  @override
  bool operator ==(Object other) =>
      other is SubscriptionBranding &&
      other.name == name &&
      other.color == color &&
      _sameSource(other.logo, logo);

  @override
  int get hashCode => Object.hash(name, color, logo.runtimeType);

  static bool _sameSource(LogoSource a, LogoSource b) => switch ((a, b)) {
    (SvgAssetLogo(:final assetPath), SvgAssetLogo(assetPath: final other)) =>
      assetPath == other,
    (
      RasterAssetLogo(:final assetPath),
      RasterAssetLogo(assetPath: final other),
    ) =>
      assetPath == other,
    (RemoteLogo(:final url), RemoteLogo(url: final other)) => url == other,
    (GlyphLogo(:final icon), GlyphLogo(icon: final other)) => icon == other,
    (InitialsLogo(:final initials), InitialsLogo(initials: final other)) =>
      initials == other,
    _ => false,
  };
}
